"""
TDD tests for the gap_analysis service and EmployeeGapAnalysisView.
Written before implementation (RED phase).
"""

import pytest
from django.urls import reverse

from ppe.factories import EmployeePPEFactory, PPEItemFactory
from ppe.models import DepartmentPPERequirement, EmployeePPEStatus


# ─── Service-level tests ─────────────────────────────────────────────────────


@pytest.mark.django_db
def test_all_ppe_assigned_is_compliant(employee, ppe_item):
    """Employee with all required PPE in valid status → is_compliant=True, missing=[]."""
    from ppe.services import gap_analysis

    DepartmentPPERequirement.objects.create(
        department=employee.department,
        ppe_item=ppe_item,
        is_required=True,
    )
    EmployeePPEFactory(
        employee=employee,
        ppe_item=ppe_item,
        status=EmployeePPEStatus.VALID,
    )

    result = gap_analysis(employee)

    assert result["is_compliant"] is True
    assert result["missing"] == []
    assert result["compliance_percentage"] == 100.0
    assert len(result["assigned"]) == 1


@pytest.mark.django_db
def test_missing_ppe_item_in_missing_list(employee, ppe_item):
    """Employee with one required item not assigned → it appears in missing."""
    from ppe.services import gap_analysis

    DepartmentPPERequirement.objects.create(
        department=employee.department,
        ppe_item=ppe_item,
        is_required=True,
    )
    # No EmployeePPE row for this employee

    result = gap_analysis(employee)

    assert result["is_compliant"] is False
    assert len(result["missing"]) == 1
    assert result["missing"][0]["ppe_item_id"] == str(ppe_item.id)
    assert result["missing"][0]["name"] == ppe_item.name
    assert result["assigned"] == []
    assert result["compliance_percentage"] == 0.0


@pytest.mark.django_db
def test_expired_ppe_classified_correctly(employee, ppe_item):
    """Employee with an expired PPE item → appears in expired, not assigned."""
    from ppe.services import gap_analysis

    DepartmentPPERequirement.objects.create(
        department=employee.department,
        ppe_item=ppe_item,
        is_required=True,
    )
    EmployeePPEFactory(
        employee=employee,
        ppe_item=ppe_item,
        status=EmployeePPEStatus.EXPIRED,
    )

    result = gap_analysis(employee)

    assert result["is_compliant"] is False
    assert len(result["expired"]) == 1
    assert result["expired"][0]["ppe_item_id"] == str(ppe_item.id)
    assert result["assigned"] == []
    assert result["missing"] == []


@pytest.mark.django_db
def test_pending_ppe_classified_correctly(employee, ppe_item):
    """Employee with a pending_issue PPE → appears in pending."""
    from ppe.services import gap_analysis

    DepartmentPPERequirement.objects.create(
        department=employee.department,
        ppe_item=ppe_item,
        is_required=True,
    )
    EmployeePPEFactory(
        employee=employee,
        ppe_item=ppe_item,
        status=EmployeePPEStatus.PENDING_ISSUE,
    )

    result = gap_analysis(employee)

    assert result["is_compliant"] is False
    assert len(result["pending"]) == 1
    assert result["pending"][0]["ppe_item_id"] == str(ppe_item.id)
    assert result["assigned"] == []
    assert result["missing"] == []


@pytest.mark.django_db
def test_non_required_items_excluded(employee, ppe_item):
    """Items with is_required=False are not counted in the gap analysis."""
    from ppe.services import gap_analysis

    DepartmentPPERequirement.objects.create(
        department=employee.department,
        ppe_item=ppe_item,
        is_required=False,
    )

    result = gap_analysis(employee)

    assert result["required"] == []
    assert result["is_compliant"] is True
    assert result["compliance_percentage"] == 100.0


# ─── API-level tests ──────────────────────────────────────────────────────────


@pytest.mark.django_db
def test_admin_can_view_any_gap(admin_client, employee, ppe_item):
    """Admin can GET the gap analysis for any employee → 200."""
    DepartmentPPERequirement.objects.create(
        department=employee.department,
        ppe_item=ppe_item,
        is_required=True,
    )
    url = f"/api/v1/ppe/gap-analysis/{employee.id}/"
    response = admin_client.get(url)
    assert response.status_code == 200
    assert "is_compliant" in response.data
    assert "missing" in response.data


@pytest.mark.django_db
def test_employee_can_view_own_gap(employee_client, employee, ppe_item):
    """Employee can GET their own gap analysis → 200."""
    DepartmentPPERequirement.objects.create(
        department=employee.department,
        ppe_item=ppe_item,
        is_required=True,
    )
    EmployeePPEFactory(
        employee=employee,
        ppe_item=ppe_item,
        status=EmployeePPEStatus.VALID,
    )
    url = f"/api/v1/ppe/gap-analysis/{employee.id}/"
    response = employee_client.get(url)
    assert response.status_code == 200
    assert response.data["is_compliant"] is True


@pytest.mark.django_db
def test_employee_cannot_view_other_gap(employee_client, department, role_employee):
    """Employee cannot view another employee's gap analysis → 403."""
    from accounts.factories import UserFactory, UserRoleFactory

    other_user = UserFactory(email="other@test.com")
    UserRoleFactory(user=other_user, role=role_employee)
    from organization.factories import EmployeeFactory
    other_emp = EmployeeFactory(department=department, user=other_user)

    url = f"/api/v1/ppe/gap-analysis/{other_emp.id}/"
    response = employee_client.get(url)
    assert response.status_code == 403


@pytest.mark.django_db
def test_gap_analysis_404_for_unknown_employee(admin_client):
    """GET with a non-existent employee UUID → 404."""
    import uuid
    url = f"/api/v1/ppe/gap-analysis/{uuid.uuid4()}/"
    response = admin_client.get(url)
    assert response.status_code == 404
