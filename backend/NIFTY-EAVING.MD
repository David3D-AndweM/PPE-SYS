# EPPEP — Enterprise PPE Compliance & Issuing Platform

## Context

Greenfield build of a full-stack enterprise system for managing PPE compliance in multi-site mining environments. Zero code exists — only `PPE-ACHTECT.md` (schema + architecture reference) and an empty `suggested.md` in `/Users/dave/Desktop/PPE_SYSTEM/`. The system enforces PPE lifecycle: assignment → monitoring → expiry alerts → picking slips → dual approval → store issuing → audit trail.

Stack: Django 5.1 + DRF + Django Channels + Celery + PostgreSQL + Redis / Flutter (mobile-first) / Docker.

---

## Directory Structure

```
/PPE_SYSTEM/
├── backend/                  # Django monolith
│   ├── config/               # settings/, urls.py, asgi.py, wsgi.py
│   ├── core/                 # Base models, permissions, QR utils
│   ├── accounts/             # CustomUser, Role, UserRole, JWT tokens
│   ├── organization/         # Organization → Site → Department → Employee
│   ├── ppe/                  # PPEItem, PPEConfiguration, EmployeePPE
│   ├── inventory/            # Warehouse, StockItem, StockMovement
│   ├── picking/              # PickingSlip, PickingSlipItem, ScanLog
│   ├── approvals/            # Approval workflow
│   ├── notifications/        # Notification model + WebSocket consumer
│   ├── audit/                # AuditLog (signals + middleware)
│   └── celery_tasks/         # expiry_engine, alert_scheduler, stock_monitor
├── frontend/                 # Flutter app (feature-first structure)
│   └── lib/
│       ├── core/             # api_client, auth_bloc, router, websocket
│       └── features/         # auth, my_ppe, picking_slips, scanning, approvals, admin
├── fixtures/                 # Numbered JSON fixtures (01_roles → 12_picking_slips_demo)
├── scripts/seed.sh
├── docker-compose.yml
├── docker-compose.prod.yml
├── .env.example
├── Makefile
└── README.md
```

---

## Implementation Order (strict dependency layers)

### Layer 0 — Infrastructure
- `docker-compose.yml`: services: postgres:16, redis:7, backend (uvicorn ASGI), celery_worker, celery_beat, nginx
- `.env.example`, `Makefile` (`make dev`, `make migrate`, `make seed`, `make test`)
- `backend/requirements/base.txt`, `dev.txt`, `prod.txt`
- `backend/Dockerfile`, `docker/nginx/default.conf`

**Key packages**: Django 5.1, djangorestframework, djangorestframework-simplejwt, django-channels, channels-redis, daphne, celery, django-celery-beat, redis, psycopg (v3), qrcode[pil], Pillow, factory-boy, pytest-django, freezegun

### Layer 1 — Django Config
- `config/settings/base.py`: INSTALLED_APPS (all 9 apps), CHANNEL_LAYERS (redis), CELERY_*, SIMPLE_JWT, DATABASES, CORS
- `config/asgi.py`: `ProtocolTypeRouter` splitting HTTP vs WebSocket (`AuthMiddlewareStack` + `URLRouter`)
- `config/urls.py`: include all app URL namespaces under `/api/v1/`

### Layer 2 — Core App (foundation all apps inherit)
- `core/models.py`: `UUIDModel(abstract)`, `TimeStampedModel(abstract)`, `SoftDeleteModel(abstract)`
- `core/permissions.py`: `IsAdmin`, `IsManager`, `IsSafetyOfficer`, `IsStoreOfficer`, `IsEmployee`
- `core/utils/qr.py`: HMAC-signed QR payload generation/verification
- `core/middleware.py`, `core/pagination.py`, `core/exceptions.py`

### Layer 3 — Accounts
- `accounts/models.py`: `CustomUser(AbstractBaseUser)`, `Role`, `UserRole` (scoped to site/department)
- `accounts/tokens.py`: Extend `TokenObtainPairSerializer` — embed `roles`, `employee_id`, `site_ids` in JWT
- `accounts/views.py`: login, refresh, profile, user CRUD
- `accounts/migrations/0001_initial.py`

### Layer 4 — Organization
- `organization/models.py`: `Organization`, `Site`, `Department` (manager_id + safety_officer_id FKs), `Employee` (mine_number unique, status)
- `organization/signals.py`: `post_save` on Employee → call `ppe.services.auto_assign_ppe()`
- `organization/migrations/0001_initial.py`

