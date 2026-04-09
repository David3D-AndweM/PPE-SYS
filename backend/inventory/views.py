from rest_framework import status
from rest_framework.generics import ListCreateAPIView, RetrieveUpdateAPIView, ListAPIView
from rest_framework.response import Response
from rest_framework.views import APIView

from core.permissions import IsAdmin, IsAdminOrManager, IsStoreOfficer

from .models import StockItem, StockMovement, Warehouse
from .serializers import (
    StockAdjustmentSerializer,
    StockItemSerializer,
    StockMovementSerializer,
    WarehouseSerializer,
)
from .services import receive_stock
from ppe.models import PPEItem


class WarehouseListCreateView(ListCreateAPIView):
    queryset = Warehouse.objects.select_related("site").filter(is_active=True)
    serializer_class = WarehouseSerializer
    permission_classes = [IsAdmin]

    def get_queryset(self):
        qs = super().get_queryset()
        site = self.request.query_params.get("site")
        if site:
            qs = qs.filter(site_id=site)
        return qs


class WarehouseDetailView(RetrieveUpdateAPIView):
    queryset = Warehouse.objects.select_related("site").all()
    serializer_class = WarehouseSerializer
    permission_classes = [IsAdmin | IsStoreOfficer]


class StockItemListView(ListAPIView):
    queryset = StockItem.objects.select_related("ppe_item", "warehouse__site")
    serializer_class = StockItemSerializer
    permission_classes = [IsAdminOrManager]

    def get_queryset(self):
        qs = super().get_queryset()
        warehouse = self.request.query_params.get("warehouse")
        site = self.request.query_params.get("site")
        if warehouse:
            qs = qs.filter(warehouse_id=warehouse)
        if site:
            qs = qs.filter(warehouse__site_id=site)
        return qs


class StockReceiveView(APIView):
    """Store Officer or Admin can receive new stock."""

    permission_classes = [IsStoreOfficer | IsAdmin]

    def post(self, request):
        serializer = StockAdjustmentSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        d = serializer.validated_data

        try:
            ppe_item = PPEItem.objects.get(pk=d["ppe_item_id"])
            warehouse = Warehouse.objects.get(pk=d["warehouse_id"])
        except (PPEItem.DoesNotExist, Warehouse.DoesNotExist) as e:
            return Response({"error": str(e)}, status=status.HTTP_404_NOT_FOUND)

        from .models import ReferenceType

        stock = receive_stock(
            ppe_item=ppe_item,
            warehouse=warehouse,
            quantity=d["quantity"],
            reference_type=ReferenceType.INITIAL,
            reference_id=None,
            performed_by=request.user,
            notes=d.get("notes", ""),
        )
        return Response(StockItemSerializer(stock).data, status=status.HTTP_200_OK)


class StockMovementListView(ListAPIView):
    queryset = StockMovement.objects.select_related("ppe_item", "warehouse", "performed_by")
    serializer_class = StockMovementSerializer
    permission_classes = [IsAdminOrManager]

    def get_queryset(self):
        qs = super().get_queryset()
        warehouse = self.request.query_params.get("warehouse")
        ppe_item = self.request.query_params.get("ppe_item")
        if warehouse:
            qs = qs.filter(warehouse_id=warehouse)
        if ppe_item:
            qs = qs.filter(ppe_item_id=ppe_item)
        return qs
