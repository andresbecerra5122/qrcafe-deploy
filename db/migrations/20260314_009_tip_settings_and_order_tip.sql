ALTER TABLE public.restaurants
  ADD COLUMN IF NOT EXISTS suggested_tip_percent numeric(5,2) NOT NULL DEFAULT 10;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS tip_amount numeric(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tip_percent_applied numeric(5,2) NULL,
  ADD COLUMN IF NOT EXISTS tip_source text NULL;

