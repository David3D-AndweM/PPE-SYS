import factory
from factory.django import DjangoModelFactory

from accounts.factories import UserFactory

from .models import Department, Employee, Organization, Site


class OrganizationFactory(DjangoModelFactory):
    class Meta:
        model = Organization
        django_get_or_create = ("slug",)

    name = "Test Mining Corp"
    slug = "test-mining-corp"
    is_active = True


class SiteFactory(DjangoModelFactory):
    class Meta:
        model = Site

    organization = factory.SubFactory(OrganizationFactory)
    name = factory.Sequence(lambda n: f"Site {n}")
    is_active = True


class DepartmentFactory(DjangoModelFactory):
    class Meta:
        model = Department

    site = factory.SubFactory(SiteFactory)
    name = factory.Sequence(lambda n: f"Department {n}")
    is_active = True


class EmployeeFactory(DjangoModelFactory):
    class Meta:
        model = Employee

    user = factory.SubFactory(UserFactory)
    department = factory.SubFactory(DepartmentFactory)
    mine_number = factory.Sequence(lambda n: f"EMP{n:04d}")
    status = "active"
