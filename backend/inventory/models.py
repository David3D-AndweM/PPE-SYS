from django.conf import settings
from django.db import models

from core.models import TimeStampedModel
from core.utils.validators import validate_positive


class Warehouse(TimeStampedModel):
    site = models.ForeignKey(
        "organization.Site", on_delete=models.CASCADE, related_name="warehouses"
    )
    name = models.CharField(max_length=255)
    location_description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = "warehouses"
        unique_together = [("site", "name")]

    def __str__(self):
        return f"{self.name} ({self.site.name})"


class StockItem(TimeStampedModel):
    """Current stock level of a PPE item in a warehouse."""

    ppe_item = models.ForeignKey(
        "ppe.PPEItem", on_delete=models.PROTECT, related_name="stock_items"
    )
    warehouse = models.ForeignKey(
        Warehouse, on_delete=models.CASCADE, related_name="stock_items"
    )
    quantity_available = models.PositiveIntegerField(default=0, validators=[validate_positive])
    reorder_level = models.PositiveIntegerField(
        default=10,
        help_text="Alert is triggered when quantity_available drops to or below this value.",
    )

    class Meta:
        db_table = "stock_items"
        unique_together = [("ppe_item", "warehouse")]
        indexes = [
            models.Index(fields=["warehouse"]),
        ]

    def __str__(self):
        return f"{self.ppe_item.name} @ {self.warehouse.name} ({self.quantity_available} available)"

    @property
    def is_at_reorder_level(self):
        return self.quantity_available <= self.reorder_level


class ChangeType(models.TextChoices):
    IN = "IN", "Stock In"
    OUT = "OUT", "Stock Out"


class ReferenceType(models.TextChoices):
    ISSUE = "ISSUE", "PPE Issue"
    RETURN = "RETURN", "PPE Return"
    ADJUSTMENT = "ADJUSTMENT", "Manual Adjustment"
    INITIAL = "INITIAL", "Initial Stock"


class StockMovement(TimeStampedModel):
    """Immutable log of every stock change. Never update — only append."""

    ppe_item = models.ForeignKey(
        "ppe.PPEItem", on_delete=models.PROTECT, related_name="stock_movements"
    )
    warehouse = models.ForeignKey(
        Warehouse, on_delete=models.CASCADE, related_name="stock_movements"
    )
    change_type = models.CharField(max_length=5, choices=ChangeType.choices)
    quantity = models.PositiveIntegerField(validators=[validate_positive])
    reference_type = models.CharField(max_length=20, choices=ReferenceType.choices)
    reference_id = models.UUIDField(null=True, blank=True)
    performed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="stock_movements",
    )
    notes = models.TextField(blank=True)

    class Meta:
        db_table = "stock_movements"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.change_type} {self.quantity}× {self.ppe_item.name} @ {self.warehouse.name}"
