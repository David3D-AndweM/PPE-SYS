# EPPEP — Full Completion Plan (Backend + Frontend)

## Context

The system is running locally (`make dev` + `flutter run`). The backend is 95% complete — all business logic, services, and endpoints are implemented and working. The frontend is partially complete — core flows work but `CreateSlipScreen` submits empty items (critical bug), admin dashboard routes 3/6 tiles to wrong pages, WebSocket service is implemented but never connected to the UI, and three admin screens are missing entirely. Backend tests have zero coverage. This plan completes everything so every role can demo the full flow end-to-end without hitting a dead end.

---

## What Is Already Working (Do Not Touch)

- Auth BLoC, login, JWT, role-based redirect ✓
- My PPE screen (compliance banner + PPE list) ✓
- Picking slip list, detail (QR renders), approvals screen ✓
- QR scan → issue confirm → finalize (stock deducted, EmployeePPE updated) ✓
- Notifications inbox (REST) ✓
- All backend services: picking, approvals, expiry engine, audit, WebSocket consumer ✓
- Docker stack, seed data, all fixtures, makefile commands ✓
- Server switcher (local/network/custom) on login screen ✓

---

## PART 1 — Frontend Fixes & Completions

### 1.1 Fix CreateSlipScreen — PPE Item Picker (CRITICAL BUG)

**Problem:** `items: []` hardcoded on line 31 of `create_slip_screen.dart` — every submitted slip has no items; backend either rejects or creates empty slips.

**Files:**
- `frontend/lib/features/picking_slips/presentation/create_slip_screen.dart` — full rewrite
- `frontend/lib/features/my_ppe/data/ppe_repository.dart` — add `getPpeItems()`
- `frontend/lib/core/api/endpoints.dart` — `ppeItems` already exists, no change needed

**Add to PpeRepository:**
```dart
Future<List<Map<String, dynamic>>> getPpeItems() async {
  final response = await _client.get(Endpoints.ppeItems);
  final data = response.data as Map<String, dynamic>;
  return (data['results'] as List).cast<Map<String, dynamic>>();
}
```

**Rewrite CreateSlipScreen state to:**
1. On `initState`, call `getPpeItems()` — show loading spinner
2. Display scrollable checklist of PPE items (name + category label)
3. Each row has a quantity stepper (+ / − buttons, default 0, max 10)
4. Tapping a row or hitting + adds it to `_selectedItems` map: `{id: qty}`
5. Section header shows "X items selected" count
6. Validate: at least 1 item with qty > 0 before submit button activates
7. Build payload: `'items': _selectedItems.entries.map((e) => {'ppe_item_id': e.key, 'quantity': e.value}).toList()`

**UI layout:**
```
Request Type
  ○ PPE Expired   ○ PPE Lost   ○ PPE Damaged   ○ New Issue

Items to Request (2 selected)
┌─────────────────────────────────────┐
│ Hard Hat           [−] [1] [+]      │
│ P2 Respirator      [−] [0] [+]      │
│ Safety Harness     [−] [0] [+]      │
│ SCSR (Critical)    [−] [0] [+]      │
└─────────────────────────────────────┘

Notes (optional)
[                              ]

[     Submit Request     ]   ← disabled until item selected
```

---

### 1.2 Wire WebSocket to UI — Real-time Notifications

**Problem:** `WsService` in `core/websocket/ws_service.dart` exists and has full reconnect/backoff logic but `connect()` is never called and `onNotification()` callback is never set. Notifications only update on manual pull-to-refresh.

**Files:**
- `frontend/lib/core/auth/auth_bloc.dart` — call connect/disconnect
- `frontend/lib/core/websocket/ws_service.dart` — add `ValueNotifier<int> unreadPushCount`
- `frontend/lib/features/my_ppe/presentation/my_ppe_screen.dart` — add badge
- `frontend/lib/features/notifications/presentation/notifications_screen.dart` — prepend WS messages

