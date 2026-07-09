# Foundation — Data Model (MySQL)

Canonical schema for the ToyShop ERP. **This is the single source of truth for table and
column names.** Screen and API docs reference these names; they do not redefine them.

Design rules:
- MySQL 8.x, InnoDB, `utf8mb4`. All money in **`DECIMAL(12,2)` rupees** (never floats).
- Every table has `id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY`, `created_at`,
  `updated_at` (`TIMESTAMP DEFAULT CURRENT_TIMESTAMP [ON UPDATE ...]`).
- **Stock is never stored as a mutable counter.** It is derived from the immutable
  `stock_movements` event log — see [sync-and-conflict-resolution.md](sync-and-conflict-resolution.md).
- Soft-delete via `is_active`/`status`, not row deletion, so ledgers/audit stay intact.
- Offline-generated rows carry `client_uuid` (UNIQUE) + `device_id` for idempotent sync.

---

## 1. Entity-relationship map

```
gst_registrations ─┐
                    ├─< purchases >─── purchase_items >── products ──< product_images
suppliers ─────────┘                                        │  ▲
                    ┌──────────────< sales >── sale_items ───┘  │
staff ──────────────┤          │                                └── categories (self-ref)
  │                 │          └── discount_approvals
  ├─< staff_badges >── badges                          products ──< stock_movements >── (sale/purchase/adjust)
  ├─< staff_incentive_progress >── incentive_rules
  └─< devices
duplicate_review_queue >── products (new + matched)
sync_log     notifications     audit_log     app_settings
```

---

## 2. Reference / configuration tables

### `gst_registrations`
Multiple GSTINs the shop may operate under.

| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| gstin | CHAR(15) UNIQUE | validated format `22AAAAA0000A1Z5` |
| legal_name | VARCHAR(150) | |
| trade_name | VARCHAR(150) | nullable |
| address | VARCHAR(255) | |
| state_code | CHAR(2) | first 2 digits of GSTIN; drives IGST vs CGST/SGST |
| is_active | TINYINT(1) DEFAULT 1 | inactive = not selectable for new txns |
| created_at / updated_at | TIMESTAMP | |

### `suppliers`
| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| name | VARCHAR(150) NOT NULL | |
| gstin | CHAR(15) | nullable — **missing → ITC-risk flag** in reconciliation |
| phone | VARCHAR(20) | |
| address | VARCHAR(255) | |
| is_active | TINYINT(1) DEFAULT 1 | |
| created_at / updated_at | | |

Index: `KEY idx_supplier_name (name)`.

### `categories`
Visual grid browsing depends on these. Self-referencing for optional sub-categories.

| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| name | VARCHAR(80) NOT NULL | "Battery Cars", "Ride-on Bikes", "Play Sets" |
| parent_id | BIGINT UN NULL | FK → categories.id |
| icon | VARCHAR(60) | icon key for the grid |
| image_url | VARCHAR(255) | optional tile image |
| color_hex | CHAR(7) | tile accent |
| sort_order | INT DEFAULT 0 | |
| is_active | TINYINT(1) DEFAULT 1 | |

### `app_settings`
Owner-configurable thresholds (aging days, low-stock defaults, similarity threshold).

| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| `key` | VARCHAR(80) UNIQUE | e.g. `aging_threshold_days`, `dup_similarity_threshold` |
| value | VARCHAR(255) | stored as string; typed in app |
| updated_by | BIGINT UN | FK → staff.id (owner) |
| updated_at | TIMESTAMP | |

---

## 3. Catalog tables

### `products`
The heart of duplicate-detection and retrieval.

| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| name | VARCHAR(150) NOT NULL | supplier-given name |
| category_id | BIGINT UN NOT NULL | FK → categories.id (**mandatory** — R2) |
| supplier_id | BIGINT UN NOT NULL | FK → suppliers.id (**mandatory** — R2) |
| cost_price | DECIMAL(12,2) | latest/last purchase cost |
| selling_price | DECIMAL(12,2) NOT NULL | |
| gst_rate | DECIMAL(5,2) DEFAULT 18.00 | % (0/5/12/18/28) |
| hsn_code | VARCHAR(10) | for GST |
| internal_qr_code | VARCHAR(40) UNIQUE | **self-generated** sticker code (R3), nullable until printed |
| shelf_location | VARCHAR(20) | e.g. "Rack A2" (R3) |
| color_tag | VARCHAR(20) | dominant color (R3) |
| image_url | VARCHAR(255) | primary photo |
| image_embedding | JSON / VECTOR | embedding vector for similarity (R2) |
| reorder_threshold | INT DEFAULT 3 | low-stock trigger |
| aging_threshold_days | INT NULL | per-product override of global aging days |
| is_active | TINYINT(1) DEFAULT 1 | deactivate instead of delete |
| created_at / updated_at | | |

Indexes: `UNIQUE uq_qr (internal_qr_code)`, `KEY idx_cat (category_id)`,
`KEY idx_supplier (supplier_id)`, `FULLTEXT ft_name (name)` for fuzzy search,
`KEY idx_color (color_tag)`, `KEY idx_shelf (shelf_location)`, `KEY idx_active (is_active)`.

> **Naming note:** the brief calls this `image_embedding_vector`. We store it as
> `image_embedding` (JSON array of floats, or a MySQL 8 `VECTOR` column if available).
> See [duplicate-detection.md](duplicate-detection.md).

### `product_images`
| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| product_id | BIGINT UN NOT NULL | FK → products.id |
| url | VARCHAR(255) NOT NULL | |
| is_primary | TINYINT(1) DEFAULT 0 | one primary per product |
| sort_order | INT DEFAULT 0 | |

---

## 4. People & devices

### `staff`
| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| name | VARCHAR(100) NOT NULL | |
| photo_url | VARCHAR(255) | shown on login & profile |
| pin_hash | CHAR(60) NOT NULL | bcrypt of 4–6 digit PIN |
| role | ENUM('staff','owner','accountant') DEFAULT 'staff' | |
| join_date | DATE | |
| total_lifetime_sales | DECIMAL(14,2) DEFAULT 0 | denormalized cache (recomputed nightly) |
| current_month_points | INT DEFAULT 0 | leaderboard points (denormalized) |
| badges_earned | JSON | array of badge codes (mirror of `staff_badges`) |
| is_active | TINYINT(1) DEFAULT 1 | |
| created_at / updated_at | | |

> Denormalized fields (`total_lifetime_sales`, `current_month_points`, `badges_earned`)
> are **caches** for fast dashboard reads; the authoritative values come from `sales`,
> `staff_incentive_progress` and `staff_badges`. A nightly job reconciles them.

### `devices`
| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| device_id | VARCHAR(64) UNIQUE | client-generated stable UUID |
| staff_id | BIGINT UN | last logged-in staff |
| platform | ENUM('android','ios','web') | |
| app_flavor | ENUM('staff','owner','web') | |
| last_seen | TIMESTAMP | |
| push_token | VARCHAR(255) | FCM/APNs |

---

## 5. Transactions

### `purchases`
| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| client_uuid | CHAR(36) UNIQUE | idempotency key |
| supplier_id | BIGINT UN NOT NULL | FK |
| gstin_id | BIGINT UN NOT NULL | FK → gst_registrations (which registration) |
| supplier_gstin | CHAR(15) NULL | copy for ITC; null → reconciliation flag |
| invoice_no | VARCHAR(40) | supplier's invoice number |
| invoice_date | DATE | |
| subtotal | DECIMAL(12,2) | |
| total_gst | DECIMAL(12,2) | input tax credit total |
| total_cost | DECIMAL(12,2) | subtotal + gst |
| status | ENUM('draft','confirmed','void') DEFAULT 'confirmed' | |
| created_by | BIGINT UN | FK → staff.id |
| device_id | VARCHAR(64) | |
| sync_status | ENUM('pending','syncing','synced','failed') DEFAULT 'synced' | |
| created_at / updated_at | | |

### `purchase_items`
| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| purchase_id | BIGINT UN NOT NULL | FK |
| product_id | BIGINT UN NOT NULL | FK |
| quantity | INT NOT NULL | > 0 |
| cost_price | DECIMAL(12,2) NOT NULL | per unit |
| gst_rate | DECIMAL(5,2) | snapshot at purchase time |
| gst_amount | DECIMAL(12,2) | |
| line_total | DECIMAL(12,2) | qty × cost + gst |

