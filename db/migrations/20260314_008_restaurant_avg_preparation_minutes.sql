ALTER TABLE public.restaurants
  ADD COLUMN IF NOT EXISTS avg_preparation_minutes integer NOT NULL DEFAULT 15;
