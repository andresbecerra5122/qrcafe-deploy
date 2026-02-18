#!/usr/bin/env bash
set -euo pipefail

echo "==> QrCafe Deploy"

# Ensure .env exists
if [ ! -f .env ]; then
  echo "ERROR: .env file not found. Copy .env.example to .env and fill in your values."
  exit 1
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