### `sales`
| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| client_uuid | CHAR(36) UNIQUE | **idempotency key** for offline replay |
| invoice_no | VARCHAR(40) | server-assigned on sync (per GSTIN sequence) |
| staff_id | BIGINT UN NOT NULL | who sold (leaderboard, audit) |
| gstin_id | BIGINT UN NOT NULL | which registration the sale is under |
| subtotal | DECIMAL(12,2) NOT NULL | pre-discount, pre-tax or tax-inclusive per config |
| discount_amount | DECIMAL(12,2) DEFAULT 0 | |
| discount_approved_by | BIGINT UN NULL | FK → staff.id (owner) — `🔒` |
| tax_amount | DECIMAL(12,2) | output GST |
| total | DECIMAL(12,2) NOT NULL | payable |
| payment_mode | ENUM('cash','upi','card') NOT NULL | (R: sales.add payment_mode) |
| sync_status | ENUM('pending','syncing','synced','failed') DEFAULT 'pending' | |
| device_id | VARCHAR(64) | (R: trace offline device) |
| sold_at | DATETIME NOT NULL | client timestamp of sale (business time) |
| created_at / updated_at | | server receipt time |

Indexes: `UNIQUE uq_sale_uuid (client_uuid)`, `KEY idx_staff_date (staff_id, sold_at)`,
`KEY idx_gstin_date (gstin_id, sold_at)`, `KEY idx_sync (sync_status)`.

### `sale_items`
| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| sale_id | BIGINT UN NOT NULL | FK |
| product_id | BIGINT UN NOT NULL | FK |
| quantity | INT NOT NULL | > 0 |
| unit_price | DECIMAL(12,2) NOT NULL | snapshot of selling_price at sale time |
| gst_rate | DECIMAL(5,2) | snapshot |
| gst_amount | DECIMAL(12,2) | |
| line_total | DECIMAL(12,2) | |

### `discount_approvals`
Tracks the owner-PIN discount flow (staff requests, owner approves).

| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| sale_client_uuid | CHAR(36) | links to the pending sale (may not be saved yet) |
| staff_id | BIGINT UN | requester |
| requested_amount | DECIMAL(12,2) | or percent — see api |
| reason | VARCHAR(255) | optional |
| status | ENUM('pending','approved','rejected') DEFAULT 'pending' | |
| approved_by | BIGINT UN NULL | owner staff id |
| pin_verified | TINYINT(1) DEFAULT 0 | |
| decided_at | DATETIME NULL | |
| created_at | | |

---

## 6. Stock event log (source of truth)

### `stock_movements`
**Immutable, append-only.** Current stock = `SUM(quantity_delta)` per product.

| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| product_id | BIGINT UN NOT NULL | FK |
| movement_type | ENUM('purchase_in','sale_out','adjustment','return_in','void_reversal') | |
| quantity_delta | INT NOT NULL | **+in / −out** (e.g. sale = −qty) |
| ref_type | ENUM('purchase','sale','manual') | |
| ref_id | BIGINT UN NULL | purchase_id / sale_id |
| ref_client_uuid | CHAR(36) NULL | ties to offline txn before server id exists |
| staff_id | BIGINT UN | who caused it |
| device_id | VARCHAR(64) | |
| note | VARCHAR(255) | for manual adjustments |
| occurred_at | DATETIME NOT NULL | business time |
| created_at | | server time |

Indexes: `KEY idx_product (product_id)`, `KEY idx_ref (ref_type, ref_id)`,
`KEY idx_occurred (occurred_at)`. Current stock is served via a view/materialized cache:

```sql
CREATE VIEW v_current_stock AS
SELECT p.id AS product_id,
       COALESCE(SUM(sm.quantity_delta), 0) AS on_hand
FROM products p
LEFT JOIN stock_movements sm ON sm.product_id = p.id
GROUP BY p.id;
```
> Reconciliation (last-write-wins + recompute from log) is in
> [sync-and-conflict-resolution.md](sync-and-conflict-resolution.md).

---

## 7. Incentives & gamification

