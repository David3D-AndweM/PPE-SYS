# GitHub Actions CI/CD Pipeline - PPE System

## Overview

This enterprise-grade CI/CD pipeline automates testing, security scanning, building, and deploying both the Django backend and Flutter frontend with professional separation of concerns and environment management.

## Pipeline Architecture

### 1. **Backend CI/CD** (`backend-ci.yml`)
Triggers on changes to `backend/**` or workflow file itself.

**Stages:**
- **Test**: Python 3.12 with PostgreSQL 16 and Redis 7 services
  - Runs flake8, black, isort for code quality
  - Executes pytest with coverage reporting to Codecov
  - Coverage threshold: configurable in pytest.ini
  
- **Security**: Trivy filesystem scanning for vulnerabilities
  - SARIF output uploaded to GitHub Security tab
  - Blocks merge on critical findings (configurable)

- **Build**: Multi-architecture Docker image
  - Platforms: linux/amd64, linux/arm64
  - Registry: GitHub Container Registry (GHCR)
  - Tags: branch, semver, short SHA, latest (main only)
  - Build cache via GitHub Actions cache
  - Pushed only on non-PR events

### 2. **Frontend CI/CD** (`frontend-ci.yml`)
Triggers on changes to `frontend/**` or workflow file itself.

**Stages:**
- **Test**: Flutter analysis, unit tests, coverage
  - Runs `flutter analyze` (equivalent to lint)
  - Executes all unit tests with coverage
  - Coverage uploaded to Codecov
  
- **Security**: Trivy scanning for dependencies
  - Detects vulnerable packages in pubspec.yaml/pubspec.lock
  
- **Build APK**: Debug APK artifact for QA
  - Runs on ubuntu-latest
  - Artifact retention: 30 days
  
- **Build iOS**: Debug iOS build for testing
  - Runs on macos-latest (requires GitHub Enterprise or macOS runner access)
  - Framework structure preserved for integration testing

### 3. **Integration & Deployment** (`integration-deploy.yml`)
Orchestrated deployments with environment promotion.

**Triggers:**
- On main branch: after both backend and frontend pipelines pass
- On version tags (v*): automated production deployment

**Environments:**
- **Staging** (develop → staging environment)
  - Automatic deployment on develop branch success
  - Health checks before marking complete
  
- **Production** (tags only)
  - Manual approval required (via GitHub Environments)
  - Creates GitHub Release with deployment notes
  - Includes automatic rollback capability on failure

### 4. **Dependency Check** (`dependency-check.yml`)
Scheduled daily + on-push to main/develop.

**Coverage:**
- Python: safety + pip-audit
- Flutter: pub outdated + vulnerability checks
- Reports stored as artifacts for 90 days

## Environment Configuration

### Required GitHub Secrets

Add these in **Settings > Secrets and variables > Actions**:

#### Staging
```
STAGING_DEPLOY_KEY       # SSH or auth token for staging infrastructure
STAGING_DEPLOY_URL       # API endpoint or deployment system URL
```

#### Production
```
PROD_DEPLOY_KEY          # SSH or auth token for production infrastructure
PROD_DEPLOY_URL          # API endpoint or deployment system URL
```

### GitHub Environments

Create in **Settings > Environments**:

1. **staging**
   - Deployment branch: develop
   - Protection rules: None (auto-deploy)

2. **production**
   - Deployment branch: main
   - Protection rules: Require approval before deployment

## Deployment Methods

The integration workflow includes placeholders for:

### Kubernetes
```bash
kubectl set image deployment/ppe-backend backend=IMAGE:TAG -n NAMESPACE
kubectl rollout undo deployment/ppe-backend -n NAMESPACE
```

### Docker Swarm
```bash
docker stack deploy -c docker-compose.ENVIRONMENT.yml ppe-ENVIRONMENT
```

### Custom API
Configure `STAGING_DEPLOY_URL` and `PROD_DEPLOY_URL` to call your deployment service.

## Image Tagging Strategy

### Backend Images (GHCR)
```
ghcr.io/your-org/ppe-system/backend:main          # Latest main
ghcr.io/your-org/ppe-system/backend:develop       # Latest develop
ghcr.io/your-org/ppe-system/backend:v1.2.3        # Semantic version
ghcr.io/your-org/ppe-system/backend:develop-a1b2c3  # Branch + SHA
```

### Supported Architectures
- `linux/amd64` (Intel/AMD)
- `linux/arm64` (Apple Silicon, Graviton)

## Coverage Requirements

Coverage reports are uploaded to Codecov. Configure minimum thresholds:

### Backend (pytest)
```bash
# In backend/pytest.ini
[pytest]
addopts = --cov=. --cov-report=xml --cov-report=html --cov-fail-under=80
```

### Frontend (Flutter)
```bash
# In frontend (configure in pubspec.yaml or CI)
# Minimum coverage threshold: 70%
```

## Troubleshooting

### Build Failures

**Backend tests fail:**
- Check PostgreSQL/Redis services are healthy
- Verify `DATABASE_URL` and `REDIS_URL` env vars
- Run locally: `pytest backend/`

**Frontend tests fail:**
- Run locally: `flutter test`
- Ensure Flutter SDK version matches workflow

**Docker build fails:**
- Check Dockerfile is valid: `docker build backend/`
- Verify COPY paths exist
- Review Buildx logs in Actions

### Security Scan Issues

**Trivy findings:**
- Review in GitHub Security tab
- Update vulnerable packages
- Add allowlist in `.trivyignore` if needed

**Dependency vulnerabilities:**
- Update packages: `pip install --upgrade -r requirements/prod.txt`
- For Flutter: `flutter pub upgrade`

### Deployment Issues

**Staging deployment hangs:**
- Check health check endpoint responds
- Verify deployment credentials are valid
- Review deployment logs in GitHub Actions

**Production rollback needed:**
- Manual: `kubectl rollout undo deployment/ppe-backend`
- Or re-tag a previous version and redeploy

## Best Practices

1. **Branch Protection**
   - Require status checks to pass before merge
   - Require code review from CODEOWNERS
   - Dismiss stale approvals

2. **Semantic Versioning**
   - Tag releases as `v1.2.3`
   - Deploy to production only via tags
   - Keep changelog updated

3. **Secret Management**
   - Never commit secrets
   - Use environment-specific secrets
   - Rotate keys quarterly

4. **Monitoring**
   - Check Actions logs regularly
   - Set up Slack/email notifications
   - Monitor GHCR image storage usage

5. **Performance**
   - Cache Docker layers in Buildx
   - Cache pip dependencies
   - Use parallel job execution where possible

## Customization

### Adding Custom Deploy Step
Edit `integration-deploy.yml`, replace placeholder:
```yaml
- name: Deploy to production
  run: |
    # Your deployment command here
    ./scripts/deploy-prod.sh v${{ steps.version.outputs.version }}
```

### Changing Coverage Threshold
Update pytest.ini or add to backend workflow:
```yaml
- name: Run tests with coverage
  run: |
    pytest --cov-fail-under=85 ...
```

### Adding Slack Notifications
```yaml
- name: Notify Slack
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}
```

## Migration from Existing CI/CD

If migrating from another system:
1. Verify all secrets are configured
2. Test staging deployment first
3. Monitor logs during first main→prod deployment
4. Keep old system running during transition period
