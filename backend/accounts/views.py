from django.contrib.auth.tokens import default_token_generator
from django.core.mail import send_mail
from django.utils.encoding import force_bytes, force_str
from django.utils.http import urlsafe_base64_decode, urlsafe_base64_encode
from rest_framework import status
from rest_framework.generics import RetrieveUpdateAPIView, ListCreateAPIView, RetrieveAPIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenRefreshView

from core.permissions import IsAdmin

from .models import Role, User, UserRole
from .serializers import (
    ChangePasswordSerializer,
    RoleSerializer,
    UserCreateSerializer,
    UserRoleSerializer,
    UserSerializer,
)
from .tokens import CustomTokenObtainPairView


class LoginView(CustomTokenObtainPairView):
    permission_classes = [AllowAny]


class ProfileView(RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = request.user
        if not user.check_password(serializer.validated_data["old_password"]):
            return Response(
                {"error": {"code": "invalid_password", "message": "Old password is incorrect."}},
                status=status.HTTP_400_BAD_REQUEST,
            )
        user.set_password(serializer.validated_data["new_password"])
        user.save()
        return Response({"message": "Password updated successfully."})


class UserListCreateView(ListCreateAPIView):
    queryset = User.objects.all().prefetch_related("user_roles__role", "user_roles__site")
    permission_classes = [IsAdmin]

    def get_serializer_class(self):
        if self.request.method == "POST":
            return UserCreateSerializer
        return UserSerializer


class UserDetailView(RetrieveUpdateAPIView):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsAdmin]


class RoleListView(RetrieveAPIView):
    queryset = Role.objects.all()
    serializer_class = RoleSerializer
    permission_classes = [IsAdmin]

    def get(self, request, *args, **kwargs):
        roles = Role.objects.all()
        serializer = RoleSerializer(roles, many=True)
        return Response(serializer.data)


class PasswordResetRequestView(APIView):
    """Step 1: Request a password reset email. Works for any registered email."""
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get("email", "").strip().lower()
        # Always return 200 to avoid user enumeration
        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({"message": "If that email is registered, a reset link has been sent."})

        uid = urlsafe_base64_encode(force_bytes(user.pk))
        token = default_token_generator.make_token(user)
        reset_link = f"http://localhost:3000/reset-password?uid={uid}&token={token}"

        send_mail(
            subject="EPPEP — Password Reset Request",
            message=(
                f"Hi {user.first_name},\n\n"
                f"Click the link below to reset your EPPEP password:\n\n"
                f"{reset_link}\n\n"
                f"This link expires in 24 hours. If you did not request a reset, ignore this email.\n\n"
                f"— EPPEP System"
            ),
            from_email=None,  # uses DEFAULT_FROM_EMAIL
            recipient_list=[user.email],
            fail_silently=False,
        )
        return Response({"message": "If that email is registered, a reset link has been sent."})


class PasswordResetConfirmView(APIView):
    """Step 2: Submit uid + token + new password to complete the reset."""
    permission_classes = [AllowAny]

    def post(self, request):
        uid = request.data.get("uid", "")
        token = request.data.get("token", "")
        new_password = request.data.get("new_password", "")

        if not all([uid, token, new_password]):
            return Response(
                {"error": "uid, token, and new_password are required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            pk = force_str(urlsafe_base64_decode(uid))
            user = User.objects.get(pk=pk)
        except (User.DoesNotExist, ValueError, TypeError):
            return Response(
                {"error": "Invalid reset link."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not default_token_generator.check_token(user, token):
            return Response(
                {"error": "Reset link is invalid or has expired."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if len(new_password) < 8:
            return Response(
                {"error": "Password must be at least 8 characters."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.set_password(new_password)
        user.save()
        return Response({"message": "Password reset successful. You can now log in."})


class AssignRoleView(APIView):
    permission_classes = [IsAdmin]

    def post(self, request, user_id):
        try:
            user = User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return Response({"error": "User not found."}, status=status.HTTP_404_NOT_FOUND)

        serializer = UserRoleSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(user=user)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    def delete(self, request, user_id):
        role_id = request.data.get("role_id")
        UserRole.objects.filter(user_id=user_id, role_id=role_id).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
