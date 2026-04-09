"""
Inventory domain services.
All stock mutations go through these functions — never update StockItem directly.
"""

import logging

from django.db import transaction

from .models import ChangeType, ReferenceType, StockItem, StockMovement

logger = logging.getLogger(__name__)


@transaction.atomic
def deduct_stock(ppe_item, warehouse, quantity, reference_type, reference_id, performed_by):
    """
    Deduct stock from a warehouse. Raises ValueError if insufficient stock.
    Creates an immutable StockMovement record.
    Returns the updated StockItem.
    """
    stock = StockItem.objects.select_for_update().get(
        ppe_item=ppe_item, warehouse=warehouse
    )
    if stock.quantity_available < quantity:
        raise ValueError(
            f"Insufficient stock for {ppe_item.name}: "
            f"available={stock.quantity_available}, requested={quantity}"
        )
    stock.quantity_available -= quantity
    stock.save(update_fields=["quantity_available", "updated_at"])

    StockMovement.objects.create(
        ppe_item=ppe_item,
        warehouse=warehouse,
        change_type=ChangeType.OUT,
        quantity=quantity,
        reference_type=reference_type,
        reference_id=reference_id,
        performed_by=performed_by,
    )

    if stock.is_at_reorder_level:
        _trigger_reorder_alert(stock)

    logger.info(
        "Stock deducted: %s × %s from %s (remaining: %s)",
        quantity, ppe_item.name, warehouse.name, stock.quantity_available,
    )
    return stock


@transaction.atomic
def receive_stock(ppe_item, warehouse, quantity, reference_type, reference_id, performed_by, notes=""):
    """
    Add stock to a warehouse. Creates a StockMovement record.
    Returns the updated StockItem (creates it if it doesn't exist).
    """
    stock, _ = StockItem.objects.select_for_update().get_or_create(
        ppe_item=ppe_item,
        warehouse=warehouse,
        defaults={"quantity_available": 0, "reorder_level": 10},
    )
    stock.quantity_available += quantity
    stock.save(update_fields=["quantity_available", "updated_at"])

    StockMovement.objects.create(
        ppe_item=ppe_item,
        warehouse=warehouse,
        change_type=ChangeType.IN,
        quantity=quantity,
        reference_type=reference_type,
        reference_id=reference_id,
        performed_by=performed_by,
        notes=notes,
    )

    logger.info(
        "Stock received: %s × %s at %s (total: %s)",
        quantity, ppe_item.name, warehouse.name, stock.quantity_available,
    )
    return stock


def check_reorder_levels(site=None):
    """
    Scan all StockItems (optionally filtered by site) and dispatch alerts
    for any that are at or below reorder level. Called by Celery beat.
    Returns count of items at reorder level.
    """
    qs = StockItem.objects.select_related("ppe_item", "warehouse__site")
    if site:
        qs = qs.filter(warehouse__site=site)

    at_reorder = [item for item in qs if item.is_at_reorder_level]
    for item in at_reorder:
        _trigger_reorder_alert(item)

    return len(at_reorder)


def _trigger_reorder_alert(stock_item):
    """Dispatch a stock alert notification to Store Officers at the site."""
    try:
        from notifications.services import dispatch_to_role

        site = stock_item.warehouse.site
        dispatch_to_role(
            site=site,
            role_name="Store",
            notification_type="stock",
            title=f"Low Stock: {stock_item.ppe_item.name}",
            message=(
                f"{stock_item.ppe_item.name} at {stock_item.warehouse.name} is at "
                f"reorder level ({stock_item.quantity_available} remaining). "
                f"Reorder threshold: {stock_item.reorder_level}."
            ),
        )
    except Exception:
        logger.exception("Failed to dispatch reorder alert for %s", stock_item)
