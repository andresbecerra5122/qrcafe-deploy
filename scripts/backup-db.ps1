param(
  [string]$OutputDir = "backups",
  [int]$RetentionDays = 90
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

$dbUser = Get-DotEnvValue -Key "POSTGRES_USER" -DefaultValue "postgres"
$dbName = Get-DotEnvValue -Key "POSTGRES_DB" -DefaultValue "qrcafe"

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

Write-Host "==> Ensuring DB container is running..."
docker compose up -d db *> $null

Write-Host "==> Waiting for DB readiness..."
for ($i = 1; $i -le 30; $i++) {
  docker compose exec -T db pg_isready -U $dbUser *> $null
  if ($LASTEXITCODE -eq 0) { break }
  Start-Sleep -Seconds 2
  if ($i -eq 30) { Write-Error "ERROR: DB did not become ready in time." }
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$file = Join-Path $OutputDir "qrcafe-$dbName-$timestamp.sql"

Write-Host "==> Creating backup: $file"
docker compose exec -T db pg_dump -U $dbUser -d $dbName | Out-File -FilePath $file -Encoding utf8

if (-not (Test-Path $file)) {
  Write-Error "ERROR: backup file was not created."
}

$size = (Get-Item $file).Length
if ($size -lt 100) {
  Write-Error "ERROR: backup file looks too small ($size bytes)."
}

Write-Host "==> Backup complete ($size bytes)."

if ($RetentionDays -gt 0) {
  $cutoff = (Get-Date).AddDays(-$RetentionDays)
  $oldFiles = Get-ChildItem -Path $OutputDir -Filter "*.sql" -File | Where-Object { $_.LastWriteTime -lt $cutoff }
  foreach ($old in $oldFiles) {
    Remove-Item $old.FullName -Force
  }
  Write-Host "==> Retention cleanup done. Removed $($oldFiles.Count) backup(s) older than $RetentionDays days."
}
