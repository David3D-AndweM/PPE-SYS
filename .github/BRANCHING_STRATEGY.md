# Git Branching Strategy for PPE System

## Overview

Your CI/CD pipeline uses a **modified Git Flow branching model** optimized for continuous deployment. This guide explains how many branches you should have and how to use them.

---

## 🌳 Branch Structure (You Need 3 Main Branches)

### 1. **`main`** (Production Branch) 🚀
**Purpose:** Production-ready code only

**Rules:**
- Only merges from `develop` via PR
- Each commit can go to production
- Tagged with semantic versioning: `v1.0.0`, `v1.0.1`, etc.
- Protected branch (requires approval)
- No direct commits allowed

**When to use:**
- After code is tested in staging
- After QA approval
- After security review
- Ready for immediate production deployment

**Example workflow:**
```bash
# Merge develop to main (via PR with approval)
# Tag the commit
git tag v1.2.3 main
git push origin v1.2.3

# This triggers automatic production deployment
```

### 2. **`develop`** (Staging/Integration Branch) 🧪
**Purpose:** Integration and staging environment testing

**Rules:**
- Receives PRs from feature branches
- Auto-deploys to staging on every commit
- Must have passing tests before merge
- Protected branch (requires tests to pass)
- Serves as base for feature branches

**When to use:**
- Merging completed features
- Testing integrated features
- Before going to production
- QA testing environment

**Example workflow:**
```bash
# Create feature branch from develop
git checkout develop
git pull origin develop
git checkout -b feature/jwt-validation

# ... make changes ...

# Create PR to develop (CI runs automatically)
# Tests pass → Merge to develop
# Auto-deploys to staging
# QA tests in staging
# When ready → PR from develop to main
```

### 3. **`feature/*`** (Feature Branches) ✨
**Purpose:** Individual feature development

**Rules:**
- Created from: `develop`
- Merged back to: `develop` via PR
- Naming convention: `feature/description` or `bugfix/description`
- No direct commits to develop
- Tests must pass before merge

**When to use:**
- Implementing new features
- Fixing bugs
- Adding improvements
- Each developer works on separate branch

**Example naming:**
```bash
feature/jwt-validation
feature/qr-code-scanner
bugfix/database-migration-issue
feature/celery-task-optimization
hotfix/security-vulnerability
```

---

## 📊 Branch Diagram

```
┌─────────────────────────────────────────────────────────┐
│                     PRODUCTION                           │
│  main (v1.0.0, v1.0.1, v1.1.0)                         │
│  🔒 Protected, Tagged, Production-ready                │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ PR + Approval (via release tag)
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                    STAGING/QA                            │
│  develop (latest code, auto-deployed)                   │
│  🧪 Testing, Integration, QA Approval                   │
└──┬──┬──┬──────────────┬──────────────┬──┬──┬────────────┘
   │  │  │              │              │  │  │
   ▼  ▼  ▼              ▼              ▼  ▼  ▼
┌──────┐ ┌──────┐ ┌──────────┐ ┌──────────┐ ┌────────┐
│feat/1│ │feat/2│ │bugfix/5  │ │hotfix/10 │ │feat/3  │
│      │ │      │ │          │ │          │ │        │
│active│ │active│ │completed │ │in-review │ │ready   │
└──────┘ └──────┘ └──────────┘ └──────────┘ └────────┘

dev1    dev2       dev3           dev4         dev5
```

---

## 🔄 Complete Workflow Example

### Scenario: Adding JWT Token Validation (Feature)

**Step 1: Create feature branch**
```bash
# Start from develop
git checkout develop
git pull origin develop

# Create feature branch
git checkout -b feature/jwt-validation

# Start coding
echo "JWT validation code" > backend/accounts/jwt_validator.py
```

**Step 2: Commit and push**
```bash
git add backend/accounts/jwt_validator.py
git commit -m "Add JWT token validation

- Implement token parsing
- Add expiration check
- Include error handling

Closes #42"

git push origin feature/jwt-validation
```

**Step 3: Create PR to develop**
```bash
# GitHub: Create PR from feature/jwt-validation → develop
# Title: [FEATURE] JWT Token Validation
# Description: Fixes issue #42
```

**What happens automatically:**
- ✅ Tests run (pytest)
- ✅ Security scan (Trivy)
- ✅ Code quality checks (flake8, black, isort)
- ✅ Docker build
- ✅ Email sent to team

**Step 4: Code review**
```bash
# Backend team reviews PR
# Changes requested or approved
# You update code if needed
git add .
git commit -m "Address review feedback"
git push origin feature/jwt-validation
```

