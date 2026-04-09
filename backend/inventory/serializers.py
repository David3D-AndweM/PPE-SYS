from rest_framework import serializers

from .models import StockItem, StockMovement, Warehouse


class WarehouseSerializer(serializers.ModelSerializer):
    site_name = serializers.CharField(source="site.name", read_only=True)

    class Meta:
        model = Warehouse
        fields = ["id", "site", "site_name", "name", "location_description", "is_active"]
        read_only_fields = ["id"]


class StockItemSerializer(serializers.ModelSerializer):
    ppe_item_name = serializers.CharField(source="ppe_item.name", read_only=True)
    warehouse_name = serializers.CharField(source="warehouse.name", read_only=True)
    is_at_reorder_level = serializers.BooleanField(read_only=True)

    class Meta:
        model = StockItem
        fields = [
            "id", "ppe_item", "ppe_item_name",
            "warehouse", "warehouse_name",
            "quantity_available", "reorder_level", "is_at_reorder_level",
            "updated_at",
        ]
        read_only_fields = ["id", "updated_at"]


class StockMovementSerializer(serializers.ModelSerializer):
    ppe_item_name = serializers.CharField(source="ppe_item.name", read_only=True)
    warehouse_name = serializers.CharField(source="warehouse.name", read_only=True)
    performed_by_name = serializers.CharField(
        source="performed_by.get_full_name", read_only=True, default=None
    )

    class Meta:
        model = StockMovement
        fields = [
            "id", "ppe_item", "ppe_item_name",
            "warehouse", "warehouse_name",
            "change_type", "quantity",
            "reference_type", "reference_id",
            "performed_by", "performed_by_name",
            "notes", "created_at",
        ]
        read_only_fields = ["id", "created_at"]


class StockAdjustmentSerializer(serializers.Serializer):
    ppe_item_id = serializers.UUIDField()
    warehouse_id = serializers.UUIDField()
    quantity = serializers.IntegerField(min_value=1)
    notes = serializers.CharField(required=False, allow_blank=True)