### `incentive_rules`
| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| rule_type | ENUM('per_unit_bonus','monthly_target','revenue_tier') | |
| target_value | DECIMAL(12,2) | e.g. 500 units, or ₹ threshold |
| reward_description | VARCHAR(255) | shown to staff |
| reward_value | DECIMAL(12,2) NULL | optional cash value |
| active_from | DATE | |
| active_to | DATE NULL | |
| is_active | TINYINT(1) DEFAULT 1 | |

### `staff_incentive_progress`
| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| staff_id | BIGINT UN | FK |
| rule_id | BIGINT UN | FK |
| period | CHAR(7) | `YYYY-MM` |
| current_value | DECIMAL(12,2) DEFAULT 0 | progress toward target |
| tier_reached | INT DEFAULT 0 | |
| updated_at | | |
| | | UNIQUE `(staff_id, rule_id, period)` |

### `badges` / `staff_badges`
| `badges` | Type | | `staff_badges` | Type |
|---|---|---|---|---|
| id | BIGINT UN PK | | id | BIGINT UN PK |
| code | VARCHAR(40) UNIQUE | | staff_id | BIGINT UN FK |
| name | VARCHAR(80) | | badge_id | BIGINT UN FK |
| description | VARCHAR(255) | | earned_at | DATETIME |
| criteria_json | JSON | | period | CHAR(7) nullable |
| icon | VARCHAR(60) | | | UNIQUE `(staff_id, badge_id, period)` |

---

## 8. Duplicate detection, sync & ops

### `duplicate_review_queue`
| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| new_product_id | BIGINT UN | FK → products (candidate) |
| matched_existing_product_id | BIGINT UN | FK → products (suspected original) |
| similarity_score | DECIMAL(5,4) | 0–1 |
| match_type | ENUM('image','text','both') | |
| status | ENUM('pending','confirmed_duplicate','confirmed_unique') DEFAULT 'pending' | |
| reviewed_by | BIGINT UN NULL | |
| reviewed_at | DATETIME NULL | |
| created_at | | |

### `sync_log`
| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| transaction_type | ENUM('sale','purchase','stock_adjustment','product') | |
| transaction_id | BIGINT UN NULL | server id once known |
| client_uuid | CHAR(36) | |
| device_id | VARCHAR(64) | |
| status | ENUM('received','applied','duplicate_ignored','failed') | |
| error_message | VARCHAR(255) NULL | |
| retry_count | INT DEFAULT 0 | |
| synced_at | DATETIME | |

### `notifications`
| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| type | ENUM('low_stock','aging_stock','sync_failure','discount_request','incentive','system') | |
| title | VARCHAR(120) | |
| body | VARCHAR(255) | |
| target_role | ENUM('owner','staff','all') | |
| target_staff_id | BIGINT UN NULL | for personal notifications |
| ref_type | VARCHAR(30) | e.g. 'product','sale' |
| ref_id | BIGINT UN NULL | |
| is_read | TINYINT(1) DEFAULT 0 | |
| created_at | | |

### `audit_log`
| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| actor_staff_id | BIGINT UN | |
| action | VARCHAR(60) | e.g. `product.deactivate`, `discount.approve` |
| entity_type | VARCHAR(40) | |
| entity_id | BIGINT UN | |
| before_json / after_json | JSON | |
| device_id | VARCHAR(64) | |
| created_at | | |

---

## 9. Migrations plan (order matters — FKs)

```
0001_create_reference        gst_registrations, suppliers, categories, app_settings
0002_create_people           staff, devices
0003_create_catalog          products, product_images
0004_create_stock            stock_movements (+ v_current_stock view)
0005_create_purchases        purchases, purchase_items
0006_create_sales            sales, sale_items, discount_approvals
0007_create_incentives       incentive_rules, staff_incentive_progress, badges, staff_badges
0008_create_ops              duplicate_review_queue, sync_log, notifications, audit_log
0009_seed                    categories, badges, default app_settings, a demo GSTIN
```

Each migration is reversible (`up`/`down`). Money columns `DECIMAL`, never `FLOAT`.
`client_uuid` UNIQUE constraints are what make offline replay safe — do not drop them.

---

## 10. Schema addendum v1.1 — ratified additions

