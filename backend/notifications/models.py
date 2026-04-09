from django.conf import settings
from django.db import models

from core.models import UUIDModel


class NotificationType(models.TextChoices):
    EXPIRY = "expiry", "PPE Expiry"
    APPROVAL = "approval", "Approval Required"
    STOCK = "stock", "Low Stock"
    COMPLIANCE = "compliance", "Compliance Alert"
    SYSTEM = "system", "System"


class Notification(UUIDModel):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="notifications",
    )
    notification_type = models.CharField(
        max_length=20,
        choices=NotificationType.choices,
        db_index=True,
    )
    title = models.CharField(max_length=255)
    message = models.TextField()
    is_read = models.BooleanField(default=False, db_index=True)
    # Optional link back to the triggering entity
    entity_type = models.CharField(max_length=100, blank=True)
    entity_id = models.UUIDField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "notifications"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "is_read"]),
        ]

    def __str__(self):
        return f"[{self.notification_type}] {self.title} → {self.user.email}"
