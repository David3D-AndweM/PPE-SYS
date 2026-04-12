# Git Branching Strategy - Quick Reference Card

## 📋 The 3 Branches You Need

### 1. `main` - Production 🚀
```
Purpose:    Production-ready code ONLY
Created:    From develop via PR
Protection: STRICT (requires tests, reviews, approval)
Deploy:     Tag → Auto-deploy to production
Rule:       Every commit can go live
```

### 2. `develop` - Staging 🧪
```
Purpose:    Integration & testing
Created:    From PR merges
Protection: MEDIUM (requires tests, 1 review)
Deploy:     Every commit → Auto-deploy to staging
Rule:       Base branch for all features
```

### 3. `feature/*` - Development ✨
```
Purpose:    Individual feature work
Created:    From develop
Protection: NONE
Naming:     feature/description or bugfix/description
Lifetime:   1-2 weeks (short-lived)
```

---

## 🎯 Step-by-Step Workflow

### Start a Feature
```bash
git checkout develop
git pull origin develop
git checkout -b feature/my-awesome-feature
```

### Work on Feature
```bash
# Edit files
git add .
git commit -m "Implement feature

Clear description of changes"

git push origin feature/my-awesome-feature
```

### Create PR
```bash
# On GitHub:
1. Go to your repo
2. Click "New Pull Request"
3. Base: develop ← Compare: feature/my-awesome-feature
4. Write description
5. Click "Create Pull Request"
6. Wait for tests ✓
7. Request review
```

### Merge to Develop
```bash
# On GitHub (after approval):
1. Review comments
2. Click "Merge Pull Request"
3. Confirm
4. Auto-deployed to staging ✓
5. QA tests in staging
```

### Release to Production
```bash
# When ready for production:
git tag v1.2.3 main
git push origin v1.2.3

# Auto-deploys to production ✓
```

### Cleanup
```bash
# Delete feature branch (GitHub does auto-delete)
git branch -d feature/my-awesome-feature
git push origin --delete feature/my-awesome-feature
```

---

## 🔑 Key Commands

| Task | Command |
|------|---------|
| Create branch | `git checkout -b feature/name` |
| Switch branch | `git checkout feature/name` |
| Update from main | `git fetch origin` |
| Get latest develop | `git pull origin develop` |
| Rebase feature | `git rebase origin/develop` |
| Push changes | `git push origin feature/name` |
| Push tag | `git push origin v1.2.3` |
| List branches | `git branch -a` |
| Delete branch | `git branch -d feature/name` |
| Sync fork (if applicable) | `git fetch upstream` |

---

## 📊 Timeline: Issue → Production

```
DAY 1 (Monday)
├─ 9:00  Create feature branch
├─ 15:00 Push to GitHub
└─ 17:00 Create PR to develop

DAY 2 (Tuesday)
├─ 9:00  Code review
├─ 10:00 Approve & merge to develop
├─ 10:05 Auto-deploy to staging ✓
└─ 14:00 QA tests in staging

DAY 3 (Wednesday)
├─ 9:00  QA signs off ✓
├─ 10:00 Create PR: develop → main
├─ 14:00 Review & approval
└─ 15:00 Merge to main

DAY 4 (Thursday)
├─ 9:00  Create release tag v1.2.3
├─ 9:05  Push tag
├─ 9:10  Auto-deploy to production ✓
└─ 14:00 ✅ IN PRODUCTION

Total Time: 3.5 days
Manual work: ~2 hours
Automated: ~22 hours
```

---

## ✅ Before Creating PR Checklist

- [ ] Branch created from `develop`
- [ ] Code follows style guide (black, flake8, isort)
- [ ] Tests written and passing locally
- [ ] No secrets or hardcoded values
- [ ] Database migrations (if needed)
- [ ] Documentation updated
- [ ] Branch is up-to-date with develop
- [ ] No merge conflicts
- [ ] Ready for code review

---

## 📌 Naming Conventions

### ✅ Good Names
```
feature/jwt-validation
feature/qr-code-scanner
feature/celery-tasks
bugfix/database-migration-error
hotfix/security-vulnerability
feature/mobile-ui-redesign
```

### ❌ Bad Names
```
feature/john-work          ← Too vague
f/test                     ← Too short
Feature_JWT                ← Wrong case
feature-jwt-validation     ← Should use /
my-branch                  ← No prefix
test123                    ← No prefix
```

---

## 🛡️ Protected Branches

### `main` Branch (Strict)
```
✅ Require PR review (2+ approvals)
✅ Require status checks (all must pass)
✅ Require CODEOWNERS approval
✅ Dismiss stale reviews
✅ No force push
✅ No direct commits
```

### `develop` Branch (Medium)
```
✅ Require PR review (1+ approval)
✅ Require status checks (all must pass)
✅ Dismiss stale reviews
✅ No direct commits (use PR)
⚠️ Force push allowed (for admins)
```

