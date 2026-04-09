import logging

from django.core.exceptions import PermissionDenied, ValidationError
from django.http import Http404
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import exception_handler

logger = logging.getLogger(__name__)


def custom_exception_handler(exc, context):
    """
    Wraps DRF's default handler to return a consistent error envelope:
    {"error": {"code": "...", "message": "...", "detail": ...}}
    """
    response = exception_handler(exc, context)

    if response is None:
        # Unhandled exception — let Django 500 machinery deal with it
        if isinstance(exc, (ValidationError, PermissionDenied)):
            response = Response(status=status.HTTP_400_BAD_REQUEST)
        else:
            logger.exception("Unhandled exception in API view", exc_info=exc)
            return None

    code = getattr(exc, "default_code", "error")
    message = str(exc) if not response else response.status_text
    detail = response.data if response else {}

    response.data = {
        "error": {
            "code": code,
            "message": message,
            "detail": detail,
        }
    }
    return response


class BusinessRuleError(Exception):
    """Raised when a domain business rule is violated."""

    def __init__(self, message, code="business_rule_violation"):
        self.message = message
        self.code = code
        super().__init__(message)