**Changes to WsService:**
```dart
final unreadPushCount = ValueNotifier<int>(0);

void _onMessage(dynamic raw) {
  try {
    final data = jsonDecode(raw as String) as Map<String, dynamic>;
    _onNotification?.call(data);
    unreadPushCount.value++;          // increment badge
  } catch (_) {}
}

void resetBadge() => unreadPushCount.value = 0;
```

**Changes to AuthBloc** (after emitting `AuthAuthenticated`):
```dart
// connect WebSocket
sl<WsService>().connect();
```
And in logout handler:
```dart
await sl<WsService>().disconnect();
sl<WsService>().unreadPushCount.value = 0;
```

**Notification bell in MyPpeScreen AppBar:**
```dart
ValueListenableBuilder<int>(
  valueListenable: sl<WsService>().unreadPushCount,
  builder: (_, count, __) => Badge(
    isLabelVisible: count > 0,
    label: Text('$count'),
    child: IconButton(
      icon: const Icon(Icons.notifications_outlined),
      onPressed: () {
        sl<WsService>().resetBadge();
        context.push('/notifications');
      },
    ),
  ),
)
```

**In NotificationsScreen.initState:** also call `sl<WsService>().resetBadge()`.

---

### 1.3 Fix Admin Dashboard + Add 3 Missing Admin Screens

**Problem:** Admin dashboard tiles for "PPE Catalogue", "Inventory", and "Audit Log" all route to `/my-ppe` (placeholder). These screens do not exist.

**Files to change:**
- `frontend/lib/features/admin/presentation/admin_dashboard_screen.dart` — fix routes
- `frontend/lib/core/router/app_router.dart` — add 3 routes

**Files to create:**
- `frontend/lib/features/admin/presentation/admin_inventory_screen.dart`
- `frontend/lib/features/admin/presentation/admin_ppe_catalogue_screen.dart`
- `frontend/lib/features/admin/presentation/admin_audit_log_screen.dart`

**Fix tile routes:**
```dart
_Tile(Icons.people,       'Employees',    '/compliance'),
_Tile(Icons.security,     'PPE Catalogue','/admin/catalogue'),  // was /my-ppe
_Tile(Icons.approval,     'Approvals',    '/approvals'),
_Tile(Icons.inventory_2,  'Inventory',    '/admin/inventory'),  // was /my-ppe
_Tile(Icons.history,      'Audit Log',    '/admin/audit'),      // was /my-ppe
_Tile(Icons.notifications,'Notifications','/notifications'),
```

**Add to `app_router.dart`:**
```dart
GoRoute(path: '/admin/catalogue', builder: (_, __) => const AdminPpeCatalogueScreen()),
GoRoute(path: '/admin/inventory', builder: (_, __) => const AdminInventoryScreen()),
GoRoute(path: '/admin/audit',     builder: (_, __) => const AdminAuditLogScreen()),
```

**AdminInventoryScreen** (`GET /inventory/stock/` + `POST /inventory/stock/receive/`):
- DataTable: PPE Item | Warehouse | In Stock | Reorder Level | Status
- Rows where `quantity_available <= reorder_level` → amber background
- FAB "Receive Stock" → BottomSheet: PPE item dropdown + warehouse dropdown + qty field → POST receive

**AdminPpeCatalogueScreen** (`GET /ppe/items/` + `POST /ppe/items/`):
- ListView of all PPE items with category Chip, `CRITICAL` badge if `is_critical`
- Tap item → detail dialog: name, category, default_validity_days, requires_serial_tracking
- FAB "Add Item" → BottomSheet form → POST /ppe/items/

**AdminAuditLogScreen** (`GET /audit/logs/`):
- ListView: action | entity_type | user name | timestamp
- Pull-to-refresh, read-only, no write operations
- Each entry is a `ListTile` with icon by action type (CREATE/UPDATE/DELETE)

---

### 1.4 Upgrade Compliance Screen — Per-Employee PPE Status

