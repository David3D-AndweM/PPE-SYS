from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from .views import (
    AssignRoleView,
    ChangePasswordView,
    LoginView,
    PasswordResetConfirmView,
    PasswordResetRequestView,
    ProfileView,
    RoleListView,
    UserDetailView,
    UserListCreateView,
)

app_name = "accounts"

urlpatterns = [
    path("login/", LoginView.as_view(), name="login"),
    path("token/refresh/", TokenRefreshView.as_view(), name="token-refresh"),
    path("me/", ProfileView.as_view(), name="profile"),
    path("me/change-password/", ChangePasswordView.as_view(), name="change-password"),
    path("users/", UserListCreateView.as_view(), name="user-list"),
    path("users/<uuid:pk>/", UserDetailView.as_view(), name="user-detail"),
    path("users/<uuid:user_id>/roles/", AssignRoleView.as_view(), name="user-roles"),
    path("roles/", RoleListView.as_view(), name="roles"),
    path("password-reset/", PasswordResetRequestView.as_view(), name="password-reset"),
    path("password-reset/confirm/", PasswordResetConfirmView.as_view(), name="password-reset-confirm"),
]
