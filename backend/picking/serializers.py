from rest_framework import serializers

from ppe.serializers import PPEItemSerializer

from .models import PickingSlip, PickingSlipItem, ScanLog


class PickingSlipItemSerializer(serializers.ModelSerializer):
    ppe_item_name = serializers.CharField(source="ppe_item.name", read_only=True)
    ppe_item_category = serializers.CharField(source="ppe_item.category", read_only=True)

    class Meta:
        model = PickingSlipItem
        fields = ["id", "ppe_item", "ppe_item_name", "ppe_item_category", "quantity", "warehouse"]
        read_only_fields = ["id"]


class PickingSlipSerializer(serializers.ModelSerializer):
    items = PickingSlipItemSerializer(many=True, read_only=True)
    employee_name = serializers.CharField(source="employee.user.get_full_name", read_only=True)
    mine_number = serializers.CharField(source="employee.mine_number", read_only=True)
    department_name = serializers.CharField(source="department.name", read_only=True)
    requested_by_name = serializers.CharField(source="requested_by.get_full_name", read_only=True, default=None)
    slip_number = serializers.CharField(read_only=True)
    qr_image = serializers.SerializerMethodField()

    class Meta:
        model = PickingSlip
        fields = [
            "id",
            "slip_number",
            "employee",
            "employee_name",
            "mine_number",
            "department",
            "department_name",
            "request_type",
            "status",
            "requested_by",
            "requested_by_name",
            "approved_at",
            "issued_at",
            "qr_code",
            "qr_image",
            "notes",
            "items",
            "created_at",
        ]
        read_only_fields = ["id", "slip_number", "qr_code", "qr_image", "created_at"]

    def get_qr_image(self, obj):
        if not obj.qr_code:
            return None
        from core.utils.qr import generate_qr_image_base64

        return generate_qr_image_base64(obj.qr_code)


class CreatePickingSlipSerializer(serializers.Serializer):
    employee_id = serializers.UUIDField()
    request_type = serializers.ChoiceField(choices=["expiry", "lost", "damaged", "new"])
    notes = serializers.CharField(required=False, allow_blank=True)
    warehouse_id = serializers.UUIDField(required=False, allow_null=True)
    items = serializers.ListField(
        child=serializers.DictField(),
        min_length=1,
    )

    def validate_items(self, value):
        from ppe.models import PPEItem

        cleaned = []
        for item in value:
            ppe_item_id = item.get("ppe_item_id")
            quantity = item.get("quantity", 1)
            if not ppe_item_id:
                raise serializers.ValidationError("Each item must have a ppe_item_id.")
            try:
                ppe_item = PPEItem.objects.get(pk=ppe_item_id, is_active=True)
            except PPEItem.DoesNotExist:
                raise serializers.ValidationError(f"PPE item {ppe_item_id} not found.")
            cleaned.append({"ppe_item": ppe_item, "quantity": int(quantity)})
        return cleaned


class AutoCreatePickingSlipSerializer(serializers.Serializer):
    employee_id = serializers.UUIDField()
    request_type = serializers.ChoiceField(choices=["expiry", "new"])
    notes = serializers.CharField(required=False, allow_blank=True)
    warehouse_id = serializers.UUIDField(required=False, allow_null=True)


class ScanValidateSerializer(serializers.Serializer):
    qr_data = serializers.CharField(required=False, allow_blank=True)
    slip_number = serializers.CharField(required=False, allow_blank=True)
    mine_number = serializers.CharField(required=False, allow_blank=True)
    employee_id = serializers.UUIDField(required=False)

    def validate(self, attrs):
        qr_data = (attrs.get("qr_data") or "").strip()
        slip_number = (attrs.get("slip_number") or "").strip()
        mine_number = (attrs.get("mine_number") or "").strip()
        employee_id = attrs.get("employee_id")

        if qr_data:
            return {"qr_data": qr_data}

        if not slip_number:
            raise serializers.ValidationError("Provide qr_data or slip_number with mine_number/employee_id.")
        if not mine_number and not employee_id:
            raise serializers.ValidationError("Provide mine_number or employee_id when using slip_number lookup.")

        cleaned = {"slip_number": slip_number.upper()}
        if mine_number:
            cleaned["mine_number"] = mine_number
        if employee_id:
            cleaned["employee_id"] = employee_id
        return cleaned


class FinalizeIssueSerializer(serializers.Serializer):
    slip_id = serializers.UUIDField()
    warehouse_id = serializers.UUIDField()


class ScanLogSerializer(serializers.ModelSerializer):
    scanned_by_name = serializers.CharField(source="scanned_by.get_full_name", read_only=True, default=None)

    class Meta:
        model = ScanLog
        fields = ["id", "picking_slip", "ppe_item", "scanned_by", "scanned_by_name", "status", "scan_time", "raw_data"]
        read_only_fields = fields
