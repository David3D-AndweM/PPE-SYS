from django.conf import settings
from django.db import models
from django.utils import timezone

from core.models import TimeStampedModel


class ApprovalRole(models.TextChoices):
    MANAGER = "manager", "Manager"
    SAFETY = "safety", "Safety Officer"
    ADMIN = "admin", "Admin"


class ApprovalStatus(models.TextChoices):
    PENDING = "pending", "Pending"
    APPROVED = "approved", "Approved"
    REJECTED = "rejected", "Rejected"


class Approval(TimeStampedModel):
    """
    One record per required approval step for a PickingSlip.
    Multiple Approval rows per slip — one per entry in PPEConfiguration.approval_levels.
    """

    picking_slip = models.ForeignKey(
        "picking.PickingSlip",
        on_delete=models.CASCADE,
        related_name="approvals",
    )
    approver = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="approval_actions",
    )
    required_role = models.CharField(
        max_length=20,
        choices=ApprovalRole.choices,
        help_text="Which role must approve this step.",
    )
    is_required = models.BooleanField(default=True)
    status = models.CharField(
        max_length=20,
        choices=ApprovalStatus.choices,
        default=ApprovalStatus.PENDING,
        db_index=True,
    )
    comment = models.TextField(blank=True)
    actioned_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "approvals"
        ordering = ["created_at"]

    def __str__(self):
        return f"Approval [{self.required_role}] for slip {self.picking_slip_id} " f"— {self.status}"

    def mark_approved(self, approver, comment=""):
        self.approver = approver
        self.status = ApprovalStatus.APPROVED
        self.comment = comment
        self.actioned_at = timezone.now()
        self.save(update_fields=["approver", "status", "comment", "actioned_at", "updated_at"])

    def mark_rejected(self, approver, comment=""):
        self.approver = approver
        self.status = ApprovalStatus.REJECTED
        self.comment = comment
        self.actioned_at = timezone.now()
        self.save(update_fields=["approver", "status", "comment", "actioned_at", "updated_at"])
