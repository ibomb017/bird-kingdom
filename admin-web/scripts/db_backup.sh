#!/bin/bash

# Database Backup Script for Bird Kingdom
# Reads credentials from /opt/bird-kingdom-admin/.env

set -euo pipefail

# Load environment variables from .env
ENV_FILE="/opt/bird-kingdom-admin/.env"
if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "ERROR: $ENV_FILE not found! Cannot proceed without credentials." >&2
    exit 1
fi

DB_NAME="${DB_NAME:-bird_kingdom}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS}"
BACKUP_DIR="/opt/bird-kingdom-admin/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_backup_${DATE}.sql.gz"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Run mysqldump and compress the output
echo "[$(date)] Starting database backup for ${DB_NAME}..."
mysqldump --defaults-extra-file=<(printf "[client]\nuser=%s\npassword=%s\n" "$DB_USER" "$DB_PASS") \
    --single-transaction --routines --triggers \
    --databases "$DB_NAME" | gzip > "$BACKUP_FILE"

# Check if backup was successful (pipefail ensures mysqldump errors are caught)
BACKUP_SIZE=$(stat -c%s "$BACKUP_FILE" 2>/dev/null || stat -f%z "$BACKUP_FILE" 2>/dev/null || echo "0")
if [ "$BACKUP_SIZE" -lt 1024 ]; then
    echo "[$(date)] ERROR: Backup file is suspiciously small (${BACKUP_SIZE} bytes). Backup may have failed!" >&2
    exit 1
fi

echo "[$(date)] Backup completed successfully: ${BACKUP_FILE} (${BACKUP_SIZE} bytes)"

# Clean up backups older than 14 days
echo "[$(date)] Cleaning up backups older than 14 days..."
find "$BACKUP_DIR" -type f -name "${DB_NAME}_backup_*.sql.gz" -mtime +14 -delete
echo "[$(date)] Cleanup completed."
