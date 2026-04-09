# Email Notifications & Copilot Automation Setup

## Email Configuration

GitHub Actions workflows now send automated email notifications for all pipeline events.

### Required Email Secrets

Add these secrets to **Settings > Secrets and variables > Actions**:

```
MAIL_SERVER          = smtp.gmail.com (or your mail server)
MAIL_PORT            = 587 (or your mail server port)
MAIL_USERNAME        = noreply@ppe-system.dev
MAIL_PASSWORD        = <app-specific password>
```

### Email Distribution Lists

Create/configure these email addresses:

```
BACKEND_TEAM_EMAIL        = backend-team@ppe-system.dev
FRONTEND_TEAM_EMAIL       = frontend-team@ppe-system.dev
QA_TEAM_EMAIL             = qa-team@ppe-system.dev
DEVOPS_TEAM_EMAIL         = devops-team@ppe-system.dev
```

### Email Templates

Emails are automatically sent for:

#### ✅ Success Notifications
- **Backend CI Success**: Full test pass, image built and pushed
- **Frontend CI Success**: Tests pass, APK/iOS built
- **Staging Deployment**: Auto-deployed to staging
- **Production Deployment**: Deployed to production

**Recipients:**
- Backend success → `BACKEND_TEAM_EMAIL`
- Frontend success → `FRONTEND_TEAM_EMAIL`
- Staging → `QA_TEAM_EMAIL` + `DEVOPS_TEAM_EMAIL`
- Production → `DEVOPS_TEAM_EMAIL` + `BACKEND_TEAM_EMAIL`

#### ❌ Failure Notifications
- **Backend CI Failure**: Tests failed or security scan blocked
- **Frontend CI Failure**: Tests or builds failed
- **Staging Deployment Failure**: Deployment failed
- **Production Failure**: Critical deployment failure + auto-rollback initiated

**Recipients:**
- Backend failure → `BACKEND_TEAM_EMAIL` (primary)
- Frontend failure → `FRONTEND_TEAM_EMAIL` (primary)
- Staging failure → `DEVOPS_TEAM_EMAIL` (primary) + `QA_TEAM_EMAIL` (CC)
- Production failure → `DEVOPS_TEAM_EMAIL` (primary) + `on-call@ppe-system.dev` (CC)

### Email Content Includes

Each notification contains:
- ✓ Status (success/failure)
- ✓ Branch/version information
- ✓ Commit SHA
- ✓ Author name
- ✓ Direct link to GitHub Actions logs
- ✓ Summary of completed checks
- ✓ Next steps or remediation

### Gmail SMTP Setup

If using Gmail:

1. Enable 2-Factor Authentication on your Gmail account
2. Create an App Password: https://myaccount.google.com/apppasswords
3. Use the app password as `MAIL_PASSWORD` secret
4. Set `MAIL_SERVER=smtp.gmail.com` and `MAIL_PORT=587`

### Custom Mail Server Setup

For corporate email:

1. Ask your email administrator for SMTP details
2. Typically: `smtp.company.com` port `587` or `25`
3. Use corporate email: `noreply@company.com`
4. Generate/request SMTP credentials

### Testing Email Configuration

```bash
# Send test email via GitHub Actions
# Manually trigger any workflow with email notifications
# Check Actions logs for SMTP connection details
```

---

## Copilot Issue Automation

GitHub Copilot is now integrated into your issue system for advanced automation.

### How It Works

1. **Issue Created** → Copilot auto-analyzes and labels
2. **Auto-triage** → Assigns priority and component labels
3. **Comment Triggers** → Use Copilot commands for code generation
4. **Auto-assignment** → Routes to appropriate team
5. **Incident Detection** → Auto-escalates critical issues

### Copilot Commands

Use these commands in issue comments:

#### 🎯 `@github-copilot suggest`
Gets code implementation suggestions for the issue.

**Example:**
```
@github-copilot suggest better error handling for API authentication
```

**Copilot will:**
- Analyze the issue
- Suggest implementation approach
- Provide code examples
- Link to relevant documentation

#### 🔧 `@github-copilot fix`
Creates a pull request with an automatic fix.

**Example:**
```
@github-copilot fix
```

**Copilot will:**
- Generate fix code
- Create PR: `copilot/fix-issue-<number>`
- Add description and testing notes
- Link back to the issue

#### 📚 `@github-copilot explain`
Provides detailed explanation and analysis.

**Example:**
```
@github-copilot explain why this is a security vulnerability
```

**Copilot will:**
- Explain the root cause
- Show examples of the problem
- Recommend solutions
- Provide best practices

#### ✅ `@github-copilot generate-test`
Creates comprehensive test cases.

**Example:**
```
@github-copilot generate-test
```

**Copilot will:**
- Generate test templates
- Create test file: `tests/test_issue_<number>.py`
- Include unit, integration, and edge case tests
- Add docstrings and comments

### Automatic Issue Analysis

When an issue is created, Copilot automatically:

