from datetime import date

import pytest
from freezegun import freeze_time

from ppe.factories import EmployeePPEFactory
from ppe.models import EmployeePPEStatus


@freeze_time("2026-04-09")
@pytest.mark.django_db
def test_send_pre_expiry_alerts_sends_for_threshold(monkeypatch, employee, ppe_item):
    # Arrange: one PPE expiring exactly at +7 days (default threshold)
    EmployeePPEFactory(
        employee=employee,
        ppe_item=ppe_item,
        status=EmployeePPEStatus.VALID,
        expiry_date=date(2026, 4, 16),
    )

    # Keep test minimal and deterministic: single threshold, no side effects.
    from django.conf import settings as django_settings

    monkeypatch.setattr(django_settings, "PPE_ALERT_THRESHOLDS_DAYS", [7], raising=False)

    # Avoid depending on notification implementation details.
    monkeypatch.setattr("notifications.services.dispatch", lambda **kwargs: None)

    # Act
    from celery_tasks.alert_scheduler import send_pre_expiry_alerts

    result = send_pre_expiry_alerts()

    # Assert
    assert result["status"] == "completed"
    assert result["alerts_sent"] == 1
