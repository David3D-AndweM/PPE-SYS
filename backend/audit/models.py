from django.conf import settings
from django.db import models

from core.models import UUIDModel


class AuditImmutableError(Exception):
    """Raised when code attempts to mutate or delete an AuditLog record."""


class AuditLogQuerySet(models.QuerySet):
    def update(self, **kwargs):
        raise AuditImmutableError("AuditLog records are immutable and cannot be updated.")

    def delete(self):
        raise AuditImmutableError("AuditLog records are immutable and cannot be deleted.")


class AuditLogManager(models.Manager.from_queryset(AuditLogQuerySet)):
    pass


class AuditLog(UUIDModel):
    """
    Immutable audit trail. Every critical action in the system writes a row here.
    Records are never updated or deleted. Immutability is enforced at the ORM
    layer; raw SQL bypasses this guard.
    """

    objects = AuditLogManager()

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
    metadata = models.JSONField(default=dict)
    timestamp = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        db_table = "audit_logs"
        ordering = ["-timestamp"]
        indexes = [
            models.Index(fields=["entity_type", "entity_id"]),
            models.Index(fields=["user", "timestamp"]),
        ]

    def save(self, *args, **kwargs):
        if not self._state.adding:
            raise AuditImmutableError("AuditLog records are immutable and cannot be updated.")
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        raise AuditImmutableError("AuditLog records are immutable and cannot be deleted.")

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
