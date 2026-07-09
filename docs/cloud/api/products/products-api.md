# Products / Catalog API

> Base URL, envelope, headers, error codes and pagination live in
> [`api-conventions.md`](../../../foundation/api-conventions.md) — referenced, not repeated.
> Paths are relative to `…/v1`.

---

## 1. Overview

The catalog is the spine of the whole ERP: every sale and purchase line references a
product, and because toys arrive with **no barcodes and no SKUs**, getting the catalog
clean and instantly retrievable is the top data-quality problem
([`requirements_and_prompt.md`](../../../requirements_and_prompt.md) R2/R3).

This module owns product CRUD, image upload (which computes the `image_embedding` used for
duplicate detection), and the self-generated **internal QR** sticker workflow.

| Caller | Uses |
|---|---|
| **Staff App** | `GET /products`, `GET /products/by-qr/{code}`, `GET /products/{id}` for fast retrieval while selling (QR → quick-pick → grid → search). |
| **Owner App / Web** | full CRUD, image upload, QR generation, deactivation, duplicate review. |
| **Sync worker** | replays offline product creates via [`/sync/push`](../sync/sync-api.md); this module holds the direct HTTP surface. |

Duplicate prevention on create is a **separate concern** — this module *triggers* it and
links out to [`duplicate-detection-api`](../duplicate-detection/duplicate-detection-api.md)
and [`duplicate-detection.md`](../../../foundation/duplicate-detection.md); it does not
re-specify the matching algorithm.

## 2. Data model touched

Source of truth: [`data-model.md`](../../../foundation/data-model.md).

| Table | R/W | Notes |
|---|---|---|
| `products` | read/write | the row; `category_id` + `supplier_id` **mandatory** (R2). |
| `product_images` | read/write | gallery; `is_primary` mirrors `products.image_url`. |
| `categories` | read | filter/validate `category_id`. |
| `suppliers` | read | validate `supplier_id`. |
| `stock_movements` | read | on-hand for a product = `SUM(quantity_delta)` (via `v_current_stock`). **Never written here** — only purchases/sales/adjustments write movements. |
| `duplicate_review_queue` | write | ambiguous creates enqueue a review row. |
| `audit_log` | write | `product.create`, `product.update`, `product.deactivate`, `product.qr`. |

`v_current_stock` (derived view) supplies `on_hand`; stock is **read-only** here.

## 3. Auth & permissions

| Endpoint | Auth | Roles | Notes |
|---|---|---|---|
| `GET /products` | Bearer | all | read; heavily used by staff billing |
| `GET /products/{id}` | Bearer | all | |
| `GET /products/by-qr/{code}` | Bearer | all | primary fast-retrieve path |
| `POST /products` | Bearer | `owner`, `accountant`, `staff`\* | \*staff may add during purchase entry per config; triggers duplicate check |
| `PATCH /products/{id}` | Bearer | `owner`, `accountant` | price/attribute edits |
| `POST /products/{id}/deactivate` | Bearer | `owner` | soft-delete |
| `POST /products/{id}/images` | Bearer | `owner`, `accountant`, `staff`\* | multipart upload; recomputes embedding |
| `POST /products/{id}/qr` | Bearer | `owner`, `accountant` | mint `internal_qr_code` + label |

---

## 4. Endpoints

### `GET /products`
- **Purpose** — list/search the catalog with the filters the billing and catalog screens
  need (category grid, color/shelf hints, fuzzy text).
- **Auth** — Bearer, all roles.
- **Idempotency** — N/A (read).
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `category_id` | query | integer | no | — | exact match on `products.category_id` |
| `q` | query | string | no | — | **fuzzy** search on `name` (`FULLTEXT ft_name` + Levenshtein rerank) |
| `color_tag` | query | string | no | — | exact match, `idx_color` |
| `shelf_location` | query | string | no | — | exact/prefix, `idx_shelf` (e.g. `Rack A2`) |
| `supplier_id` | query | integer | no | — | filter by supplier |
| `is_active` | query | boolean | no | `true` | pass `false`/`all` to include deactivated |
| `has_qr` | query | boolean | no | — | filter products with/without `internal_qr_code` (untagged legacy stock) |
| `include_stock` | query | boolean | no | `true` | join `v_current_stock` for `on_hand` |
| `sort` | query | enum | no | `name` | `name\|created_at\|selling_price` |
| `order` | query | enum | no | `asc` | `asc\|desc` |
| `page` / `per_page` | query | integer | no | `1` / `50` | page-based (conventions §7); `cursor` also accepted |

