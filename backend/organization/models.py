from django.conf import settings
from django.db import models

from core.models import SoftDeleteModel, TimeStampedModel


class Organization(TimeStampedModel):
    name = models.CharField(max_length=255)
    slug = models.SlugField(unique=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = "organizations"
        ordering = ["name"]

    def __str__(self):
        return self.name


class Site(TimeStampedModel):
    """A physical location (mine) belonging to an Organization."""

    organization = models.ForeignKey(Organization, on_delete=models.CASCADE, related_name="sites")
    name = models.CharField(max_length=255)
    location = models.CharField(max_length=500, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = "sites"
        ordering = ["organization", "name"]
        unique_together = [("organization", "name")]

    def __str__(self):
        return f"{self.name} ({self.organization.name})"


class Department(TimeStampedModel):
    site = models.ForeignKey(Site, on_delete=models.CASCADE, related_name="departments")
    name = models.CharField(max_length=255)
    manager = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="managed_departments",
    )
    safety_officer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="safety_departments",
    )
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = "departments"
        ordering = ["site", "name"]
        unique_together = [("site", "name")]

    def __str__(self):
        return f"{self.name} — {self.site.name}"


class Employee(SoftDeleteModel):
    """
    Links a User to a Department. One user = one employee record.
    The `mine_number` is a unique identifier used for physical identification.
    """

    STATUS_ACTIVE = "active"
    STATUS_INACTIVE = "inactive"
    STATUS_SUSPENDED = "suspended"
    STATUS_CHOICES = [
        (STATUS_ACTIVE, "Active"),
        (STATUS_INACTIVE, "Inactive"),
        (STATUS_SUSPENDED, "Suspended"),
    ]

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="employee",
    )
    department = models.ForeignKey(Department, on_delete=models.PROTECT, related_name="employees")
    mine_number = models.CharField(max_length=50, unique=True)
    role_title = models.CharField(max_length=255, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_ACTIVE)
    # Track previous department for transfer workflows
    previous_department = models.ForeignKey(
        Department,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="transferred_employees",
    )

    class Meta:
        db_table = "employees"
        indexes = [
            models.Index(fields=["department"]),
            models.Index(fields=["status"]),
        ]

    def __str__(self):
        return f"{self.user.get_full_name()} [{self.mine_number}]"

    @property
    def site(self):
        return self.department.site

    @property
    def organization(self):
        return self.department.site.organization
