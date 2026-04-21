from django.urls import path

from .views import AuditLogExportView, AuditLogListView

app_name = "audit"

urlpatterns = [
    path("logs/", AuditLogListView.as_view(), name="log-list"),
    path("logs/export/", AuditLogExportView.as_view(), name="log-export"),
]
