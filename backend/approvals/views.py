from rest_framework import status
from rest_framework.generics import ListAPIView
from rest_framework.response import Response
from rest_framework.views import APIView

from core.permissions import IsApprover

from .models import Approval, ApprovalStatus
from .serializers import ApprovalActionSerializer, ApprovalSerializer
from .services import approve, reject


class PendingApprovalListView(ListAPIView):
    serializer_class = ApprovalSerializer
    permission_classes = [IsApprover]

    def get_queryset(self):
        """
        Return approvals pending for the current user's role,
        scoped to their site(s).
        """
        user = self.request.user
        roles = list(user.user_roles.values_list("role__name", flat=True))
        site_ids = list(user.user_roles.exclude(site=None).values_list("site_id", flat=True))

        role_map = {"Manager": "manager", "Safety": "safety", "Admin": "admin"}
        user_approval_roles = [role_map[r] for r in roles if r in role_map]

        qs = Approval.objects.filter(
            status=ApprovalStatus.PENDING,
            required_role__in=user_approval_roles,
        ).select_related(
            "picking_slip__employee__user",
            "picking_slip__department__manager",
            "picking_slip__employee__department__site",
        )

        if "Manager" in roles and not user.is_superuser:
            qs = qs.filter(required_role="manager", picking_slip__department__manager=user)

        if site_ids and not user.is_superuser:
            qs = qs.filter(picking_slip__employee__department__site_id__in=site_ids)

        return qs


class ApproveView(APIView):
    permission_classes = [IsApprover]

    def post(self, request, pk):
        serializer = ApprovalActionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            approval = approve(pk, request.user, serializer.validated_data.get("comment", ""))
        except (Approval.DoesNotExist, KeyError):
            return Response({"error": "Approval not found."}, status=status.HTTP_404_NOT_FOUND)
        except PermissionError as e:
            return Response({"error": str(e)}, status=status.HTTP_403_FORBIDDEN)
        except ValueError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(ApprovalSerializer(approval).data)


class RejectView(APIView):
    permission_classes = [IsApprover]

    def post(self, request, pk):
        serializer = ApprovalActionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            approval = reject(pk, request.user, serializer.validated_data.get("comment", ""))
        except (Approval.DoesNotExist, KeyError):
            return Response({"error": "Approval not found."}, status=status.HTTP_404_NOT_FOUND)
        except PermissionError as e:
            return Response({"error": str(e)}, status=status.HTTP_403_FORBIDDEN)
        return Response(ApprovalSerializer(approval).data)