### Layer 5 — PPE
- `ppe/models.py`: `PPEItem` (is_critical, default_validity_days), `PPEConfiguration` (scope_type enum: system/site/department, scope_id nullable, approval_levels JSONB), `DepartmentPPERequirement`, `EmployeePPE` (status: valid/expiring_soon/expired/blocked)
- `ppe/services.py`:
  - `resolve_ppe_config(ppe_item, dept)` — walks dept → site → system scope (most specific wins)
  - `auto_assign_ppe(employee)` — wrapped in `transaction.atomic()`, creates EmployeePPE for all dept requirements not already assigned
  - `compute_expiry(issue_date, validity_days)` → date
- `ppe/migrations/0001_initial.py`

### Layer 6 — Inventory
- `inventory/models.py`: `Warehouse`, `StockItem` (quantity_available, reorder_level), `StockMovement` (change_type: IN/OUT, reference_type: ISSUE/RETURN/ADJUSTMENT)
- `inventory/services.py`: `deduct_stock()`, `receive_stock()`, `check_reorder()` (triggers notification if below reorder_level)

### Layer 7 — Audit (wires into everything via signals)
- `audit/models.py`: `AuditLog` (user_id FK, action, entity_type, entity_id, metadata JSONB, timestamp)
- `audit/signals.py`: Universal `post_save`/`post_delete` listeners on key models
- `audit/middleware.py`: Attaches request context (user, IP) to thread-local for signal use
- `audit/views.py`: Read-only endpoint (Admin only)

### Layer 8 — Notifications + WebSockets
- `notifications/models.py`: `Notification` (type: expiry/approval/stock/compliance, is_read)
- `notifications/consumers.py`: `NotificationConsumer(AsyncWebsocketConsumer)` — auth via JWT query param `?token=...`, joins group `user_{user_id}`
- `notifications/services.py`: `dispatch(user, type, title, message)` — saves model + `channel_layer.group_send` for real-time push
- `notifications/routing.py`: WebSocket URL pattern → wired into `config/asgi.py`

### Layer 9 — Approvals
- `approvals/models.py`: `Approval` (picking_slip FK, approver_id FK, role: manager/safety, status: pending/approved/rejected, comment)
- `approvals/services.py`:
  - `approve(approval_id, user, comment)` → mark approved → `check_all_approved(slip)`
  - `reject(approval_id, user, comment)` → slip status = rejected immediately
  - `check_all_approved(slip)` → if all required Approvals approved → slip.status = approved → notify store officers

### Layer 10 — Picking (orchestration hub)
- `picking/models.py`: `PickingSlip` (request_type: expiry/lost/damaged/new, status: pending/approved/issued/rejected, qr_code), `PickingSlipItem`, `ScanLog`
- `picking/services.py`:
  - `create_slip(employee, items, request_type, requested_by)` → creates slip + items → reads approval_levels from PPEConfiguration → creates Approval records → notifies approvers
  - `validate_scan(raw_qr_data)` → HMAC verify → return slip details
  - `finalize_issue(slip_id, store_officer)` → deduct stock per item → update EmployeePPE (new expiry) → mark slip issued → audit log
- `picking/qr_utils.py`: uses `core/utils/qr.py`

### Layer 11 — Celery Tasks
- `celery_tasks/expiry_engine.py` (daily at 00:30 via beat):
  1. Bulk-mark expired EmployeePPE (in chunks of 500)
  2. Bulk-mark expiring_soon (within grace_days from PPEConfiguration)
  3. Dispatch notifications to employee + manager + safety officer
  4. Critical PPE expired → also notify site Admins
  5. Redis distributed lock prevents duplicate runs; single AuditLog entry per run
- `celery_tasks/alert_scheduler.py`: Pre-expiry alert dispatch (7-day, 3-day warnings)
- `celery_tasks/stock_monitor.py`: Periodic stock level check → notify store officers when at/below reorder_level

### Layer 12 — Fixtures & Seed Data
Files: `fixtures/01_roles.json` through `fixtures/12_picking_slips_demo.json`

Demo story: "AuricMines Ltd" → 2 sites → 4 departments each → 40 employees → 12 PPE item types. Includes:
- 5 employees with PPE expiring within 7 days (alert system demo)
- 2 slips in `pending` (approval workflow demo)
- 1 slip in `approved` with QR code (scan flow demo)
- 1 stock item at reorder level (stock alert demo)

