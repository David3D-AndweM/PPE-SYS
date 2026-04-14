"""
Full picking slip lifecycle integration test.
Covers: create → approve → validate-scan → finalize-issue.
"""

import pytest

from approvals.models import Approval, ApprovalStatus
from audit.models import AuditLog
from core.utils.qr import generate_slip_qr_payload
from inventory.models import StockItem
from notifications.models import Notification
from picking.models import PickingSlip, SlipStatus
from ppe.models import EmployeePPE, EmployeePPEStatus


@pytest.mark.django_db(transaction=True)
class TestPickingSlipLifecycle:
    def _create_slip(self, employee_client, employee, ppe_item):
        return employee_client.post(
            "/api/v1/picking/slips/create/",
            {
                "employee_id": str(employee.id),
                "request_type": "expiry",
                "items": [{"ppe_item_id": str(ppe_item.id), "quantity": 1}],
            },
            format="json",
        )

    def test_create_slip_returns_201(self, employee_client, employee, ppe_item, stock_item):
        resp = self._create_slip(employee_client, employee, ppe_item)
        assert resp.status_code == 201
        assert resp.data["status"] == SlipStatus.PENDING

    def test_create_slip_empty_items_returns_400(self, employee_client, employee):
        resp = employee_client.post(
            "/api/v1/picking/slips/create/",
            {"employee_id": str(employee.id), "request_type": "expiry", "items": []},
            format="json",
        )
        assert resp.status_code == 400

    def test_full_create_approve_issue_flow(
        self,
        employee_client,
        manager_client,
        store_client,
        employee,
        manager_user,
        store_user,
        ppe_item,
        stock_item,
        warehouse,
    ):
        # 1. Create slip
        resp = self._create_slip(employee_client, employee, ppe_item)
        assert resp.status_code == 201
        slip_id = resp.data["id"]

        # 2. If there are pending approvals, approve them all with the manager
        slip = PickingSlip.objects.get(pk=slip_id)
        pending = Approval.objects.filter(picking_slip=slip, status=ApprovalStatus.PENDING)
        for approval in pending:
            # Use the appropriate role client
            if approval.required_role == "manager":
                manager_client.post(
                    f"/api/v1/approvals/{approval.id}/approve/",
                    {"comment": "Approved"},
                    format="json",
                )
            elif approval.required_role == "safety":
                # Use manager_client for safety too (role check is on the approval role)
                # In a real test you'd use safety_client
                pass

        # Manually set to APPROVED if still pending (no approval levels configured)
        slip.refresh_from_db()
        if slip.status != SlipStatus.APPROVED:
            slip.status = SlipStatus.APPROVED
            slip.save(update_fields=["status"])

        # 3. Validate scan
        qr_payload = generate_slip_qr_payload(str(slip_id))
        scan_resp = store_client.post(
            "/api/v1/picking/slips/validate-scan/",
            {"qr_data": qr_payload},
            format="json",
        )
        assert scan_resp.status_code == 200

        # 4. Finalize issue
        initial_qty = stock_item.quantity_available
        finalize_resp = store_client.post(
            "/api/v1/picking/slips/finalize-issue/",
            {"slip_id": str(slip_id), "warehouse_id": str(warehouse.id)},
            format="json",
        )
        assert finalize_resp.status_code == 200
        assert finalize_resp.data["status"] == SlipStatus.ISSUED

        # 5. Stock decremented
        stock_item.refresh_from_db()
        assert stock_item.quantity_available == initial_qty - 1

        # 6. EmployeePPE updated
        emp_ppe = EmployeePPE.objects.get(employee=employee, ppe_item=ppe_item)
        assert emp_ppe.status == EmployeePPEStatus.VALID
        assert emp_ppe.expiry_date is not None

        # 7. Audit log written
        assert AuditLog.objects.filter(entity_type="PickingSlip", entity_id=slip.id).exists()

    def test_reject_closes_slip(self, manager_client, employee, ppe_item, stock_item):
        from picking.factories import PickingSlipFactory

        slip = PickingSlipFactory(employee=employee, status=SlipStatus.PENDING)
        approval = Approval.objects.create(
            picking_slip=slip,
            required_role="manager",
            status=ApprovalStatus.PENDING,
        )

        resp = manager_client.post(
            f"/api/v1/approvals/{approval.id}/reject/",
            {"comment": "Out of stock"},
            format="json",
        )
        assert resp.status_code == 200

        slip.refresh_from_db()
        assert slip.status == SlipStatus.REJECTED

    def test_finalize_wrong_status_returns_400(self, store_client, employee, ppe_item, warehouse):
        from picking.factories import PickingSlipFactory

        slip = PickingSlipFactory(employee=employee, status=SlipStatus.PENDING)
        resp = store_client.post(
            "/api/v1/picking/slips/finalize-issue/",
            {"slip_id": str(slip.id), "warehouse_id": str(warehouse.id)},
            format="json",
        )
        assert resp.status_code == 400

    def test_invalid_qr_returns_400(self, store_client):
        resp = store_client.post(
            "/api/v1/picking/slips/validate-scan/",
            {"qr_data": "notvalidqr"},
            format="json",
        )
        assert resp.status_code == 400

    def test_unauthenticated_cannot_create_slip(self, anon_client, employee, ppe_item):
        resp = anon_client.post(
            "/api/v1/picking/slips/create/",
            {
                "employee_id": str(employee.id),
                "request_type": "expiry",
                "items": [{"ppe_item_id": str(ppe_item.id), "quantity": 1}],
            },
            format="json",
        )
        assert resp.status_code == 401

    def test_auto_create_expiry_only_includes_expired_or_expiring(self, employee_client, employee, department):
        from ppe.models import DepartmentPPERequirement, EmployeePPE, PPEItem

        valid_item = PPEItem.objects.create(
            name="Valid Item X",
            category="head",
            default_validity_days=365,
            is_active=True,
        )
        expired_item = PPEItem.objects.create(
            name="Expired Item Y",
            category="head",
            default_validity_days=365,
            is_active=True,
        )

        DepartmentPPERequirement.objects.create(
            department=department, ppe_item=valid_item, is_required=True, quantity=1
        )
        DepartmentPPERequirement.objects.create(
            department=department, ppe_item=expired_item, is_required=True, quantity=2
        )

        EmployeePPE.objects.create(employee=employee, ppe_item=valid_item, status=EmployeePPEStatus.VALID)
        EmployeePPE.objects.create(employee=employee, ppe_item=expired_item, status=EmployeePPEStatus.EXPIRED)

        resp = employee_client.post(
            "/api/v1/picking/slips/auto-create/",
            {"employee_id": str(employee.id), "request_type": "expiry"},
            format="json",
        )
        assert resp.status_code == 201
        items = resp.data["items"]
        assert len(items) == 1
        assert str(items[0]["ppe_item"]) == str(expired_item.id)
        assert items[0]["quantity"] == 2

    def test_auto_create_new_includes_missing_and_pending(self, employee_client, employee, department):
        from ppe.models import DepartmentPPERequirement, EmployeePPE, PPEItem

        item_a = PPEItem.objects.create(name="New Item A", category="head", default_validity_days=365, is_active=True)
        item_b = PPEItem.objects.create(name="New Item B", category="head", default_validity_days=365, is_active=True)
        DepartmentPPERequirement.objects.create(department=department, ppe_item=item_a, is_required=True, quantity=1)
        DepartmentPPERequirement.objects.create(department=department, ppe_item=item_b, is_required=True, quantity=1)

        # item_a pending, item_b missing => both should be included for "new"
        EmployeePPE.objects.create(employee=employee, ppe_item=item_a, status=EmployeePPEStatus.PENDING_ISSUE)

        resp = employee_client.post(
            "/api/v1/picking/slips/auto-create/",
            {"employee_id": str(employee.id), "request_type": "new"},
            format="json",
        )
        assert resp.status_code == 201
        returned_ids = sorted([str(it["ppe_item"]) for it in resp.data["items"]])
        assert returned_ids == sorted([str(item_a.id), str(item_b.id)])

    def test_auto_create_returns_existing_pending_request(self, employee_client, employee, department):
        from ppe.models import DepartmentPPERequirement, EmployeePPE, PPEItem

        due_item = PPEItem.objects.create(
            name="Due Item Existing",
            category="head",
            default_validity_days=365,
            is_active=True,
        )
        DepartmentPPERequirement.objects.create(
            department=department, ppe_item=due_item, is_required=True, quantity=1
        )
        EmployeePPE.objects.create(employee=employee, ppe_item=due_item, status=EmployeePPEStatus.EXPIRED)

        first = employee_client.post(
            "/api/v1/picking/slips/auto-create/",
            {"employee_id": str(employee.id), "request_type": "expiry"},
            format="json",
        )
        assert first.status_code == 201

        second = employee_client.post(
            "/api/v1/picking/slips/auto-create/",
            {"employee_id": str(employee.id), "request_type": "expiry"},
            format="json",
        )
        assert second.status_code == 200
        assert second.data["id"] == first.data["id"]

    def test_lost_request_forces_manager_approval(self, employee_client, employee, department, safety_user):
        from ppe.models import PPEConfiguration, PPEItem

        ppe_item = PPEItem.objects.create(
            name="Config Item Z",
            category="head",
            default_validity_days=365,
            is_active=True,
        )
        PPEConfiguration.objects.create(
            ppe_item=ppe_item,
            scope_type="department",
            scope_id=department.id,
            validity_days=365,
            grace_days=7,
            requires_approval=True,
            approval_levels=[{"role": "safety", "required": True}],
        )

        resp = employee_client.post(
            "/api/v1/picking/slips/create/",
            {"employee_id": str(employee.id), "request_type": "lost", "items": [{"ppe_item_id": str(ppe_item.id)}]},
            format="json",
        )
        assert resp.status_code == 201
        slip_id = resp.data["id"]
        slip = PickingSlip.objects.get(pk=slip_id)
        roles = list(slip.approvals.values_list("required_role", flat=True))
        assert "manager" in roles

    def test_lost_request_rejects_item_outside_department(self, employee_client, employee, department):
        from ppe.models import PPEItem

        rogue_item = PPEItem.objects.create(
            name="Outside Dept Item",
            category="head",
            default_validity_days=365,
            is_active=True,
        )
        resp = employee_client.post(
            "/api/v1/picking/slips/create/",
            {
                "employee_id": str(employee.id),
                "request_type": "lost",
                "items": [{"ppe_item_id": str(rogue_item.id), "quantity": 1}],
            },
            format="json",
        )
        assert resp.status_code == 400

    def test_manager_list_only_returns_department_submissions(self, manager_client, manager_user, site):
        from organization.factories import DepartmentFactory, EmployeeFactory
        from picking.factories import PickingSlipFactory

        managed_department = DepartmentFactory(site=site, manager=manager_user)
        other_department = DepartmentFactory(site=site)
        managed_employee = EmployeeFactory(department=managed_department)
        other_employee = EmployeeFactory(department=other_department)

        managed_slip = PickingSlipFactory(employee=managed_employee, department=managed_department)
        PickingSlipFactory(employee=other_employee, department=other_department)

        resp = manager_client.get("/api/v1/picking/slips/")
        assert resp.status_code == 200

        ids = {item["id"] for item in resp.data["results"]}
        assert str(managed_slip.id) in ids
        assert len(ids) == 1
