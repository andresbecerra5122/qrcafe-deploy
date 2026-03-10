#!/usr/bin/env bash
set -euo pipefail

MIGRATIONS_PATH="${1:-db/migrations}"

if [ ! -f ".env" ]; then
  echo "ERROR: .env file not found."
  exit 1
fi

if [ ! -d "$MIGRATIONS_PATH" ]; then
  echo "==> No migrations folder found at $MIGRATIONS_PATH. Skipping."
  exit 0
fi

set -a
source .env
set +a

DB_USER="${POSTGRES_USER:-postgres}"
DB_NAME="${POSTGRES_DB:-qrcafe}"

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

echo "==> Ensuring schema_migrations table..."
docker compose exec -T db psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 \
  -c "CREATE TABLE IF NOT EXISTS public.schema_migrations (migration_name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now());" \
  >/dev/null

shopt -s nullglob
migration_files=("$MIGRATIONS_PATH"/*.sql)
shopt -u nullglob

if [ ${#migration_files[@]} -eq 0 ]; then
  echo "==> No .sql migrations found in $MIGRATIONS_PATH."
  exit 0
fi

IFS=$'\n' sorted_files=($(printf "%s\n" "${migration_files[@]}" | sort))
unset IFS

for file in "${sorted_files[@]}"; do
  name="$(basename "$file")"
  escaped_name="${name//\'/\'\'}"
  applied="$(docker compose exec -T db psql -U "$DB_USER" -d "$DB_NAME" -t -A \
    -c "SELECT 1 FROM public.schema_migrations WHERE migration_name = '$escaped_name' LIMIT 1;")"

  if [ "${applied//[[:space:]]/}" = "1" ]; then
    echo "   - Skipping $name (already applied)"
    continue
  fi

  echo "   - Applying $name"
  docker compose exec -T db psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 < "$file" >/dev/null
  docker compose exec -T db psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 \
    -c "INSERT INTO public.schema_migrations (migration_name) VALUES ('$escaped_name');" >/dev/null
done

echo "==> Migrations complete."
