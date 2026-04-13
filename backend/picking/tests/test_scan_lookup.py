import pytest

from picking.factories import PickingSlipFactory
from picking.models import SlipStatus


@pytest.mark.django_db
class TestManualScanLookup:
    url = "/api/v1/picking/slips/validate-scan/"

    def test_manual_lookup_by_slip_number_and_mine_number(self, store_client, employee):
        slip = PickingSlipFactory(employee=employee, status=SlipStatus.APPROVED)
        slip_prefix = str(slip.id).upper()[:8]

        resp = store_client.post(
            self.url,
            {"slip_number": slip_prefix, "mine_number": employee.mine_number},
            format="json",
        )

        assert resp.status_code == 200
        assert resp.data["id"] == str(slip.id)
        assert resp.data["mine_number"] == employee.mine_number

    def test_manual_lookup_by_slip_number_and_employee_id(self, store_client, employee):
        slip = PickingSlipFactory(employee=employee, status=SlipStatus.APPROVED)
        slip_prefix = str(slip.id).upper()[:8]

        resp = store_client.post(
            self.url,
            {"slip_number": slip_prefix, "employee_id": str(employee.id)},
            format="json",
        )

        assert resp.status_code == 200
        assert resp.data["id"] == str(slip.id)

    def test_manual_lookup_requires_identity_field(self, store_client):
        resp = store_client.post(
            self.url,
            {"slip_number": "ABC12345"},
            format="json",
        )
        assert resp.status_code == 400
        assert "mine_number or employee_id" in str(resp.data)

    def test_validate_scan_requires_qr_or_slip_number(self, store_client):
        resp = store_client.post(self.url, {}, format="json")
        assert resp.status_code == 400
        assert "Provide qr_data or slip_number" in str(resp.data)

    def test_manual_lookup_rejects_non_approved_slip(self, store_client, employee):
        slip = PickingSlipFactory(employee=employee, status=SlipStatus.PENDING)
        slip_prefix = str(slip.id).upper()[:8]

        resp = store_client.post(
            self.url,
            {"slip_number": slip_prefix, "mine_number": employee.mine_number},
            format="json",
        )

        assert resp.status_code == 400
        assert "cannot be issued" in str(resp.data)
