from rest_framework import serializers

from .models import Approval


class ApprovalSerializer(serializers.ModelSerializer):
    approver_name = serializers.CharField(source="approver.get_full_name", read_only=True, default=None)
    slip_employee_name = serializers.CharField(source="picking_slip.employee.user.get_full_name", read_only=True)
    slip_request_type = serializers.CharField(source="picking_slip.request_type", read_only=True)
    slip_department_name = serializers.CharField(source="picking_slip.department.name", read_only=True)
    slip_mine_number = serializers.CharField(source="picking_slip.employee.mine_number", read_only=True)
    slip_item_count = serializers.SerializerMethodField()

    def get_slip_item_count(self, obj):
        return obj.picking_slip.items.count()

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
            "slip_request_type",
            "slip_department_name",
            "slip_mine_number",
            "slip_item_count",
            "created_at",
        ]
        read_only_fields = ["id", "created_at", "actioned_at"]


class ApprovalActionSerializer(serializers.Serializer):
    comment = serializers.CharField(required=False, allow_blank=True)