**Step 5: Merge to develop**
```bash
# Approve & merge to develop
# Automatic deployment to staging
# QA tests the feature in staging

# Check staging: https://staging.ppe-system.internal
```

**Step 6: PR to main when ready**
```bash
# After QA approval
# Create PR: develop → main
# Title: Release v1.1.0

# Wait for approval
# Once approved, merge
```

**Step 7: Create release tag**
```bash
git tag v1.1.0 main
git push origin v1.1.0

# Automatic production deployment
# Email sent: Production deployment successful
```

**Step 8: Cleanup**
```bash
# Delete feature branch (GitHub auto-deletes on PR merge)
git branch -d feature/jwt-validation
```

---

## 🎯 Branch Naming Conventions

### Feature Branches
```
feature/jwt-validation           # New feature
feature/qr-code-scanner          # New feature
feature/celery-optimization      # Improvement
bugfix/database-migration-error  # Bug fix
hotfix/security-breach           # Critical fix
refactor/api-restructure         # Code refactoring
```

### Avoid
```
feature/john-work        ❌ Too vague
f/test                   ❌ Too short
Feature_JWT              ❌ Wrong case
feature-jwt-validation   ❌ Should use /
```

---

## 🛡️ Branch Protection Rules

### `main` Branch
```
✅ Require pull request reviews
✅ Require status checks to pass:
   - Backend tests
   - Frontend tests
   - Security scan
   - Docker build
✅ Require CODEOWNERS approval
✅ Dismiss stale reviews
✅ Restrict who can push (admins only)
✅ Require branches to be up to date
```

### `develop` Branch
```
✅ Require pull request reviews (1 approval)
✅ Require status checks to pass:
   - Backend tests
   - Frontend tests
   - Security scan
   - Docker build
✅ Dismiss stale reviews
✅ Allow force pushes (for admins only)
✅ Require branches to be up to date
```

### Feature Branches
```
❌ No special protection
✓ Just follow naming convention
✓ Keep updated with develop
```

---

## 📅 Release Schedule & Versioning

### Semantic Versioning: `vMAJOR.MINOR.PATCH`

**Example versions:**
- `v1.0.0` - Initial release
- `v1.0.1` - Patch (bugfix)
- `v1.1.0` - Minor (features)
- `v2.0.0` - Major (breaking changes)

### Release Timeline

**Weekly Releases (Recommended)**
```
Monday-Thursday:   Development & testing
Friday morning:    Create release PR (develop → main)
Friday afternoon:  QA final approval
Friday evening:    Tag and deploy to production
```

**Hotfix Releases (As Needed)**
```
Critical bug found:
  → Create hotfix/issue-name from main
  → Fix and test
  → PR to main (with approval)
  → Tag: v1.0.X
  → Auto-deploy
  → Merge hotfix back to develop
```

---

## 🔍 How CI/CD Pipeline Uses Branches

### Backend CI Pipeline Triggers

**On any push to `main` or `develop`:**
```
Tests run (pytest)
  ↓
Security scan (Trivy)
  ↓
Docker build (amd64, arm64)
  ↓
Push to GHCR with branch tag
  ↓
Email sent to backend team
```

**Docker image tags created:**
```
ghcr.io/.../backend:main           ← Latest main
ghcr.io/.../backend:develop        ← Latest develop
ghcr.io/.../backend:main-a1b2c3d   ← Commit SHA
ghcr.io/.../backend:develop-x9z8y7 ← Commit SHA
```

### Integration & Deployment Pipeline

**On push to `develop`:**
```
workflow-run triggered
  ↓
deploy-staging job runs
  ↓
Pull image from GHCR:develop
  ↓
Deploy to staging
  ↓
Email sent: QA can test
```

**On push to `main` with tag `v*`:**
```
workflow-run triggered
  ↓
deploy-production job runs (requires approval)
  ↓
Pull image from GHCR:v1.2.3
  ↓
Deploy to production
  ↓
Create GitHub Release
  ↓
Email sent: Deployment complete
```

---

## 🚨 Emergency / Hotfix Workflow

When a critical bug is found in production:

**Step 1: Create hotfix branch from `main`**
```bash
git checkout main
git pull origin main
git checkout -b hotfix/security-vulnerability
```

**Step 2: Fix and test**
```bash
# Make fix
git add .
git commit -m "Fix security vulnerability

Description: [critical details]

Affects: Production
Severity: Critical

Closes #99"

git push origin hotfix/security-vulnerability
```

**Step 3: Create PR to `main`**
```bash
# GitHub: PR hotfix/... → main
# This goes to production immediately (with approval)
```

