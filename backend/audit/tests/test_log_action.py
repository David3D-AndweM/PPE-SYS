"""
TDD: Tests for the log_action() convenience function.
"""

from uuid import uuid4

import pytest

from audit.models import AuditLog, log_action


@pytest.mark.django_db
def test_log_action_writes_correct_fields():
    entity_id = uuid4()
    log = log_action(
        "ACTION",
        "Entity",
        entity_id=entity_id,
        metadata={"k": "v"},
        user=None,
        ip_address="1.2.3.4",
    )
    assert log.action == "ACTION"
    assert log.entity_type == "Entity"
    assert log.entity_id == entity_id
    assert log.metadata == {"k": "v"}
    assert log.user is None
    assert log.ip_address == "1.2.3.4"


@pytest.mark.django_db
def test_log_action_defaults_metadata_to_empty_dict():
    log = log_action("A", "B")
    assert log.metadata == {}


@pytest.mark.django_db
def test_log_action_tolerates_no_user():
    log = log_action("A", "B", user=None)
    assert log.user is None


@pytest.mark.django_db
def test_log_action_stores_ip():
    log = log_action("A", "B", ip_address="192.168.1.1")
    assert log.ip_address == "192.168.1.1"
