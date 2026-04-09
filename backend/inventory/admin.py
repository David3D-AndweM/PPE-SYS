from django.contrib import admin

from .models import StockItem, StockMovement, Warehouse


@admin.register(Warehouse)
class WarehouseAdmin(admin.ModelAdmin):
    list_display = ["name", "site", "is_active"]
    list_filter = ["site__organization", "is_active"]


@admin.register(StockItem)
class StockItemAdmin(admin.ModelAdmin):
    list_display = ["ppe_item", "warehouse", "quantity_available", "reorder_level", "is_at_reorder_level"]
    list_filter = ["warehouse__site"]


@admin.register(StockMovement)
class StockMovementAdmin(admin.ModelAdmin):
    list_display = ["ppe_item", "warehouse", "change_type", "quantity", "reference_type", "created_at"]
    list_filter = ["change_type", "reference_type"]
    date_hierarchy = "created_at"