**Problem:** `ComplianceScreen` loads employees and shows only name + status chip. Manager/Safety cannot see which PPE items are valid/expired without navigating away.

**File:** `frontend/lib/features/compliance/presentation/compliance_screen.dart`

**Add to `Endpoints`:**
```dart
static String get assignments => '$base/ppe/assignments/';
```

**Add to `PpeRepository`:**
```dart
Future<List<Map<String, dynamic>>> getEmployeeAssignments(String employeeId) async {
  final response = await _client.get(
    Endpoints.assignments,
    queryParams: {'employee': employeeId},
  );
  return ((response.data as Map)['results'] as List).cast();
}
```

**Rewrite ComplianceScreen to:**
1. Load employees via `GET /org/employees/`
2. For each employee, load assignments in parallel: `Future.wait(employees.map(...))`
3. Render as `ExpansionTile`:
   - Header: name + mine number + overall status indicator dot (green/amber/red)
   - Expanded: each PPE item row with `PpeStatusBadge` (reuse from `core/widgets/ppe_status_badge.dart`)
4. Sort: non-compliant employees first

---

### 1.5 Notification Badge on All AppBars

Apply the `ValueListenableBuilder` + `Badge` pattern from 1.2 to all screens that show the bell icon:
- `MyPpeScreen` AppBar (already targeted in 1.2)
- `SlipListScreen` AppBar — add bell icon with badge
- `ApprovalsScreen` AppBar — add bell icon with badge

---

### 1.6 Profile / Settings Screen

**File to create:** `frontend/lib/features/auth/presentation/profile_screen.dart`

Content:
- Avatar with initials, full name, email (read from `AuthAuthenticated` state)
- Roles list (chips)
- Mine number if employee role
- "Change Password" section: old password + new password fields → `POST /auth/me/change-password/`
- "Sign Out" button → `AuthBloc.add(AuthLogoutRequested())`

**Add route:**
```dart
GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
```

Add profile avatar icon to `AdminDashboardScreen` and `MyPpeScreen` AppBars.

---

## PART 2 — Backend Completions

### 2.1 Missing Detail/Update Endpoints

**PPEConfiguration detail + update**

`backend/ppe/views.py` — add:
```python
class PPEConfigurationDetailView(RetrieveUpdateDestroyAPIView):
    queryset =   PPEConfiguration.objects.select_related('ppe_item').all()
    serializer_class = PPEConfigurationSerializer
    permission_classes = [IsAdmin]
```

`backend/ppe/urls.py` — add:
```python
path("configurations/<uuid:pk>/", PPEConfigurationDetailView.as_view(), name="configuration-detail"),
```

**DepartmentPPERequirement detail + update** — same pattern in `ppe/views.py` + `ppe/urls.py`.

**Warehouse detail + update**

`backend/inventory/views.py` — add:
```python
class WarehouseDetailView(RetrieveUpdateAPIView):
    queryset = Warehouse.objects.select_related('site').all()
    serializer_class = WarehouseSerializer
    permission_classes = [IsAdmin | IsStoreOfficer]
```

`backend/inventory/urls.py` — add:
```python
path("warehouses/<uuid:pk>/", WarehouseDetailView.as_view(), name="warehouse-detail"),
```

---

### 2.2 Password Reset Flow

**Files:**
- `backend/accounts/views.py` — add `PasswordResetRequestView`, `PasswordResetConfirmView`
- `backend/accounts/urls.py` — add 2 routes
- `backend/config/settings/base.py` — set `EMAIL_BACKEND`

**Flow:**
1. `POST /auth/password-reset/` — takes `{"email": "..."}`, uses Django's `PasswordResetTokenGenerator` to make a time-limited signed token, emails it (console backend for local dev)
2. `POST /auth/password-reset/confirm/` — takes `{"uid": "...", "token": "...", "new_password": "..."}`, validates token via `check_token()`, sets password

