import os

from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.development")

app = Celery("ppe_system")

# Load configuration from Django settings under the CELERY_ namespace
app.config_from_object("django.conf:settings", namespace="CELERY")

# Auto-discover tasks in all INSTALLED_APPS
app.autodiscover_tasks()

# Named queues for priority separation
app.conf.task_routes = {
    "celery_tasks.expiry_engine.*": {"queue": "expiry"},
    "celery_tasks.alert_scheduler.*": {"queue": "alerts"},
    "celery_tasks.stock_monitor.*": {"queue": "stock"},
}
