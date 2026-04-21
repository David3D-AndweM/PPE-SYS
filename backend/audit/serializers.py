from rest_framework import serializers

from .models import AuditLog


class AuditLogSerializer(serializers.ModelSerializer):
    user_email = serializers.CharField(source="user.email", read_only=True, default=None)
    user_name = serializers.SerializerMethodField()

    class Meta:
        model = AuditLog
        fields = [
            "id",
            "user",
            "user_email",
            "user_name",
            "action",
            "entity_type",
            "entity_id",
            "ip_address",
            "metadata",
            "timestamp",
        ]
        read_only_fields = fields

    def get_user_name(self, obj) -> str | None:
        if obj.user is None:
            return None
        full_name = obj.user.get_full_name().strip()
        return full_name or obj.user.email
