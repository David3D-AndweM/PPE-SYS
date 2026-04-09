# EPPEP — Enterprise PPE Compliance & Issuing Platform

A production-grade platform for managing the full lifecycle of Personal Protective Equipment across multi-site mining operations.

## Architecture

```
Django 5.1 backend  ←→  PostgreSQL 16
       ↕                      ↕
  Celery + Beat          Redis 7
       ↕
Django Channels (WebSockets)
       ↕
Flutter mobile app
```

**Backend apps:** `core` · `accounts` · `organization` · `ppe` · `inventory` · `picking` · `approvals` · `notifications` · `audit`

---

## Quick Start (Docker)

### Prerequisites
- Docker + Docker Compose
- Make (optional but recommended)

### 1. Clone and configure

```bash
git clone <repo>
cd PPE_SYSTEM
cp .env.example .env
# Edit .env — at minimum set strong values for:
#   SECRET_KEY, POSTGRES_PASSWORD, QR_SECRET_KEY
```

### 2. Start all services

```bash
make dev
# or: docker compose up --build
```

### 3. Seed demo data

```bash
make seed
# Loads all fixtures + creates superuser: admin@auricmines.com / Admin1234!
```

### 4. Access the system

| Service | URL |
|---|---|
| API root | http://localhost/api/v1/ |
| Django admin | http://localhost/admin/ |
| WebSocket | ws://localhost/ws/notifications/?token=\<jwt\> |

---

## Demo Accounts (after seeding)

| Email | Password | Role |
|---|---|---|
| admin@auricmines.com | Admin1234! | Admin (superuser) |
| manager1@auricmines.com | — | Manager (Shaft 12) |
| safety1@auricmines.com | — | Safety Officer |
| store1@auricmines.com | — | Store Officer |
| emp001@auricmines.com | — | Employee AM-001 |

> **Note:** Fixture users have placeholder password hashes. Use `make superuser` or the admin panel to set real passwords for the non-superuser accounts, or update the fixture to use `django.contrib.auth.hashers.make_password("yourpassword")`.

---

## Demo Data Story

The seed creates **AuricMines Ltd** with two sites:

- **Shaft 12** — Underground Operations + Electrical & Maintenance departments
- **Open Pit 3** — Blasting & Drilling + Processing Plant departments

Pre-loaded states to exercise every workflow immediately:

| What | Why |
|---|---|
| Employee AM-001 has an expired SCSR (critical PPE) | Demonstrates expiry alerts and critical PPE escalation |
| AM-001's P2 respirator expires in 5 days | Demonstrates `expiring_soon` state |
| 2 picking slips in `pending` state | Demonstrates the approval queue |
| 1 picking slip in `approved` state with QR code | Demonstrates the scan-and-issue flow |
| P2 respirator stock at 8 (reorder level: 10) | Demonstrates stock alert |
| SCSR stock at 3 (reorder level: 5) | Demonstrates stock alert |

---

## Core API Endpoints

### Auth
```
POST /api/v1/auth/login/                  → access + refresh tokens
POST /api/v1/auth/token/refresh/          → rotate access token
GET  /api/v1/auth/me/                     → current user profile
```

### PPE
```
GET  /api/v1/ppe/my-ppe/                  → my assigned PPE
GET  /api/v1/ppe/my-ppe/compliance/       → compliance summary
GET  /api/v1/ppe/items/                   → PPE catalogue
GET  /api/v1/ppe/assignments/?employee=   → all employee PPE
```

### Picking Slips
```
GET  /api/v1/picking/slips/               → list slips
POST /api/v1/picking/slips/create/        → create new slip
GET  /api/v1/picking/slips/:id/           → slip detail + QR image
POST /api/v1/picking/slips/validate-scan/ → validate scanned QR
POST /api/v1/picking/slips/finalize-issue/ → execute issue, deduct stock
```

### Approvals
```
GET  /api/v1/approvals/pending/           → pending approvals for your role
POST /api/v1/approvals/:id/approve/       → approve
POST /api/v1/approvals/:id/reject/        → reject (with comment)
```

### Notifications
```
GET  /api/v1/notifications/               → notification inbox
GET  /api/v1/notifications/unread-count/  → badge count
POST /api/v1/notifications/mark-all-read/ → clear all
POST /api/v1/notifications/:id/mark-read/ → mark one read
```

### Organization
```
GET  /api/v1/org/organizations/
GET  /api/v1/org/sites/?organization=
GET  /api/v1/org/departments/?site=
GET  /api/v1/org/employees/?department=&status=
POST /api/v1/org/employees/:id/transfer/
```

### Inventory
```
GET  /api/v1/inventory/warehouses/
GET  /api/v1/inventory/stock/?site=
POST /api/v1/inventory/stock/receive/
GET  /api/v1/inventory/movements/
```

### Audit
```
GET  /api/v1/audit/logs/?entity_type=&entity_id= (Admin only)
```

---

## WebSocket (Real-time Notifications)

