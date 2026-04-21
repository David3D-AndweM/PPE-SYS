"""
Approval workflow tests — role enforcement, approve/reject propagation.
"""

import pytest

from accounts.factories import RoleFactory, UserRoleFactory
from approvals.models import Approval, ApprovalStatus
from picking.factories import PickingSlipFactory
from picking.models import PickingSlip, SlipStatus


@pytest.fixture
def manager_approval(db, manager_user, employee, ppe_item):
    """A pending manager approval record."""
    slip = PickingSlipFactory(employee=employee)
    role = RoleFactory(name="Manager")
    UserRoleFactory(user=manager_user, role=role)
    approval = Approval.objects.create(
        picking_slip=slip,
        required_role="manager",
        status=ApprovalStatus.PENDING,
    )
    return approval


@pytest.mark.django_db
class TestApprovalWorkflow:
    def test_manager_can_approve_manager_approval(self, manager_user, manager_client, manager_approval):
        manager_approval.picking_slip.department.manager = manager_user
        manager_approval.picking_slip.department.save(update_fields=["manager"])
        resp = manager_client.post(
            f"/api/v1/approvals/{manager_approval.id}/approve/",
            {"comment": "Looks good"},
        )
        assert resp.status_code == 200
        manager_approval.refresh_from_db()
        assert manager_approval.status == ApprovalStatus.APPROVED

    def test_store_officer_cannot_approve(self, store_client, manager_approval):
        resp = store_client.post(
            f"/api/v1/approvals/{manager_approval.id}/approve/",
        )
        # Store officers are not approvers — expect 403
        assert resp.status_code == 403

    def test_reject_propagates_to_slip(self, manager_user, manager_client, manager_approval):
        manager_approval.picking_slip.department.manager = manager_user
        manager_approval.picking_slip.department.save(update_fields=["manager"])
        resp = manager_client.post(
            f"/api/v1/approvals/{manager_approval.id}/reject/",
            {"comment": "No stock available"},
        )
        assert resp.status_code == 200
        manager_approval.picking_slip.refresh_from_db()
        assert manager_approval.picking_slip.status == SlipStatus.REJECTED

    def test_approve_all_marks_slip_approved(self, manager_user, manager_client, employee):
        """When all approval steps are approved the slip transitions to APPROVED."""
        slip = PickingSlipFactory(employee=employee, status=SlipStatus.PENDING)
        approval = Approval.objects.create(
            picking_slip=slip,
            required_role="manager",
            status=ApprovalStatus.PENDING,
        )
        slip.department.manager = manager_user
        slip.department.save(update_fields=["manager"])
        manager_client.post(
            f"/api/v1/approvals/{approval.id}/approve/",
            {"comment": "OK"},
        )
        slip.refresh_from_db()
        assert slip.status == SlipStatus.APPROVED

    def test_other_manager_cannot_approve_for_department(self, manager_user, employee):
        from accounts.factories import UserFactory
        from rest_framework.test import APIClient

        slip = PickingSlipFactory(employee=employee, status=SlipStatus.PENDING)
        slip.department.manager = manager_user
        slip.department.save(update_fields=["manager"])
        approval = Approval.objects.create(
            picking_slip=slip,
            required_role="manager",
            status=ApprovalStatus.PENDING,
        )

        other_manager = UserFactory(email="manager.other@test.com")
        role = RoleFactory(name="Manager")
        UserRoleFactory(user=other_manager, role=role)
        other_client = APIClient()
        other_client.force_authenticate(user=other_manager)

        resp = other_client.post(f"/api/v1/approvals/{approval.id}/approve/")
        assert resp.status_code == 403

    def test_unauthenticated_cannot_approve(self, anon_client, manager_approval):
        resp = anon_client.post(f"/api/v1/approvals/{manager_approval.id}/approve/")
        assert resp.status_code == 401

    def test_double_approve_returns_400(self, manager_client, manager_approval):
        manager_client.post(f"/api/v1/approvals/{manager_approval.id}/approve/")
        # Second approve on already-approved record
        resp = manager_client.post(f"/api/v1/approvals/{manager_approval.id}/approve/")
        assert resp.status_code == 400
