import pytest


@pytest.mark.django_db
class TestSafetyRolePermissions:
    def test_safety_can_list_sites_and_departments(self, safety_client):
        sites_resp = safety_client.get("/api/v1/org/sites/")
        depts_resp = safety_client.get("/api/v1/org/departments/")
        employees_resp = safety_client.get("/api/v1/org/employees/")

        assert sites_resp.status_code == 200
        assert depts_resp.status_code == 200
        assert employees_resp.status_code == 200

    def test_safety_can_create_department(self, safety_client, site):
        resp = safety_client.post(
            "/api/v1/org/departments/",
            {"site": str(site.id), "name": "Safety Managed Dept"},
            format="json",
        )
        assert resp.status_code == 201
        assert resp.data["name"] == "Safety Managed Dept"
