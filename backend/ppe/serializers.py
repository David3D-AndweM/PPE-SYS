from rest_framework import serializers

from .models import (
    DepartmentPPERequirement,
    EmployeePPE,
    PPEConfiguration,
    PPEItem,
)


class PPEItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = PPEItem
        fields = [
            "id", "name", "category", "description",
            "is_critical", "default_validity_days",
            "requires_serial_tracking", "is_active",
        ]
        read_only_fields = ["id"]


class PPEConfigurationSerializer(serializers.ModelSerializer):
    ppe_item_name = serializers.CharField(source="ppe_item.name", read_only=True)

    class Meta:
        model = PPEConfiguration
        fields = [
            "id", "ppe_item", "ppe_item_name",
            "scope_type", "scope_id",
            "validity_days", "grace_days",
            "requires_approval", "approval_levels",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]


class DepartmentPPERequirementSerializer(serializers.ModelSerializer):
    ppe_item_name = serializers.CharField(source="ppe_item.name", read_only=True)
    department_name = serializers.CharField(source="department.name", read_only=True)

    class Meta:
        model = DepartmentPPERequirement
        fields = [
            "id", "department", "department_name",
            "ppe_item", "ppe_item_name",
            "is_required", "quantity",
        ]
        read_only_fields = ["id"]


class EmployeePPESerializer(serializers.ModelSerializer):
    ppe_item_name = serializers.CharField(source="ppe_item.name", read_only=True)
    ppe_item_category = serializers.CharField(source="ppe_item.category", read_only=True)
    is_critical = serializers.BooleanField(source="ppe_item.is_critical", read_only=True)
    employee_name = serializers.CharField(source="employee.user.get_full_name", read_only=True)
    mine_number = serializers.CharField(source="employee.mine_number", read_only=True)

    class Meta:
        model = EmployeePPE
        fields = [
            "id", "employee", "employee_name", "mine_number",
            "ppe_item", "ppe_item_name", "ppe_item_category", "is_critical",
            "issue_date", "expiry_date", "status",
            "last_inspection_date", "condition_status",
            "serial_number", "notes",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]
