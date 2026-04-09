from django.conf import settings
from django.db import models

from core.models import TimeStampedModel


class RequestType(models.TextChoices):
    EXPIRY = "expiry", "PPE Expired"
    LOST = "lost", "PPE Lost"
    DAMAGED = "damaged", "PPE Damaged"
    NEW = "new", "New Employee / First Issue"


class SlipStatus(models.TextChoices):
    PENDING = "pending", "Pending Approval"
    APPROVED = "approved", "Approved — Ready to Issue"
    ISSUED = "issued", "Issued"
    REJECTED = "rejected", "Rejected"
    CANCELLED = "cancelled", "Cancelled"


class PickingSlip(TimeStampedModel):
    """
    Central document driving the PPE issuing workflow.
    Lifecycle: pending → approved → issued (or rejected at any point).
    """

    employee = models.ForeignKey(
        "organization.Employee",
        on_delete=models.PROTECT,
        related_name="picking_slips",
    )
    department = models.ForeignKey(
        "organization.Department",
        on_delete=models.PROTECT,
        related_name="picking_slips",
    )
    request_type = models.CharField(max_length=20, choices=RequestType.choices)
    status = models.CharField(
        max_length=20,
        choices=SlipStatus.choices,
        default=SlipStatus.PENDING,
        db_index=True,
    )
    requested_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="requested_slips",
    )
    approved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="approved_slips",
    )
    issued_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="issued_slips",
    )
    approved_at = models.DateTimeField(null=True, blank=True)
    issued_at = models.DateTimeField(null=True, blank=True)
    # HMAC-signed QR payload (see core/utils/qr.py)
    qr_code = models.TextField(blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        db_table = "picking_slips"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["status"]),
            models.Index(fields=["employee"]),
        ]

    def __str__(self):
        return f"PickingSlip {self.id} [{self.status}] — {self.employee}"

    @property
    def slip_number(self):
        """Human-readable short reference using the first 8 chars of the UUID."""
        return str(self.id).upper()[:8]


class PickingSlipItem(TimeStampedModel):
    picking_slip = models.ForeignKey(PickingSlip, on_delete=models.CASCADE, related_name="items")
    ppe_item = models.ForeignKey("ppe.PPEItem", on_delete=models.PROTECT, related_name="slip_items")
    quantity = models.PositiveIntegerField(default=1)
    # Set by finalize_issue — which warehouse the stock was pulled from
    warehouse = models.ForeignKey(
        "inventory.Warehouse",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )

    class Meta:
        db_table = "picking_slip_items"
        unique_together = [("picking_slip", "ppe_item")]

    def __str__(self):
        return f"{self.quantity}× {self.ppe_item.name} (slip {self.picking_slip.slip_number})"


class ScanLog(TimeStampedModel):
    """Records each QR scan event — both slip scans and item scans."""

    VALID = "valid"
    MISMATCH = "mismatch"
    EXPIRED = "expired"
    STATUS_CHOICES = [
        (VALID, "Valid"),
        (MISMATCH, "Mismatch"),
        (EXPIRED, "Expired Slip"),
    ]

    picking_slip = models.ForeignKey(
        PickingSlip,
        on_delete=models.CASCADE,
        related_name="scan_logs",
        null=True,
        blank=True,
    )
    ppe_item = models.ForeignKey(
        "ppe.PPEItem",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="scan_logs",
    )
    scanned_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="scan_logs",
    )
    raw_data = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=VALID)
    scan_time = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "scan_logs"
        ordering = ["-scan_time"]
