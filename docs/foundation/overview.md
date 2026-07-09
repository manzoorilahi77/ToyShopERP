# Foundation — Architecture Overview

Read this before any screen or API doc. It defines the surfaces, the tech stack, the
module map, and the naming conventions the rest of the docs assume.

---

## 1. Product in one paragraph

A small, high-footfall retail shop sells battery-operated toy cars, bikes, ride-ons and
play sets. Products arrive with **no barcodes and no SKUs** — only a supplier name and a
look. Five to six staff bill walk-in customers fast during evening/weekend rushes; the
owner floats the floor approving discounts and watching sales/stock; at GST time the
owner compiles purchase/sales data across possibly multiple GSTINs. The ERP replaces
memory-based operation with a fast, forgiving, offline-first system.

---

## 2. Surfaces & responsibilities

```
                         ┌─────────────────────────────┐
                         │   Node.js / Express API      │
                         │   + MySQL (source of truth)  │
                         │   + object storage (images)  │
                         └──────────────┬──────────────┘
                                        │ single REST API (JSON)
        ┌───────────────────────────────┼───────────────────────────────┐
        │                               │                               │
┌───────▼────────┐             ┌────────▼────────┐             ┌────────▼────────┐
│  STAFF APP     │             │  OWNER APP      │             │  OWNER WEB       │
│  Flutter mobile│             │  Flutter mobile │             │  Flutter Web     │
│  offline-first │             │  lightweight    │             │  GST/ledgers     │
│  camera, BT    │             │  approvals      │             │  desktop, export │
│  printer, Drift│             │  quick reports  │             │  (mostly online) │
└────────────────┘             └─────────────────┘             └──────────────────┘
```

| Surface | Offline? | Local DB | Hardware | Optimized for |
|---|---|---|---|---|
| Staff App | **Yes, offline-first** | Drift (SQLite) | Camera, Bluetooth thermal printer, mic (voice), QR scan | Billing speed, zero data-entry friction |
| Owner App | Mostly online, tolerant | Light cache | Camera/QR (purchase entry) | On-the-go approvals & glanceable KPIs |
| Owner Web | Online | none (session) | — | Bulk work, ledgers, GST export |

---

## 3. Tech stack

**Client (single Flutter codebase, 3 targets)**
- Flutter 3.x, Dart 3.x. Build flavors: `staff`, `owner`, `web`.
- State: Riverpod (or Bloc) — pick one, keep it consistent.
- Local storage (staff): **Drift** (SQLite) for the offline outbox + read cache.
- Connectivity: `connectivity_plus`. Background sync: **WorkManager** (Android).
- Printing: `esc_pos_bluetooth` / `blue_thermal_printer`. QR: `mobile_scanner`.
  Camera: `camera` / `image_picker`. Voice: on-device `speech_to_text`.
- HTTP: `dio` with interceptors (auth, retry, envelope unwrap).

**Backend**
- Node.js + Express.js (TypeScript recommended).
- MySQL 8.x (source of truth). Migrations via Knex/Prisma/Flyway (pick one).
- Auth: JWT access + refresh; staff PIN → short-lived session; device tokens for sync.
- Object storage for product images (S3-compatible). Optional vector store / MySQL
  `VECTOR`/JSON column for image embeddings (see `duplicate-detection.md`).
- Background: a reconciliation job + notification generator (cron/worker).

---

## 4. Shared Flutter package (`packages/shared`)

The three apps share:
- **models/** — Dart data classes mirroring the API schemas (Product, Sale, Purchase, …).
- **api/** — typed API client (dio) with envelope + error handling.
- **sync/** — offline sync manager (outbox, WorkManager scheduler, backoff).
- **duplicate/** — duplicate-detection service (image embed + fuzzy text).
- **design/** — the design system tokens & shared widgets (`design-system.md`).

Screen docs specify UI/UX; the shared package specifies reusable behavior. When a screen
says "calls `POST /sales`", it goes through the shared API client, not raw HTTP.

---

## 5. Module map (docs ↔ code)

| Domain module | Mobile screens | Web screens | API doc |
|---|---|---|---|
| Auth | staff/login, owner/login | web/login | `api/auth` |
| Catalog / Products | staff/product-search-browse, owner/catalog | web/catalog | `api/products`, `api/duplicate-detection` |
| Suppliers | (within purchase) | (within purchase ledger) | `api/suppliers` |
| Purchases | owner/new-purchase | web/purchase-ledger | `api/purchases` |
| Sales | staff/new-sale, staff/receipt, staff/my-sales-history | web/sales-ledger | `api/sales` |
| Stock | (reads across screens) | web/stock-report | `api/stock` |
| GST | owner/gst-registrations | web/gst-filing | `api/gst` |
| Staff / Incentives | staff/dashboard, staff/profile, owner/staff-management | web/staff-performance | `api/staff`, `api/incentives` |
| Sync | (background, all staff screens) | — | `api/sync` |
| Reports / Notifications | owner/dashboard, owner/notifications | web/dashboard | `api/reports-notifications` |

---

## 6. Cross-cutting principles (apply to every screen/endpoint)

1. **Never block the sale.** On the staff app, no network call is on the critical path.
   Write locally, show success, sync in the background. (`sync-and-conflict-resolution.md`)
2. **Confirm visually, type minimally.** Photo/QR/quick-pick first; typing is the last
   resort. A photo+name+price confirmation card precedes every add-to-cart.
3. **Server owns stock truth.** Clients never trust a local counter; stock is recomputed
   from the immutable `stock_movements` event log. (`data-model.md`)
4. **Idempotent writes.** Every offline-generated transaction carries a `client_uuid`;
   the server dedupes replays. (`api-conventions.md`)
5. **Owner-PIN gates cart-level money leaks.** Any cart-level discount requires an owner PIN.
   A per-line price override is the one deliberate exception — staff can enter it unsupervised,
   traded off against rule 6 below (it's flagged and auditable rather than blocked).
6. **Everything is auditable.** Who did what, on which device, when — traceable, including
   staff-entered price overrides (new-sale doc rule 3a).

---

## 7. Environments & config

| Env | API base URL | Notes |
|---|---|---|
| `dev` | `https://dev-api.toyshop.local/v1` | seed data, verbose logs |
| `staging` | `https://staging-api.toyshop.example/v1` | pre-prod, real GST test |
| `prod` | `https://api.toyshop.example/v1` | live |

API version is pinned in the path (`/v1`). See `api-conventions.md` for the envelope,
auth headers, error format, and pagination shared by all endpoints.

## 8. Related docs
- [data-model.md](data-model.md) · [sync-and-conflict-resolution.md](sync-and-conflict-resolution.md)
- [api-conventions.md](api-conventions.md) · [design-system.md](design-system.md) · [duplicate-detection.md](duplicate-detection.md)
