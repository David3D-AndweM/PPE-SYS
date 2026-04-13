"""
Picking slip domain services — the most cross-cutting layer in the system.

Orchestrates: PPE → Approvals → Inventory → EmployeePPE → Audit → Notifications.
"""

import logging
from datetime import date

from django.db import transaction

from .models import PickingSlip, PickingSlipItem, RequestType, ScanLog, SlipStatus

logger = logging.getLogger(__name__)


def _ensure_manager_required(approval_levels):
    """
    Ensure a manager approval step exists and is required.
    approval_levels shape: [{"role": "manager", "required": true}, ...]
    """
    levels = list(approval_levels or [])
    if not any((lvl.get("role") == "manager") for lvl in levels):
        return [{"role": "manager", "required": True}] + levels
    # Force required=True if present
    for lvl in levels:
        if lvl.get("role") == "manager":
            lvl["required"] = True
    return levels


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
    from approvals.services import create_approvals_for_slip
    from core.utils.qr import generate_slip_qr_payload
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

    # Lost/damaged requests must always be explicitly approved by the manager.
    if request_type in (RequestType.LOST, RequestType.DAMAGED):
        approval_levels = _ensure_manager_required(approval_levels)

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


def build_auto_items_for_employee(employee, request_type):
    """
    Build the list of slip items automatically from:
    - DepartmentPPERequirement (required items for the employee's department)
    - EmployeePPE status (what is expired/expiring/pending)

    request_type:
      - new: include missing or pending_issue requirements
      - expiry: include expired or expiring_soon requirements
    """
    from ppe.models import DepartmentPPERequirement, EmployeePPE, EmployeePPEStatus

    requirements = (
        DepartmentPPERequirement.objects.filter(department=employee.department, is_required=True)
        .select_related("ppe_item")
        .all()
    )
    if not requirements:
        return []

    by_item_id = {
        str(ep.ppe_item_id): ep for ep in EmployeePPE.objects.filter(employee=employee).select_related("ppe_item").all()
    }

    items = []
    for req in requirements:
        ep = by_item_id.get(str(req.ppe_item_id))

        if request_type == RequestType.NEW:
            include = (ep is None) or (ep.status == EmployeePPEStatus.PENDING_ISSUE)
        else:
            include = (ep is None) or (ep.status in (EmployeePPEStatus.EXPIRED, EmployeePPEStatus.EXPIRING_SOON))

        if include:
            items.append({"ppe_item": req.ppe_item, "quantity": req.quantity})

    return items


@transaction.atomic
def create_auto_slip(employee, request_type, requested_by, notes="", warehouse=None):
    """
    Create a picking slip with system-generated items so employees don't have to
    select PPE manually for standard renewal/first-issue requests.
    """
    # request_type may be passed as string from serializer; normalize.
    if request_type in (RequestType.NEW, RequestType.EXPIRY, RequestType.LOST, RequestType.DAMAGED):
        normalized = request_type
    else:
        normalized = str(request_type)

    if normalized not in (RequestType.NEW, RequestType.EXPIRY):
        raise ValueError("Auto-create only supports request_type 'new' or 'expiry'.")

    # Prevent duplicate pending/approved auto-renewals cluttering the workflow.
    if PickingSlip.objects.filter(
        employee=employee,
        request_type=normalized,
        status__in=(SlipStatus.PENDING, SlipStatus.APPROVED),
    ).exists():
        raise ValueError("A request of this type is already pending/approved for this employee.")

    items = build_auto_items_for_employee(employee, request_type=normalized)
    if not items:
        raise ValueError("No PPE items require action for this employee.")

    return create_slip(
        employee=employee,
        ppe_items_with_qty=items,
        request_type=normalized,
        requested_by=requested_by,
        notes=notes,
        warehouse=warehouse,
    )


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

    from inventory.models import ReferenceType
    from inventory.services import deduct_stock
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
