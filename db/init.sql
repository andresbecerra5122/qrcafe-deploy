-- ============================================================
-- QrCafe – Full DDL + Demo Seed Data
-- Runs automatically on first Docker Compose startup.
-- Safe to re-run (uses IF NOT EXISTS / ON CONFLICT DO NOTHING).
-- ============================================================

-- ============ TABLES ============

CREATE TABLE IF NOT EXISTS public.restaurants (
    id              UUID PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    slug            VARCHAR(100) NOT NULL UNIQUE,
    country_code    VARCHAR(5)   NOT NULL DEFAULT 'CO',
    currency        VARCHAR(5)   NOT NULL DEFAULT 'COP',
    timezone        VARCHAR(50)  NOT NULL DEFAULT 'America/Bogota',
    tax_rate        NUMERIC(5,4) NOT NULL DEFAULT 0.00,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    enable_dine_in  BOOLEAN      NOT NULL DEFAULT TRUE,
    enable_delivery BOOLEAN      NOT NULL DEFAULT FALSE,
    enable_delivery_cash BOOLEAN NOT NULL DEFAULT TRUE,
    enable_delivery_card BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.tables (
    id              UUID PRIMARY KEY,
    restaurant_id   UUID         NOT NULL REFERENCES public.restaurants(id),
    number          INT          NOT NULL,
    token           VARCHAR(200) NOT NULL UNIQUE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.categories (
    id              UUID PRIMARY KEY,
    restaurant_id   UUID         NOT NULL REFERENCES public.restaurants(id),
    name            VARCHAR(150) NOT NULL,
    sort            INT          NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.products (
    id              UUID PRIMARY KEY,
    restaurant_id   UUID         NOT NULL REFERENCES public.restaurants(id),
    category_id     UUID         REFERENCES public.categories(id),
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    price           NUMERIC(12,2) NOT NULL DEFAULT 0,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    is_available    BOOLEAN      NOT NULL DEFAULT TRUE,
    sort            INT          NOT NULL DEFAULT 0,
    image_url       TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.orders (
    id                   UUID PRIMARY KEY,
    restaurant_id        UUID         NOT NULL REFERENCES public.restaurants(id),
    order_type           VARCHAR(20)  NOT NULL DEFAULT 'DINE_IN',
    table_id             UUID         REFERENCES public.tables(id),
    customer_name        VARCHAR(200),
    notes                TEXT,
    delivery_address     TEXT,
    delivery_reference   TEXT,
    delivery_phone       VARCHAR(50),
    status               VARCHAR(30)  NOT NULL DEFAULT 'CREATED',
    currency             VARCHAR(5)   NOT NULL DEFAULT 'COP',
    subtotal             NUMERIC(12,2) NOT NULL DEFAULT 0,
    tax                  NUMERIC(12,2) NOT NULL DEFAULT 0,
    total                NUMERIC(12,2) NOT NULL DEFAULT 0,
    payment_method       VARCHAR(20),
    payment_requested_at TIMESTAMPTZ,
    paid_at              TIMESTAMPTZ,
    order_number         BIGINT       NOT NULL DEFAULT 0,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

ALTER TABLE public.restaurants
    ADD COLUMN IF NOT EXISTS enable_dine_in BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS enable_delivery BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS enable_delivery_cash BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS enable_delivery_card BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE public.orders
    ADD COLUMN IF NOT EXISTS delivery_address TEXT,
    ADD COLUMN IF NOT EXISTS delivery_reference TEXT,
    ADD COLUMN IF NOT EXISTS delivery_phone VARCHAR(50);

CREATE TABLE IF NOT EXISTS public.order_items (
    id                UUID PRIMARY KEY,
    order_id          UUID           NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id        UUID           NOT NULL,
    product_name_snap VARCHAR(200)   NOT NULL,
    unit_price_snap   NUMERIC(12,2)  NOT NULL DEFAULT 0,
    qty               INT            NOT NULL DEFAULT 1,
    notes             TEXT,
    line_total        NUMERIC(12,2)  NOT NULL DEFAULT 0,
    created_at        TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.payments (
    id              UUID PRIMARY KEY,
    order_id        UUID           NOT NULL REFERENCES public.orders(id),
    provider        VARCHAR(30)    NOT NULL,
    provider_ref    VARCHAR(500),
    status          VARCHAR(30)    NOT NULL DEFAULT 'PENDING',
    amount          NUMERIC(12,2)  NOT NULL DEFAULT 0,
    currency        VARCHAR(5)     NOT NULL DEFAULT 'COP',
    created_at      TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.waiter_calls (
    id              UUID PRIMARY KEY,
    restaurant_id   UUID         NOT NULL REFERENCES public.restaurants(id),
    table_id        UUID         REFERENCES public.tables(id),
    table_number    INT,
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    attended_at     TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.staff_users (
    id              UUID PRIMARY KEY,
    restaurant_id   UUID         NOT NULL REFERENCES public.restaurants(id),
    full_name       VARCHAR(200) NOT NULL,
    email           VARCHAR(320) NOT NULL,
    password_hash   TEXT         NOT NULL,
    role            VARCHAR(30)  NOT NULL,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    last_login_at   TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.restaurant_order_counters (
    restaurant_id   UUID PRIMARY KEY REFERENCES public.restaurants(id),
    last_number     BIGINT NOT NULL DEFAULT 0
);

-- ============ INDEXES ============

CREATE INDEX IF NOT EXISTS idx_orders_restaurant_status ON public.orders(restaurant_id, status);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id     ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_products_restaurant      ON public.products(restaurant_id, is_active);
CREATE INDEX IF NOT EXISTS idx_tables_restaurant_token  ON public.tables(restaurant_id, token);
CREATE INDEX IF NOT EXISTS idx_waiter_calls_restaurant  ON public.waiter_calls(restaurant_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS ux_staff_users_restaurant_email ON public.staff_users(restaurant_id, email);

-- ============================================================
-- DEMO SEED DATA
--
-- Restaurant ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890
--
-- Access URLs (after docker-compose up):
--   Customer menu:  http://localhost/menu?restaurantId=a1b2c3d4-e5f6-7890-abcd-ef1234567890&table=mesa-1-token-abc123
--   Kitchen:        http://localhost/admin/dashboard?restaurantId=a1b2c3d4-e5f6-7890-abcd-ef1234567890
--   Waiters:        http://localhost/admin/waiters?restaurantId=a1b2c3d4-e5f6-7890-abcd-ef1234567890
--   Products:       http://localhost/admin/products?restaurantId=a1b2c3d4-e5f6-7890-abcd-ef1234567890
--
-- Demo staff login users:
--   admin@qrcafe.local   / Admin123!
--   kitchen@qrcafe.local / Kitchen123!
--   waiter@qrcafe.local  / Waiter123!
--   delivery@qrcafe.local / Waiter123!
-- ============================================================

-- Restaurant
INSERT INTO public.restaurants (
  id, name, slug, country_code, currency, timezone, tax_rate, is_active,
  enable_dine_in, enable_delivery, enable_delivery_cash, enable_delivery_card
)
VALUES (
  'a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'Mi Restaurante Demo', 'mi-restaurante-demo', 'CO', 'COP',
  'America/Bogota', 0.08, TRUE, TRUE, TRUE, TRUE, TRUE
)
ON CONFLICT (id) DO NOTHING;

-- Order counter
INSERT INTO public.restaurant_order_counters (restaurant_id, last_number)
VALUES ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', 0)
ON CONFLICT (restaurant_id) DO NOTHING;

-- Tables (5 mesas)
INSERT INTO public.tables (id, restaurant_id, number, token, is_active) VALUES
  ('11111111-1111-1111-1111-111111111101', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', 1, 'mesa-1-token-abc123', TRUE),
  ('11111111-1111-1111-1111-111111111102', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', 2, 'mesa-2-token-def456', TRUE),
  ('11111111-1111-1111-1111-111111111103', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', 3, 'mesa-3-token-ghi789', TRUE),
  ('11111111-1111-1111-1111-111111111104', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', 4, 'mesa-4-token-jkl012', TRUE),
  ('11111111-1111-1111-1111-111111111105', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', 5, 'mesa-5-token-mno345', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Categories
INSERT INTO public.categories (id, restaurant_id, name, sort) VALUES
  ('22222222-2222-2222-2222-222222222201', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'Desayunos',      1),
  ('22222222-2222-2222-2222-222222222202', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'Platos Fuertes', 2),
  ('22222222-2222-2222-2222-222222222203', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'Bebidas',        3)
ON CONFLICT (id) DO NOTHING;

-- Products
INSERT INTO public.products (id, restaurant_id, category_id, name, description, price, is_active, is_available, sort, image_url) VALUES
  -- Desayunos
  ('33333333-3333-3333-3333-333333333301', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', '22222222-2222-2222-2222-222222222201',
   'Huevos Rancheros', 'Huevos fritos sobre tortilla con salsa roja y frijoles', 18000, TRUE, TRUE, 1,
   'https://images.pexels.com/photos/5848072/pexels-photo-5848072.jpeg?auto=compress&cs=tinysrgb&w=600'),

  ('33333333-3333-3333-3333-333333333302', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', '22222222-2222-2222-2222-222222222201',
   'Pancakes con Frutas', 'Stack de pancakes con frutas frescas, miel de maple y crema', 16000, TRUE, TRUE, 2,
   'https://images.pexels.com/photos/376464/pexels-photo-376464.jpeg?auto=compress&cs=tinysrgb&w=600'),

  ('33333333-3333-3333-3333-333333333303', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', '22222222-2222-2222-2222-222222222201',
   'Croissant Jamón y Queso', 'Croissant relleno de jamón y queso gratinado', 12000, TRUE, TRUE, 3,
   'https://images.pexels.com/photos/3892469/pexels-photo-3892469.jpeg?auto=compress&cs=tinysrgb&w=600'),

  -- Platos Fuertes
  ('33333333-3333-3333-3333-333333333304', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', '22222222-2222-2222-2222-222222222202',
   'Hamburguesa Clásica', 'Carne angus 200g, lechuga, tomate, queso cheddar y papas', 28000, TRUE, TRUE, 1,
   'https://images.pexels.com/photos/1639557/pexels-photo-1639557.jpeg?auto=compress&cs=tinysrgb&w=600'),

  ('33333333-3333-3333-3333-333333333305', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', '22222222-2222-2222-2222-222222222202',
   'Bandeja Paisa', 'Frijoles, arroz, chicharrón, carne molida, huevo, plátano, arepa y aguacate', 32000, TRUE, TRUE, 2,
   'https://images.pexels.com/photos/5409015/pexels-photo-5409015.jpeg?auto=compress&cs=tinysrgb&w=600'),

  ('33333333-3333-3333-3333-333333333306', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', '22222222-2222-2222-2222-222222222202',
   'Salmón a la Plancha', 'Filete de salmón con vegetales asados y puré de papa', 35000, TRUE, TRUE, 3,
   'https://images.pexels.com/photos/3763847/pexels-photo-3763847.jpeg?auto=compress&cs=tinysrgb&w=600'),

  -- Bebidas
  ('33333333-3333-3333-3333-333333333307', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', '22222222-2222-2222-2222-222222222203',
   'Limonada Natural', 'Limonada fresca con hierbabuena', 7000, TRUE, TRUE, 1,
   'https://images.pexels.com/photos/2109099/pexels-photo-2109099.jpeg?auto=compress&cs=tinysrgb&w=600'),

  ('33333333-3333-3333-3333-333333333308', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', '22222222-2222-2222-2222-222222222203',
   'Café Latte', 'Espresso doble con leche vaporizada', 8000, TRUE, TRUE, 2,
   'https://images.pexels.com/photos/312418/pexels-photo-312418.jpeg?auto=compress&cs=tinysrgb&w=600'),

  ('33333333-3333-3333-3333-333333333309', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', '22222222-2222-2222-2222-222222222203',
   'Jugo de Mango', 'Jugo natural de mango fresco', 9000, TRUE, TRUE, 3,
   'https://images.pexels.com/photos/2789328/pexels-photo-2789328.jpeg?auto=compress&cs=tinysrgb&w=600')
ON CONFLICT (id) DO NOTHING;

-- Staff users (password hashes generated with PBKDF2-SHA256, 100000 iterations)
INSERT INTO public.staff_users (id, restaurant_id, full_name, email, password_hash, role, is_active) VALUES
  ('44444444-4444-4444-4444-444444444401', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'Admin Demo', 'admin@qrcafe.local',
   '100000.hwighKEROwv9/PqKUUDlEg==.vlrvQrSrJirucbvY08OqjUtjMBCZoZrKGe3nmiI8OEc=', 'Admin', TRUE),
  ('44444444-4444-4444-4444-444444444402', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'Kitchen Demo', 'kitchen@qrcafe.local',
   '100000.mBaWv1dcLCf8Q2/Z3dh+Fw==.Yg9uRg1LWL0dzUEQGZVZpERFaG28OeUGV1fuJklnlns=', 'Kitchen', TRUE),
  ('44444444-4444-4444-4444-444444444403', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'Waiter Demo', 'waiter@qrcafe.local',
   '100000.awFf6Kxbx3kpVia/Ym5xbQ==.6BniZm8dNZBYZ74SDAhcZj1sp51R8XBWaRNdZulqsz8=', 'Waiter', TRUE),
  ('44444444-4444-4444-4444-444444444404', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'Delivery Demo', 'delivery@qrcafe.local',
   '100000.awFf6Kxbx3kpVia/Ym5xbQ==.6BniZm8dNZBYZ74SDAhcZj1sp51R8XBWaRNdZulqsz8=', 'Delivery', TRUE)
ON CONFLICT (id) DO NOTHING;
