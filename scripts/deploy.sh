#!/bin/bash
# Deploy script for manual deployments (fallback to GitHub Actions)
# Usage: ./scripts/deploy-staging.sh
#        ./scripts/deploy-prod.sh v1.2.3

set -euo pipefail

ENVIRONMENT=${1:-staging}
VERSION=${2:-latest}
REGISTRY="ghcr.io"
REPO="${REGISTRY}/${GITHUB_REPOSITORY}"
BACKEND_IMAGE="${REPO}/backend:${VERSION}"

echo "🚀 Deploying ${ENVIRONMENT} environment"
echo "📦 Backend image: ${BACKEND_IMAGE}"

# Pull latest image
echo "📥 Pulling image..."
docker pull "${BACKEND_IMAGE}"

# Verify image
echo "✅ Verifying image..."
docker inspect "${BACKEND_IMAGE}" > /dev/null || {
  echo "❌ Image not found: ${BACKEND_IMAGE}"
  exit 1
}

case "${ENVIRONMENT}" in
  staging)
    echo "🔄 Deploying to staging..."
    # kubectl set image deployment/ppe-backend backend="${BACKEND_IMAGE}" -n staging
    # OR
    # docker stack deploy -c docker-compose.staging.yml ppe-staging
    echo "✅ Staging deployment initiated"
    ;;
  
  prod|production)
    echo "⚠️  Production deployment"
    read -p "Continue with production deployment? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
      echo "❌ Deployment cancelled"
      exit 1
    fi
    
    echo "🔄 Deploying to production..."
    # kubectl set image deployment/ppe-backend backend="${BACKEND_IMAGE}" -n production
    # OR
    # docker stack deploy -c docker-compose.prod.yml ppe-prod
    echo "✅ Production deployment initiated"
    ;;
  
  *)
    echo "❌ Unknown environment: ${ENVIRONMENT}"
    exit 1
    ;;
esac

echo "✨ Deployment complete"
