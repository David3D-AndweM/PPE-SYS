from django.urls import path

from .views import (
    CreatePickingSlipView,
    FinalizeIssueView,
    PickingSlipDetailView,
    PickingSlipListView,
    ValidateScanView,
)

app_name = "picking"

urlpatterns = [
    path("slips/", PickingSlipListView.as_view(), name="slip-list"),
    path("slips/create/", CreatePickingSlipView.as_view(), name="slip-create"),
    path("slips/<uuid:pk>/", PickingSlipDetailView.as_view(), name="slip-detail"),
    path("slips/validate-scan/", ValidateScanView.as_view(), name="validate-scan"),
    path("slips/finalize-issue/", FinalizeIssueView.as_view(), name="finalize-issue"),
]
