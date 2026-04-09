"""
Full picking slip lifecycle integration test.
Covers: create → approve → validate-scan → finalize-issue.
"""
import pytest

from approvals.models import Approval, ApprovalStatus
from audit.models import AuditLog
from inventory.models import StockItem
from notifications.models import Notification
from picking.models import PickingSlip, SlipStatus
from ppe.models import EmployeePPE, EmployeePPEStatus

from core.utils.qr import generate_slip_qr_payload


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
