"""
Pre-expiry alert scheduler.
Sends targeted warnings at 7, 3, and 1 day before expiry.
"""

import logging
from datetime import date, timedelta

from celery import shared_task
from django.conf import settings

logger = logging.getLogger(__name__)


@shared_task(name="celery_tasks.alert_scheduler.send_pre_expiry_alerts")
def send_pre_expiry_alerts():
    """
    For each configured alert threshold, find PPE expiring on exactly
    that day and send a targeted warning notification.
    """
    from notifications.models import NotificationType
    from notifications.services import dispatch
    from ppe.models import EmployeePPE, EmployeePPEStatus

    today = date.today()
    thresholds = getattr(settings, "PPE_ALERT_THRESHOLDS_DAYS", [7, 3, 1])

    total_sent = 0

    for days in thresholds:
        target_date = today + timedelta(days=days)
        expiring = EmployeePPE.objects.filter(
            expiry_date=target_date,
            status__in=[EmployeePPEStatus.VALID, EmployeePPEStatus.EXPIRING_SOON],
        ).select_related("employee__user", "ppe_item")

        for emp_ppe in expiring:
            try:
                dispatch(
                    user=emp_ppe.employee.user,
                    notification_type=NotificationType.EXPIRY,
                    title=f"⏰ PPE Expiry Reminder: {emp_ppe.ppe_item.name}",
                    message=(
                        f"Your {emp_ppe.ppe_item.name} expires in {days} day(s) "
                        f"(on {emp_ppe.expiry_date}). Please arrange a replacement."
                    ),
                    entity_type="EmployeePPE",
                    entity_id=emp_ppe.id,
                )
                total_sent += 1
            except Exception:
                logger.exception("Failed to send pre-expiry alert for %s", emp_ppe.id)

    logger.info("Pre-expiry alerts sent: %d", total_sent)
    return {"status": "completed", "alerts_sent": total_sent, "date": today.isoformat()}
