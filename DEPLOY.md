# QrCafe - Deployment Guide

## 1. Project Overview

QrCafe is a QR-based menu and ordering system for restaurants. Customers scan a QR code at their table, browse the menu on their phone, place orders, and request payment. Kitchen staff and waiters manage orders in real time through dedicated dashboards.

## 2. Architecture

The system runs as three Docker containers orchestrated by Docker Compose:

```
                  +------------------+
                  |     Nginx        |  :80 (or HTTP_PORT)
                  |  (static files + |
                  |   reverse proxy) |
                  +--------+---------+
                           |
              +------------+------------+
              |                         |
     /menu, /checkout, ...     /admin/dashboard, ...
     (Customer Angular SPA)    (Admin Angular SPA)
              |                         |
              +------------+------------+
                           |
                      /api/* -> strips prefix
                           |
                  +--------+---------+
                  |   .NET 8 API     |  :5015 (internal)
                  |   (MediatR/CQRS) |
                  +--------+---------+
                           |
                  +--------+---------+
                  |  PostgreSQL 16   |  :5432 (internal)
                  +------------------+
```

- **Nginx** serves both Angular SPAs as static files and reverse-proxies `/api/*` requests to the .NET API (stripping the `/api` prefix).
- **Customer app** is served at `/` (root).
- **Admin app** is served at `/admin/` (kitchen, waiters, products pages).
- **.NET 8 API** uses MediatR (CQRS pattern), Entity Framework Core with Npgsql.
- **PostgreSQL 16** (Alpine) stores all data. The `db/init.sql` script creates tables and seeds demo data on first startup.

### Repository Structure

```
QrCafe-main/                  # Deploy monorepo
├── QrCafe/                   # .NET 8 Backend API (submodule)
│   ├── QrCafe.Api/           #   Controllers, DTOs, Mappers
│   ├── QrCafe.Application/   #   Commands, Queries, Handlers (MediatR)
│   ├── QrCafe.Domain/        #   Entities, Enums
│   ├── QrCafe.Infrastructure/#   DbContext, EF Core config
│   └── Dockerfile
├── QrCafe-Web/
│   └── qrcafe-web/           # Angular 18 Customer App (submodule)
├── QrCafe-Web-Admin/
│   └── qrcafe-admin/         # Angular 18 Admin App (submodule)
├── nginx/
│   ├── Dockerfile            # Multi-stage: builds both Angular apps + Nginx
│   └── nginx.conf            # Reverse proxy + SPA routing
├── db/
│   └── init.sql              # DDL + seed data (auto-runs on first startup)
├── docker-compose.yml
├── .env                      # Environment variables (not committed)
└── .env.example              # Template for .env
```

## 3. Features Built

### Customer-Facing (QrCafe-Web)
- **QR Table Scanning** -- Customer scans QR, lands on menu with table auto-detected
- **Menu Browsing** -- Products grouped by category with images, descriptions, prices
- **Cart & Order Placement** -- Add/remove items, notes, place order
- **Order Tracking** -- Post-order status page showing real-time status
- **Payment Request** -- Customer can request payment (selects cash/card)
- **Call Waiter** -- Button to summon a waiter for assistance
- **Dynamic Restaurant Name** -- Restaurant name fetched from DB, displayed in header

### Kitchen Dashboard (Admin /dashboard)
- **Order Cards** -- Shows all orders with status, table, customer, total
- **Order Items Display** -- Each card lists the ordered products (qty x name)
- **Hybrid Collapse** -- Orders with 5+ items show first 4 with "ver todo" expand
- **Preparation Checkboxes** -- Kitchen staff can check off prepared items (local-only, no backend)
- **Checkboxes Disabled** -- Only interactive when order is IN_PROGRESS or READY
- **Status Flow** -- CREATED -> "Preparar" -> IN_PROGRESS -> "Listo" -> READY
- **Filter Tabs** -- Active, New, In Progress, Ready, Delivered, All
- **Product Availability** -- Toggle products on/off from the Productos page