Connect after login:
```
ws://localhost/ws/notifications/?token=<access_token>
```

The server pushes JSON when a notification is dispatched:
```json
{
  "id": "uuid",
  "type": "expiry|approval|stock|compliance|system",
  "title": "...",
  "message": "...",
  "created_at": "2026-04-09T..."
}
```

Client can send:
```json
{"action": "mark_read", "notification_id": "uuid"}
```

---

## Celery Background Tasks

| Task | Schedule | Queue |
|---|---|---|
| `celery_tasks.expiry_engine.run_expiry_check` | Daily 00:30 | `expiry` |
| `celery_tasks.alert_scheduler.send_pre_expiry_alerts` | Daily | `alerts` |
| `celery_tasks.stock_monitor.check_reorder_levels` | Hourly | `stock` |

Run manually:
```bash
make task name=celery_tasks.expiry_engine.run_expiry_check
```

Schedules are managed via Django admin → **Periodic Tasks** (django-celery-beat).

---

## Key Design Decisions

### QR Code Security
Picking slip QR codes are **HMAC-SHA256 signed** (not raw UUIDs). The `QR_SECRET_KEY` env variable signs each payload. The store officer's scan is rejected if the signature doesn't match.

### PPE Configuration Hierarchy
`resolve_ppe_config(ppe_item, department)` resolves validity and approval rules in order:
1. Department-scope config
2. Site-scope config  
3. System-scope config
4. `ppe_item.default_validity_days` fallback

### Approval Levels
Stored as JSONB on `PPEConfiguration.approval_levels`:
```json
[{"role": "manager", "required": true}, {"role": "safety", "required": true}]
```
Adding a third approver requires **zero code changes** — update the database record.

### JWT Claims
Access tokens embed `roles`, `employee_id`, `site_ids`, and `full_name` to avoid per-request DB queries for authorization.

---

## Flutter Frontend

### Setup
```bash
cd frontend
flutter pub get
flutter run
```

Configure API URL in `frontend/.env`:
```
API_BASE_URL=http://<your-machine-ip>/api/v1
WS_BASE_URL=ws://<your-machine-ip>/ws
```

Use your machine's LAN IP (not `localhost`) when running on a physical device.

### Role-based Navigation
| Role | Home screen |
|---|---|
| Admin | Admin dashboard |
| Manager | Team compliance |
| Safety Officer | Pending approvals |
| Store Officer | QR scanner |
| Employee | My PPE |

---

## Running Tests

### Backend
```bash
make test
# Runs: pytest --cov=. --cov-report=term-missing
```

Individual app:
```bash
docker compose exec backend pytest accounts/tests/ -v
```

### Flutter
```bash
cd frontend
flutter test
```

---

## Development Commands

```bash
make dev           # Start all services (foreground)
make dev-d         # Start in background
make migrate       # Run Django migrations
make seed          # Load all fixtures + create superuser
make test          # Run backend test suite
make shell         # Django shell
make logs          # Tail backend + celery logs
make superuser     # Create superuser interactively
make static        # Collect static files
make reset         # Stop all services and wipe volumes (full reset)
make task name=<celery.task.path>  # Run a Celery task manually
```

---

## Production Deployment Checklist

- [ ] Set strong `SECRET_KEY`, `POSTGRES_PASSWORD`, `QR_SECRET_KEY` in `.env`
- [ ] Set `DEBUG=False` and `DJANGO_SETTINGS_MODULE=config.settings.production`
- [ ] Switch Dockerfile to use `requirements/prod.txt`
- [ ] Configure `ALLOWED_HOSTS` with your domain
- [ ] Enable HTTPS (update nginx config with SSL cert)
- [ ] Set `SECURE_SSL_REDIRECT=True`
- [ ] Configure external email provider (update `EMAIL_*` env vars)
- [ ] Set up database backups
- [ ] Configure Sentry DSN for error tracking
- [ ] Scale Celery workers: `celery -A celery_tasks.app worker -c 8`

---

## Project Structure

```
PPE_SYSTEM/
├── backend/              Django project
│   ├── config/           Settings, ASGI, URLs
│   ├── core/             Base models, permissions, QR utils
│   ├── accounts/         Users, roles, JWT
│   ├── organization/     Org hierarchy + employee signals
│   ├── ppe/              PPE catalogue, config, employee tracking
│   ├── inventory/        Warehouses, stock, movements
│   ├── picking/          Picking slip lifecycle (create→approve→issue)
│   ├── approvals/        Dual-approval workflow
│   ├── notifications/    In-app + WebSocket notifications
│   ├── audit/            Immutable audit trail
│   └── celery_tasks/     Expiry engine, alert scheduler, stock monitor
├── frontend/             Flutter app (feature-first)
├── fixtures/             Demo data (numbered, load in order)
├── scripts/seed.sh       Database seeding script
├── docker-compose.yml    Local dev orchestration
├── docker-compose.prod.yml
├── Makefile              Developer convenience commands
└── .env.example          Environment variable template
```
