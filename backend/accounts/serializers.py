from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

from .models import Role, User, UserRole


class RoleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Role
        fields = ["id", "name", "description"]


class UserRoleSerializer(serializers.ModelSerializer):
    role_name = serializers.CharField(source="role.name", read_only=True)
    site_name = serializers.CharField(source="site.name", read_only=True, default=None)
    department_name = serializers.CharField(source="department.name", read_only=True, default=None)

    class Meta:
        model = UserRole
        fields = ["id", "role", "role_name", "site", "site_name", "department", "department_name"]

    def validate(self, attrs):
        role = attrs.get("role")
        department = attrs.get("department")
        site = attrs.get("site")
        role_name = (role.name if role else "").strip()

        # Enforce department-scoped identity for all operational roles.
        if role_name != "Admin" and department is None:
            raise serializers.ValidationError({"department": "Department is required for non-admin roles."})

        if department is not None:
            department_site = department.site
            if site is not None and site.id != department_site.id:
                raise serializers.ValidationError({"site": "Selected site does not match the selected department."})
            # Auto-populate scope site from department if omitted.
            attrs["site"] = department_site

        return attrs


class UserSerializer(serializers.ModelSerializer):
    user_roles = UserRoleSerializer(many=True, read_only=True)
    full_name = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id",
            "email",
            "first_name",
            "last_name",
            "full_name",
            "profile_image",
            "is_active",
            "date_joined",
            "user_roles",
        ]
        read_only_fields = ["id", "date_joined"]

    def get_full_name(self, obj):
        return obj.get_full_name()


class UserCreateSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    confirm_password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ["id", "email", "first_name", "last_name", "password", "confirm_password"]
        read_only_fields = ["id"]

    def validate(self, attrs):
        if attrs["password"] != attrs.pop("confirm_password"):
            raise serializers.ValidationError({"confirm_password": "Passwords do not match."})
        validate_password(attrs["password"])
        return attrs

    def create(self, validated_data):
        return User.objects.create_user(**validated_data)


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(required=True)
    new_password = serializers.CharField(required=True)

    def validate_new_password(self, value):
        validate_password(value)
        return value
