from django.urls import path

from .views import (
    DepartmentPPERequirementDetailView,
    DepartmentPPERequirementListCreateView,
    EmployeePPEListView,
    MyPPEComplianceSummaryView,
    MyPPEView,
    PPEConfigurationDetailView,
    PPEConfigurationListCreateView,
    PPEItemDetailView,
    PPEItemListCreateView,
)

app_name = "ppe"

urlpatterns = [
    path("items/", PPEItemListCreateView.as_view(), name="item-list"),
    path("items/<uuid:pk>/", PPEItemDetailView.as_view(), name="item-detail"),
    path("configurations/", PPEConfigurationListCreateView.as_view(), name="config-list"),
    path("configurations/<uuid:pk>/", PPEConfigurationDetailView.as_view(), name="config-detail"),
    path("requirements/", DepartmentPPERequirementListCreateView.as_view(), name="requirements-list"),
    path("requirements/<uuid:pk>/", DepartmentPPERequirementDetailView.as_view(), name="requirement-detail"),
    path("assignments/", EmployeePPEListView.as_view(), name="assignment-list"),
    path("my-ppe/", MyPPEView.as_view(), name="my-ppe"),
    path("my-ppe/compliance/", MyPPEComplianceSummaryView.as_view(), name="my-ppe-compliance"),
]
