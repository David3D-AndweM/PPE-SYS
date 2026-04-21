"""
TDD tests for the AuditLogExportView CSV export endpoint.
Written before implementation (RED phase).
"""

import io

import pytest

from audit.models import AuditLog

# ─── Helpers ─────────────────────────────────────────────────────────────────

EXPORT_URL = "/api/v1/audit/logs/export/"

EXPECTED_HEADERS = {
    "timestamp",
    "user_email",
    "user_name",
    "action",
    "entity_type",
    "entity_id",
    "ip_address",
    "metadata",
}


# ─── Tests ───────────────────────────────────────────────────────────────────


@pytest.mark.django_db
def test_admin_export_returns_csv(admin_client):
    """Admin GET /api/audit/logs/export/ → 200 with text/csv content type."""
    response = admin_client.get(EXPORT_URL)
    assert response.status_code == 200
    assert "text/csv" in response.get("Content-Type", "")


@pytest.mark.django_db
def test_csv_has_correct_headers(admin_client, admin_user):
    """First row of the CSV contains all required column names."""
    AuditLog.objects.create(
        user=admin_user,
        action="CREATE",
        entity_type="PPEItem",
        metadata={"test": True},
    )

    response = admin_client.get(EXPORT_URL)
    assert response.status_code == 200

    # StreamingHttpResponse: iterate content chunks
    raw = b"".join(response.streaming_content).decode("utf-8")
    lines = raw.strip().splitlines()
    assert len(lines) >= 1, "Expected at least a header row"

    header_fields = {field.strip() for field in lines[0].split(",")}
    assert EXPECTED_HEADERS.issubset(header_fields), f"Missing columns: {EXPECTED_HEADERS - header_fields}"


@pytest.mark.django_db
def test_non_admin_export_forbidden(manager_client):
    """Non-admin users cannot access the export endpoint → 403."""
    response = manager_client.get(EXPORT_URL)
    assert response.status_code == 403


@pytest.mark.django_db
def test_filter_by_entity_type_in_export(admin_client, admin_user):
    """?entity_type= filter works — only matching rows appear in CSV body."""
    AuditLog.objects.create(
        user=admin_user,
        action="CREATE",
        entity_type="PPEItem",
        metadata={},
    )
    AuditLog.objects.create(
        user=admin_user,
        action="UPDATE",
        entity_type="Employee",
        metadata={},
    )

    response = admin_client.get(EXPORT_URL + "?entity_type=PPEItem")
    assert response.status_code == 200

    raw = b"".join(response.streaming_content).decode("utf-8")
    lines = raw.strip().splitlines()
    # 1 header + 1 data row
    assert len(lines) == 2, f"Expected 2 lines (header + 1 row), got: {lines}"
    # The data row must contain PPEItem but not Employee
    assert "PPEItem" in lines[1]
    assert "Employee" not in lines[1]


@pytest.mark.django_db
def test_export_includes_system_user_label(admin_client):
    """Logs without a user get 'system' in the user_email and user_name columns."""
    AuditLog.objects.create(
        user=None,
        action="SYSTEM_CLEANUP",
        entity_type="EmployeePPE",
        metadata={},
    )

    response = admin_client.get(EXPORT_URL)
    assert response.status_code == 200

    raw = b"".join(response.streaming_content).decode("utf-8")
    lines = raw.strip().splitlines()
    assert len(lines) >= 2
    # The data row should contain 'system' for the null user
    assert "system" in lines[1]