**Step 4: Tag for production**
```bash
# After merge and approval
git tag v1.0.1 main
git push origin v1.0.1
# Automatic production deployment
```

**Step 5: Backport to `develop`**
```bash
# Ensure develop also gets the fix
git checkout develop
git pull origin develop
git merge hotfix/security-vulnerability
git push origin develop
```

**Step 6: Cleanup**
```bash
git branch -d hotfix/security-vulnerability
```

---

## 📋 Team Responsibilities by Branch

### Feature Branch Developer
- ✅ Create from develop
- ✅ Write tests
- ✅ Ensure code quality
- ✅ Keep branch updated
- ✅ Request review when ready

### Code Reviewer (Backend Team Lead)
- ✅ Review code quality
- ✅ Check tests
- ✅ Verify security practices
- ✅ Approve or request changes

### QA Team (Staging)
- ✅ Test in staging after merge to develop
- ✅ Verify functionality
- ✅ Check for regressions
- ✅ Approve for production

### DevOps Team
- ✅ Manage main/develop branches
- ✅ Create release PRs
- ✅ Approve production deployments
- ✅ Monitor production
- ✅ Handle hotfixes

---

## ⚠️ Common Mistakes to Avoid

### ❌ Committing directly to main or develop
```bash
git checkout main
git commit -m "Quick fix"  ❌ WRONG!

# Instead:
git checkout -b bugfix/quick-fix
git commit -m "Quick fix"
git push origin bugfix/quick-fix
# Then create PR
```

### ❌ Out-of-sync feature branch
```bash
# Feature branch is old
# main has new changes
# This causes merge conflicts

# Instead, keep updated:
git checkout feature/jwt-validation
git pull origin develop
git rebase origin/develop
git push -f origin feature/jwt-validation
```

### ❌ Large feature branches
```bash
# Worked on feature for 3 weeks
# 50 commits, 500 line PR
# Hard to review ❌

# Instead:
# Split into smaller PRs
# Merge small pieces
# Easier to review ✅
```

### ❌ No tests before PR
```bash
# Created PR but no tests ❌

# Instead:
# Write tests first
# Run pytest locally
# Then create PR
```

### ❌ Forgotten branches
```bash
# Created feature/old-work
# Abandoned 2 months ago
# Clutters branch list ❌

# Instead:
# Delete completed branches
# Clean up stale branches monthly
```

---

## ✅ Best Practices Summary

### Daily Workflow
1. ✅ Create feature branch from `develop`
2. ✅ Write code + tests
3. ✅ Commit with clear messages
4. ✅ Push to origin
5. ✅ Create PR with description
6. ✅ Wait for tests to pass
7. ✅ Request code review
8. ✅ Address feedback
9. ✅ Merge when approved
10. ✅ Delete feature branch

### Code Review Checklist
- [ ] Tests written and passing
- [ ] No security issues
- [ ] Code follows style guide (black, flake8, isort)
- [ ] Database migrations (if needed)
- [ ] Documentation updated
- [ ] No hardcoded secrets
- [ ] Performance acceptable

### Release Checklist
- [ ] All PRs merged to `develop`
- [ ] Staging deployment successful
- [ ] QA testing complete
- [ ] Security review passed
- [ ] Release notes prepared
- [ ] Version number selected
- [ ] Main branch updated
- [ ] Tag created and pushed
- [ ] Email sent to team

---

## 🎓 Quick Reference

### Commands You'll Use

**Start a feature:**
```bash
git checkout develop
git pull origin develop
git checkout -b feature/my-feature
```

**Keep branch updated:**
```bash
git fetch origin
git rebase origin/develop
git push -f origin feature/my-feature
```

**Cleanup old branches:**
```bash
git branch -d feature/completed-feature  # Local
git push origin --delete feature/completed-feature  # Remote
```

**Create release:**
```bash
git tag v1.2.3 main
git push origin v1.2.3
```

**List all branches:**
```bash
git branch -a
git branch --list feature/*
```

---

## Summary: You Need Exactly 3 Types of Branches

| Branch | Purpose | Created From | Merged To | Protection |
|--------|---------|--------------|-----------|-----------|
| `main` | Production | develop | None | Strong |
| `develop` | Staging/QA | Pull requests | main | Medium |
| `feature/*` | Feature dev | develop | develop | None |

**Total active branches at any time:** ~5-10 feature branches + main + develop = ~7-12 branches

**Long-lived branches:** Only 2 (`main` and `develop`)

**Short-lived branches:** Feature branches (1-3 weeks average lifetime)

---

Your PPE System is ready for professional branch management! 🚀
