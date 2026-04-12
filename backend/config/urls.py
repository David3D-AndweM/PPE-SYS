from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

api_v1_patterns = [
    path("auth/", include("accounts.urls", namespace="accounts")),
    path("org/", include("organization.urls", namespace="organization")),
    path("ppe/", include("ppe.urls", namespace="ppe")),
    path("inventory/", include("inventory.urls", namespace="inventory")),
    path("picking/", include("picking.urls", namespace="picking")),
    path("approvals/", include("approvals.urls", namespace="approvals")),
    path("notifications/", include("notifications.urls", namespace="notifications")),
    path("audit/", include("audit.urls", namespace="audit")),
]

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/", include(api_v1_patterns)),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
