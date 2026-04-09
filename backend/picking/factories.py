import factory
from factory.django import DjangoModelFactory

from organization.factories import EmployeeFactory
from .models import PickingSlip, PickingSlipItem, SlipStatus


class PickingSlipFactory(DjangoModelFactory):
    class Meta:
        model = PickingSlip

    employee = factory.SubFactory(EmployeeFactory)
    department = factory.LazyAttribute(lambda o: o.employee.department)
    request_type = "expiry"
    status = SlipStatus.PENDING
    requested_by = factory.LazyAttribute(lambda o: o.employee.user)
    notes = ""


class PickingSlipItemFactory(DjangoModelFactory):
    class Meta:
        model = PickingSlipItem

    picking_slip = factory.SubFactory(PickingSlipFactory)
    quantity = 1
