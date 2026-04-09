"""
Picking slip domain services — the most cross-cutting layer in the system.

Orchestrates: PPE → Approvals → Inventory → EmployeePPE → Audit → Notifications.
"""

import logging
from datetime import date

from django.db import transaction

from .models import PickingSlip, PickingSlipItem, ScanLog, SlipStatus

logger = logging.getLogger(__name__)


@transaction.atomic
def create_slip(employee, ppe_items_with_qty, request_type, requested_by, notes="", warehouse=None):
    """
    Create a PickingSlip for an employee.

    ppe_items_with_qty: list of {"ppe_item": PPEItem, "quantity": int}

    Reads approval_levels from the highest-priority PPEConfiguration
    for the items in the slip, creates the slip and items, then creates
    pending Approval records and notifies approvers.

    Returns the created PickingSlip.
    """
    from core.utils.qr import generate_slip_qr_payload
    from approvals.services import create_approvals_for_slip
    from ppe.services import resolve_ppe_config

    slip = PickingSlip.objects.create(
        employee=employee,
        department=employee.department,
        request_type=request_type,
        status=SlipStatus.PENDING,
        requested_by=requested_by,
        notes=notes,
    )

    # Generate HMAC-signed QR payload
    slip.qr_code = generate_slip_qr_payload(str(slip.id))
    slip.save(update_fields=["qr_code"])

    # Create slip items
    for entry in ppe_items_with_qty:
        PickingSlipItem.objects.create(
            picking_slip=slip,
            ppe_item=entry["ppe_item"],
            quantity=entry.get("quantity", 1),
            warehouse=warehouse,
        )

    # Determine approval levels from the most critical item's config
    # (take the config with the most approval steps as the governing config)
    approval_levels = _determine_approval_levels(ppe_items_with_qty, employee.department)

    if approval_levels:
        create_approvals_for_slip(slip, approval_levels)
    else:
        # No approval required — auto-approve
        slip.status = SlipStatus.APPROVED
        from django.utils import timezone

        slip.approved_at = timezone.now()
        slip.save(update_fields=["status", "approved_at"])

    from audit.models import log_action

    log_action(
        action="picking_slip_created",
        entity_type="PickingSlip",
        entity_id=slip.id,
        metadata={
            "employee": str(employee.id),
            "request_type": request_type,
            "items_count": len(ppe_items_with_qty),
        },
        user=requested_by,
    )

    logger.info(
        "PickingSlip %s created for employee %s (%s items)",
        slip.id,
        employee.mine_number,
        len(ppe_items_with_qty),
    )
    return slip


def validate_scan(raw_qr_data, scanned_by):
    """
    Decode and verify a QR payload, then return the slip details.
    Logs the scan event regardless of outcome.
    Raises ValueError for invalid/expired slips.
    """
    from core.utils.qr import verify_slip_qr_payload

    log_entry = ScanLog(scanned_by=scanned_by, raw_data=raw_qr_data[:500])

    try:
        payload = verify_slip_qr_payload(raw_qr_data)
    except ValueError as exc:
        log_entry.status = ScanLog.MISMATCH
        log_entry.save()
        raise ValueError(f"Invalid QR code: {exc}") from exc

    slip_id = payload.get("slip_id")
    try:
        slip = (
            PickingSlip.objects.select_related("employee__user", "employee__department__site")
            .prefetch_related("items__ppe_item", "approvals")
            .get(pk=slip_id)
        )
    except PickingSlip.DoesNotExist:
        log_entry.status = ScanLog.MISMATCH
        log_entry.save()
        raise ValueError(f"Picking slip {slip_id} not found.")

    log_entry.picking_slip = slip

    if slip.status != SlipStatus.APPROVED:
        log_entry.status = ScanLog.EXPIRED
        log_entry.save()
        raise ValueError(f"This picking slip is {slip.status} and cannot be issued.")

    log_entry.status = ScanLog.VALID
    log_entry.save()

    return slip


@transaction.atomic
def finalize_issue(slip, store_officer, warehouse):
    """
    Execute the physical issue of all items on a PickingSlip.

    For each item:
    1. Deduct stock from the warehouse
    2. Update EmployeePPE (new issue date, expiry date, status = valid)

    Then:
    3. Mark slip as issued
    4. Write audit log

    Raises ValueError if stock is insufficient.
    """
    from datetime import date

    from django.utils import timezone

    from inventory.services import deduct_stock
    from inventory.models import ReferenceType
    from ppe.services import update_ppe_after_issue

    if slip.status != SlipStatus.APPROVED:
        raise ValueError(f"Cannot issue a slip with status '{slip.status}'.")

    today = date.today()
    items = slip.items.select_related("ppe_item").all()

    for slip_item in items:
        # Deduct stock
        deduct_stock(
            ppe_item=slip_item.ppe_item,
            warehouse=warehouse,
            quantity=slip_item.quantity,
            reference_type=ReferenceType.ISSUE,
            reference_id=slip.id,
            performed_by=store_officer,
        )
        # Update EmployeePPE
        from ppe.models import EmployeePPE

        try:
            emp_ppe = EmployeePPE.objects.get(
                employee=slip.employee,
                ppe_item=slip_item.ppe_item,
            )
        except EmployeePPE.DoesNotExist:
            emp_ppe = EmployeePPE(
                employee=slip.employee,
                ppe_item=slip_item.ppe_item,
            )

        update_ppe_after_issue(emp_ppe, today)

        # Record the warehouse on the slip item for traceability
        slip_item.warehouse = warehouse
        slip_item.save(update_fields=["warehouse"])

    # Mark slip as issued
    slip.status = SlipStatus.ISSUED
    slip.issued_by = store_officer
    slip.issued_at = timezone.now()
    slip.save(update_fields=["status", "issued_by", "issued_at", "updated_at"])

    from audit.models import log_action

    log_action(
        action="picking_slip_issued",
        entity_type="PickingSlip",
        entity_id=slip.id,
        metadata={
            "issued_by": str(store_officer.id),
            "warehouse": str(warehouse.id),
            "employee": str(slip.employee_id),
        },
        user=store_officer,
    )

    # Notify employee
    try:
        from notifications.models import NotificationType
        from notifications.services import dispatch

        dispatch(
            user=slip.employee.user,
            notification_type=NotificationType.COMPLIANCE,
            title="PPE Issued",
            message=(
                f"Your PPE request has been fulfilled. "
                f"{slip.items.count()} item(s) issued by "
                f"{store_officer.get_full_name()}."
            ),
            entity_type="PickingSlip",
            entity_id=slip.id,
        )
    except Exception:
        logger.exception("Failed to notify employee of PPE issue")

    logger.info("PickingSlip %s issued by %s", slip.id, store_officer.email)
    return slip


def _determine_approval_levels(ppe_items_with_qty, department):
    """
    Find the most stringent approval_levels across all items in the slip.
    Most stringent = highest number of required approval steps.
    """
    from ppe.services import resolve_ppe_config

    best_levels = []
    for entry in ppe_items_with_qty:
        config = resolve_ppe_config(entry["ppe_item"], department)
        levels = config.get("approval_levels", [])
        if len(levels) > len(best_levels):
            best_levels = levels
    return best_levels