1. **Determines Issue Type**
   - 🐛 Bug
   - ✨ Enhancement
   - 🔒 Security
   - ⚡ Performance

2. **Assigns Priority**
   - 🔴 Critical (security issues)
   - 🟠 High (bugs)
   - 🟡 Medium (enhancements)
   - 🟢 Low (improvements)

3. **Component Labels**
   - `backend` - Django/Python
   - `frontend` - Flutter
   - `database` - PostgreSQL
   - `async` - Celery
   - `security` - Security issues

4. **Effort Estimation**
   - Story points (2, 5, 8, 13)
   - Time estimate
   - Breakdown by phase

5. **Auto-Assignment**
   - Backend issues → `@backend-team`
   - Frontend issues → `@frontend-team`
   - Security issues → `@security-team`

### Incident Management

Critical issues are automatically escalated:

1. **Incident Created** → Auto-triggered for:
   - Security vulnerabilities
   - System outages
   - Data loss risks
   - Production failures

2. **Auto-Actions:**
   - Creates incident tracking issue
   - Notifies on-call engineer
   - Tags with `incident` and `critical`
   - Includes incident response checklist

3. **Incident Response**
   - Assess impact
   - Gather logs
   - Root cause analysis
   - Hotfix implementation
   - Post-mortem review

### Issue Templates

Three issue templates available:

#### 1. **Bug Report** (`bug_report.md`)
For reporting bugs and issues.

Fields:
- Severity level
- Description
- Steps to reproduce
- Environment info
- Error logs
- Screenshots

#### 2. **Feature Request** (`feature_request.md`)
For suggesting new features.

Fields:
- Problem statement
- Proposed solution
- Alternatives
- Acceptance criteria
- Affected component

#### 3. **Incident Report** (`incident.md`)
For critical incidents.

Fields:
- Incident summary
- Business impact
- Timeline
- Root cause
- Temporary workaround
- Notification checklist

### Example: Creating and Fixing an Issue

**Step 1: Create Bug Report**
```
Title: [BUG] JWT token validation failing on iOS
Severity: High
Description: JWT tokens valid on Android fail on iOS app
```

**Step 2: Copilot Auto-Analysis**
- Label added: `bug`, `high`, `frontend`, `security`
- Effort estimated: 5 points (medium)
- Assigned to: `@frontend-team`
- Comment posted with analysis

**Step 3: Request Code Suggestion**
```
@github-copilot suggest JWT token validation fix for iOS
```

**Step 4: Copilot Suggests Solution**
```python
# iOS token validation fix
class TokenValidator:
    def validate_ios(self, token):
        # Handle iOS-specific JWT parsing
        ...
```

**Step 5: Create Automatic PR**
```
@github-copilot fix
```

**Step 6: Copilot Creates PR**
- Branch: `copilot/fix-issue-42`
- Changes: Token validation fix
- Tests: Auto-generated test suite
- Status checks: All passing

**Step 7: Review and Merge**
- Frontend team reviews
- Approves changes
- Merges to develop
- Auto-deploys to staging

### Best Practices

1. **Use Issue Templates**
   - Provide detailed information
   - Include logs/screenshots
   - Specify affected components

2. **Be Specific with Copilot**
   - `@github-copilot suggest optimal caching strategy`
   - Better than: `@github-copilot suggest`

3. **Follow Copilot Suggestions**
   - Review generated code
   - Run tests locally before merge
   - Provide feedback

4. **Incident Management**
   - Use incident template for critical issues
   - Follow incident response checklist
   - Conduct post-mortems

5. **Monitor Automation**
   - Check auto-labeled issues
   - Review auto-assignments
   - Verify effort estimates

### Copilot Configuration (Advanced)

Copilot behavior is configured via:
- Issue analysis rules (in `copilot-automation.yml`)
- Label mapping (customizable)
- Team assignments (in GitHub Teams)
- Email notifications (in workflow files)

To customize:
1. Edit `.github/workflows/copilot-automation.yml`
2. Adjust label assignments
3. Update team references
4. Modify effort estimation logic

### Troubleshooting

**Issue not auto-labeled?**
- Check issue body contains keywords
- Verify workflow is enabled
- Check GitHub Actions logs

**Copilot not responding to comments?**
- Ensure comment contains `@github-copilot`
- Check workflow permissions
- Verify issue is open (not closed)

**Email not sent?**
- Verify SMTP secrets are configured
- Check email addresses are valid
- Review workflow logs for errors

---

## Integration with Monitoring

Email notifications integrate with:
- **GitHub Actions** - Pipeline events
- **Issue System** - Problem tracking
- **Incident Management** - Critical escalation
- **Team Notifications** - Role-based routing

This creates an **automated incident response system** where:
1. Issues detected → Copilot analyzes
2. Auto-labeled → Routed to team
3. Email sent → Team notified
4. Copilot suggests → Quick fix available
5. PR created → Code ready
6. Tests run → Validation automated
7. Deploy → Push to staging/prod

Result: **Fast incident resolution with minimal manual intervention**.
