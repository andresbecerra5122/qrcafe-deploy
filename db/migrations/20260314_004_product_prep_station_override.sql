ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS prep_station text NULL;

