from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.views import TokenObtainPairView


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """
    Extends the JWT payload with role and employee context so the Flutter
    app can make routing and permission decisions without extra API calls.
    """

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)

        # User identity
        token["email"] = user.email
        token["full_name"] = user.get_full_name()

        # Roles — list of role names (e.g. ["Manager", "Safety"])
        token["roles"] = list(user.user_roles.select_related("role").values_list("role__name", flat=True).distinct())

        # Employee ID (null if the user is admin-only and has no employee record)
        try:
            token["employee_id"] = str(user.employee.id)
            token["mine_number"] = user.employee.mine_number
        except Exception:
            token["employee_id"] = None
            token["mine_number"] = None

        # Site IDs the user is scoped to
        token["site_ids"] = [
            str(sid) for sid in user.user_roles.exclude(site=None).values_list("site_id", flat=True).distinct()
        ]

        return token


class CustomTokenObtainPairView(TokenObtainPairView):
    serializer_class = CustomTokenObtainPairSerializer
