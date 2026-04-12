"""
WebSocket consumer tests — authentication, connection, message delivery.
"""

import pytest
from channels.auth import AuthMiddlewareStack
from channels.routing import URLRouter
from channels.testing import WebsocketCommunicator

# Use the inner router (no AllowedHostsOriginValidator) so tests work without a browser origin
from notifications.routing import websocket_urlpatterns

_test_application = AuthMiddlewareStack(URLRouter(websocket_urlpatterns))


def _get_token(user):
    """Get a valid JWT access token for the user."""
    from rest_framework_simplejwt.tokens import AccessToken

    return str(AccessToken.for_user(user))


@pytest.mark.asyncio
@pytest.mark.django_db(transaction=True)
class TestNotificationConsumer:
    async def test_authenticated_connection_accepted(self, manager_user):
        token = _get_token(manager_user)
        communicator = WebsocketCommunicator(
            _test_application,
            f"/ws/notifications/?token={token}",
        )
        connected, code = await communicator.connect()
        assert connected
        await communicator.disconnect()

    async def test_unauthenticated_connection_rejected(self):
        communicator = WebsocketCommunicator(_test_application, "/ws/notifications/")
        connected, code = await communicator.connect()
        assert not connected or code == 4001
        await communicator.disconnect()

    async def test_invalid_token_rejected(self):
        communicator = WebsocketCommunicator(
            _test_application,
            "/ws/notifications/?token=garbage.token.here",
        )
        connected, code = await communicator.connect()
        assert not connected or code == 4001
        await communicator.disconnect()

    async def test_dispatch_delivers_message(self, manager_user):
        from asgiref.sync import sync_to_async

        from notifications.models import NotificationType
        from notifications.services import dispatch

        token = _get_token(manager_user)
        communicator = WebsocketCommunicator(
            _test_application,
            f"/ws/notifications/?token={token}",
        )
        connected, _ = await communicator.connect()
        assert connected

        # Dispatch a notification via the service (uses channel layer)
        await sync_to_async(dispatch)(
            user=manager_user,
            notification_type=NotificationType.SYSTEM,
            title="Test Notification",
            message="Hello from test.",
        )

        # Expect to receive it
        response = await communicator.receive_json_from(timeout=3)
        assert response.get("title") == "Test Notification"

        await communicator.disconnect()
