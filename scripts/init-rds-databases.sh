#!/bin/bash
# Initialize RDS MySQL databases with OncoKB data
# Run this script after Terraform apply to load SQL dumps

set -e

DEPLOYMENT_BUCKET="${DEPLOYMENT_BUCKET:-oncokb-deployment-data-270327054051}"
WORK_DIR="${WORK_DIR:-/tmp/oncokb-init}"

echo "=== OncoKB RDS Database Initialization ==="

# Load environment variables
if [ -f /opt/oncokb/.env ]; then
    source /opt/oncokb/.env
else
    echo "ERROR: Environment file not found at /opt/oncokb/.env"
    exit 1
fi

# Verify required environment variables
if [ -z "${RDS_ENDPOINT}" ] || [ -z "${RDS_USERNAME}" ] || [ -z "${RDS_PASSWORD}" ]; then
    echo "ERROR: Missing required environment variables (RDS_ENDPOINT, RDS_USERNAME, RDS_PASSWORD)"
    exit 1
fi

# Extract hostname from endpoint (remove port)
RDS_HOST=$(echo "${RDS_ENDPOINT}" | cut -d: -f1)

echo "RDS Host: ${RDS_HOST}"
echo "RDS Username: ${RDS_USERNAME}"

# Create working directory
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

# Download SQL dumps from S3
echo ""
echo "Downloading SQL dumps from S3..."
echo "This may take 5-10 minutes depending on file sizes..."

aws s3 cp "s3://${DEPLOYMENT_BUCKET}/sql/oncokb_v4_27.sql.gz" . \
    --no-progress

aws s3 cp "s3://${DEPLOYMENT_BUCKET}/sql/oncokb_transcript_v4_27.sql.gz" . \
    --no-progress

# Decompress files
echo ""
echo "Decompressing SQL files..."
gunzip oncokb_v4_27.sql.gz
gunzip oncokb_transcript_v4_27.sql.gz

# Create databases
echo ""
echo "Creating databases..."
mysql -h "${RDS_HOST}" -u "${RDS_USERNAME}" -p"${RDS_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS oncokb;
CREATE DATABASE IF NOT EXISTS oncokb_transcript;
SHOW DATABASES;
EOF

# Load OncoKB database
echo ""
echo "Loading oncokb database..."
echo "This may take 15-20 minutes..."
mysql -h "${RDS_HOST}" -u "${RDS_USERNAME}" -p"${RDS_PASSWORD}" oncokb < oncokb_v4_27.sql

# Load OncoKB Transcript database
echo ""
echo "Loading oncokb_transcript database..."
echo "This may take 5-10 minutes..."
mysql -h "${RDS_HOST}" -u "${RDS_USERNAME}" -p"${RDS_PASSWORD}" oncokb_transcript < oncokb_transcript_v4_27.sql

# Verify data
echo ""
echo "=== Verification ==="
echo "OncoKB tables:"
mysql -h "${RDS_HOST}" -u "${RDS_USERNAME}" -p"${RDS_PASSWORD}" oncokb -e "SHOW TABLES;" | wc -l

echo ""
echo "OncoKB gene count:"
mysql -h "${RDS_HOST}" -u "${RDS_USERNAME}" -p"${RDS_PASSWORD}" oncokb -e "SELECT COUNT(*) as gene_count FROM gene;"

echo ""
echo "OncoKB Transcript tables:"
mysql -h "${RDS_HOST}" -u "${RDS_USERNAME}" -p"${RDS_PASSWORD}" oncokb_transcript -e "SHOW TABLES;" | wc -l

# Clean up
echo ""
echo "Cleaning up temporary files..."
cd /
rm -rf "${WORK_DIR}"

echo ""
echo "=== RDS Database Initialization Complete ==="
echo "Next steps:"
echo "1. Restart OncoKB containers: docker compose restart oncokb oncokb-transcript"
echo "2. Check application logs: docker compose logs oncokb oncokb-transcript"
echo "3. Test API: curl http://localhost:8080/api/v1/info"
