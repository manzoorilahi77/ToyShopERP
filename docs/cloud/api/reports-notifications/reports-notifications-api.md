# Reports & Notifications API

> Base URL, auth, the response envelope, error codes, pagination and `?format=` export are
> defined once in [api-conventions.md](../../../foundation/api-conventions.md) — referenced,
> not repeated.

---

## 1. Overview

Two closely-related concerns for the owner surfaces (R5 dashboards, R1/R4 alerts):

- **Reports** — read-only aggregates that power the owner dashboard and web analytics:
  today's KPIs, sales trend, category margin leaderboard, sales summary.
- **Notifications** — the server-generated alert feed (`low_stock`, `aging_stock`,
  `sync_failure`, `discount_request`, `incentive`, `system`), plus mark-as-read.

Callers: Owner App ([owner/dashboard](../../../mobile/owner/dashboard/dashboard-home.md),
[owner/notifications](../../../mobile/owner/notifications/notifications.md)) and Owner Web
([web/dashboard](../../web/dashboard/dashboard-home.md)). Reports **read across modules**
(sales, stock, staff, gst); they don't own a table beyond `notifications`.

---

## 2. Data model touched

Canonical names from [data-model.md](../../../foundation/data-model.md):

| Table / view | Role | R/W |
|---|---|---|
| `sales` / `sale_items` | today's totals, trend, margins, top performer | read |
| `products` / `categories` | cost vs selling price for margin & profit estimate | read |
| `v_current_stock` / `stock_movements` | low/aging alert generation | read |
| `staff` | top performer (`current_month_points`, revenue) | read |
| `gst_registrations` / `sales.tax_amount` / `purchases.total_gst` | pending GST liability tile | read |
| `sync_log` | `sync_failure` notification generation | read |
| `discount_approvals` | `discount_request` notification generation | read |
| `notifications` | **owned table** — the alert feed | read + write |

**Source of truth:** the underlying transaction tables. Reports compute at read time (cached
per window); `notifications` is the only table this module writes.

---

## 3. Auth & permissions

| Endpoint | staff | owner | accountant | Notes |
|---|---|---|---|---|
| `GET /reports/owner-dashboard` | ❌ | ✅ | ✅ | |
| `GET /reports/sales-trend` | ❌ | ✅ | ✅ | |
| `GET /reports/category-margins` | ❌ | ✅ | ✅ | cost data is owner-sensitive |
| `GET /reports/sales-summary` | ❌ | ✅ | ✅ | |
| `GET /notifications` | ✅ (own + role=staff/all) | ✅ | ✅ | staff see staff/all + personal only |
| `POST /notifications/{id}/read` | ✅ (own) | ✅ | ✅ | |

Reports are owner/accountant only (they expose cost/margin). Notifications are role-scoped
via `target_role` + `target_staff_id`.

---

## 4. Endpoints

### `GET /reports/owner-dashboard`

- **Purpose** — the top-row KPI counters + top performer + alert counts for the owner home.
- **Auth** — owner/accountant.
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `gstin_id` | query | int | no | all | scope to one registration |
| `date` | query | date | no | today | the "today" reference day |
| `tz` | query | string | no | `Asia/Kolkata` | day boundary |

- **Request body** — none.
- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `date` | date | reference day |
| `sales_total` | decimal | `Σ sales.total` for the day |
| `profit_estimate` | decimal | `Σ (unit_price − cost_price) × quantity` over `sale_items` (derived, gross) |
| `items_sold` | int | `Σ sale_items.quantity` |
| `invoice_count` | int | sales for the day |
| `pending_gst_liability` | decimal | output GST − ITC accrued this period (net, all/selected GSTIN) |
| `top_performer` | object / null | `{ staff_id, name, photo_url, revenue, units }` best staff today |
| `alerts` | object | `{ low_stock, aging_stock, sync_failure, discount_request }` unread counts |

