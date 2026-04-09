from django.urls import path

from .views import (
    DepartmentPPERequirementListCreateView,
    EmployeePPEListView,
    MyPPEComplianceSummaryView,
    MyPPEView,
    PPEConfigurationListCreateView,
    PPEItemDetailView,
    PPEItemListCreateView,
)

app_name = "ppe"

urlpatterns = [
    path("items/", PPEItemListCreateView.as_view(), name="item-list"),
    path("items/<uuid:pk>/", PPEItemDetailView.as_view(), name="item-detail"),
    path("configurations/", PPEConfigurationListCreateView.as_view(), name="config-list"),
    path("requirements/", DepartmentPPERequirementListCreateView.as_view(), name="requirements-list"),
    path("assignments/", EmployeePPEListView.as_view(), name="assignment-list"),
    path("my-ppe/", MyPPEView.as_view(), name="my-ppe"),
    path("my-ppe/compliance/", MyPPEComplianceSummaryView.as_view(), name="my-ppe-compliance"),
]
