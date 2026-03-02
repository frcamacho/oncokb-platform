#!/bin/bash
# Pull images from Docker Hub and push to ECR.
# Requires: docker, aws cli, and Docker Hub access (or images already cached locally).
#
# Usage:
#   ./scripts/push-ecr.sh [options]
#
# Options:
#   --region REGION       AWS region       (default: us-east-1)
#   --env ENV             Environment      (default: dev)
#   --account-id ID       AWS account ID   (default: from aws sts)

set -euo pipefail

REGION="us-east-1"
ENVIRONMENT="dev"
ACCOUNT_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --region)     REGION="$2"; shift 2 ;;
    --env)        ENVIRONMENT="$2"; shift 2 ;;
    --account-id) ACCOUNT_ID="$2"; shift 2 ;;
    *)            echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$ACCOUNT_ID" ]; then
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
fi

ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

ECR_TAGS=(
  "gn-mongo-grch37:0.32"
  "gn-mongo-grch38:0.32_grch38_ensembl95"
  "genome-nexus-vep:v0.0.1"
  "gn-spring-boot:2.0.2"
  "oncokb-transcript:0.9.4"
  "oncokb:4.3.0"
)
HUB_IMAGES=(
  "genomenexus/gn-mongo:0.32"
  "genomenexus/gn-mongo:0.32_grch38_ensembl95"
  "genomenexus/genome-nexus-vep:v0.0.1"
  "genomenexus/gn-spring-boot:2.0.2"
  "mskcc/oncokb-transcript:0.9.4"
  "mskcc/oncokb:4.3.0"
)

echo "=== Push Docker Hub images to ECR ==="
echo "ECR:         ${ECR_BASE}"
echo "Environment: ${ENVIRONMENT}"
echo ""

echo "Authenticating Docker to ECR..."
aws ecr get-login-password --region "$REGION" | \
  docker login --username AWS --password-stdin "${ECR_BASE}"
echo ""

FAILED=()
for i in "${!ECR_TAGS[@]}"; do
  ecr_tag="${ECR_TAGS[$i]}"
  hub_image="${HUB_IMAGES[$i]}"
  ecr_repo="${ENVIRONMENT}/${ecr_tag%%:*}"
  ecr_version="${ecr_tag#*:}"
  ecr_image="${ECR_BASE}/${ecr_repo}:${ecr_version}"

  echo "--- ${ecr_repo}:${ecr_version} ---"
  echo "  Source: ${hub_image}"
  echo "  Target: ${ecr_image}"

  if ! docker pull --platform linux/amd64 "${hub_image}"; then
    echo "  FAILED to pull ${hub_image}"
    FAILED+=("${hub_image}")
    continue
  fi

  docker tag "${hub_image}" "${ecr_image}"

  if ! docker push "${ecr_image}"; then
    echo "  FAILED to push ${ecr_image}"
    FAILED+=("${ecr_image}")
    continue
  fi

  echo "  OK"
  echo ""
done

echo "=== Summary ==="
if [ ${#FAILED[@]} -eq 0 ]; then
  echo "All ${#ECR_TAGS[@]} images pushed successfully."
else
  echo "FAILED (${#FAILED[@]}):"
  printf "  %s\n" "${FAILED[@]}"
  exit 1
fi