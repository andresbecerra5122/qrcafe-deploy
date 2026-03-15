ALTER TABLE IF EXISTS public.restaurants
    ADD COLUMN IF NOT EXISTS enable_kitchen_bar_split boolean NOT NULL DEFAULT false;

ALTER TABLE IF EXISTS public.categories
    ADD COLUMN IF NOT EXISTS prep_station text NOT NULL DEFAULT 'KITCHEN';

ALTER TABLE IF EXISTS public.order_items
    ADD COLUMN IF NOT EXISTS prep_station text NOT NULL DEFAULT 'KITCHEN',
    ADD COLUMN IF NOT EXISTS is_prepared boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS is_delivered boolean NOT NULL DEFAULT false;

UPDATE public.order_items
SET is_prepared = is_done
WHERE is_prepared IS DISTINCT FROM is_done;
