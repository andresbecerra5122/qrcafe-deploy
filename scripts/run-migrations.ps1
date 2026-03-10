param(
  [string]$MigrationsPath = "db/migrations"
)

$ErrorActionPreference = "Stop"

function Get-DotEnvValue {
  param(
    [string]$Key,
    [string]$DefaultValue = ""
  )

  if (-not (Test-Path ".env")) {
    return $DefaultValue
  }

  $line = Get-Content ".env" | Where-Object {
    $_ -match "^\s*$Key\s*=" -and $_ -notmatch "^\s*#"
  } | Select-Object -First 1

  if (-not $line) { return $DefaultValue }
  $parts = $line -split "=", 2
  if ($parts.Count -lt 2) { return $DefaultValue }
  return $parts[1].Trim()
}

if (-not (Test-Path ".env")) {
  Write-Error "ERROR: .env file not found."
}

if (-not (Test-Path $MigrationsPath)) {
  Write-Host "==> No migrations folder found at $MigrationsPath. Skipping."
  exit 0
}

$dbUser = Get-DotEnvValue -Key "POSTGRES_USER" -DefaultValue "postgres"
$dbName = Get-DotEnvValue -Key "POSTGRES_DB" -DefaultValue "qrcafe"

Write-Host "==> Ensuring DB container is running..."
docker compose up -d db *> $null

Write-Host "==> Waiting for DB readiness..."
for ($i = 1; $i -le 30; $i++) {
  docker compose exec -T db pg_isready -U $dbUser *> $null
  if ($LASTEXITCODE -eq 0) { break }
  Start-Sleep -Seconds 2
  if ($i -eq 30) { Write-Error "ERROR: DB did not become ready in time." }
}

Write-Host "==> Ensuring schema_migrations table..."
docker compose exec -T db psql -U $dbUser -d $dbName -v ON_ERROR_STOP=1 -c "CREATE TABLE IF NOT EXISTS public.schema_migrations (migration_name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now());" *> $null

$files = Get-ChildItem -Path $MigrationsPath -Filter "*.sql" | Sort-Object Name
if ($files.Count -eq 0) {
  Write-Host "==> No .sql migrations found in $MigrationsPath."
  exit 0
}

foreach ($file in $files) {
  $migrationName = $file.Name.Replace("'", "''")
  $alreadyApplied = docker compose exec -T db psql -U $dbUser -d $dbName -t -A -c "SELECT 1 FROM public.schema_migrations WHERE migration_name = '$migrationName' LIMIT 1;"
  $alreadyAppliedText = if ($null -eq $alreadyApplied) { "" } else { "$alreadyApplied".Trim() }

  if ($alreadyAppliedText -eq "1") {
    Write-Host "   - Skipping $($file.Name) (already applied)"
    continue
  }

  Write-Host "   - Applying $($file.Name)"
  Get-Content -Raw $file.FullName | docker compose exec -T db psql -U $dbUser -d $dbName -v ON_ERROR_STOP=1 *> $null
  docker compose exec -T db psql -U $dbUser -d $dbName -v ON_ERROR_STOP=1 -c "INSERT INTO public.schema_migrations (migration_name) VALUES ('$migrationName');" *> $null
}

Write-Host "==> Migrations complete."
