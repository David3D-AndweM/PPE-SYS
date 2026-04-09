#!/bin/bash
# Setup script for email notifications and Copilot automation
# Run this to configure email and GitHub settings

set -euo pipefail

echo "📧 PPE System Email & Copilot Setup"
echo "===================================="

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
  echo "❌ GitHub CLI not found. Install from https://cli.github.com/"
  exit 1
fi

# Verify authenticated
if ! gh auth status &> /dev/null; then
  echo "❌ Not authenticated with GitHub. Run: gh auth login"
  exit 1
fi

echo "✅ GitHub CLI authenticated"

REPO=$(gh repo view --json nameWithOwner -q)
echo "📦 Repository: ${REPO}"

echo ""
echo "📧 Email Configuration"
echo "====================="
echo ""
echo "Choose your email provider:"
echo "1) Gmail"
echo "2) Corporate Email Server"
echo "3) Other SMTP Provider"
read -p "Select (1-3): " provider_choice

case $provider_choice in
  1)
    echo ""
    echo "📧 Gmail Setup Instructions:"
    echo "1. Go to: https://myaccount.google.com/apppasswords"
    echo "2. Select 'Mail' and 'Windows Computer'"
    echo "3. Copy the generated password"
    echo ""
    read -s -p "Enter your app-specific password (hidden): " mail_password
    echo ""
    
    echo "Setting Gmail secrets..."
    gh secret set MAIL_SERVER --body "smtp.gmail.com"
    gh secret set MAIL_PORT --body "587"
    read -p "Enter Gmail address (e.g., noreply@company.com): " mail_user
    gh secret set MAIL_USERNAME --body "$mail_user"
    gh secret set MAIL_PASSWORD --body "$mail_password"
    ;;
    
  2)
    echo ""
    echo "📧 Corporate Email Setup:"
    read -p "Enter SMTP server (e.g., smtp.company.com): " mail_server
    read -p "Enter SMTP port (typically 587 or 25): " mail_port
    read -p "Enter email address (noreply@company.com): " mail_user
    read -s -p "Enter SMTP password (hidden): " mail_password
    echo ""
    
    echo "Setting corporate email secrets..."
    gh secret set MAIL_SERVER --body "$mail_server"
    gh secret set MAIL_PORT --body "$mail_port"
    gh secret set MAIL_USERNAME --body "$mail_user"
    gh secret set MAIL_PASSWORD --body "$mail_password"
    ;;
    
  3)
    echo ""
    read -p "Enter SMTP server: " mail_server
    read -p "Enter SMTP port: " mail_port
    read -p "Enter email address: " mail_user
    read -s -p "Enter SMTP password (hidden): " mail_password
    echo ""
    
    echo "Setting custom SMTP secrets..."
    gh secret set MAIL_SERVER --body "$mail_server"
    gh secret set MAIL_PORT --body "$mail_port"
    gh secret set MAIL_USERNAME --body "$mail_user"
    gh secret set MAIL_PASSWORD --body "$mail_password"
    ;;
    
  *)
    echo "❌ Invalid selection"
    exit 1
    ;;
esac

echo "✅ Email secrets configured"

echo ""
echo "👥 Email Distribution Lists"
echo "============================"
echo ""
echo "Configure team email addresses for notifications:"
echo ""

read -p "Backend team email (e.g., backend@company.com): " backend_email
gh secret set BACKEND_TEAM_EMAIL --body "$backend_email"

read -p "Frontend team email (e.g., frontend@company.com): " frontend_email
gh secret set FRONTEND_TEAM_EMAIL --body "$frontend_email"

read -p "QA team email (e.g., qa@company.com): " qa_email
gh secret set QA_TEAM_EMAIL --body "$qa_email"

read -p "DevOps team email (e.g., devops@company.com): " devops_email
gh secret set DEVOPS_TEAM_EMAIL --body "$devops_email"

echo "✅ Team email addresses configured"

echo ""
echo "🤖 GitHub Copilot Configuration"
echo "==============================="
echo ""
echo "Copilot automation is now enabled for:"
echo "  ✓ Issue auto-triage and labeling"
echo "  ✓ Issue analysis and effort estimation"
echo "  ✓ Code generation suggestions"
echo "  ✓ Automatic PR creation"
echo "  ✓ Test case generation"
echo "  ✓ Incident escalation"
echo ""

echo "📋 Creating Issue Templates"
echo "============================"
echo ""
echo "Issue templates available:"
echo "  ✓ Bug Report (.github/ISSUE_TEMPLATE/bug_report.md)"
echo "  ✓ Feature Request (.github/ISSUE_TEMPLATE/feature_request.md)"
echo "  ✓ Incident Report (.github/ISSUE_TEMPLATE/incident.md)"
echo ""

echo "📚 GitHub Teams Setup (Optional)"
echo "================================"
echo ""
echo "To enable auto-assignment, configure GitHub Teams:"
echo ""
echo "1. Go to: https://github.com/orgs/YOUR_ORG/teams"
echo "2. Create teams:"
echo "   - backend-team"
echo "   - frontend-team"
echo "   - security-team"
echo ""
echo "3. Add team members"
echo "4. Copilot will auto-assign issues to these teams"
echo ""

read -p "Have you created GitHub teams? (yes/no): " teams_created

if [ "$teams_created" = "yes" ]; then
  echo "✅ Teams configured"
else
  echo "⏭️  You can create teams later and update the workflow"
fi

echo ""
echo "🎯 Final Setup Steps"
echo "===================="
echo ""
echo "1. ✅ Email configured for notifications"
echo "2. ✅ Copilot automation enabled"
echo "3. ⏭️  Next steps:"
echo ""
echo "   a) Verify email secrets:"
echo "      - Open: Settings > Secrets and variables > Actions"
echo "      - Check all MAIL_* secrets are set"
echo ""
echo "   b) Create GitHub Teams (optional but recommended):"
echo "      - Settings > Teams"
echo "      - Create: backend-team, frontend-team, security-team"
echo ""
echo "   c) Test email configuration:"
echo "      - Push a commit to develop"
echo "      - Watch GitHub Actions run"
echo "      - Check email inbox for notifications"
echo ""
echo "   d) Create a test issue:"
echo "      - Go to Issues > New Issue"
echo "      - Use 'Bug Report' template"
echo "      - Verify Copilot auto-analyzes"
echo ""
echo "   e) Test Copilot commands:"
echo "      - Comment: '@github-copilot suggest'"
echo "      - Comment: '@github-copilot fix'"
echo ""

echo "✨ Setup complete! Your CI/CD pipeline now has:"
echo "   • Automated email notifications"
echo "   • Issue automation with Copilot"
echo "   • Incident escalation"
echo "   • Code generation assistance"
echo ""
echo "🚀 Ready to go!"
