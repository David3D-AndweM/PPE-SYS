import csv
import json
from datetime import datetime

from django.http import StreamingHttpResponse
from rest_framework.generics import ListAPIView
from rest_framework.response import Response
from rest_framework.views import APIView

from core.permissions import IsAdmin

from .models import AuditLog
from .serializers import AuditLogSerializer


def _filter_audit_qs(request, qs):
    """Apply shared query-param filters to an AuditLog queryset."""
    entity_type = request.query_params.get("entity_type")
    entity_id = request.query_params.get("entity_id")
    user_id = request.query_params.get("user")
    date_from = request.query_params.get("from")
    date_to = request.query_params.get("to")

    if entity_type:
        qs = qs.filter(entity_type=entity_type)
    if entity_id:
        qs = qs.filter(entity_id=entity_id)
    if user_id:
        qs = qs.filter(user_id=user_id)
    if date_from:
        qs = qs.filter(timestamp__date__gte=date_from)
    if date_to:
        qs = qs.filter(timestamp__date__lte=date_to)
    return qs


class AuditLogListView(ListAPIView):
    queryset = AuditLog.objects.select_related("user").order_by("-timestamp")
    serializer_class = AuditLogSerializer
    permission_classes = [IsAdmin]
    filterset_fields = ["action", "entity_type", "user"]
    search_fields = ["action", "entity_type", "user__email"]

    def get_queryset(self):
        qs = super().get_queryset()
        return _filter_audit_qs(self.request, qs)


class _Echo:
    """Pseudo-buffer for csv.writer that returns the written value."""

    def write(self, value):
        return value


class AuditLogExportView(APIView):
    """
    Stream a CSV export of the audit log.
    Accepts the same filters as AuditLogListView plus optional
    ?from=YYYY-MM-DD and ?to=YYYY-MM-DD date range params.
    """

    permission_classes = [IsAdmin]

    _COLUMNS = [
        "timestamp",
        "user_email",
        "user_name",
        "action",
        "entity_type",
        "entity_id",
        "ip_address",
        "metadata",
    ]

    def get(self, request):
        qs = AuditLog.objects.select_related("user").order_by("-timestamp")
        qs = _filter_audit_qs(request, qs)

        filename = f"audit_log_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.csv"

        response = StreamingHttpResponse(
            self._generate_rows(qs),
            content_type="text/csv; charset=utf-8",
        )
        response["Content-Disposition"] = f'attachment; filename="{filename}"'
        return response

    def _generate_rows(self, qs):
        writer = csv.writer(_Echo())
        yield writer.writerow(self._COLUMNS)

        for log in qs.iterator(chunk_size=2000):
            if log.user:
                user_email = log.user.email
                full_name = log.user.get_full_name().strip()
                user_name = full_name if full_name else log.user.email
            else:
                user_email = "system"
                user_name = "system"

            yield writer.writerow([
                log.timestamp.isoformat(),
                user_email,
                user_name,
                log.action,
                log.entity_type,
                str(log.entity_id) if log.entity_id else "",
                log.ip_address or "",
                json.dumps(log.metadata, default=str, ensure_ascii=False),
            ])
