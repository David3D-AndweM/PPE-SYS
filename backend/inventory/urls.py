from django.urls import path

from .views import (
    StockItemListView,
    StockMovementListView,
    StockReceiveView,
    WarehouseListCreateView,
)

app_name = "inventory"

urlpatterns = [
    path("warehouses/", WarehouseListCreateView.as_view(), name="warehouse-list"),
    path("stock/", StockItemListView.as_view(), name="stock-list"),
    path("stock/receive/", StockReceiveView.as_view(), name="stock-receive"),
    path("movements/", StockMovementListView.as_view(), name="movement-list"),
]
