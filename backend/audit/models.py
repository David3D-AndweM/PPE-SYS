from django.conf import settings
from django.db import models

from core.models import UUIDModel


class AuditLog(UUIDModel):
    """
    Immutable audit trail. Every critical action in the system writes a row here.
    Records are never updated or deleted.
    """

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="audit_logs",
    )
    action = models.CharField(max_length=100, db_index=True)
    entity_type = models.CharField(max_length=100, db_index=True)
    entity_id = models.UUIDField(null=True, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    # JSONB: arbitrary context (before/after state, related IDs, etc.)
    metadata = models.JSONField(default=dict)
    timestamp = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        db_table = "audit_logs"
        ordering = ["-timestamp"]
        indexes = [
            models.Index(fields=["entity_type", "entity_id"]),
            models.Index(fields=["user", "timestamp"]),
        ]

    def __str__(self):
        user_str = self.user.email if self.user else "system"
        return f"[{self.timestamp:%Y-%m-%d %H:%M}] {user_str} — {self.action} on {self.entity_type}"


def log_action(action, entity_type, entity_id=None, metadata=None, user=None, ip_address=None):
    """
    Convenience function for writing an audit log entry.
    Falls back to thread-local request context for user/IP if not provided.
    """
    from core.middleware import get_current_ip, get_current_user

    if user is None:
        user = get_current_user()
        if user and not user.is_authenticated:
            user = None

    if ip_address is None:
        ip_address = get_current_ip()

    return AuditLog.objects.create(
        user=user,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        ip_address=ip_address,
        metadata=metadata or {},
    )
