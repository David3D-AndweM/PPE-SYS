import pytest


@pytest.mark.django_db
class TestPPEConfigurationAccess:
    def test_safety_can_manage_requirements_for_own_department(self, safety_client, safety_user, department, ppe_item):
        department.safety_officer = safety_user
        department.save(update_fields=["safety_officer"])

        resp = safety_client.post(
            "/api/v1/ppe/requirements/",
            {"department": str(department.id), "ppe_item": str(ppe_item.id), "is_required": True, "quantity": 1},
            format="json",
        )
        assert resp.status_code == 201

    def test_safety_cannot_manage_requirements_for_other_department(
        self, safety_client, safety_user, department, site, ppe_item
    ):
        from organization.factories import DepartmentFactory

        allowed = department
        allowed.safety_officer = safety_user
        allowed.save(update_fields=["safety_officer"])

        other_dept = DepartmentFactory(site=site)

        resp = safety_client.post(
            "/api/v1/ppe/requirements/",
            {"department": str(other_dept.id), "ppe_item": str(ppe_item.id), "is_required": True, "quantity": 1},
            format="json",
        )
        assert resp.status_code == 400

    def test_safety_cannot_create_system_scoped_configuration(self, safety_client, safety_user, department, ppe_item):
        department.safety_officer = safety_user
        department.save(update_fields=["safety_officer"])

        resp = safety_client.post(
            "/api/v1/ppe/configurations/",
            {
                "ppe_item": str(ppe_item.id),
                "scope_type": "system",
                "scope_id": None,
                "validity_days": 365,
                "grace_days": 7,
                "requires_approval": True,
                "approval_levels": [{"role": "manager", "required": True}],
            },
            format="json",
        )
        assert resp.status_code == 400
