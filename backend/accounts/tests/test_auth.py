"""
Auth endpoint tests — login, JWT claims, token refresh, change password.
"""
import pytest
from rest_framework.test import APIClient

from accounts.factories import RoleFactory, UserFactory, UserRoleFactory


@pytest.mark.django_db
class TestLogin:
    url = "/api/v1/auth/login/"

    def test_valid_credentials_return_jwt(self, client, manager_user):
        resp = APIClient().post(self.url, {"email": "manager@test.com", "password": "TestPass1234!"})
        assert resp.status_code == 200
        assert "access" in resp.data
        assert "refresh" in resp.data

    def test_jwt_contains_roles(self, manager_user):
        import jwt as pyjwt
        from django.conf import settings
        resp = APIClient().post(self.url, {"email": "manager@test.com", "password": "TestPass1234!"})
        # Decode without verification to inspect claims (HS256, signed by backend)
        payload = pyjwt.decode(resp.data["access"], options={"verify_signature": False})
        assert "roles" in payload
        assert "Manager" in payload["roles"]

    def test_invalid_password_returns_401(self):
        user = UserFactory(email="x@test.com")
        resp = APIClient().post(self.url, {"email": "x@test.com", "password": "wrong"})
        assert resp.status_code == 401

    def test_unknown_email_returns_401(self):
        resp = APIClient().post(self.url, {"email": "nobody@x.com", "password": "any"})
        assert resp.status_code == 401

    def test_unauthenticated_profile_returns_401(self):
        resp = APIClient().get("/api/v1/auth/me/")
        assert resp.status_code == 401


@pytest.mark.django_db
class TestTokenRefresh:
    def test_valid_refresh_token_returns_new_access(self, manager_user):
        login = APIClient().post(
            "/api/v1/auth/login/",
            {"email": "manager@test.com", "password": "TestPass1234!"},
        )
        resp = APIClient().post(
            "/api/v1/auth/token/refresh/",
            {"refresh": login.data["refresh"]},
        )
        assert resp.status_code == 200
        assert "access" in resp.data

    def test_invalid_refresh_token_returns_401(self):
        resp = APIClient().post("/api/v1/auth/token/refresh/", {"refresh": "garbage"})
        assert resp.status_code in (401, 400)


@pytest.mark.django_db
class TestChangePassword:
    def test_authenticated_user_can_change_password(self, manager_user, manager_client):
        resp = manager_client.post(
            "/api/v1/auth/me/change-password/",
            {"old_password": "TestPass1234!", "new_password": "NewPass5678!"},
        )
        assert resp.status_code == 200
        manager_user.refresh_from_db()
        assert manager_user.check_password("NewPass5678!")

    def test_wrong_old_password_returns_400(self, manager_user, manager_client):
        resp = manager_client.post(
            "/api/v1/auth/me/change-password/",
            {"old_password": "wrong", "new_password": "NewPass5678!"},
        )
        assert resp.status_code == 400

    def test_unauthenticated_cannot_change_password(self, anon_client):
        resp = anon_client.post(
            "/api/v1/auth/me/change-password/",
            {"old_password": "x", "new_password": "y"},
        )
        assert resp.status_code == 401


@pytest.mark.django_db
class TestPasswordReset:
    def test_request_always_returns_200(self):
        resp = APIClient().post(
            "/api/v1/auth/password-reset/",
            {"email": "nobody@nothere.com"},
        )
        assert resp.status_code == 200

    def test_invalid_uid_returns_400(self):
        resp = APIClient().post(
            "/api/v1/auth/password-reset/confirm/",
            {"uid": "bad", "token": "bad", "new_password": "NewPass5678!"},
        )
        assert resp.status_code == 400
