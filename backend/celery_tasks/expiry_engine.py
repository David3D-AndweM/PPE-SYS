"""
Expiry Engine — runs daily via Celery beat.

Marks EmployeePPE records as expired or expiring_soon, then dispatches
notifications to employees, managers, safety officers, and (for critical
PPE) site admins.

Uses a Redis distributed lock to ensure only one worker runs this at a time.
"""

import logging
from datetime import date, timedelta

from celery import shared_task
from django.conf import settings

logger = logging.getLogger(__name__)

LOCK_KEY = "ppe:expiry_engine:lock"
LOCK_TTL = 3600  # 1 hour — task should never take this long


@shared_task(name="celery_tasks.expiry_engine.run_expiry_check", bind=True, max_retries=0)
def run_expiry_check(self):
    """
    Main expiry engine task. Acquires a Redis lock before processing.
    """
    from django.core.cache import cache

    lock = cache.lock(LOCK_KEY, timeout=LOCK_TTL)
    if not lock.acquire(blocking=False):
        logger.warning("Expiry engine already running — skipping this run")
        return {"status": "skipped", "reason": "lock_held"}

    try:
        return _run_expiry_check_logic()
    finally:
        try:
            lock.release()
        except Exception:
            pass


def _run_expiry_check_logic():
    from django.conf import settings as s

    chunk_size = getattr(s, "CELERY_BULK_CHUNK_SIZE", 500)
    today = date.today()

    expired_count = _mark_expired(today, chunk_size)
    expiring_count = _mark_expiring_soon(today, chunk_size)

    result = {
        "status": "completed",
        "date": today.isoformat(),
        "expired_count": expired_count,
        "expiring_soon_count": expiring_count,
    }

    from audit.models import log_action
    log_action(
        action="expiry_engine_run",
        entity_type="System",
        metadata=result,
    )

    logger.info("Expiry engine completed: %s", result)
    return result


def _mark_expired(today, chunk_size):
    """Mark all valid/expiring PPE that has passed its expiry date."""
    from ppe.models import EmployeePPE, EmployeePPEStatus

    qs = EmployeePPE.objects.filter(
        status__in=[EmployeePPEStatus.VALID, EmployeePPEStatus.EXPIRING_SOON],
        expiry_date__lt=today,
    ).select_related(
        "employee__user",
        "employee__department__site",
        "ppe_item",
    )

    total = 0
    ids_to_update = []

    for emp_ppe in qs.iterator(chunk_size=chunk_size):
        ids_to_update.append(emp_ppe.id)
        _notify_expiry(emp_ppe, "expired")

        if len(ids_to_update) >= chunk_size:
            EmployeePPE.objects.filter(id__in=ids_to_update).update(
                status=EmployeePPEStatus.EXPIRED
            )
            total += len(ids_to_update)
            ids_to_update = []

    if ids_to_update:
        EmployeePPE.objects.filter(id__in=ids_to_update).update(
            status=EmployeePPEStatus.EXPIRED
        )
        total += len(ids_to_update)

    return total


def _mark_expiring_soon(today, chunk_size):
    """
    Mark valid PPE as 'expiring_soon' based on each item's grace_days config.
    Uses the system-level alert thresholds for simplicity.
    """
    from ppe.models import EmployeePPE, EmployeePPEStatus

    alert_days = getattr(settings, "PPE_ALERT_THRESHOLDS_DAYS", [7])
    max_days = max(alert_days)

    qs = EmployeePPE.objects.filter(
        status=EmployeePPEStatus.VALID,
        expiry_date__gte=today,
        expiry_date__lte=today + timedelta(days=max_days),
    ).select_related(
        "employee__user",
        "employee__department__site",
        "ppe_item",
    )

    total = 0
    ids_to_update = []

    for emp_ppe in qs.iterator(chunk_size=chunk_size):
        ids_to_update.append(emp_ppe.id)
        _notify_expiry(emp_ppe, "expiring_soon")

        if len(ids_to_update) >= chunk_size:
            EmployeePPE.objects.filter(id__in=ids_to_update).update(
                status=EmployeePPEStatus.EXPIRING_SOON
            )
            total += len(ids_to_update)
            ids_to_update = []

    if ids_to_update:
        EmployeePPE.objects.filter(id__in=ids_to_update).update(
            status=EmployeePPEStatus.EXPIRING_SOON
        )
        total += len(ids_to_update)

    return total


def _notify_expiry(emp_ppe, event_type):
    """Dispatch notifications for a single expiry event."""
    try:
        from notifications.models import NotificationType
        from notifications.services import dispatch, dispatch_to_role

        employee = emp_ppe.employee
        ppe_name = emp_ppe.ppe_item.name
        is_critical = emp_ppe.ppe_item.is_critical
        site = employee.department.site

        if event_type == "expired":
            title = f"PPE Expired: {ppe_name}"
            message = (
                f"Your {ppe_name} expired on {emp_ppe.expiry_date}. "
                f"A replacement request should be submitted immediately."
            )
            if is_critical:
                message += " ⚠ This is a CRITICAL item."
        else:
            days_remaining = (emp_ppe.expiry_date - date.today()).days
            title = f"PPE Expiring Soon: {ppe_name}"
            message = (
                f"Your {ppe_name} expires on {emp_ppe.expiry_date} "
                f"({days_remaining} day(s) remaining)."
            )

        # Notify employee
        dispatch(
            user=employee.user,
            notification_type=NotificationType.EXPIRY,
            title=title,
            message=message,
            entity_type="EmployeePPE",
            entity_id=emp_ppe.id,
        )

        # Notify department manager and safety officer
        for officer_user in [employee.department.manager, employee.department.safety_officer]:
            if officer_user:
                dispatch(
                    user=officer_user,
                    notification_type=NotificationType.COMPLIANCE,
                    title=f"[{employee.mine_number}] {title}",
                    message=f"Employee: {employee.user.get_full_name()}. {message}",
                    entity_type="EmployeePPE",
                    entity_id=emp_ppe.id,
                )

        # For critical expired items, also notify site Admins
        if event_type == "expired" and is_critical:
            dispatch_to_role(
                site=site,
                role_name="Admin",
                notification_type=NotificationType.COMPLIANCE,
                title=f"[CRITICAL] PPE Expired: {ppe_name}",
                message=(
                    f"{employee.user.get_full_name()} [{employee.mine_number}] "
                    f"has an expired critical PPE item: {ppe_name}."
                ),
            )

    except Exception:
        logger.exception("Failed to notify expiry for EmployeePPE %s", emp_ppe.id)
