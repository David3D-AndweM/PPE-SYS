from django.db import models

from core.models import TimeStampedModel
from core.utils.validators import validate_positive_nonzero


class PPECategory(models.TextChoices):
    HEAD = "head", "Head Protection"
    EYE = "eye", "Eye & Face Protection"
    RESPIRATORY = "respiratory", "Respiratory Protection"
    HAND = "hand", "Hand Protection"
    FOOT = "foot", "Foot Protection"
    HEARING = "hearing", "Hearing Protection"
    HI_VIS = "hi_vis", "High-Visibility Clothing"
    BODY = "body", "Body / Fall Protection"
    OTHER = "other", "Other"


class PPEItem(TimeStampedModel):
    """
    Master catalogue of PPE types. Seeded by admin — not created by users.
    """

    name = models.CharField(max_length=255, unique=True)
    category = models.CharField(max_length=50, choices=PPECategory.choices)
    description = models.TextField(blank=True)
    is_critical = models.BooleanField(
        default=False,
        help_text="Critical PPE requires additional oversight when expired.",
    )
    default_validity_days = models.PositiveIntegerField(
        help_text="System-wide default validity in days if no config override exists.",
        validators=[validate_positive_nonzero],
    )
    requires_serial_tracking = models.BooleanField(
        default=False,
        help_text="True for items like helmets that need individual serial numbers.",
    )
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = "ppe_items"
        ordering = ["category", "name"]

    def __str__(self):
        return f"{self.name} ({self.get_category_display()})"


class ScopeType(models.TextChoices):
    SYSTEM = "system", "System-wide"
    SITE = "site", "Site"
    DEPARTMENT = "department", "Department"


class PPEConfiguration(TimeStampedModel):
    """
    Configurable override layer for PPE rules. Scope hierarchy:
    department > site > system (most specific wins).

    `scope_id` references the PK of either a Site or Department — stored
    as a plain UUID to avoid a polymorphic FK. Service layer resolves it.
    """

    ppe_item = models.ForeignKey(
        PPEItem, on_delete=models.CASCADE, related_name="configurations"
    )
    scope_type = models.CharField(max_length=20, choices=ScopeType.choices)
    scope_id = models.UUIDField(null=True, blank=True)
    validity_days = models.PositiveIntegerField(validators=[validate_positive_nonzero])
    grace_days = models.PositiveIntegerField(
        default=7,
        help_text="Number of days before expiry to mark status as 'expiring_soon'.",
    )
    requires_approval = models.BooleanField(default=True)
    # JSONB: [{"role": "manager", "required": true}, {"role": "safety", "required": true}]
    approval_levels = models.JSONField(
        default=list,
        help_text="Ordered list of approval steps. Example: [{\"role\": \"manager\", \"required\": true}]",
    )

    class Meta:
        db_table = "ppe_configurations"
        indexes = [
            models.Index(fields=["ppe_item", "scope_type"]),
        ]

    def __str__(self):
        scope = f"{self.scope_type}"
        if self.scope_id:
            scope += f":{self.scope_id}"
        return f"{self.ppe_item.name} config [{scope}]"


class DepartmentPPERequirement(TimeStampedModel):
    """Which PPE items are required for a given department, and how many."""

    department = models.ForeignKey(
        "organization.Department",
        on_delete=models.CASCADE,
        related_name="ppe_requirements",
    )
    ppe_item = models.ForeignKey(PPEItem, on_delete=models.CASCADE)
    is_required = models.BooleanField(default=True)
    quantity = models.PositiveIntegerField(default=1)

    class Meta:
        db_table = "department_ppe_requirements"
        unique_together = [("department", "ppe_item")]

    def __str__(self):
        req = "required" if self.is_required else "optional"
        return f"{self.department} → {self.ppe_item} ({req}, qty={self.quantity})"


class EmployeePPEStatus(models.TextChoices):
    VALID = "valid", "Valid"
    EXPIRING_SOON = "expiring_soon", "Expiring Soon"
    EXPIRED = "expired", "Expired"
    BLOCKED = "blocked", "Blocked"
    PENDING_ISSUE = "pending_issue", "Pending Issue"


class EmployeePPE(TimeStampedModel):
    """
    Tracks the actual PPE held by an employee. One row per employee per PPE type.
    Updated by the picking/issuing flow and by the Celery expiry engine.
    """

    employee = models.ForeignKey(
        "organization.Employee",
        on_delete=models.CASCADE,
        related_name="ppe_assignments",
    )
    ppe_item = models.ForeignKey(PPEItem, on_delete=models.PROTECT)
    issue_date = models.DateField(null=True, blank=True)
    expiry_date = models.DateField(null=True, blank=True, db_index=True)
    status = models.CharField(
        max_length=20,
        choices=EmployeePPEStatus.choices,
        default=EmployeePPEStatus.PENDING_ISSUE,
        db_index=True,
    )
    last_inspection_date = models.DateField(null=True, blank=True)
    condition_status = models.CharField(max_length=50, blank=True)
    # Serial number for items that require tracking
    serial_number = models.CharField(max_length=100, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        db_table = "employee_ppe"
        unique_together = [("employee", "ppe_item")]
        indexes = [
            models.Index(fields=["employee"]),
            models.Index(fields=["expiry_date"]),
            models.Index(fields=["status"]),
        ]

    def __str__(self):
        return f"{self.employee} — {self.ppe_item} [{self.status}]"

    @property
    def is_compliant(self):
        return self.status == EmployeePPEStatus.VALID
