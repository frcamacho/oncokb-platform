#!/bin/bash
# Test OncoKB API endpoints via the ALB.
# Run from a host with VPC/VPN access to the internal ALB.
#
# Usage: ./scripts/test-endpoints.sh [ALB_DNS]

set -euo pipefail

ALB_DNS="${1:-$(terraform output -raw alb_dns_name 2>/dev/null || true)}"
if [ -z "$ALB_DNS" ]; then
  echo "Usage: $0 <ALB_DNS>"
  echo "Or run from repo root so terraform output works."
  exit 1
fi

echo "Testing OncoKB API at http://${ALB_DNS}"
echo ""

echo "1. GET /api/v1/info"
curl -sf "http://${ALB_DNS}/api/v1/info" | jq . || { echo "FAIL"; exit 1; }
echo ""

echo "2. GET annotation (BRAF V600E)"
curl -sf "http://${ALB_DNS}/api/v1/annotate/mutations/byProteinChange?hugoSymbol=BRAF&alteration=V600E" | jq . || { echo "FAIL"; exit 1; }
echo ""

echo "All endpoint tests passed."
