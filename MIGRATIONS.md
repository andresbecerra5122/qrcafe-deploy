# Database Migrations Guide

This project uses SQL-file migrations with tracking in `public.schema_migrations`.

## Quick Answer

Yes. For any DB schema/data change in normal operation, add a new `.sql` file in:

- `db/migrations/`

Then run normal deploy:

- `./deploy.ps1` (Windows)
- `./deploy.sh` (Linux/macOS)

Deploy will:

1. Create a pre-deploy DB backup.
2. Run pending migrations once.
3. Build/restart services.

## How Migration Tracking Works

Migration runner scripts:

- `scripts/run-migrations.ps1`
- `scripts/run-migrations.sh`

Behavior:

1. Ensure DB is up and healthy.
2. Ensure table exists:
   - `public.schema_migrations(migration_name, applied_at)`
3. Read all `*.sql` files in `db/migrations/` sorted by filename.
4. For each file:
   - If filename is already in `schema_migrations`, skip.
   - Otherwise run SQL and insert filename into `schema_migrations`.

This makes migrations idempotent at the file level.

## File Naming Convention

Use ordered, unique names so execution order is clear.

Recommended format:

- `YYYYMMDD_NNN_short_description.sql`

Examples:

- `20260310_002_add_invoices_table.sql`
- `20260311_003_add_order_indexes.sql`

## Safe Migration Rules (Production)

Prefer additive, backward-compatible changes:

- `ADD COLUMN` with safe defaults/nullability
- `CREATE TABLE`
- `CREATE INDEX`
- backfill scripts that do not break existing reads

Avoid destructive changes in the same release:

- `DROP COLUMN`
- type changes without compatibility strategy
- hard deletes of production data

For destructive/major refactors, use two-step rollout:

1. Add new structure + dual-write/read compatibility.
2. Later clean up old structure.

## Backups and Restore

Backup scripts:

- `scripts/backup-db.ps1`
- `scripts/backup-db.sh`

Backups are written to:

- `backups/`

Run manually anytime:

- `./scripts/backup-db.ps1`
- `./scripts/backup-db.sh`

## Deploy Options

Normal safe deploy (recommended):

- `./deploy.ps1`
- `./deploy.sh`

Skip backup (not recommended):

- `./deploy.ps1 -SkipBackup`
- `./deploy.sh --skip-backup`

Reset DB (destructive, dev only):

- `./deploy.ps1 -ResetDb`
- `./deploy.sh --reset-db`

## Relationship with `db/init.sql`

`db/init.sql` runs only on first DB initialization (fresh volume).

After environments are live, ongoing schema evolution should happen through:

- `db/migrations/*.sql`

Do not rely on `init.sql` for production updates after go-live.