**Settings (`base.py`):**
```python
EMAIL_BACKEND = env('EMAIL_BACKEND', default='django.core.mail.backends.console.EmailBackend')
```

In local dev this prints the reset link to Docker logs — no SMTP needed. In production, set `EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend` and provide `EMAIL_HOST` etc.

---

### 2.3 Backend Test Suite

**This is the largest missing piece.** All `tests/__init__.py` files are empty (0 test cases, 0% coverage).

**New test files to create:**

**`backend/conftest.py`** (root-level shared fixtures):
```python
import pytest
from accounts.factories import UserFactory, RoleFactory
from organization.factories import OrganizationFactory, SiteFactory, DepartmentFactory, EmployeeFactory
from ppe.factories import PPEItemFactory, PPEConfigurationFactory, EmployeePPEFactory
from inventory.factories import WarehouseFactory, StockItemFactory

@pytest.fixture
def admin_user(db): return UserFactory(role='Admin')
@pytest.fixture
def manager_user(db): return UserFactory(role='Manager')
@pytest.fixture
def safety_user(db): return UserFactory(role='Safety')
@pytest.fixture
def store_user(db): return UserFactory(role='Store')
@pytest.fixture
def employee(db): return EmployeeFactory()
```

**Factories** — one `factories.py` per app, using `factory_boy`. Example for picking:
```python
class PickingSlipFactory(DjangoModelFactory):
    class Meta: model = PickingSlip
    employee = SubFactory(EmployeeFactory)
    request_type = 'expiry'
    status = 'pending'
```

**`picking/tests/test_lifecycle.py`** — full integration test:
```python
@pytest.mark.django_db(transaction=True)
class TestPickingSlipLifecycle:
    def test_full_create_approve_issue_flow(self, manager_user, safety_user, store_user, employee, stock_item):
        # 1. POST /picking/slips/create/ → 201, slip created, 2 approvals created
        # 2. POST /approvals/<manager_approval_id>/approve/ → partial
        # 3. POST /approvals/<safety_approval_id>/approve/ → slip=APPROVED
        # 4. POST /picking/slips/validate-scan/ with HMAC QR → 200
        # 5. POST /picking/slips/finalize-issue/ → slip=ISSUED
        # 6. Assert stock_item.quantity_available decremented by item qty
        # 7. Assert EmployeePPE.status == 'valid', expiry_date set correctly
        # 8. Assert AuditLog.objects.filter(entity_type='PickingSlip').count() >= 2
        # 9. Assert Notification.objects.filter(user=employee.user).exists()

    def test_reject_closes_slip_immediately(self, manager_user, picking_slip):
        # POST /approvals/<id>/reject/ with comment → slip.status == 'rejected'
```

**`celery_tasks/tests/test_expiry_engine.py`**:
```python
@freeze_time("2026-04-09")
@pytest.mark.django_db
class TestExpiryEngine:
    def test_marks_expired_ppe(self, employee_ppe_expired):
        # employee_ppe_expired.expiry_date = date.today() - timedelta(days=1)
        run_expiry_check()
        employee_ppe_expired.refresh_from_db()
        assert employee_ppe_expired.status == EmployeePPEStatus.EXPIRED

    def test_marks_expiring_soon(self, employee_ppe_expiring):
        # expiry_date = today + 5 days
        run_expiry_check()
        employee_ppe_expiring.refresh_from_db()
        assert employee_ppe_expiring.status == EmployeePPEStatus.EXPIRING_SOON

    def test_redis_lock_prevents_duplicate(self, settings):
        # Call twice concurrently — second returns {"status": "skipped"}
        result = run_expiry_check()
        result2 = run_expiry_check()
        assert result2['status'] == 'skipped'

    def test_critical_expired_notifies_admin(self, critical_employee_ppe):
        run_expiry_check()
        # Admin notification dispatched
        assert Notification.objects.filter(notification_type='expiry').exists()
```

