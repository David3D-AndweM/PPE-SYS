"""
Audit signal listeners for key models.
We listen selectively — not every model needs an audit entry,
only the compliance-critical ones.
"""

import logging

from django.db.models.signals import post_save
from django.dispatch import receiver

logger = logging.getLogger(__name__)

AUDITED_MODELS = {}


def register_audit(model, action_create="created", action_update="updated"):
    """Decorator to register a model for automatic audit logging."""

    @receiver(post_save, sender=model)
    def _audit_handler(sender, instance, created, **kwargs):
        try:
            from .models import log_action

            action = action_create if created else action_update
            entity_type = sender.__name__
            entity_id = getattr(instance, "id", None)
            log_action(
                action=action,
                entity_type=entity_type,
                entity_id=entity_id,
                metadata={"pk": str(entity_id)},
            )
        except Exception:
            logger.exception("Audit signal failed for %s", sender.__name__)

    AUDITED_MODELS[model] = _audit_handler
    return model


# Register critical models
def _setup_audit_signals():
    from approvals.models import Approval
    from picking.models import PickingSlip

    register_audit(PickingSlip, "picking_slip_created", "picking_slip_updated")
    register_audit(Approval, "approval_created", "approval_updated")


# Called lazily to avoid import errors during app startup
try:
    _setup_audit_signals()
except Exception:
    pass  # Apps not ready yet — signals registered when ready() is called
