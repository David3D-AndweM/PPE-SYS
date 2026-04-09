"""
Periodic stock level monitor.
Checks all warehouses for items at or below reorder level.
"""

import logging

from celery import shared_task

logger = logging.getLogger(__name__)


@shared_task(name="celery_tasks.stock_monitor.check_reorder_levels")
def check_reorder_levels():
    from inventory.services import check_reorder_levels as _check

    count = _check()
    logger.info("Stock monitor: %d items at or below reorder level", count)
    return {"status": "completed", "items_at_reorder_level": count}
