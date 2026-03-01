#!/bin/bash
# Initialize EFS with VEP 98 cache data for GRCh37 and GRCh38.
# Run after terraform apply from an EC2 instance or ECS Exec session
# with the EFS mounted, or use an ECS task that has EFS volumes.
#
# Usage: ./scripts/init-efs-vep-cache.sh [deployment-bucket] [efs-mount-path]

set -euo pipefail

DEPLOYMENT_BUCKET="${1:-${DEPLOYMENT_BUCKET:-oncokb-deployment-data-270327054051}}"
EFS_MOUNT_PATH="${2:-${EFS_MOUNT_PATH:-/mnt/efs/vep_cache}}"

echo "=== OncoKB VEP 98 Cache Initialization ==="
echo "Deployment bucket: ${DEPLOYMENT_BUCKET}"
echo "EFS mount path:    ${EFS_MOUNT_PATH}"

if ! mountpoint -q "${EFS_MOUNT_PATH}" 2>/dev/null; then
    echo "ERROR: EFS is not mounted at ${EFS_MOUNT_PATH}"
    echo "Mount it first or run from an ECS task with EFS volumes configured."
    exit 1
fi

cd "${EFS_MOUNT_PATH}"

echo ""
echo "Downloading VEP 98 cache files from S3 (this may take 10-15 min)..."
aws s3 cp "s3://${DEPLOYMENT_BUCKET}/gn-vep-data/98_GRCh37.tar" . --no-progress
aws s3 cp "s3://${DEPLOYMENT_BUCKET}/gn-vep-data/98_GRCh38.tar" . --no-progress

echo "Creating cache directories..."
mkdir -p grch37 grch38

echo "Extracting GRCh37 cache..."
tar -xf 98_GRCh37.tar -C grch37/

echo "Extracting GRCh38 cache..."
tar -xf 98_GRCh38.tar -C grch38/

echo "Cleaning up archive files..."
rm -f 98_GRCh37.tar 98_GRCh38.tar

echo "Setting permissions..."
chown -R 1000:1000 grch37 grch38
chmod -R 755 grch37 grch38

echo ""
echo "=== Verification ==="
echo "GRCh37 cache:"
ls -lh grch37/ | head -10
echo ""
echo "GRCh38 cache:"
ls -lh grch38/ | head -10
echo ""
echo "Disk usage:"
du -sh grch37 grch38

echo ""
echo "=== VEP Cache Initialization Complete ==="
