import threading

_thread_local = threading.local()


def get_current_user():
    return getattr(_thread_local, "user", None)


def get_current_ip():
    return getattr(_thread_local, "ip_address", None)


class AuditContextMiddleware:
    """
    Stores the current request user and IP in thread-local so that
    audit signal handlers can access them without needing a request object.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        _thread_local.user = getattr(request, "user", None)
        _thread_local.ip_address = self._get_ip(request)
        response = self.get_response(request)
        _thread_local.user = None
        _thread_local.ip_address = None
        return response

    @staticmethod
    def _get_ip(request):
        x_forwarded_for = request.META.get("HTTP_X_FORWARDED_FOR")
        if x_forwarded_for:
            return x_forwarded_for.split(",")[0].strip()
        return request.META.get("REMOTE_ADDR", "")