### Waiter Dashboard (Admin /waiters)
- **Waiter Call Cards** -- Shows pending customer calls with table number and time
- **"Tomar pedido" Button** -- On call cards, navigates to new order page with table pre-filled
- **"Nueva orden" Button** -- Global button in header to create order for any table
- **Order Status Flow** -- READY -> "Entregado" -> DELIVERED (waiter handles delivery)
- **"Cobrar" Quick-Collect** -- On DELIVERED orders, expand to choose Efectivo/Tarjeta, marks PAID instantly
- **Order Items Display** -- Same item list as kitchen (without checkboxes)

### Waiter Order Creation (Admin /new-order)
- **Product Catalog** -- Full menu grouped by category with qty +/- controls
- **Table Selection** -- Table number input (pre-filled from waiter call)
- **Customer Name & Notes** -- Optional fields
- **Sticky Bottom Bar** -- Shows item count, subtotal, and confirm button

### Product Management (Admin /products)
- **Product List** -- All products grouped by category
- **Availability Toggle** -- Switch to hide/show products from customer menu

## 4. Prerequisites

- **Docker Desktop** (Windows/Mac) or Docker Engine + Docker Compose (Linux)
- **Git** (to clone the repository)
- Ports **80** (or your chosen `HTTP_PORT`) must be available

## 5. Step-by-Step Deployment

### 5.1 Clone the Repository

```bash
git clone https://github.com/andresbecerra5122/qrcafe-deploy.git QrCafe-main
cd QrCafe-main

# If using submodules:
git submodule update --init --recursive
```

### 5.2 Create Environment File

```bash
cp .env.example .env
```

Edit `.env` with your values:

```env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_strong_password_here
POSTGRES_DB=qrcafe
ALLOWED_ORIGINS=http://localhost
HTTP_PORT=80
```

> **Important:** If port 80 is already in use (common on Windows with IIS), change `HTTP_PORT` to another value like `8080` and update `ALLOWED_ORIGINS` to match (e.g., `http://localhost:8080`).

### 5.3 Build and Start

```bash
docker-compose up --build -d
```

First build takes 5-10 minutes (downloading base images, npm install, Angular builds, .NET publish). Subsequent builds use cached layers and are much faster.

### 5.4 Verify All Containers Are Running

```bash
docker-compose ps
```

You should see three containers (db, api, nginx) all with status "Up" and db showing "(healthy)".

### 5.5 Access the Application

Using the demo seed data (see Section 8):

| Page | URL |
|------|-----|
| Customer Menu (Mesa 1) | `http://localhost:{PORT}/menu?restaurantId=a1b2c3d4-e5f6-7890-abcd-ef1234567890&table=mesa-1-token-abc123` |
| Kitchen Dashboard | `http://localhost:{PORT}/admin/dashboard?restaurantId=a1b2c3d4-e5f6-7890-abcd-ef1234567890` |
| Waiter Dashboard | `http://localhost:{PORT}/admin/waiters?restaurantId=a1b2c3d4-e5f6-7890-abcd-ef1234567890` |
| Products Management | `http://localhost:{PORT}/admin/products?restaurantId=a1b2c3d4-e5f6-7890-abcd-ef1234567890` |

Replace `{PORT}` with your `HTTP_PORT` value (default `80`).

### 5.6 Stop the Application

```bash
docker-compose down
```

To also remove the database volume (full reset):

```bash
docker-compose down -v
```

## 6. Configuration

### Environment Variables (.env)

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_USER` | `postgres` | PostgreSQL username |
| `POSTGRES_PASSWORD` | *(required)* | PostgreSQL password |
| `POSTGRES_DB` | `qrcafe` | Database name |
| `ALLOWED_ORIGINS` | `http://localhost` | CORS origins for the API (comma-separated for multiple) |
| `HTTP_PORT` | `80` | Host port for Nginx (the port you access in browser) |

### Changing the Port

If port 80 is taken:

1. Set `HTTP_PORT=8080` in `.env`
2. Set `ALLOWED_ORIGINS=http://localhost:8080` in `.env`
3. Restart: `docker-compose up -d`

### Production Deployment

For a VPS with a domain:

