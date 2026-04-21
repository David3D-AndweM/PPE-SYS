import pytest

from organization.factories import DepartmentFactory, EmployeeFactory


@pytest.mark.django_db
class TestManagerScope:
    def test_manager_sees_only_employees_in_managed_department(self, manager_client, manager_user, site):
        managed_dept = DepartmentFactory(site=site, manager=manager_user)
        other_dept = DepartmentFactory(site=site)
        managed_employee = EmployeeFactory(department=managed_dept)
        EmployeeFactory(department=other_dept)

        resp = manager_client.get("/api/v1/org/employees/")

        assert resp.status_code == 200
        ids = {item["id"] for item in resp.data["results"]}
        assert str(managed_employee.id) in ids
        assert len(ids) == 1
