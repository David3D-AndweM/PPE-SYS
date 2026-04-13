from django.db import models
from rest_framework.generics import ListAPIView, ListCreateAPIView, RetrieveUpdateAPIView, RetrieveUpdateDestroyAPIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.permissions import IsAdmin, IsAdminOrManagerOrSafety

from .models import DepartmentPPERequirement, EmployeePPE, PPEConfiguration, PPEItem
from .serializers import (
    DepartmentPPERequirementSerializer,
    EmployeePPESerializer,
    PPEConfigurationSerializer,
    PPEItemSerializer,
)
from .services import get_employee_compliance_summary


class PPEItemListCreateView(ListCreateAPIView):
    queryset = PPEItem.objects.filter(is_active=True)
    serializer_class = PPEItemSerializer
    permission_classes = [IsAuthenticated]

    def get_permissions(self):
        if self.request.method == "POST":
            return [IsAdmin()]
        return [IsAuthenticated()]


class PPEItemDetailView(RetrieveUpdateAPIView):
    queryset = PPEItem.objects.all()
    serializer_class = PPEItemSerializer
    permission_classes = [IsAdmin]


class PPEConfigurationListCreateView(ListCreateAPIView):
    queryset = PPEConfiguration.objects.select_related("ppe_item")
    serializer_class = PPEConfigurationSerializer
    permission_classes = [IsAdminOrManagerOrSafety]

    def get_queryset(self):
        qs = super().get_queryset()
        ppe_item = self.request.query_params.get("ppe_item")
        scope_type = self.request.query_params.get("scope_type")
        if ppe_item:
            qs = qs.filter(ppe_item_id=ppe_item)
        if scope_type:
            qs = qs.filter(scope_type=scope_type)
        # Non-admins should only ever see configs for departments they can manage.
        user = self.request.user
        if not (user.is_superuser or "Admin" in set(user.get_roles())):
            from organization.models import Department
            allowed_dept_ids = Department.objects.filter(
                models.Q(manager=user) | models.Q(safety_officer=user) | models.Q(user_roles__user=user),
                is_active=True,
            ).values_list("id", flat=True)
            qs = qs.filter(scope_type="department", scope_id__in=list(allowed_dept_ids))
        return qs


class DepartmentPPERequirementListCreateView(ListCreateAPIView):
    queryset = DepartmentPPERequirement.objects.select_related("department", "ppe_item")
    serializer_class = DepartmentPPERequirementSerializer
    permission_classes = [IsAdminOrManagerOrSafety]

    def get_queryset(self):
        qs = super().get_queryset()
        dept = self.request.query_params.get("department")
        if dept:
            qs = qs.filter(department_id=dept)
        user = self.request.user
        if not (user.is_superuser or "Admin" in set(user.get_roles())):
            qs = qs.filter(
                models.Q(department__manager=user)
                | models.Q(department__safety_officer=user)
                | models.Q(department__user_roles__user=user)
            )
        return qs


class PPEConfigurationDetailView(RetrieveUpdateDestroyAPIView):
    queryset = PPEConfiguration.objects.select_related("ppe_item").all()
    serializer_class = PPEConfigurationSerializer
    permission_classes = [IsAdminOrManagerOrSafety]


class DepartmentPPERequirementDetailView(RetrieveUpdateDestroyAPIView):
    queryset = DepartmentPPERequirement.objects.select_related("department", "ppe_item").all()
    serializer_class = DepartmentPPERequirementSerializer
    permission_classes = [IsAdminOrManagerOrSafety]


class EmployeePPEListView(ListAPIView):
    serializer_class = EmployeePPESerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = EmployeePPE.objects.select_related("ppe_item", "employee__user")

        # Employee can only see their own PPE
        if hasattr(user, "employee"):
            employee_param = self.request.query_params.get("employee")
            roles = [r for r in user.get_roles()]
            if "Employee" in roles and "Manager" not in roles and "Admin" not in roles:
                return qs.filter(employee=user.employee)

        employee = self.request.query_params.get("employee")
        department = self.request.query_params.get("department")
        status_filter = self.request.query_params.get("status")

        if employee:
            qs = qs.filter(employee_id=employee)
        if department:
            qs = qs.filter(employee__department_id=department)
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs


class MyPPEView(ListAPIView):
    serializer_class = EmployeePPESerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if hasattr(user, "employee"):
            return EmployeePPE.objects.filter(employee=user.employee).select_related("ppe_item")
        return EmployeePPE.objects.none()


class MyPPEComplianceSummaryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        if not hasattr(user, "employee"):
            return Response({"error": "No employee record for this user."}, status=404)
        summary = get_employee_compliance_summary(user.employee)
        return Response(summary)