1. Set `ALLOWED_ORIGINS=https://yourdomain.com`
2. Set `HTTP_PORT=80`
3. Add an SSL termination proxy (Certbot + Nginx on the host, or Cloudflare) in front

## 7. Database

### How It Works

The file `db/init.sql` is mounted into the PostgreSQL container at `/docker-entrypoint-initdb.d/01-init.sql`. PostgreSQL automatically runs this script **only on first startup** (when the data volume is empty).

### Tables Created (9 total)

| Table | Purpose |
|-------|---------|
| `restaurants` | Restaurant metadata (name, currency, tax rate) |
| `tables` | Physical tables with QR tokens |
| `categories` | Product grouping (Desayunos, Platos Fuertes, etc.) |
| `products` | Menu items (name, price, image, availability) |
| `orders` | Customer and waiter orders |
| `order_items` | Line items per order (product snapshot) |
| `payments` | Payment records |
| `waiter_calls` | Waiter assistance requests |
| `restaurant_order_counters` | Atomic order number generator |

### Resetting the Database

To wipe all data and re-run the init script:

```bash
docker-compose down -v
docker-compose up -d
```

The `-v` flag removes the PostgreSQL volume, so the init script runs again on next startup.

### Adding a New Restaurant Manually

Connect to the database:

```bash
docker exec -it qrcafe-main-db-1 psql -U postgres -d qrcafe
```

Then run SQL:

```sql
-- 1. Create restaurant
INSERT INTO restaurants (id, name, slug, country_code, currency, timezone, tax_rate, is_active)
VALUES (gen_random_uuid(), 'My New Restaurant', 'my-new-restaurant', 'CO', 'COP', 'America/Bogota', 0.08, TRUE);

-- 2. Note the generated ID, then create tables
INSERT INTO tables (id, restaurant_id, number, token, is_active)
VALUES (gen_random_uuid(), '<restaurant_id>', 1, 'unique-token-for-table-1', TRUE);

-- 3. Create order counter
INSERT INTO restaurant_order_counters (restaurant_id, last_number)
VALUES ('<restaurant_id>', 0);

-- 4. Create categories
INSERT INTO categories (id, restaurant_id, name, sort)
VALUES (gen_random_uuid(), '<restaurant_id>', 'My Category', 1);

-- 5. Create products
INSERT INTO products (id, restaurant_id, category_id, name, description, price, is_active, is_available, sort, image_url)
VALUES (gen_random_uuid(), '<restaurant_id>', '<category_id>', 'Product Name', 'Description', 15000, TRUE, TRUE, 1, 'https://example.com/image.jpg');
```

## 8. Seed Data Reference

The `db/init.sql` script creates the following demo data:

### Restaurant

| Field | Value |
|-------|-------|
| ID | `a1b2c3d4-e5f6-7890-abcd-ef1234567890` |
| Name | Mi Restaurante Demo |
| Currency | COP |
| Tax Rate | 8% |

### Tables

| Mesa | Token | QR URL Parameter |
|------|-------|------------------|
| 1 | `mesa-1-token-abc123` | `&table=mesa-1-token-abc123` |
| 2 | `mesa-2-token-def456` | `&table=mesa-2-token-def456` |
| 3 | `mesa-3-token-ghi789` | `&table=mesa-3-token-ghi789` |
| 4 | `mesa-4-token-jkl012` | `&table=mesa-4-token-jkl012` |
| 5 | `mesa-5-token-mno345` | `&table=mesa-5-token-mno345` |

### Categories

| Category | Products |
|----------|----------|
| Desayunos | Huevos Rancheros, Pancakes con Frutas, Croissant Jamon y Queso |
| Platos Fuertes | Hamburguesa Clasica, Bandeja Paisa, Salmon a la Plancha |
| Bebidas | Limonada Natural, Cafe Latte, Jugo de Mango |

## 9. Known Issues and Fixes

These are problems encountered during development and deployment, along with their solutions.

### 9.1 npm ci Lock File Mismatch

**Problem:** `npm ci` in Docker failed with "package.json and package-lock.json are in sync" errors because `chokidar` and `readdirp` versions diverged.

