"""
TDD: AuditLog list view permission and filter tests.
"""

import pytest

from audit.models import AuditLog


@pytest.mark.django_db
def test_admin_can_list_audit_logs(admin_client):
    response = admin_client.get("/api/v1/audit/logs/")
    assert response.status_code == 200


@pytest.mark.django_db
def test_manager_cannot_list_audit_logs(manager_client):
    response = manager_client.get("/api/v1/audit/logs/")
    assert response.status_code == 403


@pytest.mark.django_db
def test_anon_cannot_list_audit_logs(anon_client):
    response = anon_client.get("/api/v1/audit/logs/")
    assert response.status_code in (401, 403)


@pytest.mark.django_db
def test_filter_by_entity_type(admin_client):
    AuditLog.objects.create(action="a1", entity_type="TypeA")
    AuditLog.objects.create(action="a2", entity_type="TypeB")
    response = admin_client.get("/api/v1/audit/logs/?entity_type=TypeA")
    assert response.status_code == 200
    data = response.json()
    results = data.get("results", data)
    assert len(results) == 1
    assert results[0]["entity_type"] == "TypeA"


@pytest.mark.django_db
def test_response_includes_timestamp_field(admin_client):
    AuditLog.objects.create(action="check", entity_type="TestEntity")
    response = admin_client.get("/api/v1/audit/logs/")
    assert response.status_code == 200
    data = response.json()
    results = data.get("results", data)
    assert len(results) >= 1
    assert "timestamp" in results[0]


@pytest.mark.django_db
def test_response_includes_user_name_field(admin_client, admin_user):
    AuditLog.objects.create(action="check", entity_type="TestEntity", user=admin_user)
    response = admin_client.get("/api/v1/audit/logs/")
    assert response.status_code == 200
    data = response.json()
    results = data.get("results", data)
    assert len(results) >= 1
    # Find the log created with our admin_user
    log_with_user = next((r for r in results if r.get("user_name") is not None), None)
    assert log_with_user is not None
    assert log_with_user["user_name"] is not None
