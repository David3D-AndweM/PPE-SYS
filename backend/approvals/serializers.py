from rest_framework import serializers

from .models import Approval


class ApprovalSerializer(serializers.ModelSerializer):
    approver_name = serializers.CharField(source="approver.get_full_name", read_only=True, default=None)
    slip_employee_name = serializers.CharField(source="picking_slip.employee.user.get_full_name", read_only=True)

    class Meta:
        model = Approval
        fields = [
            "id",
            "picking_slip",
            "approver",
            "approver_name",
            "required_role",
            "is_required",
            "status",
            "comment",
            "actioned_at",
            "slip_employee_name",
            "created_at",
        ]
        read_only_fields = ["id", "created_at", "actioned_at"]


class ApprovalActionSerializer(serializers.Serializer):
    comment = serializers.CharField(required=False, allow_blank=True)
