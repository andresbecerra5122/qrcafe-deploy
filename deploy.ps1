param(
  [switch]$ResetDb,
  [switch]$SkipBackup
)

$ErrorActionPreference = "Stop"

Write-Host "==> QrCafe Deploy"

if (-not (Test-Path ".env")) {
  Write-Error "ERROR: .env file not found. Copy .env.example to .env and fill in your values."
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Error "ERROR: Docker daemon is not running. Start Docker Desktop and retry."
}

if ($ResetDb) {
  Write-Host "==> Resetting database volume (this will remove existing DB data)..."
  docker compose down -v
} else {
  if (-not $SkipBackup) {
    Write-Host "==> Running pre-deploy DB backup..."
    ./scripts/backup-db.ps1
  } else {
    Write-Host "==> Skipping DB backup by request."
  }

  Write-Host "==> Running SQL migrations..."
  ./scripts/run-migrations.ps1
}

Write-Host "==> Building and starting containers..."
docker compose up -d --build

Write-Host ""
Write-Host "==> Done! Services:"
docker compose ps
Write-Host ""
Write-Host "Customer app: http://localhost (or your domain)"
Write-Host "Admin app:    http://localhost/admin/"
Write-Host "API:          http://localhost/api/"
Write-Host ""
Write-Host "Seeded demo staff users (from db/init.sql):"
Write-Host "  superadmin@qrcafe.local / Admin123!"
Write-Host "  admin@qrcafe.local   / Admin123!"
Write-Host "  kitchen@qrcafe.local / Kitchen123!"
Write-Host "  waiter@qrcafe.local  / Waiter123!"
Write-Host "  delivery@qrcafe.local / Waiter123!"
