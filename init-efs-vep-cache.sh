#!/bin/bash
# Initialize EFS with VEP cache data
# Run this script after Terraform apply to populate EFS with VEP caches

set -e

DEPLOYMENT_BUCKET="${DEPLOYMENT_BUCKET:-oncokb-deployment-data-270327054051}"
EFS_MOUNT_PATH="${EFS_MOUNT_PATH:-/mnt/efs/vep_cache}"

echo "=== OncoKB VEP Cache Initialization ==="
echo "Deployment bucket: ${DEPLOYMENT_BUCKET}"
echo "EFS mount path: ${EFS_MOUNT_PATH}"

# Verify EFS is mounted
if ! mountpoint -q "${EFS_MOUNT_PATH}"; then
    echo "ERROR: EFS is not mounted at ${EFS_MOUNT_PATH}"
    exit 1
fi

cd "${EFS_MOUNT_PATH}"

# Download VEP caches from S3
echo "Downloading VEP cache files from S3..."
echo "This may take 10-15 minutes depending on file sizes..."

aws s3 cp "s3://${DEPLOYMENT_BUCKET}/vep/vep_cache_grch37.tar.gz" . \
    --no-progress

aws s3 cp "s3://${DEPLOYMENT_BUCKET}/vep/vep_cache_grch38.tar.gz" . \
    --no-progress

# Create directories
echo "Creating cache directories..."
mkdir -p grch37 grch38

# Extract caches
echo "Extracting GRCh37 cache..."
tar -xzf vep_cache_grch37.tar.gz -C grch37/

echo "Extracting GRCh38 cache..."
tar -xzf vep_cache_grch38.tar.gz -C grch38/

# Clean up tarballs
echo "Cleaning up archive files..."
rm -f vep_cache_grch37.tar.gz vep_cache_grch38.tar.gz

# Set permissions for Docker containers
echo "Setting permissions..."
chown -R 1000:1000 grch37 grch38
chmod -R 755 grch37 grch38

# Verify structure
echo ""
echo "=== Verification ==="
echo "GRCh37 cache:"
ls -lh grch37/
echo ""
echo "GRCh38 cache:"
ls -lh grch38/
echo ""
echo "Disk usage:"
du -sh grch37 grch38

echo ""
echo "=== VEP Cache Initialization Complete ==="
echo "Next steps:"
echo "1. Restart VEP containers: docker compose restart vep-grch37 vep-grch38"
echo "2. Check VEP logs: docker compose logs vep-grch37 vep-grch38"
