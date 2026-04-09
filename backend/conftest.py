"""
Root-level pytest fixtures shared across all apps.
"""

import pytest
from rest_framework.test import APIClient

from accounts.factories import RoleFactory, UserFactory, UserRoleFactory
from inventory.factories import StockItemFactory, WarehouseFactory
from organization.factories import DepartmentFactory, EmployeeFactory, SiteFactory
from ppe.factories import EmployeePPEFactory, PPEItemFactory

# ─── Roles (seeded once, get_or_create) ─────────────────────────────────────


@pytest.fixture
def role_admin(db):
    return RoleFactory(name="Admin")


@pytest.fixture
def role_manager(db):
    return RoleFactory(name="Manager")


@pytest.fixture
def role_safety(db):
    return RoleFactory(name="Safety")


@pytest.fixture
def role_store(db):
    return RoleFactory(name="Store")


@pytest.fixture
def role_employee(db):
    return RoleFactory(name="Employee")


# ─── Users with roles ───────────────────────────────────────────────────────


@pytest.fixture
def admin_user(db, role_admin):
    user = UserFactory(email="admin@test.com")
    UserRoleFactory(user=user, role=role_admin)
    return user


@pytest.fixture
def manager_user(db, role_manager):
    user = UserFactory(email="manager@test.com")
    UserRoleFactory(user=user, role=role_manager)
    return user


@pytest.fixture
def safety_user(db, role_safety):
    user = UserFactory(email="safety@test.com")
    UserRoleFactory(user=user, role=role_safety)
    return user


@pytest.fixture
def store_user(db, role_store):
    user = UserFactory(email="store@test.com")
    UserRoleFactory(user=user, role=role_store)
    return user


# ─── Organisation ───────────────────────────────────────────────────────────


@pytest.fixture
def site(db):
    return SiteFactory()


@pytest.fixture
def department(db, site):
    return DepartmentFactory(site=site)


@pytest.fixture
def employee(db, department, role_employee):
    emp = EmployeeFactory(department=department)
    UserRoleFactory(user=emp.user, role=role_employee)
    return emp


# ─── PPE & Stock ────────────────────────────────────────────────────────────


@pytest.fixture
def ppe_item(db):
    return PPEItemFactory(default_validity_days=365)


@pytest.fixture
def critical_ppe_item(db):
    return PPEItemFactory(is_critical=True, default_validity_days=180)


@pytest.fixture
def warehouse(db, site):
    return WarehouseFactory(site=site)


@pytest.fixture
def stock_item(db, ppe_item, warehouse):
    return StockItemFactory(ppe_item=ppe_item, warehouse=warehouse, quantity_available=50)


# ─── API clients (authenticated) ────────────────────────────────────────────


def _auth_client(user):
    client = APIClient()
    client.force_authenticate(user=user)
    return client


@pytest.fixture
def admin_client(admin_user):
    return _auth_client(admin_user)


@pytest.fixture
def manager_client(manager_user):
    return _auth_client(manager_user)


@pytest.fixture
def safety_client(safety_user):
    return _auth_client(safety_user)


@pytest.fixture
def store_client(store_user):
    return _auth_client(store_user)


@pytest.fixture
def employee_client(employee):
    return _auth_client(employee.user)


@pytest.fixture
def anon_client():
    return APIClient()