**Fix:** Changed `RUN npm ci` to `RUN npm install` in `nginx/Dockerfile`. This is slightly slower but tolerates lock file drift.

### 9.2 Font Inlining Fails in Docker

**Problem:** Angular's production build tries to download Google Fonts from the internet during build to inline them. Inside Docker, DNS resolution fails: `getaddrinfo EAI_AGAIN fonts.googleapis.com`.

**Fix:** Added `ENV NG_BUILD_FONTS_INLINE=false` before the Angular build step in `nginx/Dockerfile`. Fonts are loaded at runtime via the `<link>` tag in `index.html` instead.

### 9.3 Port Conflicts on Windows

**Problem:** Port 80 is often used by Windows IIS/World Wide Web Publishing Service (PID 4). Port 5432 is used by a local PostgreSQL installation.

**Fix:**
- Made `HTTP_PORT` configurable via `.env` (default 80, set to 8080 for local testing).
- Removed the PostgreSQL host port mapping entirely -- the DB only needs to be reachable by the API container on the internal Docker network.

### 9.4 Healthcheck Timeout on First DB Init

**Problem:** The PostgreSQL init script (creating tables + inserting seed data) took ~30 seconds on first startup. The healthcheck was configured with only 5 retries x 5 seconds = 25 seconds, causing the DB to be marked "unhealthy" before it was ready.

**Fix:** Increased healthcheck to `retries: 10` and added `start_period: 30s` in `docker-compose.yml`, giving the DB up to 80 seconds to become healthy on first init.

### 9.5 Angular Component Style Budget Exceeded

**Problem:** Several Angular component SCSS files exceeded the default `anyComponentStyle` budget limits during production builds, causing build errors.

**Fix:** Increased budget limits in both `angular.json` files:
- Customer app: `maximumWarning: 12kB`, `maximumError: 20kB`
- Admin app: `maximumWarning: 16kB`, `maximumError: 24kB`

### 9.6 PowerShell Heredoc Parsing

**Problem:** Multi-line git commit messages using heredoc syntax (`@"..."@`) failed to parse in PowerShell, producing `ParserError`.

**Fix:** Used single-line commit messages instead of heredoc when running git commands from PowerShell.

### 9.7 Admin App Base Href for Nginx

**Problem:** The admin Angular app had `<base href="/">` by default, which caused routing issues when served from `/admin/` by Nginx.

**Fix:** The admin app is built with `--base-href=/admin/` flag in the Nginx Dockerfile.

## 10. Useful URL Templates

Replace the placeholders with your actual values:

```
RESTAURANT_ID = a1b2c3d4-e5f6-7890-abcd-ef1234567890  (or your own)
TABLE_TOKEN   = mesa-1-token-abc123                     (or your own)
HOST          = http://localhost:8080                    (or your domain)
```

| Page | URL |
|------|-----|
| Customer Menu | `{HOST}/menu?restaurantId={RESTAURANT_ID}&table={TABLE_TOKEN}` |
| Checkout | `{HOST}/checkout?restaurantId={RESTAURANT_ID}&table={TABLE_TOKEN}` |
| Order Success | `{HOST}/order-success?orderId={ORDER_ID}` |
| Kitchen Dashboard | `{HOST}/admin/dashboard?restaurantId={RESTAURANT_ID}` |
| Waiter Dashboard | `{HOST}/admin/waiters?restaurantId={RESTAURANT_ID}` |
| Products Management | `{HOST}/admin/products?restaurantId={RESTAURANT_ID}` |
| New Order (Waiter) | `{HOST}/admin/new-order?restaurantId={RESTAURANT_ID}&tableNumber=1` |

## 11. Order Status Flow

```
Customer places order
        |
    [CREATED]
        |
  Kitchen: "Preparar"
        |
  [IN_PROGRESS]
        |
  Kitchen: "Listo"
        |
     [READY]
        |
  Waiter: "Entregado"
        |
  [DELIVERED]
        |
  +-----+-----+
  |             |
Customer       Waiter
requests       quick-collects
payment        (Cobrar)
  |             |
[PAYMENT_PENDING]  -> [PAID]
  |
Waiter: "Cobrado"
  |
[PAID]
```
