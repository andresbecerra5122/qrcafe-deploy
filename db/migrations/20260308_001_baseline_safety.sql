-- Baseline safety migration:
-- Keep critical tables/columns aligned without destructive changes.
-- Safe to run multiple times.

CREATE TABLE IF NOT EXISTS public.schema_migrations (
    migration_name text PRIMARY KEY,
    applied_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.restaurant_order_counters (
    restaurant_id uuid PRIMARY KEY REFERENCES public.restaurants(id),
    last_number bigint NOT NULL DEFAULT 0
);

ALTER TABLE IF EXISTS public.restaurants
    ADD COLUMN IF NOT EXISTS enable_dine_in boolean NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS enable_delivery boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS enable_delivery_cash boolean NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS enable_delivery_card boolean NOT NULL DEFAULT true;

ALTER TABLE IF EXISTS public.orders
    ADD COLUMN IF NOT EXISTS delivery_address text NULL,
    ADD COLUMN IF NOT EXISTS delivery_reference text NULL,
    ADD COLUMN IF NOT EXISTS delivery_phone varchar(50) NULL;
