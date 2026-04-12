from rest_framework import status
from rest_framework.generics import ListAPIView, RetrieveAPIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.permissions import IsAdminOrManager, IsStoreOfficer

from .models import PickingSlip
from .serializers import (
    CreatePickingSlipSerializer,
    FinalizeIssueSerializer,
    PickingSlipSerializer,
    ScanValidateSerializer,
)
from .services import create_slip, finalize_issue, validate_scan


class PickingSlipListView(ListAPIView):
    serializer_class = PickingSlipSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = PickingSlip.objects.select_related(
            "employee__user",
            "employee__department__site",
            "department",
            "requested_by",
        ).prefetch_related("items__ppe_item", "approvals")

        # Employees can only see their own slips
        if hasattr(user, "employee"):
            roles = user.get_roles()
            if "Employee" in roles and not any(r in roles for r in ["Manager", "Admin", "Store"]):
                return qs.filter(employee=user.employee)

        slip_status = self.request.query_params.get("status")
        employee_id = self.request.query_params.get("employee")
        department_id = self.request.query_params.get("department")

        if slip_status:
            qs = qs.filter(status=slip_status)
        if employee_id:
            qs = qs.filter(employee_id=employee_id)
        if department_id:
            qs = qs.filter(department_id=department_id)
        return qs


class PickingSlipDetailView(RetrieveAPIView):
    serializer_class = PickingSlipSerializer
    permission_classes = [IsAuthenticated]
    queryset = PickingSlip.objects.all()


class CreatePickingSlipView(APIView):
    permission_classes = [IsAdminOrManager | IsAuthenticated]

    def post(self, request):
        serializer = CreatePickingSlipSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        d = serializer.validated_data

        from inventory.models import Warehouse
        from organization.models import Employee

        try:
            employee = Employee.objects.get(pk=d["employee_id"])
        except Employee.DoesNotExist:
            return Response({"error": "Employee not found."}, status=status.HTTP_404_NOT_FOUND)

        warehouse = None
        if d.get("warehouse_id"):
            try:
                warehouse = Warehouse.objects.get(pk=d["warehouse_id"])
            except Warehouse.DoesNotExist:
                return Response({"error": "Warehouse not found."}, status=status.HTTP_404_NOT_FOUND)

        try:
            slip = create_slip(
                employee=employee,
                ppe_items_with_qty=d["items"],
                request_type=d["request_type"],
                requested_by=request.user,
                notes=d.get("notes", ""),
                warehouse=warehouse,
            )
        except Exception as exc:
            return Response({"error": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(PickingSlipSerializer(slip).data, status=status.HTTP_201_CREATED)


class ValidateScanView(APIView):
    """Store Officer scans a picking slip QR code to retrieve slip details."""

    permission_classes = [IsStoreOfficer]

    def post(self, request):
        serializer = ScanValidateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            slip = validate_scan(serializer.validated_data["qr_data"], request.user)
        except ValueError as exc:
            return Response({"error": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(PickingSlipSerializer(slip).data)


class FinalizeIssueView(APIView):
    """Store Officer finalises the issue — deducts stock and marks slip issued."""

    permission_classes = [IsStoreOfficer]

    def post(self, request):
        serializer = FinalizeIssueSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        d = serializer.validated_data

        from inventory.models import Warehouse

        try:
            slip = PickingSlip.objects.get(pk=d["slip_id"])
        except PickingSlip.DoesNotExist:
            return Response({"error": "Picking slip not found."}, status=status.HTTP_404_NOT_FOUND)

        try:
            warehouse = Warehouse.objects.get(pk=d["warehouse_id"])
        except Warehouse.DoesNotExist:
            return Response({"error": "Warehouse not found."}, status=status.HTTP_404_NOT_FOUND)

        try:
            slip = finalize_issue(slip, request.user, warehouse)
        except ValueError as exc:
            return Response({"error": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(PickingSlipSerializer(slip).data)
