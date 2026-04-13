import pytest


@pytest.mark.django_db
class TestSafetyPpeItemPermissions:
    def test_safety_can_create_ppe_item(self, safety_client):
        resp = safety_client.post(
            "/api/v1/ppe/items/",
            {
                "name": "Safety Created Harness",
                "category": "body",
                "default_validity_days": 365,
                "is_critical": True,
                "requires_serial_tracking": True,
            },
            format="json",
        )
        assert resp.status_code == 201
        assert resp.data["name"] == "Safety Created Harness"

    def test_safety_can_update_ppe_item(self, safety_client, ppe_item):
        resp = safety_client.patch(
            f"/api/v1/ppe/items/{ppe_item.id}/",
            {"default_validity_days": 540},
            format="json",
        )
        assert resp.status_code == 200
        assert resp.data["default_validity_days"] == 540

    def test_safety_can_delete_ppe_item(self, safety_client):
        create = safety_client.post(
            "/api/v1/ppe/items/",
            {
                "name": "Safety Delete Candidate",
                "category": "other",
                "default_validity_days": 90,
                "is_critical": False,
                "requires_serial_tracking": False,
            },
            format="json",
        )
        assert create.status_code == 201

        delete = safety_client.delete(
            f"/api/v1/ppe/items/{create.data['id']}/",
            format="json",
        )
        assert delete.status_code == 204
