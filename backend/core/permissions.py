from rest_framework.permissions import BasePermission


def _has_role(request, role_name):
    """Check if the authenticated user has a given role (from JWT claims)."""
    roles = getattr(request, "user_roles", None)
    if roles is None:
        # Fall back to DB if JWT claims not available
        if not request.user or not request.user.is_authenticated:
            return False
        roles = list(request.user.user_roles.select_related("role").values_list("role__name", flat=True))
        request.user_roles = roles  # cache on request
    return role_name in roles


class IsAdmin(BasePermission):
    message = "Admin role required."

    def has_permission(self, request, view):
        return request.user.is_authenticated and (request.user.is_superuser or _has_role(request, "Admin"))


class IsManager(BasePermission):
    message = "Manager role required."

    def has_permission(self, request, view):
        return request.user.is_authenticated and _has_role(request, "Manager")


class IsSafetyOfficer(BasePermission):
    message = "Safety Officer role required."

    def has_permission(self, request, view):
        return request.user.is_authenticated and _has_role(request, "Safety")


class IsStoreOfficer(BasePermission):
    message = "Store Officer role required."

    def has_permission(self, request, view):
        return request.user.is_authenticated and _has_role(request, "Store")


class IsEmployee(BasePermission):
    message = "Employee role required."

    def has_permission(self, request, view):
        return request.user.is_authenticated and _has_role(request, "Employee")


class IsAdminOrManager(BasePermission):
    message = "Admin or Manager role required."

    def has_permission(self, request, view):
        return request.user.is_authenticated and (
            request.user.is_superuser or _has_role(request, "Admin") or _has_role(request, "Manager")
        )


class IsApprover(BasePermission):
    """Manager or Safety Officer — both can participate in approvals."""

    message = "Manager or Safety Officer role required."

    def has_permission(self, request, view):
        return request.user.is_authenticated and (_has_role(request, "Manager") or _has_role(request, "Safety"))
