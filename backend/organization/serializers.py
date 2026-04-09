from rest_framework import serializers

from accounts.serializers import UserSerializer

from .models import Department, Employee, Organization, Site


class OrganizationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Organization
        fields = ["id", "name", "slug", "is_active", "created_at"]
        read_only_fields = ["id", "created_at"]


class SiteSerializer(serializers.ModelSerializer):
    organization_name = serializers.CharField(source="organization.name", read_only=True)

    class Meta:
        model = Site
        fields = ["id", "organization", "organization_name", "name", "location", "is_active"]
        read_only_fields = ["id"]


class DepartmentSerializer(serializers.ModelSerializer):
    site_name = serializers.CharField(source="site.name", read_only=True)
    manager_name = serializers.CharField(
        source="manager.get_full_name", read_only=True, default=None
    )
    safety_officer_name = serializers.CharField(
        source="safety_officer.get_full_name", read_only=True, default=None
    )

    class Meta:
        model = Department
        fields = [
            "id", "site", "site_name", "name",
            "manager", "manager_name",
            "safety_officer", "safety_officer_name",
            "is_active",
        ]
        read_only_fields = ["id"]


class EmployeeSerializer(serializers.ModelSerializer):
    user_email = serializers.CharField(source="user.email", read_only=True)
    full_name = serializers.CharField(source="user.get_full_name", read_only=True)
    department_name = serializers.CharField(source="department.name", read_only=True)
    site_name = serializers.CharField(source="site.name", read_only=True)

    class Meta:
        model = Employee
        fields = [
            "id", "user", "user_email", "full_name",
            "department", "department_name", "site_name",
            "mine_number", "role_title", "status",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]


class EmployeeTransferSerializer(serializers.Serializer):
    department_id = serializers.UUIDField()

    def validate_department_id(self, value):
        from .models import Department
        try:
            Department.objects.get(pk=value)
        except Department.DoesNotExist:
            raise serializers.ValidationError("Department not found.")
        return value
