from django.contrib import admin

from .models import Department, Employee, Organization, Site


@admin.register(Organization)
class OrganizationAdmin(admin.ModelAdmin):
    list_display = ["name", "slug", "is_active", "created_at"]
    prepopulated_fields = {"slug": ("name",)}


@admin.register(Site)
class SiteAdmin(admin.ModelAdmin):
    list_display = ["name", "organization", "location", "is_active"]
    list_filter = ["organization", "is_active"]
    search_fields = ["name", "location"]


@admin.register(Department)
class DepartmentAdmin(admin.ModelAdmin):
    list_display = ["name", "site", "manager", "safety_officer", "is_active"]
    list_filter = ["site__organization", "site", "is_active"]
    search_fields = ["name"]
    raw_id_fields = ["manager", "safety_officer"]


@admin.register(Employee)
class EmployeeAdmin(admin.ModelAdmin):
    list_display = ["mine_number", "user", "department", "role_title", "status"]
    list_filter = ["department__site", "status"]
    search_fields = ["mine_number", "user__email", "user__first_name", "user__last_name"]
    raw_id_fields = ["user"]
