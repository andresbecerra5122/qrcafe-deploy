ALTER TABLE IF EXISTS public.orders
    ADD COLUMN IF NOT EXISTS payment_method_label TEXT NULL;

CREATE TABLE IF NOT EXISTS public.restaurant_payment_methods (
    id uuid PRIMARY KEY,
    restaurant_id uuid NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
    code varchar(30) NOT NULL,
    label varchar(80) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    sort int NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_restaurant_payment_methods_restaurant_code
    ON public.restaurant_payment_methods (restaurant_id, code);

INSERT INTO public.restaurant_payment_methods (id, restaurant_id, code, label, is_active, sort, created_at, updated_at)
SELECT gen_random_uuid(), r.id, 'CASH', 'Efectivo', true, 1, now(), now()
FROM public.restaurants r
WHERE NOT EXISTS (
    SELECT 1
    FROM public.restaurant_payment_methods rpm
    WHERE rpm.restaurant_id = r.id AND rpm.code = 'CASH'
);

INSERT INTO public.restaurant_payment_methods (id, restaurant_id, code, label, is_active, sort, created_at, updated_at)
SELECT gen_random_uuid(), r.id, 'CARD', 'Tarjeta', true, 2, now(), now()
FROM public.restaurants r
WHERE NOT EXISTS (
    SELECT 1
    FROM public.restaurant_payment_methods rpm
    WHERE rpm.restaurant_id = r.id AND rpm.code = 'CARD'
);

UPDATE public.orders
SET payment_method_label = CASE
    WHEN payment_method = 'CASH' THEN 'Efectivo'
    WHEN payment_method = 'CARD' THEN 'Tarjeta'
    ELSE payment_method
END
WHERE payment_method_label IS NULL
  AND payment_method IS NOT NULL;
