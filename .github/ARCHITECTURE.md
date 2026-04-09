# PPE System CI/CD Architecture

## Pipeline Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Developer Push / Pull Request                │
└────────────┬────────────────────────────────────────────────────┘
             │
             ├─────────────────────────────────────────────────────┐
             │                                                     │
      ┌──────▼──────┐                                    ┌─────────▼──────┐
      │ Backend Code│                                    │ Frontend Code  │
      │   Changed?  │                                    │    Changed?    │
      └──────┬──────┘                                    └────────┬───────┘
             │                                                    │
      ┌──────▼──────────────────┐                       ┌────────▼──────────┐
      │  backend-ci.yml         │                       │ frontend-ci.yml   │
      │  ─────────────────────  │                       │ ──────────────────│
      │  1️⃣  Test (pytest)      │                       │ 1️⃣  Test (flutter)│
      │  2️⃣  Lint (black,flake8)│                       │ 2️⃣  Analyze      │
      │  3️⃣  Security (Trivy)   │                       │ 3️⃣  Security     │
      │  4️⃣  Build Docker (x2)  │                       │ 4️⃣  Build APK/iOS│
      │      └─ amd64           │                       │                   │
      │      └─ arm64           │                       │                   │
      │  5️⃣  Push GHCR          │                       │                   │
      └──────┬──────────────────┘                       └────────┬──────────┘
             │                                                    │
             └──────────────────────┬──────────────────────────────┘
                                    │
                           ┌────────▼────────┐
                           │  Both Complete? │
                           └────────┬────────┘
                                    │
                   ┌────────────────┼────────────────┐
                   │                │                │
            ┌──────▼──────┐  ┌──────▼──────┐  ┌─────▼────────┐
            │   develop   │  │     main    │  │    v*.*.*    │
            │   branch    │  │    branch   │  │   Git Tag    │
            └──────┬──────┘  └──────┬──────┘  └─────┬────────┘
                   │                │               │
      ┌────────────▼─────────┐     │      ┌────────▼───────────┐
      │  integration-deploy  │     │      │  integration-deploy │
      │                      │     │      │  (Manual Approval)  │
      │  STAGING             │     │      │  PRODUCTION         │
      │  Auto-Deploy         │     │      │  Manual Deploy      │
      │                      │     │      │                     │
      │  - Pull Image        │     │      │  - Extract Version  │
      │  - Health Check      │     │      │  - Verify Image     │
      │  - Update Stack      │     │      │  - Deploy           │
      │  - Notify            │     │      │  - Health Check     │
      └──────┬───────────────┘     │      │  - Create Release   │
             │                     │      │  - Rollback on fail │
             │                     │      └──────────┬─────────┘
             │                     │                 │
      ┌──────▼──────────┐         │          ┌──────▼─────────┐
      │ STAGING         │         │          │ PRODUCTION      │
      │ Environment     │         │          │ Environment     │
      │                 │         │          │                 │
      │ ✓ Running       │         │          │ ✓ Running       │
      │ ✓ Health OK     │         │          │ ✓ Health OK     │
      │ ✓ Logs flowing  │         │          │ ✓ Logs flowing  │
      └─────────────────┘         │          └─────────────────┘
                                  │
                       ┌──────────▼──────────┐
                       │ dependency-check.yml│
                       │ (Daily Schedule)    │
                       │                     │
                       │ - Python safety     │
                       │ - pip-audit         │
                       │ - Flutter outdated  │
                       │ - Reports stored    │
                       └─────────────────────┘
```

## Environment Promotion Path

```
Local Development
       │
       ▼
GitHub Branch (PR)
       │
       ├─ Tests ───┬─ FAIL ──► Fix & Push
       │           │
       │           └─ PASS ───┐
       │                      │
       ▼                      │
   develop (merge)            │
       │◄─────────────────────┘
       │
       ├─ Tests ✓
       ├─ Security ✓
       └─ BUILD ✓
              │
              ▼
        STAGING Auto-Deploy
              │
              ├─ Health Check ✓
              └─ Verification ✓
                     │
                     ▼
                 QA Testing
                     │
                     ├─ Pass ────┐
                     │           │
                     │           ▼
                     │      Create Release Tag
                     │      git tag v1.2.3
                     │      git push origin v1.2.3
                     │           │
                     │           ▼
                     │      PRODUCTION (Manual Approval)
                     │           │
                     │           ├─ Approve ──► Deploy
                     │           │
                     │           └─ Reject ──► Cancel
                     │
                     └─ Fail ────► Debug & Backtrack
