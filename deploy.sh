#!/usr/bin/env bash
set -euo pipefail

echo "==> QrCafe Deploy"

RESET_DB=false
SKIP_BACKUP=false
if [[ "${1:-}" == "--reset-db" ]]; then
  RESET_DB=true
fi
if [[ "${2:-}" == "--skip-backup" || "${1:-}" == "--skip-backup" ]]; then
  SKIP_BACKUP=true
fi

# Ensure .env exists
if [ ! -f .env ]; then
  echo "ERROR: .env file not found. Copy .env.example to .env and fill in your values."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker daemon is not running. Start Docker Desktop and retry."
  exit 1
fi

if [ "$RESET_DB" = true ]; then
  echo "==> Resetting database volume (this will remove existing DB data)..."
  docker compose down -v
else
  if [ "$SKIP_BACKUP" = false ]; then
    echo "==> Running pre-deploy DB backup..."
    ./scripts/backup-db.sh
  else
    echo "==> Skipping DB backup by request."
  fi

  echo "==> Running SQL migrations..."
  ./scripts/run-migrations.sh
fi

echo "==> Building and starting containers..."
docker compose up -d --build

echo ""
echo "==> Done! Services:"
docker compose ps
echo ""
echo "Customer app: http://localhost (or your domain)"
echo "Admin app:    http://localhost/admin/"
echo "API:          http://localhost/api/"
echo ""
echo "Seeded demo staff users (from db/init.sql):"
echo "  superadmin@qrcafe.local / Admin123!"
echo "  admin@qrcafe.local   / Admin123!"
echo "  kitchen@qrcafe.local / Kitchen123!"
echo "  waiter@qrcafe.local  / Waiter123!"
echo "  delivery@qrcafe.local / Waiter123!"