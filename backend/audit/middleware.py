from core.middleware import AuditContextMiddleware

# Re-export so that settings.MIDDLEWARE can reference audit.middleware.AuditMiddleware
AuditMiddleware = AuditContextMiddleware