These were surfaced while authoring the screen/API docs and are **now canonical**. Child
docs that say "Proposed schema addition" refer to items in this list; treat them as
accepted. Ship as migrations `0010`–`0013` (below). Rationale is in the linked docs.

### 10.1 New columns on existing tables

| Table | Column | Type | Why | Source doc |
|---|---|---|---|---|
| `staff` | `email` | VARCHAR(150) UNIQUE NULL | owner/accountant credential login (email+password) — `staff` had only `pin_hash` | [api/auth](../cloud/api/auth/auth-api.md), [web/login](../cloud/web/auth/login.md) |
| `staff` | `password_hash` | CHAR(60) NULL | bcrypt for credential login | same |
| `staff` | `failed_pin_attempts` | INT DEFAULT 0 | login lockout | [api/auth](../cloud/api/auth/auth-api.md) |
| `staff` | `locked_until` | DATETIME NULL | login lockout window | same |
| `staff` | `last_login_at` | DATETIME NULL | audit / session UX | [web/login](../cloud/web/auth/login.md) |
| `sales` | `place_of_supply_state_code` | CHAR(2) NULL | IGST vs CGST/SGST determination; default = registration `state_code` (intra-state B2C) | [api/gst](../cloud/api/gst/gst-api.md), [web/gst-filing](../cloud/web/gst/gst-filing.md) |
| `sales` | `customer_gstin` | CHAR(15) NULL | B2B GSTR-1 line split (optional) | [web/gst-filing](../cloud/web/gst/gst-filing.md) |
| `sales` | `status` | ENUM('completed','void') DEFAULT 'completed' | void/return trail (mirrors `purchases.status`) | [web/sales-ledger](../cloud/web/sales/sales-ledger.md) |
| `purchases` | `voided_by` / `voided_at` / `void_reason` | BIGINT UN / DATETIME / VARCHAR(255), all NULL | first-class void trail | [api/purchases](../cloud/api/purchases/purchases-api.md) |
| `discount_approvals` | `discount_type` | ENUM('amount','percent') DEFAULT 'amount' | staff can request % or ₹ | [new-sale](../mobile/staff/sales/new-sale.md), [discount-approval](../mobile/owner/approvals/discount-approval.md) |
| `discount_approvals` | `requested_percent` | DECIMAL(5,2) NULL | the % when `discount_type='percent'` | same |
| `discount_approvals` | `cart_total` | DECIMAL(12,2) NULL | so the owner sees context when approving | [discount-approval](../mobile/owner/approvals/discount-approval.md) |
| `discount_approvals` | `cart_summary_json` | JSON NULL | product line summary shown at approval | same |
| `incentive_rules` | `metric` | ENUM('units','revenue') DEFAULT 'units' | `monthly_target` can be unit- or ₹-based | [api/incentives](../cloud/api/incentives/incentives-api.md) |
| `products` | `clearance_flag` | TINYINT(1) DEFAULT 0 | "push for clearance" on aging stock | [web/stock-report](../cloud/web/stock/stock-report.md) |
| `products` | `clearance_since` | DATE NULL | when clearance was flagged | same |
| `suppliers` | `client_uuid` | CHAR(36) UNIQUE NULL | **only if** offline inline supplier creation is required (else create online first) | [api/suppliers](../cloud/api/suppliers/suppliers-api.md) |

### 10.2 ENUM value additions

| Table.column | Add value | Why |
|---|---|---|
| `notifications.type` | `'oversold'` | the sync doc emits `type='oversold'`; ENUM lacked it | 
| `stock_movements.movement_type` | (already has `void_reversal`) | used by purchase/sale void |

### 10.3 New tables

**`staff_favorites`** — R3 "favorites per staff" (personal quick-access row). No prior home.
| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| staff_id | BIGINT UN NOT NULL | FK → staff.id |
| product_id | BIGINT UN NOT NULL | FK → products.id |
| sort_order | INT DEFAULT 0 | |
| created_at | TIMESTAMP | |
| | | UNIQUE `(staff_id, product_id)` |
> API: `GET/POST/DELETE /staff/{id}/favorites`. Consumed by [staff/dashboard](../mobile/staff/dashboard/dashboard-home.md), [new-sale](../mobile/staff/sales/new-sale.md), [product-search-browse](../mobile/staff/catalog/product-search-browse.md), [profile](../mobile/staff/profile/profile.md).

