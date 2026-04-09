#!/bin/bash
# Setup script for initial CI/CD configuration
# Run this once to configure GitHub secrets and environments

set -euo pipefail

echo "🔧 PPE System GitHub Actions Setup"
echo "=================================="

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

# Get repository info
REPO=$(gh repo view --json nameWithOwner -q)
echo "📦 Repository: ${REPO}"

echo ""
echo "📝 Creating GitHub Environments..."

# Create staging environment
gh api repos/${REPO}/environments -X POST -f name=staging -f deployment_branch_policy='{"protected_branch_required":false}' || echo "Staging environment may already exist"

# Create production environment  
gh api repos/${REPO}/environments -X POST -f name=production -f deployment_branch_policy='{"protected_branch_required":true}' || echo "Production environment may already exist"

echo "✅ Environments created"

echo ""
echo "🔐 Next Steps - Add these secrets in GitHub:"
echo ""
echo "Staging Secrets (.github Settings > Secrets and variables > Actions):"
echo "  - STAGING_DEPLOY_KEY: <your-staging-ssh-key-or-token>"
echo "  - STAGING_DEPLOY_URL: <your-staging-api-endpoint>"
echo ""
echo "Production Secrets:"
echo "  - PROD_DEPLOY_KEY: <your-prod-ssh-key-or-token>"
echo "  - PROD_DEPLOY_URL: <your-prod-api-endpoint>"
echo ""
echo "Optional Secrets (for third-party integrations):"
echo "  - SENTRY_DSN: <your-sentry-dsn>"
echo "  - SENTRY_DSN_STAGING: <your-staging-sentry-dsn>"
echo "  - SLACK_WEBHOOK: <your-slack-webhook-url>"
echo ""
echo "For Codecov coverage reporting:"
echo "  - CODECOV_TOKEN: <your-codecov-token>"
echo ""
echo "🎯 Configuration complete! Workflows will trigger on next push."