`scripts/seed.sh`: `migrate` → `loaddata` in order → `createsuperuser --noinput`

### Layer 13 — Flutter Frontend
Feature-first structure. Key packages: flutter_bloc, go_router, dio, flutter_secure_storage, web_socket_channel, mobile_scanner, freezed, get_it.

**Core**:
- `core/api/api_client.dart`: Dio with base URL from env
- `core/api/interceptors.dart`: Inject Bearer token; on 401 → silent refresh via refresh token → retry; on refresh fail → redirect to login
- `core/auth/token_storage.dart`: flutter_secure_storage (never SharedPreferences for tokens)
- `core/router/app_router.dart`: go_router with redirect based on role in decoded JWT:
  - admin → `/admin/dashboard`
  - manager → `/manager/compliance`
  - safety → `/safety/approvals`
  - store → `/store/scan`
  - employee → `/my-ppe`
- `core/websocket/ws_service.dart`: Connect on foreground, exponential backoff on disconnect, dispatch NotificationBloc events

**Features** (each has `data/`, `domain/`, `presentation/`):
- `auth/`: Login screen, JWT decode, auth state
- `my_ppe/`: Employee PPE list with status badges
- `picking_slips/`: List + detail + create slip
- `scanning/`: Camera scan via mobile_scanner → POST validate-scan → confirm issue
- `approvals/`: Pending approvals list → approve/reject with comment
- `compliance/`: Team PPE compliance grid (Manager/Admin)
- `notifications/`: Inbox with real-time WebSocket updates
- `admin/`: Org settings, user management, PPE catalogue, branding

---

## Key Design Decisions

| Concern | Decision |
|---|---|
| JWT claims | Embed roles + employee_id + site_ids → no per-request DB lookup for authorization |
| QR payload | HMAC-signed, not raw UUID → forgery prevention |
| Approval levels | JSONB field on PPEConfiguration → add levels with zero code change |
| PPE config scope | dept > site > system (most specific wins) |
| Stock deduction timing | On `finalize_issue()`, not on approval → matches physical reality |
| ASGI server | Daphne or Uvicorn workers (Gunicorn alone breaks Channels) |
| Celery beat scheduler | `DatabaseScheduler` → schedule managed via Django admin |
| State management (Flutter) | BLoC — testable, predictable across 5 role UIs |

---

## Critical Files (highest blast radius)

1. `backend/core/models.py` — Abstract base classes every model inherits; wrong here = painful migration cascade
2. `backend/config/settings/base.py` — INSTALLED_APPS, CHANNEL_LAYERS, CELERY_BEAT_SCHEDULE, SIMPLE_JWT, DATABASES all land here
3. `backend/config/asgi.py` — Channels routing; most error-prone setup step; must be correct before any WS code works
4. `backend/ppe/services.py` — `auto_assign_ppe()` and `resolve_ppe_config()`; drives assignment, expiry calc, approval level derivation
5. `backend/picking/services.py` — Full slip lifecycle orchestration; highest cross-app coordination; bugs here have compliance risk

---

## Indexes to Add (post-migration)

```sql
employee_ppe(employee_id)
employee_ppe(expiry_date)
picking_slips(status)
stock_items(warehouse_id)
notifications(user_id, is_read)
```

---

## Verification / Testing

**Backend**:
- `pytest` + `pytest-django` + `factory_boy` (no raw `Model.objects.create()` in tests)
- `freezegun` for expiry engine date-freezing
- `channels.testing.WebsocketCommunicator` for WebSocket consumer tests
- Full picking slip lifecycle integration test: create → approve (×2) → issue → verify AuditLog entries + StockItem quantity + EmployeePPE updated
- Min 80% coverage gate (`pytest-cov`)

**Flutter**:
- BLoC state machines via `bloc_test` + `mocktail`
- Widget tests for approval confirm flow
- Integration test for scan-and-issue flow against mock backend

**End-to-end smoke test** (`make seed && make dev`):
1. Login as each of the 5 role types → correct dashboard loads
2. Trigger expiry engine manually: `celery call celery_tasks.expiry_engine.run_expiry_check` → notifications appear in UI
3. Scan the demo approved slip QR → issue flow completes → stock decrements → EmployeePPE updated
4. Audit log endpoint returns full trail
