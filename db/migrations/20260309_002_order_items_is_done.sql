-- Persist per-item completion so reopened table orders can keep prior items marked done.
ALTER TABLE IF EXISTS public.order_items
    ADD COLUMN IF NOT EXISTS is_done boolean NOT NULL DEFAULT false;
