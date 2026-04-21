"""
TDD: Immutability guard tests for AuditLog.
Write these BEFORE implementing B1, run to confirm RED, then implement.
"""

import pytest

from audit.models import AuditImmutableError, AuditLog


@pytest.mark.django_db
def test_creating_audit_log_succeeds():
    log = AuditLog.objects.create(action="created", entity_type="TestEntity")
    assert log.pk is not None


@pytest.mark.django_db
def test_log_action_helper_creates_log():
    from audit.models import log_action

    log_action("test", "entity")
    assert AuditLog.objects.count() == 1


@pytest.mark.django_db
def test_save_on_existing_raises():
    log = AuditLog.objects.create(action="original", entity_type="TestEntity")
    with pytest.raises(AuditImmutableError):
        log.save()


@pytest.mark.django_db
def test_instance_delete_raises():
    log = AuditLog.objects.create(action="original", entity_type="TestEntity")
    with pytest.raises(AuditImmutableError):
        log.delete()


@pytest.mark.django_db
def test_queryset_delete_raises():
    log = AuditLog.objects.create(action="original", entity_type="TestEntity")
    with pytest.raises(AuditImmutableError):
        AuditLog.objects.filter(pk=log.pk).delete()


@pytest.mark.django_db
def test_queryset_update_raises():
    log = AuditLog.objects.create(action="original", entity_type="TestEntity")
    with pytest.raises(AuditImmutableError):
        AuditLog.objects.filter(pk=log.pk).update(action="x")
