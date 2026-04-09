from django.urls import path

from .views import (
    DepartmentDetailView,
    DepartmentListCreateView,
    EmployeeDetailView,
    EmployeeListCreateView,
    EmployeeTransferView,
    OrganizationDetailView,
    OrganizationListCreateView,
    SiteDetailView,
    SiteListCreateView,
)

app_name = "organization"

urlpatterns = [
    path("organizations/", OrganizationListCreateView.as_view(), name="org-list"),
    path("organizations/<uuid:pk>/", OrganizationDetailView.as_view(), name="org-detail"),
    path("sites/", SiteListCreateView.as_view(), name="site-list"),
    path("sites/<uuid:pk>/", SiteDetailView.as_view(), name="site-detail"),
    path("departments/", DepartmentListCreateView.as_view(), name="dept-list"),
    path("departments/<uuid:pk>/", DepartmentDetailView.as_view(), name="dept-detail"),
    path("employees/", EmployeeListCreateView.as_view(), name="employee-list"),
    path("employees/<uuid:pk>/", EmployeeDetailView.as_view(), name="employee-detail"),
    path("employees/<uuid:pk>/transfer/", EmployeeTransferView.as_view(), name="employee-transfer"),
]
