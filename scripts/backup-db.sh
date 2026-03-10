#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${1:-backups}"
RETENTION_DAYS="${RETENTION_DAYS:-90}"

if [ ! -f ".env" ]; then
  echo "ERROR: .env file not found."
  exit 1
fi

set -a
source .env
set +a

DB_USER="${POSTGRES_USER:-postgres}"
DB_NAME="${POSTGRES_DB:-qrcafe}"

mkdir -p "$OUTPUT_DIR"

echo "==> Ensuring DB container is running..."
docker compose up -d db >/dev/null

echo "==> Waiting for DB readiness..."
for i in {1..30}; do
  if docker compose exec -T db pg_isready -U "$DB_USER" >/dev/null 2>&1; then
    break
  fi
  sleep 2
  if [ "$i" -eq 30 ]; then
    echo "ERROR: DB did not become ready in time."
    exit 1
  fi
done

timestamp="$(date +%Y%m%d-%H%M%S)"
file="$OUTPUT_DIR/qrcafe-$DB_NAME-$timestamp.sql"

echo "==> Creating backup: $file"
docker compose exec -T db pg_dump -U "$DB_USER" -d "$DB_NAME" > "$file"

if [ ! -f "$file" ]; then
  echo "ERROR: backup file was not created."
  exit 1
fi

size="$(wc -c < "$file" | tr -d ' ')"
if [ "$size" -lt 100 ]; then
  echo "ERROR: backup file looks too small ($size bytes)."
  exit 1
fi

echo "==> Backup complete ($size bytes)."

if [ "$RETENTION_DAYS" -gt 0 ] 2>/dev/null; then
  before_count="$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.sql' | wc -l | tr -d ' ')"
  find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.sql' -mtime +"$RETENTION_DAYS" -delete
  after_count="$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.sql' | wc -l | tr -d ' ')"
  removed=$((before_count - after_count))
  echo "==> Retention cleanup done. Removed $removed backup(s) older than $RETENTION_DAYS days."
fi
