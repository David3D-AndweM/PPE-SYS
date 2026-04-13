import pytest
from rest_framework.test import APIClient

from accounts.factories import RoleFactory, UserFactory
from organization.factories import DepartmentFactory


@pytest.mark.django_db
class TestUserRoleScopeValidation:
    def test_manager_role_requires_department(self):
        admin = UserFactory(email="admin_scope@test.com", is_staff=True, is_superuser=True)
        target = UserFactory(email="target_manager_scope@test.com")
        manager_role = RoleFactory(name="Manager")

        client = APIClient()
        client.force_authenticate(user=admin)
        resp = client.post(
            f"/api/v1/auth/users/{target.id}/roles/",
            {"role": str(manager_role.id)},
            format="json",
        )

        assert resp.status_code == 400
        assert "department" in resp.data["error"]["detail"]

    def test_safety_role_requires_department(self):
        admin = UserFactory(email="admin_safety_scope@test.com", is_staff=True, is_superuser=True)
        target = UserFactory(email="target_safety_scope@test.com")
        safety_role = RoleFactory(name="Safety")

        client = APIClient()
        client.force_authenticate(user=admin)
        resp = client.post(
            f"/api/v1/auth/users/{target.id}/roles/",
            {"role": str(safety_role.id)},
            format="json",
        )

        assert resp.status_code == 400
        assert "department" in resp.data["error"]["detail"]

    def test_employee_role_accepts_department_and_derives_site(self):
        admin = UserFactory(email="admin_emp_scope@test.com", is_staff=True, is_superuser=True)
        target = UserFactory(email="target_emp_scope@test.com")
        employee_role = RoleFactory(name="Employee")
        department = DepartmentFactory()

        client = APIClient()
        client.force_authenticate(user=admin)
        resp = client.post(
            f"/api/v1/auth/users/{target.id}/roles/",
            {"role": str(employee_role.id), "department": str(department.id)},
            format="json",
        )

        assert resp.status_code == 201
        assert str(resp.data["department"]) == str(department.id)
        assert str(resp.data["site"]) == str(department.site.id)

    def test_manager_role_assignment_sets_department_manager(self):
        admin = UserFactory(email="admin_manager_link@test.com", is_staff=True, is_superuser=True)
        target = UserFactory(email="target_manager_link@test.com")
        manager_role = RoleFactory(name="Manager")
        department = DepartmentFactory()

        client = APIClient()
        client.force_authenticate(user=admin)
        resp = client.post(
            f"/api/v1/auth/users/{target.id}/roles/",
            {"role": str(manager_role.id), "department": str(department.id)},
            format="json",
        )

        department.refresh_from_db()
        assert resp.status_code == 201
        assert str(department.manager_id) == str(target.id)
