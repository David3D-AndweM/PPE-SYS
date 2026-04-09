from rest_framework import status
from rest_framework.generics import ListCreateAPIView, RetrieveUpdateAPIView
from rest_framework.response import Response
from rest_framework.views import APIView

from core.permissions import IsAdmin, IsAdminOrManager

from .models import Department, Employee, Organization, Site
from .serializers import (
    DepartmentSerializer,
    EmployeeSerializer,
    EmployeeTransferSerializer,
    OrganizationSerializer,
    SiteSerializer,
)


class OrganizationListCreateView(ListCreateAPIView):
    queryset = Organization.objects.filter(is_active=True)
    serializer_class = OrganizationSerializer
    permission_classes = [IsAdmin]


class OrganizationDetailView(RetrieveUpdateAPIView):
    queryset = Organization.objects.all()
    serializer_class = OrganizationSerializer
    permission_classes = [IsAdmin]


class SiteListCreateView(ListCreateAPIView):
    queryset = Site.objects.select_related("organization").filter(is_active=True)
    serializer_class = SiteSerializer
    permission_classes = [IsAdmin]

    def get_queryset(self):
        qs = super().get_queryset()
        org_id = self.request.query_params.get("organization")
        if org_id:
            qs = qs.filter(organization_id=org_id)
        return qs


class SiteDetailView(RetrieveUpdateAPIView):
    queryset = Site.objects.all()
    serializer_class = SiteSerializer
    permission_classes = [IsAdmin]


class DepartmentListCreateView(ListCreateAPIView):
    queryset = Department.objects.select_related("site", "manager", "safety_officer")
    serializer_class = DepartmentSerializer
    permission_classes = [IsAdminOrManager]

    def get_queryset(self):
        qs = super().get_queryset().filter(is_active=True)
        site_id = self.request.query_params.get("site")
        if site_id:
            qs = qs.filter(site_id=site_id)
        return qs


class DepartmentDetailView(RetrieveUpdateAPIView):
    queryset = Department.objects.all()
    serializer_class = DepartmentSerializer
    permission_classes = [IsAdminOrManager]


class EmployeeListCreateView(ListCreateAPIView):
    queryset = Employee.objects.select_related("user", "department__site")
    serializer_class = EmployeeSerializer
    permission_classes = [IsAdminOrManager]

    def get_queryset(self):
        qs = super().get_queryset()
        dept = self.request.query_params.get("department")
        site = self.request.query_params.get("site")
        status_filter = self.request.query_params.get("status")
        if dept:
            qs = qs.filter(department_id=dept)
        if site:
            qs = qs.filter(department__site_id=site)
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs


class EmployeeDetailView(RetrieveUpdateAPIView):
    queryset = Employee.objects.all()
    serializer_class = EmployeeSerializer
    permission_classes = [IsAdminOrManager]


class EmployeeTransferView(APIView):
    """Move an employee to a new department, preserving history."""

    permission_classes = [IsAdminOrManager]

    def post(self, request, pk):
        try:
            employee = Employee.objects.get(pk=pk)
        except Employee.DoesNotExist:
            return Response({"error": "Employee not found."}, status=status.HTTP_404_NOT_FOUND)

        serializer = EmployeeTransferSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        new_dept = Department.objects.get(pk=serializer.validated_data["department_id"])
        employee.previous_department = employee.department
        employee.department = new_dept
        employee.save()  # triggers signal → PPE re-assignment

        return Response(EmployeeSerializer(employee).data)