- **Response `200`** — list envelope; each item:

| Field | Type | Notes |
|---|---|---|
| `id` | integer | |
| `name` | string | |
| `category_id` | integer | |
| `supplier_id` | integer | |
| `cost_price` | string(dec) | last purchase cost |
| `selling_price` | string(dec) | |
| `gst_rate` | number | % |
| `hsn_code` | string | |
| `internal_qr_code` | string\|null | null until printed |
| `shelf_location` | string\|null | |
| `color_tag` | string\|null | |
| `image_url` | string\|null | primary photo |
| `on_hand` | integer | from `v_current_stock` (present when `include_stock`) |
| `is_active` | boolean | |

```json
{ "ok": true,
  "data": [
    { "id": 22, "name": "Red Racer Battery Car", "category_id": 1, "supplier_id": 3,
      "cost_price": "820.00", "selling_price": "1499.00", "gst_rate": 18,
      "hsn_code": "9503", "internal_qr_code": "TS-0000022", "shelf_location": "Rack A2",
      "color_tag": "red", "image_url": "https://…/22.jpg", "on_hand": 7,
      "is_active": true }
  ],
  "meta": { "page": 1, "per_page": 50, "total": 214, "cursor": "eyJ…" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | bad `sort`/`order`, non-numeric ids |
| 401 | `UNAUTHENTICATED` | no token |

---

### `GET /products/{id}`
- **Purpose** — full product detail incl. image gallery + current stock.
- **Auth** — Bearer, all roles. **Idempotency** — N/A.
- **Path params** — `id` (integer, required).
- **Response `200`** — all `products` columns + `on_hand` + `images[]`:

| Field | Type | Notes |
|---|---|---|
| …all list fields… | | |
| `reorder_threshold` | integer | low-stock trigger |
| `aging_threshold_days` | integer\|null | per-product override |
| `on_hand` | integer | derived |
| `images` | array | `[{ id, url, is_primary, sort_order }]` |
| `created_at` / `updated_at` | string(ISO) | |

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 404 | `NOT_FOUND` | no such product |

---

### `GET /products/by-qr/{code}`
- **Purpose** — resolve a scanned internal sticker to a product in **one step** — the
  fastest retrieval path while selling (R3 primary).
- **Auth** — Bearer, all roles. **Idempotency** — N/A.
- **Path params** — `code` (string, required) = `products.internal_qr_code` (UNIQUE).
- **Response `200`** — same shape as `GET /products/{id}` (single object) incl. `on_hand`,
  so the staff app can render the `ItemConfirmCard` immediately.

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 404 | `NOT_FOUND` | code not found (unprinted/foreign sticker) |
| 422 | `BUSINESS_RULE` | product resolved but `is_active=0` (reactivate prompt) |

```bash
curl …/v1/products/by-qr/TS-0000022 -H 'Authorization: Bearer …'
```

---

### `POST /products`
- **Purpose** — create a new product; **triggers duplicate detection** before/at save.
- **Auth** — Bearer; `owner`/`accountant` (and `staff` during purchase entry per config).
- **Idempotency** — `Idempotency-Key` = `client_uuid` (offline creates replay-safe;
  conventions §6). Repeat key → returns the original product, no duplicate row.
- **Request body**

| Field | Type | Required | Validation | Notes |
|---|---|---|---|---|
| `client_uuid` | string(uuid) | yes\* | UNIQUE | \*required for offline-originated creates |
| `name` | string | yes | 1–150 | supplier-given name |
| `category_id` | integer | **yes** | exists, active | **mandatory** (R2 scoping) |
| `supplier_id` | integer | **yes** | exists, active | **mandatory** (R2 scoping) |
| `selling_price` | string(dec) | yes | ≥ 0 | |
| `cost_price` | string(dec) | no | ≥ 0 | usually set by first purchase |
| `gst_rate` | number | no | one of `0,5,12,18,28` | default `18.00` |
| `hsn_code` | string | no | ≤ 10 | GST |
| `shelf_location` | string | no | ≤ 20 | R3 |
| `color_tag` | string | no | ≤ 20 | R3 |
| `reorder_threshold` | integer | no | ≥ 0 | default `3` |
| `image_embedding` | array<float>\|null | no | 256–512 dims | if computed on-device; else set later on image upload |
| `duplicate_ack` | object | no | `{ matched_product_id, decision }` | client's answer to the "same item?" prompt: `new` \| `same` |

- **Duplicate flow (summary — full spec in [duplicate-detection-api](../duplicate-detection/duplicate-detection-api.md)):**
  - If `duplicate_ack` is absent, the server runs image+text matching. A **strong single
    match** → responds `409 CONFLICT` (`error.code=DUPLICATE_CANDIDATE`) with candidates so
    the client can prompt "same item?" and resubmit with `duplicate_ack`.
  - `duplicate_ack.decision = "same"` → **no new product**; server routes to the existing
    product (add-stock/price-correct path) and returns that product.
  - `duplicate_ack.decision = "new"` → creates the product and records `confirmed_unique`.
  - **Ambiguous/multiple** matches → create provisionally **and** enqueue
    `duplicate_review_queue(status='pending')` for the web review queue.

- **Response `201`** — the created (or resolved-existing) product object (as
  `GET /products/{id}`), plus:

| Field | Type | Notes |
|---|---|---|
| `created` | boolean | `false` when an existing product was reused (`decision=same`) |
| `review_enqueued` | boolean | true if a `duplicate_review_queue` row was created |

```json
{ "ok": true,
  "data": { "id": 231, "name": "Blue Speedster Bike", "category_id": 2, "supplier_id": 3,
            "selling_price": "1799.00", "gst_rate": 18, "internal_qr_code": null,
            "image_url": null, "is_active": true, "created": true,
            "review_enqueued": false },
  "meta": { "request_id": "req_…" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | missing `name`/`category_id`/`supplier_id`/`selling_price` |
| 401 | `UNAUTHENTICATED` | no token |
| 403 | `FORBIDDEN` | role not allowed |
| 404 | `NOT_FOUND` | `category_id`/`supplier_id` do not exist |
| 409 | `DUPLICATE_CANDIDATE` | strong match found, awaiting `duplicate_ack` (payload carries candidates) |
| 409 | `DUPLICATE_IGNORED` | same `Idempotency-Key`/`client_uuid` already applied → returns original |
| 422 | `BUSINESS_RULE` | inactive category/supplier |

---

### `PATCH /products/{id}`
- **Purpose** — edit price, HSN, thresholds, shelf/color, name. **Last-write-wins** on
  attributes (sync doc §5).
- **Auth** — Bearer; `owner`/`accountant`.
- **Idempotency** — natural (partial update); optional `If-Unmodified-Since`/`updated_at`
  for optimistic concurrency.
- **Path params** — `id` (integer, required).
- **Request body** — any subset of: `name`, `category_id`, `supplier_id`, `cost_price`,
  `selling_price`, `gst_rate`, `hsn_code`, `shelf_location`, `color_tag`,
  `reorder_threshold`, `aging_threshold_days`. Same validation as create.
- **Response `200`** — updated product object.
- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | invalid field values |
| 404 | `NOT_FOUND` | no such product |
| 409 | `CONFLICT` | optimistic-concurrency `updated_at` mismatch |

Writes `audit_log` (`product.update`, before/after JSON). **Does not** change stock —
price edits never write `stock_movements`.

---

### `POST /products/{id}/deactivate`
- **Purpose** — soft-delete (`is_active=0`); keeps ledger/audit intact (design rule).
- **Auth** — Bearer; `owner` only.
- **Idempotency** — safe to repeat (already inactive → `200`).
- **Request body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `reason` | string | no | stored in `audit_log.after_json` |

- **Response `200`** — `{ "id": 22, "is_active": false }`.
- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 404 | `NOT_FOUND` | no such product |
| 422 | `BUSINESS_RULE` | (advisory) product still has positive `on_hand` — response includes `warnings:["has_stock"]` but still deactivates |

A deactivated product can still be **auto-reactivated** if an offline sale referencing it
arrives (sync doc decision table) — the sale wins because the goods physically left.

---

### `POST /products/{id}/images`
- **Purpose** — upload a product photo; sets/updates `image_url` + a `product_images` row,
  and **(re)computes `products.image_embedding`** for duplicate detection.
- **Auth** — Bearer; `owner`/`accountant`/`staff`.
- **Idempotency** — N/A (each upload is a new asset); client may send `client_uuid` to
  dedupe accidental double-taps.
- **Request** — `multipart/form-data`:

| Part | Type | Required | Validation | Notes |
|---|---|---|---|---|
| `file` | binary | yes | jpeg/png/webp, ≤ 8 MB, size/virus-checked | object storage upload |
| `is_primary` | boolean | no | default: `true` if product has no image yet | primary mirrors `products.image_url` |
| `sort_order` | integer | no | | gallery ordering |

- **Response `201`**

| Field | Type | Notes |
|---|---|---|
| `image` | object | `{ id, url, is_primary, sort_order }` |
| `product` | object | `{ id, image_url }` updated primary |
| `embedding_computed` | boolean | true once the vector is stored (may be async) |

```json
{ "ok": true,
  "data": { "image": { "id": 88, "url": "https://…/231-a.jpg", "is_primary": true,
                       "sort_order": 0 },
            "product": { "id": 231, "image_url": "https://…/231-a.jpg" },
            "embedding_computed": true },
  "meta": { "request_id": "req_…" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | no file / unsupported type |
| 404 | `NOT_FOUND` | no such product |
| 413 | `VALIDATION_ERROR` | file too large |
| 422 | `BUSINESS_RULE` | file failed virus/size scan |

> **Embedding note:** the embedding is computed from the **primary** image. If the primary
> changes (new `is_primary=true` upload), the embedding is recomputed
> ([duplicate-detection.md](../../../foundation/duplicate-detection.md) §3). Computation may
> be async: `embedding_computed=false` means it is queued.

---

### `POST /products/{id}/qr`
- **Purpose** — generate the self-printed **internal QR sticker** — mint
  `internal_qr_code` and return a printable label (R3 primary long-term retrieval).
- **Auth** — Bearer; `owner`/`accountant`.
- **Idempotency** — if the product already has an `internal_qr_code`, returns the existing
  one unless `regenerate=true`.
- **Path params** — `id` (integer, required).
- **Request body**

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `regenerate` | boolean | no | `false` | mint a new code even if one exists (old code invalidated) |
| `label_format` | enum | no | `png` | `png\|pdf\|zpl` — thermal label render for `blue_thermal_printer` |

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `internal_qr_code` | string | e.g. `TS-0000022` (UNIQUE) |
| `qr_payload` | string | what the QR encodes (the code itself; scanned by `GET /products/by-qr/{code}`) |
| `label_url` | string | rendered label asset (photo + name + price + QR) |
| `label_format` | enum | echoed |

```json
{ "ok": true,
  "data": { "internal_qr_code": "TS-0000022", "qr_payload": "TS-0000022",
            "label_url": "https://…/labels/22.png", "label_format": "png" },
  "meta": { "request_id": "req_…" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 404 | `NOT_FOUND` | no such product |
| 409 | `CONFLICT` | code already exists and `regenerate=false` (returns existing in body) |

Writes `audit_log` (`product.qr`). Code format is server-controlled and globally unique
(satisfies `uq_qr`).

---

## 5. Business logic & validation
- **Mandatory scoping** — `category_id` and `supplier_id` are enforced NOT NULL at create;
  this both matches the schema and narrows the duplicate-search space (R2 Layer 3).
- **`gst_rate` snapshotting** — the product carries the *current* rate; sale/purchase lines
  snapshot it at transaction time (see [sales](../sales/sales-api.md) /
  [purchases](../purchases/purchases-api.md)), so later rate edits don't rewrite history.
- **`cost_price` provenance** — set by the latest confirmed purchase
  ([purchases-api](../purchases/purchases-api.md) updates `products.cost_price`); manual
  `PATCH` is allowed but audited.
- **Primary image invariant** — at most one `product_images.is_primary=1`; setting a new
  primary clears the old and updates `products.image_url` in the same transaction, then
  queues embedding recompute.
- **QR minting** — server generates a collision-checked code against `uq_qr`; regeneration
  invalidates the previous code (old stickers stop resolving → `404`).
- **Stock is read-only here** — `on_hand` comes from `v_current_stock`; no product endpoint
  writes `stock_movements`.

## 6. Sync & conflict handling
- **Create** carries `client_uuid`/`Idempotency-Key`; replays return the original product
  (`DUPLICATE_IGNORED`). This is what lets the offline outbox push a "create product" item
  before the "sell it" item (FIFO) safely.
- **Attribute edits** resolve **last-write-wins** by `updated_at`
  ([sync doc §5](../../../foundation/sync-and-conflict-resolution.md)); deltas (stock) never
  conflict because products don't own stock.
- **Offline duplicate check** runs on-device against the cached catalog; a **server-side
  re-check** on sync can still enqueue `duplicate_review_queue`.
- **Ordering dependency** — a sale referencing a not-yet-synced product yields `409 CONFLICT`
  at [`/sales`](../sales/sales-api.md); the worker pushes the product create first, then
  retries (sync doc decision table).

## 7. Edge cases & failure modes
1. **Two look-alike but genuinely different toys** → review queue; once resolved
   `confirmed_unique`, that pair stops prompting (dup doc §6).
2. **Untagged legacy stock** (`internal_qr_code` null) → still fully sellable via photo/grid;
   `GET /products?has_qr=false` drives a "print a QR" nudge.
3. **QR regenerated while old stickers still on shelves** → old code `404`s on scan;
   staff falls back to photo/search, then reprints.
4. **Image embedding backend down** → upload still succeeds; `embedding_computed=false`,
   embedding queued; duplicate check degrades to **text-only** until it catches up.
5. **Deactivate a product with stock** → allowed with `warnings:["has_stock"]`; the on-hand
   remains visible in stock reports for audit.
6. **Concurrent price edits from owner app + web** → LWW by `updated_at`; the loser's change
   is overwritten (audited), never silently merged.
7. **`selling_price` below `cost_price`** → accepted (clearance), but flagged in the profit
   leaderboard; not a hard error.

## 8. Performance & indexing
- **Hot query:** `GET /products?category_id=…` and `GET /products/by-qr/{code}` on the
  billing critical path — must be fast. Relies on `idx_cat`, `uq_qr`, and
  `include_stock` joining the `v_current_stock` view (or a materialized stock cache at
  scale).
- **Fuzzy `q`:** `FULLTEXT ft_name` pre-filters, then app-side Levenshtein reranks the small
  candidate set — avoids full scans (dup doc §3).
- Other indexes: `idx_supplier`, `idx_color`, `idx_shelf`, `idx_active`.
- Catalog is small (< ~10k SKUs) so brute-force embedding similarity is acceptable; ANN only
  needed above that (dup doc §3).
- Staff apps **cache** the catalog locally (Drift) and mostly read from cache; server list
  calls are periodic pulls, so they tolerate cursor pagination.

## 9. Related docs
- Screens: [staff/product-search-browse](../../../mobile/staff/catalog/product-search-browse.md) ·
  [staff/new-sale](../../../mobile/staff/sales/new-sale.md) ·
  [owner/catalog](../../../mobile/owner/catalog/product-catalog-management.md) ·
  [web/catalog](../../web/catalog/product-catalog-management.md)
- Sibling APIs: [duplicate-detection-api](../duplicate-detection/duplicate-detection-api.md) ·
  [suppliers-api](../suppliers/suppliers-api.md) ·
  [purchases-api](../purchases/purchases-api.md) ·
  [sales-api](../sales/sales-api.md) · [stock-api](../stock/stock-api.md)
- Foundation: [duplicate-detection](../../../foundation/duplicate-detection.md) ·
  [data-model](../../../foundation/data-model.md) ·
  [api-conventions](../../../foundation/api-conventions.md)