**`accounts/tests/test_auth.py`**:
```python
@pytest.mark.django_db
class TestAuth:
    def test_login_returns_jwt_with_claims(self, client, manager_user):
        resp = client.post('/api/v1/auth/login/', {'email': ..., 'password': ...})
        payload = jwt_decode(resp.data['access'])
        assert 'roles' in payload
        assert 'employee_id' in payload

    def test_refresh_token_works(self, client, manager_user):
    def test_change_password(self, auth_client, manager_user):
    def test_unauthenticated_request_returns_401(self, client):
```

**`approvals/tests/test_workflow.py`**:
```python
@pytest.mark.django_db
class TestApprovalWorkflow:
    def test_wrong_role_cannot_approve(self, store_client, manager_approval):
        resp = store_client.post(f'/api/v1/approvals/{manager_approval.id}/approve/')
        assert resp.status_code == 403

    def test_reject_propagates_to_slip(self, manager_client, approval):
        manager_client.post(f'/api/v1/approvals/{approval.id}/reject/', {'comment': 'No stock'})
        approval.picking_slip.refresh_from_db()
        assert approval.picking_slip.status == PickingSlipStatus.REJECTED
```

**`notifications/tests/test_websocket.py`**:
```python
@pytest.mark.asyncio
class TestNotificationConsumer:
    async def test_authenticated_connection_accepted(self, db, user_with_token):
        communicator = WebsocketCommunicator(
            application, f'/ws/notifications/?token={user_with_token.token}'
        )
        connected, _ = await communicator.connect()
        assert connected

    async def test_unauthenticated_connection_rejected(self):
        communicator = WebsocketCommunicator(application, '/ws/notifications/')
        connected, code = await communicator.connect()
        assert not connected

    async def test_dispatch_delivers_message(self, db, user_with_token):
        communicator = WebsocketCommunicator(...)
        await communicator.connect()
        dispatch(user_with_token.user, 'expiry', 'Test', 'Your PPE expired')
        response = await communicator.receive_json_from()
        assert response['title'] == 'Test'
```

**Coverage target:** 80% minimum — enforce via `backend/pytest.ini`:
```ini
[pytest]
DJANGO_SETTINGS_MODULE = config.settings.development
addopts = --cov=. --cov-report=term-missing --cov-fail-under=80
```

---

## Execution Order

Execute in this exact sequence (each step depends on the previous):

| Step | What | Why First |
|---|---|---|
| 1 | Backend 2.1 — detail/update endpoints | Needed by admin screens |
| 2 | Backend 2.2 — password reset | Standalone, quick |
| 3 | Frontend 1.1 — CreateSlip item picker | Critical bug — blocks core flow |
| 4 | Frontend 1.2 — WebSocket wiring | Auth BLoC change is foundational |
| 5 | Frontend 1.3 — Admin screens | Routes + 3 new screens |
| 6 | Frontend 1.4 — Compliance grid | Uses PpeRepository additions from 1.1 |
| 7 | Frontend 1.5 — Notification badges | Uses WsService from 1.2 |
| 8 | Frontend 1.6 — Profile screen | Standalone |
| 9 | Backend 2.3 — Test suite | Last (requires all features stable) |

---

## Critical Files

