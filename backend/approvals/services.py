"""
Approval workflow services.
"""

import logging

from django.db import transaction

from .models import Approval, ApprovalStatus

logger = logging.getLogger(__name__)


def create_approvals_for_slip(picking_slip, approval_levels):
    """
    Create pending Approval records for a PickingSlip based on
    the approval_levels list from PPEConfiguration.

    approval_levels example:
    [{"role": "manager", "required": True}, {"role": "safety", "required": True}]
    """
    # Business rule: department manager is the single approval authority.
    approval = Approval.objects.create(
        picking_slip=picking_slip,
        required_role="manager",
        is_required=True,
        status=ApprovalStatus.PENDING,
    )
    _notify_approvers(picking_slip, [{"role": "manager", "required": True}])
    return [approval]


@transaction.atomic
def approve(approval_id, user, comment=""):
    """
    Mark an approval record as approved.
    After approval, check if all required steps are done.
    Raises PermissionError if the user doesn't hold the required role.
    """
    approval = (
        Approval.objects.select_for_update()
        .select_related(
            "picking_slip__employee__user",
            "picking_slip__employee__department__site",
        )
        .get(pk=approval_id)
    )

    _validate_approver_role(approval, user)

    if approval.status != ApprovalStatus.PENDING:
        raise ValueError(f"This approval step is already {approval.status}.")

    approval.mark_approved(user, comment)
    logger.info("Approval %s approved by %s", approval_id, user.email)

    from audit.models import log_action

    log_action(
        action="approval_approved",
        entity_type="Approval",
        entity_id=approval.id,
        metadata={"slip_id": str(approval.picking_slip_id), "comment": comment},
        user=user,
    )

    check_all_approved(approval.picking_slip)
    return approval


@transaction.atomic
def reject(approval_id, user, comment=""):
    """
    Mark an approval as rejected. The entire PickingSlip is immediately rejected.
    """
    approval = Approval.objects.select_for_update().select_related("picking_slip").get(pk=approval_id)
    _validate_approver_role(approval, user)

    approval.mark_rejected(user, comment)

    # Reject the whole slip immediately
    slip = approval.picking_slip
    slip.status = "rejected"
    slip.save(update_fields=["status", "updated_at"])

    from audit.models import log_action

    log_action(
        action="approval_rejected",
        entity_type="Approval",
        entity_id=approval.id,
        metadata={"slip_id": str(slip.id), "comment": comment},
        user=user,
    )

    # Notify requester
    try:
        from notifications.models import NotificationType
        from notifications.services import dispatch

        dispatch(
            user=slip.requested_by,
            notification_type=NotificationType.APPROVAL,
            title="PPE Request Rejected",
            message=(
                f"Your PPE request for {slip.employee.user.get_full_name()} "
                f"was rejected by {user.get_full_name()}. Reason: {comment or 'No reason given.'}"
            ),
            entity_type="PickingSlip",
            entity_id=slip.id,
        )
    except Exception:
        logger.exception("Failed to send rejection notification")

    return approval


def check_all_approved(picking_slip):
    """
    After each approval action, check if all required approvals are done.
    If yes, mark the slip as approved and notify store officers.
    """
    required = Approval.objects.filter(picking_slip=picking_slip, is_required=True)
    all_approved = required.filter(status=ApprovalStatus.APPROVED).count() == required.count()

    if all_approved and picking_slip.status == "pending":
        from django.utils import timezone

        picking_slip.status = "approved"
        picking_slip.approved_at = timezone.now()
        picking_slip.save(update_fields=["status", "approved_at", "updated_at"])

        logger.info("PickingSlip %s fully approved", picking_slip.id)

        from audit.models import log_action

        log_action(
            action="picking_slip_approved",
            entity_type="PickingSlip",
            entity_id=picking_slip.id,
            metadata={"employee": str(picking_slip.employee_id)},
        )

        _notify_store_officers(picking_slip)


def _validate_approver_role(approval, user):
    """Ensure the user holds the required role for this approval step."""
    roles = list(user.user_roles.values_list("role__name", flat=True))
    role_map = {
        "manager": "Manager",
        "safety": "Safety",
        "admin": "Admin",
    }
    required = role_map.get(approval.required_role, approval.required_role.capitalize())
    if required not in roles and not user.is_superuser:
        raise PermissionError(f"You must hold the {required} role to perform this approval.")

    # Department manager ownership check for manager approvals.
    if approval.required_role == "manager" and not user.is_superuser:
        dept_manager_id = approval.picking_slip.department.manager_id
        if dept_manager_id != user.id:
            raise PermissionError("Only the assigned department manager can approve this request.")


def _notify_approvers(picking_slip, approval_levels):
    """Notify relevant role holders that an approval is pending."""
    try:
        from notifications.models import NotificationType
        from notifications.services import dispatch_to_role

        employee_name = picking_slip.employee.user.get_full_name()
        site = picking_slip.employee.site

        for level in approval_levels:
            role_name = level.get("role", "manager").capitalize()
            if role_name == "Safety":
                role_name = "Safety"

            dispatch_to_role(
                site=site,
                role_name=role_name,
                notification_type=NotificationType.APPROVAL,
                title="PPE Approval Required",
                message=(
                    f"PPE request for {employee_name} requires your approval. "
                    f"Request type: {picking_slip.request_type}."
                ),
            )
    except Exception:
        logger.exception("Failed to notify approvers for slip %s", picking_slip.id)


def _notify_store_officers(picking_slip):
    """Tell store officers that a slip is ready to issue."""
    try:
        from notifications.models import NotificationType
        from notifications.services import dispatch_to_role

        employee_name = picking_slip.employee.user.get_full_name()
        site = picking_slip.employee.site

        dispatch_to_role(
            site=site,
            role_name="Store",
            notification_type=NotificationType.APPROVAL,
            title="PPE Request Ready for Issue",
            message=(
                f"PPE request for {employee_name} has been fully approved "
                f"and is ready for issue. Scan the picking slip QR to proceed."
            ),
        )
    except Exception:
        logger.exception("Failed to notify store officers for slip %s", picking_slip.id)