### Feature Branches (None)
```
❌ No protection
✅ Just follow naming convention
✅ Keep updated with develop
```

---

## 🚨 Emergency / Hotfix

When critical bug in production:

```bash
# 1. Create hotfix from main
git checkout main
git pull origin main
git checkout -b hotfix/critical-issue

# 2. Fix and test
git commit -m "Fix critical issue"
git push origin hotfix/critical-issue

# 3. Create PR to main (URGENT)
# GitHub: PR hotfix/... → main
# ⚠️ Request immediate approval

# 4. After merge to main
git tag v1.0.1 main
git push origin v1.0.1
# Auto-deploys to production ✓

# 5. Backport to develop
git checkout develop
git merge hotfix/critical-issue
git push origin develop

# 6. Cleanup
git branch -d hotfix/critical-issue
```

---

## 📧 Email Notifications by Branch

| Event | Branch | Recipient | Status |
|-------|--------|-----------|--------|
| Tests pass | main/develop | Backend team | ✅ Success |
| Tests fail | main/develop | Backend team | ❌ Failure |
| Deploy to staging | develop | QA team | 🧪 Testing |
| Deploy to prod | main (tag) | DevOps team | 🚀 Live |
| Prod failure | main (tag) | On-call | 🚨 URGENT |

---

## 🎓 Team Roles

### Developer
- Create feature branches
- Write code + tests
- Push to origin
- Create PR
- Address review feedback
- Keep branch updated

### Code Reviewer
- Review PR code
- Check tests
- Verify security
- Approve or request changes

### QA Team
- Test in staging
- Verify functionality
- Report bugs
- Approve for production

### DevOps/Tech Lead
- Merge to main
- Create release tags
- Approve production
- Handle hotfixes

---

## ⏰ Release Schedule

### Weekly Release (Recommended)
```
Monday-Thursday:  Development
Friday morning:   Create release PR
Friday afternoon: QA final check
Friday evening:   Tag & deploy
```

### Hotfix Release (As Needed)
```
When: Critical bug found
How:  hotfix branch → main → tag → deploy
Time: ~30 minutes
```

---

## 📊 Expected Branches at Any Time

```
Total Branches: ~7-12

Long-lived:
├─ main (1)
└─ develop (1)

Short-lived (feature/bugfix):
├─ feature/a (developer 1)
├─ feature/b (developer 2)
├─ feature/c (developer 3)
├─ bugfix/x (developer 4)
├─ hotfix/y (if critical)
└─ feature/z (developer 5)

Expected lifecycle:
- Create → Development (5-10 days)
- Code review → Approval (1-2 days)
- Merged → Auto-deleted
```

---

## 🔍 Health Check Commands

```bash
# See all branches
git branch -a

# See branches with their last commit
git branch -v

# See branches merged to develop
git branch --merged develop

# See branches not yet merged
git branch --no-merged develop

# See remote branches
git branch -r

# Prune deleted remote branches
git fetch --prune origin
```

---

## ⚠️ Common Mistakes

### Mistake 1: Committing to main/develop
```bash
# ❌ WRONG
git checkout main
git commit -m "quick fix"

# ✅ RIGHT
git checkout -b bugfix/quick-fix
git commit -m "quick fix"
```

### Mistake 2: Out-of-sync feature
```bash
# ❌ WRONG (old branch, conflicts)
git push origin feature/old-work

# ✅ RIGHT (keep updated)
git pull origin develop
git rebase origin/develop
git push -f origin feature/old-work
```

### Mistake 3: Large PR
```bash
# ❌ WRONG (50 commits, hard to review)
# Feature developed for 3 weeks

# ✅ RIGHT (multiple small PRs)
# Features broken into reviewable pieces
```

### Mistake 4: No tests
```bash
# ❌ WRONG (PR with no tests)

# ✅ RIGHT (tests first, then PR)
pytest backend/  # All pass
```

---

## Summary: You Have 3 Branches

```
┌─────────────────────────────────────────────────────────┐
│ main ← develop ← feature/* ← developer computers       │
└─────────────────────────────────────────────────────────┘

main:           Production releases (tagged: v1.0.0)
develop:        Staging integration (auto-deploys)
feature/*:      Developer work (auto-deleted after merge)

That's it! No other permanent branches needed.
```

---

## 🚀 You're Ready!

1. ✅ Create feature from develop
2. ✅ Code + test locally
3. ✅ Push and create PR
4. ✅ Wait for tests + review
5. ✅ Merge to develop
6. ✅ Auto-deploys to staging
7. ✅ QA tests in staging
8. ✅ When ready: merge to main
9. ✅ Tag for production
10. ✅ Auto-deploys to production

**Happy coding! 🎉**
