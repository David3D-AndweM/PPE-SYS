import logging

from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import Employee

logger = logging.getLogger(__name__)


@receiver(post_save, sender=Employee)
def on_employee_saved(sender, instance, created, **kwargs):
    """
    Trigger PPE auto-assignment whenever an employee is created or their
    department changes (transfer). Import is deferred to avoid circular imports.
    """
    from ppe.services import auto_assign_ppe

    if created:
        logger.info("New employee %s — triggering PPE auto-assignment", instance.mine_number)
        try:
            auto_assign_ppe(instance)
        except Exception:
            logger.exception(
                "PPE auto-assignment failed for employee %s", instance.mine_number
            )
    elif instance.previous_department and instance.previous_department != instance.department:
        logger.info(
            "Employee %s transferred from %s to %s — re-assigning PPE",
            instance.mine_number,
            instance.previous_department,
            instance.department,
        )
        try:
            auto_assign_ppe(instance)
        except Exception:
            logger.exception(
                "PPE re-assignment after transfer failed for %s", instance.mine_number
            )
