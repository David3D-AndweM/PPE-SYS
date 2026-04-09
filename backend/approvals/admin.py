from django.contrib import admin

from .models import Approval


@admin.register(Approval)
class ApprovalAdmin(admin.ModelAdmin):
    list_display = ["picking_slip", "required_role", "approver", "status", "actioned_at"]
    list_filter = ["required_role", "status"]
    search_fields = ["picking_slip__id", "approver__email"]
    date_hierarchy = "created_at"