```

## Service Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        NGINX Load Balancer                      │
│                    (3 replicas in production)                   │
└─────────────────────────────────────────────────────────────────┘
         │              │              │
         ▼              ▼              ▼
   ┌─────────┐    ┌─────────┐    ┌─────────┐
   │ Django  │    │ Django  │    │ Django  │
   │Backend  │    │Backend  │    │Backend  │
   │Instance │    │Instance │    │Instance │
   │:8000    │    │:8000    │    │:8000    │
   └────┬────┘    └────┬────┘    └────┬────┘
        │              │              │
        └──────────────┼──────────────┘
                       │
         ┌─────────────┼─────────────┐
         │             │             │
         ▼             ▼             ▼
    ┌─────────┐  ┌─────────┐  ┌──────────┐
    │PostgreSQL │ │ Redis   │ │ Celery   │
    │   DB      │ │ Cache   │ │ Workers  │
    │           │ │         │ │(2 nodes) │
    │ HA Setup  │ │ HA Setup│ │          │
    └───────────┘ └─────────┘ └──────────┘
                                    │
                                    ▼
                            ┌─────────────┐
                            │CeleryBeat   │
                            │Scheduler    │
                            │(1 instance) │
                            └─────────────┘
```

## Workflow Status Check Hierarchy

```
Pull Request Created
    │
    ├─► backend-ci.yml (if backend/* changed)
    │   ├─► test
    │   │   ├─ pytest ✓/✗
    │   │   └─ Coverage ✓/✗
    │   │
    │   ├─► security
    │   │   └─ trivy ✓/✗
    │   │
    │   └─► build
    │       ├─ Docker amd64 ✓/✗
    │       ├─ Docker arm64 ✓/✗
    │       └─ GHCR Push ✓/✗
    │
    ├─► frontend-ci.yml (if frontend/* changed)
    │   ├─► test
    │   │   ├─ flutter analyze ✓/✗
    │   │   ├─ flutter test ✓/✗
    │   │   └─ Coverage ✓/✗
    │   │
    │   ├─► security
    │   │   └─ trivy ✓/✗
    │   │
    │   ├─► build-apk
    │   │   └─ APK artifact ✓/✗
    │   │
    │   └─► build-ios
    │       └─ iOS artifact ✓/✗
    │
    └─► MERGE BLOCKED if any status ✗
        MERGE ALLOWED if all ✓
```

## Docker Image Tag Convention

```
Development/Testing
├─ ghcr.io/.../backend:develop
│  └─ Latest develop branch build
│
├─ ghcr.io/.../backend:develop-a1b2c3d
│  └─ Development commit (short SHA)
│
└─ ghcr.io/.../backend:pr-123-a1b2c3d
   └─ Pull request build

Main/Production
├─ ghcr.io/.../backend:main
│  └─ Latest main branch build
│
├─ ghcr.io/.../backend:main-a1b2c3d
│  └─ Main branch commit (short SHA)
│
├─ ghcr.io/.../backend:v1.2.3
│  └─ Version release (semver)
│
└─ ghcr.io/.../backend:latest
   └─ Latest release (main only)
```

## Security Scanning Results

```
GitHub Actions → Trivy Scan
                     │
                     ├─ Container registry
                     ├─ Filesystem (deps)
                     └─ Config files
                            │
                            ▼
                  SARIF Report Generated
                            │
                     ┌──────┴──────┐
                     │             │
                ┌────▼────┐   ┌────▼────┐
                │CRITICAL │   │HIGH     │
                │ (Block)  │   │ (Warn)  │
                └──────────┘   └─────────┘
                     │             │
                     ▼             ▼
              GitHub Security Tab
              (Auto-visible to repo maintainers)
```

---

**This diagram shows a production-ready, enterprise CI/CD pipeline with:**
- ✅ Automated testing and security scanning
- ✅ Multi-environment promotion (staging → production)
- ✅ Coordinated backend + frontend deployment
- ✅ High-availability configuration (HA replicas)
- ✅ Health checks and rollback capabilities
- ✅ Container image registry with multi-arch support