```json
{ "ok": true, "data": {
  "date": "2026-07-02", "sales_total": 84200.00, "profit_estimate": 24380.00,
  "items_sold": 47, "invoice_count": 39, "pending_gst_liability": 74070.00,
  "top_performer": { "staff_id": 5, "name": "Deepa",
    "photo_url": "https://cdn.toyshop.example/s/5.jpg", "revenue": 31200.00, "units": 18 },
  "alerts": { "low_stock": 6, "aging_stock": 17, "sync_failure": 0, "discount_request": 1 }
}, "meta": { "request_id": "req_r10" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | ok |
| 403 | `FORBIDDEN` | staff role |

---

### `GET /reports/sales-trend`

- **Purpose** — time-series of sales for the dashboard trend chart (line/bar), daily / weekly
  / monthly toggle (R5).
- **Auth** — owner/accountant.
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `granularity` | query | enum | no | `daily` | `daily \| weekly \| monthly` |
| `from` / `to` | query | date | no | last 30d (daily) | inclusive on `sold_at` |
| `gstin_id` | query | int | no | all | scope |
| `staff_id` | query | int | no | all | scope to one seller |
| `metric` | query | enum | no | `revenue` | `revenue \| units \| profit` |
| `format` | query | enum | no | `json` | `json \| csv \| xlsx` |

- **Request body** — none.
- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `granularity` | enum | echoed |
| `metric` | enum | echoed |
| `data[].bucket` | string | `YYYY-MM-DD` (daily), ISO week (weekly), `YYYY-MM` (monthly) |
| `data[].value` | number | metric value |
| `data[].invoice_count` | int | sales in bucket |
| `meta.total` | number | sum of `value` across buckets |

```json
{ "ok": true, "data": [
  { "bucket": "2026-06-30", "value": 71200.00, "invoice_count": 34 },
  { "bucket": "2026-07-01", "value": 88400.00, "invoice_count": 41 },
  { "bucket": "2026-07-02", "value": 84200.00, "invoice_count": 39 }
], "meta": { "granularity": "daily", "metric": "revenue",
             "total": 243800.00, "request_id": "req_r20" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | ok |
| 400 | `VALIDATION_ERROR` | bad `granularity`/`metric`/date range |
| 403 | `FORBIDDEN` | staff role |

---

### `GET /reports/category-margins`

- **Purpose** — profit-margin leaderboard by product category (R5). Ranks categories by
  margin % / absolute profit.
- **Auth** — owner/accountant.
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `from` / `to` | query | date | no | current month | inclusive on `sold_at` |
| `sort` | query | enum | no | `margin_pct` | `margin_pct \| profit \| revenue` |
| `order` | query | enum | no | `desc` | best-first |
| `format` | query | enum | no | `json` | export |

- **Request body** — none.
- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `data[].category_id` | int | |
| `data[].name` | string | |
| `data[].units` | int | sold in range |
| `data[].revenue` | decimal | `Σ line_total` (pre-tax) |
| `data[].cost` | decimal | `Σ cost_price × quantity` |
| `data[].profit` | decimal | `revenue − cost` (gross) |
| `data[].margin_pct` | decimal | `profit / revenue × 100` |

```json
{ "ok": true, "data": [
  { "category_id": 3, "name": "Battery Cars", "units": 210, "revenue": 420000.00,
    "cost": 294000.00, "profit": 126000.00, "margin_pct": 30.00 },
  { "category_id": 7, "name": "Play Sets", "units": 88, "revenue": 61600.00,
    "cost": 49280.00, "profit": 12320.00, "margin_pct": 20.00 }
], "meta": { "request_id": "req_r30" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | ok |
| 403 | `FORBIDDEN` | staff role |

---

### `GET /reports/sales-summary`

- **Purpose** — a compact sales roll-up for a period: totals, payment mix, discounts, tax —
  the condensed mobile reports view + web summary header.
- **Auth** — owner/accountant.
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `from` / `to` | query | date | no | current month | inclusive on `sold_at` |
| `gstin_id` | query | int | no | all | scope |
| `staff_id` | query | int | no | all | scope |
| `group_by` | query | enum | no | — | `staff \| category \| payment_mode \| gstin` optional breakdown |
| `format` | query | enum | no | `json` | export |

- **Request body** — none.
- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `range` | object | `{ from, to }` |
| `totals.revenue` | decimal | `Σ sales.total` |
| `totals.subtotal` | decimal | pre-discount/pre-tax |
| `totals.discount` | decimal | `Σ discount_amount` |
| `totals.tax` | decimal | `Σ tax_amount` (output GST) |
| `totals.units` | int | |
| `totals.invoices` | int | |
| `totals.avg_basket` | decimal | revenue / invoices |
| `payment_mix` | object | `{ cash, upi, card }` revenue share |
| `breakdown[]` | array / null | present when `group_by` set: `{ key, label, revenue, units }` |

```json
{ "ok": true, "data": {
  "range": { "from": "2026-06-01", "to": "2026-06-30" },
  "totals": { "revenue": 958750.00, "subtotal": 812500.00, "discount": 4200.00,
              "tax": 146250.00, "units": 601, "invoices": 418, "avg_basket": 2293.66 },
  "payment_mix": { "cash": 300000.00, "upi": 560000.00, "card": 98750.00 },
  "breakdown": null
}, "meta": { "request_id": "req_r40" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | ok |
| 400 | `VALIDATION_ERROR` | bad `group_by`/date range |
| 403 | `FORBIDDEN` | staff role |

---

### `GET /notifications`

- **Purpose** — the alert feed, filtered by type / target role / read state.
- **Auth** — any authenticated role; results scoped to the caller's role + personal notifs.
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `type` | query | enum | no | — | `low_stock \| aging_stock \| sync_failure \| discount_request \| incentive \| system` |
| `target_role` | query | enum | no | — | `owner \| staff \| all` (owner may filter; staff forced to own scope) |
| `is_read` | query | bool | no | — | `false` = unread only |
| `since` | query | datetime | no | — | incremental fetch (poll) |
| `cursor` | query | string | no | — | cursor pagination |
| `per_page` | query | int | no | `50` | max `100` |

- **Request body** — none.
- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `data[].id` | int | |
| `data[].type` | enum | |
| `data[].title` | string | |
| `data[].body` | string | |
| `data[].target_role` | enum | |
| `data[].target_staff_id` | int / null | personal notif |
| `data[].ref_type` | string / null | e.g. `product`, `sale`, `discount_approval` |
| `data[].ref_id` | int / null | deep-link target (drill-down) |
| `data[].is_read` | bool | |
| `data[].created_at` | datetime | |
| `meta.unread_count` | int | for the badge |
| `meta.cursor` | string | next page |

```json
{ "ok": true, "data": [
  { "id": 902, "type": "low_stock", "title": "Low stock: Lamborghini 12V Ride-on",
    "body": "On hand 2 (reorder at 3). Tap to create a purchase order.",
    "target_role": "owner", "target_staff_id": null, "ref_type": "product",
    "ref_id": 22, "is_read": false, "created_at": "2026-07-02T06:00:00+05:30" },
  { "id": 903, "type": "discount_request", "title": "Discount request from Arun",
    "body": "₹300 off on invoice draft — approve?", "target_role": "owner",
    "target_staff_id": null, "ref_type": "discount_approval", "ref_id": 55,
    "is_read": false, "created_at": "2026-07-02T19:40:00+05:30" }
], "meta": { "unread_count": 8, "cursor": "eyJpZCI6OTAyfQ", "request_id": "req_r50" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | ok |
| 400 | `VALIDATION_ERROR` | bad `type`/`target_role` |

---

### `POST /notifications/{id}/read`

- **Purpose** — mark a notification read (dismiss the badge).
- **Auth** — any authenticated role; only for notifications the caller can see.
- **Idempotency** — **naturally idempotent** — marking an already-read notif returns `200`
  no-op. No `client_uuid` needed.
- **Path / query params** — `id` (path, int, required).
- **Request body** — none (empty `{}`). Optional `{ "read_all": true, "type": "low_stock" }`
  variant 🧩 to bulk-mark (proposed; otherwise call per id).
- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `id` | int | |
| `is_read` | bool | `true` |
| `unread_count` | int | remaining unread for the caller |

```json
{ "ok": true, "data": { "id": 902, "is_read": true, "unread_count": 7 },
  "meta": { "request_id": "req_r51" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | marked (or already read) |
| 403 | `FORBIDDEN` | notif not visible to caller |
| 404 | `NOT_FOUND` | no such notification |

---

## 5. Business logic & validation

**Profit estimate (gross).** `profit = Σ (sale_items.unit_price − products.cost_price) ×
quantity`. Uses the product's **current** `cost_price` (last purchase cost) — an estimate,
not FIFO/COGS accounting. Labelled "estimate" in the UI.

**Pending GST liability.** Reuses the [gst-api](../gst/gst-api.md) computation:
`max(output_tax − eligible_itc, 0)` for the current period across the selected GSTIN(s).

**Top performer.** Highest `Σ sales.total` (or units, per config) among active staff for the
day; ties broken by units then earliest to reach it 🧩.

**Notification generation (worker / cron).** The server generates notifications — clients
never create them. A background worker (per
[overview §3](../../../foundation/overview.md), "reconciliation job + notification
generator") runs these producers:

| `type` | Trigger | Source | Cadence | `target_role` |
|---|---|---|---|---|
| `low_stock` | `on_hand ≤ reorder_threshold` after a stock movement | `v_current_stock` vs `products` | on apply + hourly sweep | `owner` |
| `aging_stock` | product crosses aging threshold (30/60/90d unsold) | `stock_movements` age calc | nightly | `owner` |
| `sync_failure` | outbox item exceeds retry ceiling | `sync_log.status='failed'` + `retry_count` | on failure | `owner` |
| `discount_request` | staff raises a discount needing owner PIN | `discount_approvals(status='pending')` | on create | `owner` (+ personal to owner) |
| `incentive` | staff crosses a tier / earns a badge | `staff_incentive_progress`, `staff_badges` | on award | `staff` (personal `target_staff_id`) |
| `system` | broadcasts (maintenance, version) | manual/ops | ad-hoc | `all` |

**De-duplication.** Producers are idempotent per natural key (e.g. one open `low_stock` per
product until stock recovers; one `incentive` per `(staff, badge, period)`) so a product
hovering at the threshold doesn't spam. `is_read` is per-notification; a resolved condition
may auto-mark its notif read 🧩.

**Scoping.** `GET /notifications` returns rows where `target_role ∈ {caller_role, 'all'}` **or**
`target_staff_id = caller`. Staff never see owner-only alerts (low/aging/sync/discount).

---

## 6. Sync & conflict handling

- Reports are **read-only aggregates** — not part of the offline outbox. They read committed,
  **synced** sales; unsynced staff-device sales are excluded until they flush (the dashboard
  may show an "unsynced: N" hint sourced from [sync-api](../sync/sync-api.md)).
- Notifications are **server-generated**; `POST /notifications/{id}/read` is naturally
  idempotent and typically online (owner app). No `client_uuid`.
- The `sync_failure` notification is itself a product of the sync pipeline
  ([sync-and-conflict-resolution.md §8](../../../foundation/sync-and-conflict-resolution.md)).

---

## 7. Edge cases & failure modes

1. **Timezone at day boundary.** All "today" math uses `tz` (default `Asia/Kolkata`); a sale
   at 00:05 IST counts on the correct local day even though stored UTC.
2. **Unsynced sales skew today's KPIs.** Excluded until synced; dashboard surfaces the
   pending count so the owner isn't misled.
3. **Product with no `cost_price`.** Profit contribution treated as 0 and the product flagged
   (missing cost) 🧩 — avoids negative/garbage margins.
4. **Notification storm.** Idempotent producers + one-open-per-natural-key prevent flooding.
5. **Read race.** Two devices mark the same notif read → both `200`; `unread_count` converges.
6. **Voided sale after report cached.** Cache invalidated for the affected window on void;
   next read recomputes.
7. **Empty period.** Reports return zeros / empty arrays with `200`, never `404`.

---

## 8. Performance & indexing

| Query | Index relied on |
|---|---|
| today's KPIs | `sales.idx_gstin_date`, `idx_staff_date` |
| trend buckets | `sales (sold_at)`; group in SQL by day/week/month |
| category margins | join `sale_items → products.idx_cat` |
| low/aging producers | `stock_movements.idx_product`, `idx_occurred` + `v_current_stock` cache |
| notifications feed | `notifications (target_role, is_read, created_at)` — add `KEY idx_notif_feed` 🧩 |

- **Caching:** dashboard KPIs and summaries are cached per `(window, gstin_id)` and
  invalidated on sale/stock change; trend/margins recomputed on demand (bounded ranges).
- **Notifications** use cursor pagination + `since` for cheap incremental polling; the unread
  badge is a cheap `COUNT` on the partial index.
- Notification producers run in the background worker, off the request path.

---

## 9. Related docs

- Foundation: [data-model.md](../../../foundation/data-model.md) ·
  [overview.md](../../../foundation/overview.md) (worker/cron) ·
  [api-conventions.md](../../../foundation/api-conventions.md) ·
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md)
- Sibling APIs: [sales-api](../sales/sales-api.md) · [stock-api](../stock/stock-api.md)
  (low/aging) · [gst-api](../gst/gst-api.md) (pending liability) ·
  [staff-api](../staff/staff-api.md) (top performer) ·
  [incentives-api](../incentives/incentives-api.md) (incentive notifs) ·
  [sync-api](../sync/sync-api.md) (sync_failure)
- Screens: [owner/dashboard](../../../mobile/owner/dashboard/dashboard-home.md) ·
  [owner/notifications](../../../mobile/owner/notifications/notifications.md) ·
  [web/dashboard](../../web/dashboard/dashboard-home.md) ·
  [owner/reports](../../../mobile/owner/reports/reports.md)
