# EPPEP Flutter Client

Flutter mobile client for the **Enterprise PPE Compliance & Issuing Platform**.

## What this app does

- **Employee**: view assigned PPE + compliance, submit PPE requests
- **Manager / Safety Officer**: review and approve/reject requests
- **Store Officer**: scan picking slip QR, finalise issuance
- **Admin**: manage PPE catalogue, inventory, audit logs

## Environment configuration

Create or edit `frontend/.env`:

```
API_BASE_URL=http://<your-host>/api/v1
WS_BASE_URL=ws://<your-host>/ws
```

Notes:
- On a physical device, use your machine’s LAN IP (not `localhost`).

## Running locally

```bash
cd frontend
flutter pub get
flutter run
```

## API usage notes (important)

- **Smart requests (recommended for normal renewals / first issue)**:
  - When request type is `expiry` or `new`, the app calls:
    - `POST /api/v1/picking/slips/auto-create/`
  - The backend generates slip items automatically based on:
    - department PPE requirements
    - employee PPE status (expired / expiring soon / pending issue)

- **Exception requests (manual selection)**:
  - For `lost` and `damaged`, the app uses manual item selection and calls:
    - `POST /api/v1/picking/slips/create/`
  - Backend policy forces **Manager approval** for lost/damaged requests.

## Recent changes (backend/frontend alignment)

- Added `auto-create` picking slip support and wired the app to use it for `expiry` and `new`.
- Kept manual item selection only for exception flows (`lost`, `damaged`).
- Added the new endpoint constant in `lib/core/api/endpoints.dart`.