| File | Change |
|---|---|
| `frontend/lib/features/picking_slips/presentation/create_slip_screen.dart` | Full rewrite — item picker |
| `frontend/lib/features/my_ppe/data/ppe_repository.dart` | Add `getPpeItems()`, `getEmployeeAssignments()` |
| `frontend/lib/core/api/endpoints.dart` | Add `assignments` endpoint |
| `frontend/lib/core/auth/auth_bloc.dart` | Connect/disconnect WsService on login/logout |
| `frontend/lib/core/websocket/ws_service.dart` | Add `unreadPushCount ValueNotifier`, `resetBadge()` |
| `frontend/lib/features/admin/presentation/admin_dashboard_screen.dart` | Fix 3 tile routes |
| `frontend/lib/features/admin/presentation/admin_inventory_screen.dart` | NEW |
| `frontend/lib/features/admin/presentation/admin_ppe_catalogue_screen.dart` | NEW |
| `frontend/lib/features/admin/presentation/admin_audit_log_screen.dart` | NEW |
| `frontend/lib/features/auth/presentation/profile_screen.dart` | NEW |
| `frontend/lib/features/compliance/presentation/compliance_screen.dart` | Per-employee PPE expansion |
| `frontend/lib/core/router/app_router.dart` | Add `/admin/catalogue`, `/admin/inventory`, `/admin/audit`, `/profile` |
| `frontend/lib/features/my_ppe/presentation/my_ppe_screen.dart` | Bell badge |
| `backend/ppe/views.py` | Add `PPEConfigurationDetailView`, `DepartmentPPERequirementDetailView` |
| `backend/ppe/urls.py` | Add 2 detail routes |
| `backend/inventory/views.py` | Add `WarehouseDetailView` |
| `backend/inventory/urls.py` | Add warehouse detail route |
| `backend/accounts/views.py` | Add `PasswordResetRequestView`, `PasswordResetConfirmView` |
| `backend/accounts/urls.py` | Add 2 password reset routes |
| `backend/conftest.py` | NEW — shared pytest fixtures |
| `backend/*/factories.py` | NEW — factory_boy factories per app |
| `backend/picking/tests/test_lifecycle.py` | NEW — full flow integration test |
| `backend/celery_tasks/tests/test_expiry_engine.py` | NEW |
| `backend/accounts/tests/test_auth.py` | NEW |
| `backend/approvals/tests/test_workflow.py` | NEW |
| `backend/notifications/tests/test_websocket.py` | NEW |
| `backend/pytest.ini` | Add `--cov-fail-under=80` |

---

## Reuse (Do Not Duplicate)

- `core/utils/qr.py` — HMAC sign/verify — import in tests, don't mock
- `core/permissions.py` — `IsAdmin`, `IsManager`, etc. — use on all new views
- `core/pagination.py` — apply to all new list endpoints
- `notifications/services.py::dispatch()` — use in all new notification sends
- `PpeStatusBadge` (`core/widgets/ppe_status_badge.dart`) — reuse in compliance tiles
- `_StatusChip` in `slip_list_screen.dart` — consider extracting to core/widgets for reuse

---

## Verification — End-to-End Demo Flow

After all steps complete, run this flow to confirm everything works:

```bash
make dev-d && make seed   # backend up + seeded
cd frontend && flutter run -d web-server --web-port 3000
# open http://localhost:3000 in Safari
```

| Step | Login | Action | Expected Result |
|---|---|---|---|
| 1 | `emp001` / `Emp001_1234!` | My PPE | Expired SCSR + expiring P2 with status badges |
| 2 | `emp001` | Create Replacement Request | PPE item list loads, select items, submit → slip created |
| 3 | `emp001` | Notifications bell | Red badge appears |
| 4 | `manager1` / `Manager1234!` | Approvals | New slip in queue → approve |
| 5 | `safety1` / `Safety1234!` | Approvals | Slip requires safety → approve |
| 6 | `store1` / `Store1234!` | Scan QR | Camera opens, scan approved slip QR |
| 7 | `store1` | Confirm Issue | Confirm → stock decrements, slip = ISSUED |
| 8 | `emp001` | Notifications | "PPE Issued" notification appears without refresh |
| 9 | `admin` / `Admin1234!` | Admin → Audit Log | Full trail visible (create, approve×2, issue) |
| 10 | `admin` | Admin → Inventory | Stock levels shown, low-stock rows amber |
| 11 | `admin` | Admin → PPE Catalogue | All 12 PPE items listed |
| 12 | `admin` | Admin → Employees → expand | Per-employee PPE status grid visible |

```bash
# Backend tests
make test
# All tests pass, coverage ≥ 80%
```
