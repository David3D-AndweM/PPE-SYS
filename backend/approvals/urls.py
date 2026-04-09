from django.urls import path

from .views import ApproveView, PendingApprovalListView, RejectView

app_name = "approvals"

urlpatterns = [
    path("pending/", PendingApprovalListView.as_view(), name="pending-list"),
    path("<uuid:pk>/approve/", ApproveView.as_view(), name="approve"),
    path("<uuid:pk>/reject/", RejectView.as_view(), name="reject"),
]
