"""
PPE domain services.

Critical functions:
- resolve_ppe_config: hierarchical scope resolution (dept > site > system)
- auto_assign_ppe: idempotent PPE assignment on employee creation/transfer
- compute_expiry: date arithmetic for expiry calculation
"""

import logging
from datetime import date, timedelta

from django.db import transaction

logger = logging.getLogger(__name__)


def resolve_ppe_config(ppe_item, department):
    """
    Find the most specific PPEConfiguration for a (ppe_item, department) pair.

    Resolution order (most specific wins):
    1. Department-level config for this department
    2. Site-level config for the department's site
    3. System-level config
    4. Fall back to ppe_item.default_validity_days with sensible defaults

    Returns a dict with keys: validity_days, grace_days, requires_approval,
    approval_levels.
    """
    from .models import PPEConfiguration, ScopeType

    # 1. Department scope
    config = PPEConfiguration.objects.filter(
        ppe_item=ppe_item,
        scope_type=ScopeType.DEPARTMENT,
        scope_id=department.id,
    ).first()

    if config is None:
        # 2. Site scope
        config = PPEConfiguration.objects.filter(
            ppe_item=ppe_item,
            scope_type=ScopeType.SITE,
            scope_id=department.site_id,
        ).first()

    if config is None:
        # 3. System scope
        config = PPEConfiguration.objects.filter(
            ppe_item=ppe_item,
            scope_type=ScopeType.SYSTEM,
            scope_id=None,
        ).first()

    if config is not None:
        return {
            "validity_days": config.validity_days,
            "grace_days": config.grace_days,
            "requires_approval": config.requires_approval,
            "approval_levels": config.approval_levels,
        }

    # 4. Hardcoded fallback — uses ppe_item default
    return {
        "validity_days": ppe_item.default_validity_days,
        "grace_days": 7,
        "requires_approval": True,
        "approval_levels": [
            {"role": "manager", "required": True},
            {"role": "safety", "required": True},
        ],
    }


def compute_expiry(issue_date: date, validity_days: int) -> date:
    return issue_date + timedelta(days=validity_days)


@transaction.atomic
def auto_assign_ppe(employee):
    """
    Idempotently assign all required PPE for an employee based on their
    department's requirements. Called on employee creation and department
    transfer. Does NOT overwrite existing valid/expiring PPE records.

    Returns a list of newly created EmployeePPE instances.
    """
    from .models import DepartmentPPERequirement, EmployeePPE, EmployeePPEStatus

    requirements = DepartmentPPERequirement.objects.filter(
        department=employee.department,
        is_required=True,
    ).select_related("ppe_item")

    created = []

    for req in requirements:
        ppe_item = req.ppe_item
        config = resolve_ppe_config(ppe_item, employee.department)

        # Idempotency check — don't overwrite valid/expiring records
        existing = EmployeePPE.objects.filter(
            employee=employee,
            ppe_item=ppe_item,
        ).first()

        if existing and existing.status not in (
            EmployeePPEStatus.EXPIRED,
            EmployeePPEStatus.BLOCKED,
        ):
            logger.debug(
                "Employee %s already has %s (%s) — skipping",
                employee.mine_number,
                ppe_item.name,
                existing.status,
            )
            continue

        today = date.today()
        assignment, new = EmployeePPE.objects.update_or_create(
            employee=employee,
            ppe_item=ppe_item,
            defaults={
                "status": EmployeePPEStatus.PENDING_ISSUE,
                "issue_date": None,
                "expiry_date": None,
                "notes": "Auto-assigned — pending first issue",
            },
        )
        if new:
            created.append(assignment)
            logger.info(
                "Created PPE assignment: %s → %s",
                employee.mine_number,
                ppe_item.name,
            )

    return created


def update_ppe_after_issue(employee_ppe, issue_date: date):
    """
    Called by picking.services.finalize_issue after a PPE item has been
    physically issued to an employee.
    """
    from .models import EmployeePPEStatus

    config = resolve_ppe_config(employee_ppe.ppe_item, employee_ppe.employee.department)
    employee_ppe.issue_date = issue_date
    employee_ppe.expiry_date = compute_expiry(issue_date, config["validity_days"])
    employee_ppe.status = EmployeePPEStatus.VALID
    employee_ppe.save(update_fields=["issue_date", "expiry_date", "status", "updated_at"])


def get_employee_compliance_summary(employee):
    """
    Returns a dict summarising the employee's PPE compliance status:
    total, valid, expiring_soon, expired, pending.
    """
    from .models import EmployeePPE, EmployeePPEStatus

    assignments = EmployeePPE.objects.filter(employee=employee)
    total = assignments.count()

    counts = {
        "employee_name": employee.user.get_full_name(),
        "mine_number": employee.mine_number,
        "department_name": employee.department.name,
        "site_name": employee.department.site.name,
        "total": total,
        "valid": assignments.filter(status=EmployeePPEStatus.VALID).count(),
        "expiring_soon": assignments.filter(status=EmployeePPEStatus.EXPIRING_SOON).count(),
        "expired": assignments.filter(status=EmployeePPEStatus.EXPIRED).count(),
        "pending_issue": assignments.filter(status=EmployeePPEStatus.PENDING_ISSUE).count(),
        "is_compliant": not assignments.exclude(status=EmployeePPEStatus.VALID).exists(),
    }
    return counts
