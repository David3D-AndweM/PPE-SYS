import factory
from factory.django import DjangoModelFactory

from organization.factories import SiteFactory
from ppe.factories import PPEItemFactory

from .models import StockItem, Warehouse


class WarehouseFactory(DjangoModelFactory):
    class Meta:
        model = Warehouse

    site = factory.SubFactory(SiteFactory)
    name = factory.Sequence(lambda n: f"Warehouse {n}")
    is_active = True


class StockItemFactory(DjangoModelFactory):
    class Meta:
        model = StockItem

    ppe_item = factory.SubFactory(PPEItemFactory)
    warehouse = factory.SubFactory(WarehouseFactory)
    quantity_available = 50
    reorder_level = 10
