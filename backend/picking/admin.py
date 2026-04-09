from django.contrib import admin

from .models import PickingSlip, PickingSlipItem, ScanLog


class PickingSlipItemInline(admin.TabularInline):
    model = PickingSlipItem
    extra = 0
    readonly_fields = ["ppe_item", "quantity", "warehouse"]


@admin.register(PickingSlip)
class PickingSlipAdmin(admin.ModelAdmin):
    list_display = ["slip_number", "employee", "request_type", "status", "created_at"]
    list_filter = ["status", "request_type"]
    search_fields = ["employee__mine_number", "employee__user__email"]
    date_hierarchy = "created_at"
    inlines = [PickingSlipItemInline]
    readonly_fields = ["qr_code", "slip_number"]


@admin.register(ScanLog)
class ScanLogAdmin(admin.ModelAdmin):
    list_display = ["picking_slip", "scanned_by", "status", "scan_time"]
    list_filter = ["status"]
    date_hierarchy = "scan_time"
