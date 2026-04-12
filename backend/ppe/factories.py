import factory
from factory.django import DjangoModelFactory

from organization.factories import EmployeeFactory

from .models import EmployeePPE, EmployeePPEStatus, PPECategory, PPEItem


class PPEItemFactory(DjangoModelFactory):
    class Meta:
        model = PPEItem

    name = factory.Sequence(lambda n: f"PPE Item {n}")
    category = PPECategory.HEAD
    default_validity_days = 365
    is_critical = False
    is_active = True
    requires_serial_tracking = False


class EmployeePPEFactory(DjangoModelFactory):
    class Meta:
        model = EmployeePPE

    employee = factory.SubFactory(EmployeeFactory)
    ppe_item = factory.SubFactory(PPEItemFactory)
    status = EmployeePPEStatus.VALID
    issue_date = None
    expiry_date = None
