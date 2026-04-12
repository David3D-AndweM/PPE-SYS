"""
WebSocket consumer for real-time notifications.
Authentication: JWT token passed as query param ?token=<access_token>
"""

import json
import logging

from channels.generic.websocket import AsyncWebsocketConsumer

logger = logging.getLogger(__name__)


class NotificationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        """
        Authenticate the user from the JWT token in the query string,
        then add them to a user-specific channel group.
        """
        user = await self._get_user()
        if user is None:
            await self.close(code=4001)
            return

        self.user = user
        self.group_name = f"user_{user.id}"

        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

        logger.debug("WS connected: user=%s group=%s", user.email, self.group_name)

    async def disconnect(self, close_code):
        if hasattr(self, "group_name"):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)
            logger.debug("WS disconnected: group=%s code=%s", self.group_name, close_code)

    async def receive(self, text_data=None, bytes_data=None):
        """Handle client-side messages (e.g. mark_read commands)."""
        if not text_data:
            return
        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            return

        if data.get("action") == "mark_read" and data.get("notification_id"):
            await self._mark_read(data["notification_id"])

    async def notify(self, event):
        """Called by channel_layer.group_send — pushes to connected client."""
        await self.send(text_data=json.dumps(event["data"]))

    async def _get_user(self):
        """Decode the JWT token from the query string and return the user."""
        from urllib.parse import parse_qs

        from channels.db import database_sync_to_async
        from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
        from rest_framework_simplejwt.tokens import AccessToken

        query_string = self.scope.get("query_string", b"").decode()
        params = parse_qs(query_string)
        token_list = params.get("token", [])
        if not token_list:
            return None

        try:
            token = AccessToken(token_list[0])
            user_id = token.get("user_id")
        except (TokenError, InvalidToken):
            logger.warning("WS connection rejected: invalid JWT")
            return None

        return await database_sync_to_async(self._load_user)(user_id)

    @staticmethod
    def _load_user(user_id):
        from accounts.models import User

        try:
            return User.objects.get(id=user_id, is_active=True)
        except User.DoesNotExist:
            return None

    async def _mark_read(self, notification_id):
        from channels.db import database_sync_to_async

        from notifications.services import mark_read

        success = await database_sync_to_async(mark_read)(notification_id, self.user)
        await self.send(
            text_data=json.dumps(
                {
                    "action": "marked_read",
                    "notification_id": notification_id,
                    "success": success,
                }
            )
        )
