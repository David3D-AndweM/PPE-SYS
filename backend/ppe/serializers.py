from rest_framework import serializers

from .models import (
    DepartmentPPERequirement,
    EmployeePPE,
    PPEConfiguration,
    PPEItem,
)


def _user_can_manage_department(user, department) -> bool:
    if not user or not user.is_authenticated:
        return False
    if user.is_superuser:
        return True
    roles = set(user.get_roles())
    if "Admin" in roles:
        return True
    # Safety owns department PPE standards across departments.
    if "Safety" in roles:
        return True
    if "Manager" in roles and getattr(department, "manager_id", None) == user.id:
        return True

    # Fallback: allow if role is explicitly scoped to this department or its site.
    # (UserRole supports site/department scoping.)
    try:
        if user.user_roles.filter(role__name__in=["Manager", "Safety"], department=department).exists():
            return True
        if user.user_roles.filter(role__name__in=["Manager", "Safety"], site=department.site).exists():
            return True
    except Exception:
        return False

    return False


class PPEItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = PPEItem
        fields = [
            "id",
            "name",
            "category",
            "description",
            "is_critical",
            "default_validity_days",
            "requires_serial_tracking",
            "image",
            "is_active",
        ]
        read_only_fields = ["id"]


class PPEConfigurationSerializer(serializers.ModelSerializer):
    ppe_item_name = serializers.CharField(source="ppe_item.name", read_only=True)

    class Meta:
        model = PPEConfiguration
        fields = [
            "id",
            "ppe_item",
            "ppe_item_name",
            "scope_type",
            "scope_id",
            "validity_days",
            "grace_days",
            "requires_approval",
            "approval_levels",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]

    def validate(self, attrs):
        request = self.context.get("request")
        user = getattr(request, "user", None)
        if not user or not user.is_authenticated:
            return attrs

        if user.is_superuser or "Admin" in set(user.get_roles()):
            return attrs

        # Non-admins may only manage department-scoped configurations for departments they manage/own.
        scope_type = attrs.get("scope_type", getattr(self.instance, "scope_type", None))
        scope_id = attrs.get("scope_id", getattr(self.instance, "scope_id", None))
        if scope_type != "department" or not scope_id:
            raise serializers.ValidationError("Only Admin can create/update system or site scoped PPE configurations.")

        from organization.models import Department

        try:
            dept = Department.objects.select_related("site").get(pk=scope_id)
        except Department.DoesNotExist as exc:
            raise serializers.ValidationError("Invalid department scope_id.") from exc

        if not _user_can_manage_department(user, dept):
            raise serializers.ValidationError("You are not allowed to manage PPE configuration for this department.")

        return attrs


class DepartmentPPERequirementSerializer(serializers.ModelSerializer):
    ppe_item_name = serializers.CharField(source="ppe_item.name", read_only=True)
    department_name = serializers.CharField(source="department.name", read_only=True)

    class Meta:
        model = DepartmentPPERequirement
        fields = [
            "id",
            "department",
            "department_name",
            "ppe_item",
            "ppe_item_name",
            "is_required",
            "quantity",
        ]
        read_only_fields = ["id"]

    def validate_department(self, department):
        request = self.context.get("request")
        user = getattr(request, "user", None)
        if not user or not user.is_authenticated:
            return department
        if user.is_superuser or "Admin" in set(user.get_roles()):
            return department
        if not _user_can_manage_department(user, department):
            raise serializers.ValidationError("You are not allowed to manage PPE requirements for this department.")
        return department


class EmployeePPESerializer(serializers.ModelSerializer):
    ppe_item_name = serializers.CharField(source="ppe_item.name", read_only=True)
    ppe_item_category = serializers.CharField(source="ppe_item.category", read_only=True)
    is_critical = serializers.BooleanField(source="ppe_item.is_critical", read_only=True)
    employee_name = serializers.CharField(source="employee.user.get_full_name", read_only=True)
    mine_number = serializers.CharField(source="employee.mine_number", read_only=True)
    department_name = serializers.CharField(source="employee.department.name", read_only=True)
    site_name = serializers.CharField(source="employee.department.site.name", read_only=True)

    class Meta:
        model = EmployeePPE
        fields = [
            "id",
            "employee",
            "employee_name",
            "mine_number",
            "department_name",
            "site_name",
            "ppe_item",
            "ppe_item_name",
            "ppe_item_category",
            "is_critical",
            "issue_date",
            "expiry_date",
            "status",
            "last_inspection_date",
            "condition_status",
            "serial_number",
            "notes",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]
