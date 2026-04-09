"""
Notification dispatch services.
All notification creation goes through these functions.
"""

import logging

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

from .models import Notification, NotificationType

logger = logging.getLogger(__name__)


def dispatch(user, notification_type, title, message, entity_type="", entity_id=None):
    """
    Create a Notification record and push it to the user's WebSocket channel
    group if they are currently connected.
    """
    notification = Notification.objects.create(
        user=user,
        notification_type=notification_type,
        title=title,
        message=message,
        entity_type=entity_type,
        entity_id=entity_id,
    )

    _push_to_websocket(user.id, {
        "id": str(notification.id),
        "type": notification_type,
        "title": title,
        "message": message,
        "created_at": notification.created_at.isoformat(),
    })

    return notification


def bulk_notify(users, notification_type, title, message, entity_type="", entity_id=None):
    """Dispatch the same notification to multiple users."""
    results = []
    for user in users:
        try:
            n = dispatch(user, notification_type, title, message, entity_type, entity_id)
            results.append(n)
        except Exception:
            logger.exception("Failed to dispatch notification to user %s", user.id)
    return results


def dispatch_to_role(site, role_name, notification_type, title, message):
    """
    Dispatch a notification to all users who hold a given role at a site.
    """
    from accounts.models import UserRole

    user_ids = UserRole.objects.filter(
        role__name=role_name,
        site=site,
    ).values_list("user_id", flat=True).distinct()

    from accounts.models import User

    users = User.objects.filter(id__in=user_ids, is_active=True)
    return bulk_notify(users, notification_type, title, message)


def mark_read(notification_id, user):
    """Mark a single notification as read. Validates ownership."""
    updated = Notification.objects.filter(
        id=notification_id, user=user
    ).update(is_read=True)
    return updated > 0


def mark_all_read(user):
    """Mark all of a user's unread notifications as read."""
    return Notification.objects.filter(user=user, is_read=False).update(is_read=True)


def _push_to_websocket(user_id, payload):
    """
    Push a notification payload to the user's WebSocket group.
    Silently fails if no WebSocket connection is active.
    """
    try:
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            f"user_{user_id}",
            {
                "type": "notify",
                "data": payload,
            },
        )
    except Exception:
        logger.debug("WebSocket push failed for user %s (probably not connected)", user_id)
