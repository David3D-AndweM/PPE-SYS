from django.contrib import admin

from .models import DepartmentPPERequirement, EmployeePPE, PPEConfiguration, PPEItem


@admin.register(PPEItem)
class PPEItemAdmin(admin.ModelAdmin):
    list_display = ["name", "category", "is_critical", "default_validity_days", "is_active"]
    list_filter = ["category", "is_critical", "is_active"]
    search_fields = ["name"]


@admin.register(PPEConfiguration)
class PPEConfigurationAdmin(admin.ModelAdmin):
    list_display = ["ppe_item", "scope_type", "scope_id", "validity_days", "grace_days"]
    list_filter = ["scope_type", "ppe_item"]


@admin.register(DepartmentPPERequirement)
class DepartmentPPERequirementAdmin(admin.ModelAdmin):
    list_display = ["department", "ppe_item", "is_required", "quantity"]
    list_filter = ["department__site", "is_required"]


@admin.register(EmployeePPE)
class EmployeePPEAdmin(admin.ModelAdmin):
    list_display = ["employee", "ppe_item", "status", "issue_date", "expiry_date"]
    list_filter = ["status", "ppe_item__category"]
    search_fields = ["employee__mine_number", "employee__user__email"]
    date_hierarchy = "expiry_date"