**`invoice_sequences`** — gapless per-GSTIN, per-financial-year invoice numbers under concurrency.
| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| gstin_id | BIGINT UN NOT NULL | FK → gst_registrations.id |
| fy | CHAR(7) NOT NULL | e.g. `26-27` |
| last_seq | BIGINT UN DEFAULT 0 | incremented atomically on sale apply |
| | | UNIQUE `(gstin_id, fy)` |
> Used by [api/sales](../cloud/api/sales/sales-api.md) invoice numbering (`SELECT … FOR UPDATE`).

**`refresh_tokens`** — server-side JWT refresh so tokens can be rotated/revoked.
| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| staff_id | BIGINT UN NOT NULL | FK |
| token_hash | CHAR(64) NOT NULL | store hash, never raw |
| device_id | VARCHAR(64) | |
| expires_at | DATETIME NOT NULL | |
| revoked_at | DATETIME NULL | |
| created_at | TIMESTAMP | |

**`password_reset_tokens`** — forgot-password for web credential login.
| Column | Type | Notes |
|---|---|---|
| id | BIGINT UN PK | |
| staff_id | BIGINT UN NOT NULL | FK |
| token_hash | CHAR(64) NOT NULL | |
| expires_at | DATETIME NOT NULL | short-lived |
| used_at | DATETIME NULL | single-use |

**`change_feed`** *(optional)* — monotonic, resumable cursor for `GET /sync/pull` (avoids
`updated_at`+`id` tie issues). `id, entity_type, entity_id, op, created_at`. Build only if
`updated_at` cursors prove insufficient at scale. See [api/sync](../cloud/api/sync/sync-api.md).

### 10.4 New `app_settings` keys

| key | Purpose |
|---|---|
| `default_reorder_threshold` | fallback low-stock threshold when product has none |
| `dup_text_ratio` | fuzzy-text duplicate threshold (image threshold is `dup_similarity_threshold`) |
| `backup_frequency` / `backup_time` / `backup_retention_days` / `backup_target` / `last_backup_at` | backup config ([web/settings](../cloud/web/settings/settings.md), [api/settings](../cloud/api/settings/settings-api.md)) |

### 10.5 New indexes & constraints

| On | Definition | Why |
|---|---|---|
| `purchases` | `UNIQUE uq_pur_supplier_invoice (supplier_id, invoice_no)` | prevents double-claimed ITC on the same supplier invoice |
| `purchases` | `KEY idx_pur_gstin_date (gstin_id, invoice_date)` | GST reconciliation queries |
| `notifications` | `KEY idx_notif_feed (target_role, is_read, created_at)` | inbox feed |
| `sales` | `KEY idx_sales_pos (place_of_supply_state_code)` | IGST split reporting |

### 10.6 Additional migrations

```
0010_auth_hardening      staff.email/password_hash/failed_pin_attempts/locked_until/last_login_at,
                         refresh_tokens, password_reset_tokens
0011_gst_void            sales.place_of_supply_state_code/customer_gstin/status,
                         purchases void columns + uq_pur_supplier_invoice, notifications 'oversold'
0012_favorites_invoice   staff_favorites, invoice_sequences
0013_incentive_clearance discount_approvals.discount_type/requested_percent/cart_total/cart_summary_json,
                         incentive_rules.metric, products.clearance_flag/clearance_since,
                         new app_settings keys, new indexes
```

> **API-level (no schema)**: `PATCH /products/bulk`, `POST /products/import` (bulk web catalog),
> `POST /notifications/read-all`, and the `api/settings` module — documented in
> [api/products](../cloud/api/products/products-api.md), [api/reports-notifications](../cloud/api/reports-notifications/reports-notifications-api.md), [api/settings](../cloud/api/settings/settings-api.md).

## 11. Related docs
- [sync-and-conflict-resolution.md](sync-and-conflict-resolution.md) — how `stock_movements` reconciles
- [duplicate-detection.md](duplicate-detection.md) — `image_embedding`, `duplicate_review_queue`
- [api-conventions.md](api-conventions.md) — how these map to REST resources
