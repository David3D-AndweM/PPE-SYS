"""
Expiry engine tests — marks expired/expiring PPE, sends notifications,
respects Redis lock.
"""

from datetime import date, timedelta

import pytest
from freezegun import freeze_time

from notifications.models import Notification, NotificationType
from ppe.factories import EmployeePPEFactory
from ppe.models import EmployeePPE, EmployeePPEStatus


@pytest.fixture
def employee_ppe_expired(db, employee, ppe_item):
    return EmployeePPEFactory(
        employee=employee,
        ppe_item=ppe_item,
        status=EmployeePPEStatus.VALID,
        expiry_date=date.today() - timedelta(days=1),
    )


@pytest.fixture
def employee_ppe_expiring_soon(db, employee, ppe_item):
    return EmployeePPEFactory(
        employee=employee,
        ppe_item=ppe_item,
        status=EmployeePPEStatus.VALID,
        expiry_date=date.today() + timedelta(days=5),
    )


@pytest.fixture
def critical_employee_ppe_expired(db, employee, critical_ppe_item):
    return EmployeePPEFactory(
        employee=employee,
        ppe_item=critical_ppe_item,
        status=EmployeePPEStatus.VALID,
        expiry_date=date.today() - timedelta(days=1),
    )


@freeze_time("2026-04-09")
@pytest.mark.django_db
class TestExpiryEngine:
    def _run(self):
        from celery_tasks.expiry_engine import _run_expiry_check_logic

        return _run_expiry_check_logic()

    def test_marks_expired_ppe(self, employee_ppe_expired):
        result = self._run()
        assert result["status"] == "completed"
        employee_ppe_expired.refresh_from_db()
        assert employee_ppe_expired.status == EmployeePPEStatus.EXPIRED

    def test_marks_expiring_soon(self, employee_ppe_expiring_soon):
        result = self._run()
        assert result["status"] == "completed"
        employee_ppe_expiring_soon.refresh_from_db()
        assert employee_ppe_expiring_soon.status == EmployeePPEStatus.EXPIRING_SOON

    def test_already_expired_not_double_counted(self, employee):
        from ppe.factories import EmployeePPEFactory

        emp_ppe = EmployeePPEFactory(
            employee=employee,
            status=EmployeePPEStatus.EXPIRED,  # already expired
            expiry_date=date.today() - timedelta(days=10),
        )
        self._run()
        emp_ppe.refresh_from_db()
        assert emp_ppe.status == EmployeePPEStatus.EXPIRED  # unchanged

    def test_valid_non_expiring_not_touched(self, employee, ppe_item):
        emp_ppe = EmployeePPEFactory(
            employee=employee,
            ppe_item=ppe_item,
            status=EmployeePPEStatus.VALID,
            expiry_date=date.today() + timedelta(days=90),
        )
        self._run()
        emp_ppe.refresh_from_db()
        assert emp_ppe.status == EmployeePPEStatus.VALID

    def test_expired_dispatches_notification(self, employee_ppe_expired):
        self._run()
        assert Notification.objects.filter(
            user=employee_ppe_expired.employee.user,
            notification_type=NotificationType.EXPIRY,
        ).exists()

    def test_critical_expired_dispatches_admin_notification(self, critical_employee_ppe_expired, admin_user):
        from accounts.factories import UserRoleFactory, RoleFactory

        # Ensure admin user is on the same site
        site = critical_employee_ppe_expired.employee.department.site
        UserRoleFactory(
            user=admin_user,
            role=RoleFactory(name="Admin"),
            site=site,
        )
        self._run()
        # Critical expired items should notify admins
        assert Notification.objects.filter(
            notification_type=NotificationType.COMPLIANCE,
        ).exists()

    def test_redis_lock_prevents_duplicate_run(self, db):
        """Second call while lock is held should return skipped."""
        from celery_tasks.expiry_engine import LOCK_KEY, LOCK_TTL, _get_redis_client, run_expiry_check

        client = _get_redis_client()
        # Manually hold the lock
        client.set(LOCK_KEY, "1", ex=LOCK_TTL, nx=True)

        try:
            result = run_expiry_check.apply().get()
            assert result["status"] == "skipped"
        finally:
            client.delete(LOCK_KEY)
