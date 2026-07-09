# Sales API

> Base URL, envelope, headers, error codes and pagination live in
> [`api-conventions.md`](../../../foundation/api-conventions.md) — referenced, not repeated.
> Paths are relative to `…/v1`. **This is the highest-traffic, highest-risk write path in
> the system** — read [`sync-and-conflict-resolution.md`](../../../foundation/sync-and-conflict-resolution.md)
> alongside this doc.

---

## 1. Overview

Sales is the money path. A sale is created on the staff app during a fast, chaotic rush and
**must never block on the network** (cross-cutting principle 1): the client writes locally,
shows the receipt, and syncs in the background. The server is the authority for stock,
invoice numbers, and GST.

A confirmed sale, applied server-side, does the following atomically: writes the `sales`
header + `sale_items`, appends `sale_out` rows to the immutable `stock_movements` log
(**−qty**), assigns a gapless `invoice_no` per GSTIN sequence, and reconciles on-hand
(surfacing oversold rather than dropping the sale).

Business drivers ([`requirements_and_prompt.md`](../../../requirements_and_prompt.md) R1/R4/R5):
- **Speed & offline-first** — the sale completes in < 100 ms locally; sync is fire-and-forget.
- **Owner-PIN gated discounts** — `discount_amount > 0` requires an owner PIN
  (`X-Owner-Pin-Token` from [`/auth/verify-pin`](../auth/auth-api.md) or an approved
  `discount_approvals` row).
- **Per-staff attribution** — every sale carries `staff_id` (leaderboard, incentives, audit).
- **Device traceability** — `device_id` records which offline device generated the sale.
- **Auto invoice + GST** — server assigns `invoice_no` and computes output GST per GSTIN.

| Caller | Uses |
|---|---|
| **Staff App** | writes locally then pushes via [`/sync/push`](../sync/sync-api.md); may call `POST /sales` directly when online. |
| **Owner/Web** | `GET /sales` ledger + export, `GET /sales/{id}`. |
| **Sync worker** | batch replay; apply logic is identical to `POST /sales`. |

## 2. Data model touched

Source of truth: [`data-model.md`](../../../foundation/data-model.md).

| Table | R/W | Role |
|---|---|---|
| `sales` | write | header: `client_uuid` (idempotency), `invoice_no` (server-assigned), `staff_id`, `gstin_id`, `subtotal`, `discount_amount`, `discount_approved_by` (`🔒`), `tax_amount`, `total`, `payment_mode`, `sync_status`, `device_id`, `sold_at`. |
| `sale_items` | write | lines: `product_id`, `quantity`, `unit_price`, `gst_rate`, `gst_amount`, `line_total`. |
| `stock_movements` | write | **source of truth for stock.** One `sale_out` (−qty) per line. |
| `products` | read | validate ids, snapshot `unit_price`/`gst_rate`; on-hand hint. |
| `gst_registrations` | read | `gstin_id` active; `state_code` for CGST/SGST vs IGST; invoice sequence scope. |
| `discount_approvals` | read/write | owner-PIN discount flow; links via `sale_client_uuid`. |
| `staff` | read | `staff_id`, and (denormalized cache) `total_lifetime_sales`, `current_month_points`. |
| `sync_log` | write | idempotency/status trail. |
| `notifications` | write | `low_stock`, oversold (see proposed type §6). |
| `audit_log` | write | `sale.void` (if enabled), `discount.approve`. |

`stock_movements` is the **source of truth**; `staff.total_lifetime_sales` /
`current_month_points` are **caches** (nightly reconcile, data-model §4).

### Proposed schema additions

| Addition | Where | Why |
|---|---|---|
| `invoice_sequences(gstin_id, fy CHAR(7), last_seq INT, UNIQUE(gstin_id, fy))` | new table | invoice numbers are a **gapless per-GSTIN, per-financial-year** sequence (sync doc §7); a dedicated counter table gives atomic `last_seq` allocation without gaps. Without it, gapless numbering under concurrency is unsafe. |
| add `'oversold'` to `notifications.type` ENUM | `notifications` | sync doc §5 emits `notification(type='oversold')`, but the canonical ENUM lacks it. Until added, oversold is emitted as `type='low_stock'` with a distinguishing `title`. |

## 3. Auth & permissions

| Endpoint | Auth | Roles | PIN |
|---|---|---|---|
| `POST /sales` | Bearer + `X-Device-Id` | `staff`, `owner` | 🔒 owner PIN **only if** `discount_amount > 0` |
| `GET /sales` | Bearer | `owner`, `accountant` (staff → own only) | — |
| `GET /sales/{id}` | Bearer | `owner`, `accountant` (staff → own only) | — |

`🔒` discount authorization is satisfied by **either** header `X-Owner-Pin-Token` (from
[`/auth/verify-pin`](../auth/auth-api.md)) **or** a matching approved `discount_approvals`
row referenced by `sale_client_uuid` (async approval from the owner app).

---

## 4. Endpoints

### `POST /sales`
- **Purpose** — record a completed sale; transactionally decrements stock, assigns the
  invoice number, computes GST, and returns reconciled stock.
- **Auth** — Bearer (`staff`/`owner`) + `X-Device-Id`. `🔒` owner PIN required when
  `discount_amount > 0`.
- **Idempotency** — **`Idempotency-Key` = `client_uuid`** (conventions §6, sync doc §6).
  Repeat key → returns the original sale with its assigned `invoice_no`, no double stock
  decrement. `sales.client_uuid` is UNIQUE (`uq_sale_uuid`).
- **Path / query params** — none.
- **Request body**

| Field | Type | Required | Validation | Notes |
|---|---|---|---|---|
| `client_uuid` | string(uuid) | **yes** | UNIQUE | generated at sale creation on device |
| `staff_id` | integer | **yes** | exists, active | who sold (leaderboard/audit) |
| `gstin_id` | integer | **yes** | exists, `is_active=1` | which registration → invoice sequence + GST |
| `items` | array | **yes** | ≥ 1 line | see below |
| `items[].product_id` | integer | yes | exists (synced) | |
| `items[].quantity` | integer | yes | > 0 | units sold |
| `items[].unit_price` | string(dec) | yes | ≥ 0 | snapshot of selling price at sale time |
| `items[].gst_rate` | number | no | `0/5/12/18/28` | defaults to product's `gst_rate` |
| `discount_amount` | string(dec) | no | ≥ 0, ≤ subtotal | `> 0` requires owner-PIN authorization `🔒` |
| `discount_approved_by` | integer | cond. | owner `staff_id` | required when `discount_amount > 0`; must match the PIN token / approval |
| `payment_mode` | enum | **yes** | `cash\|upi\|card` | |
| `sold_at` | string(ISO) | **yes** | ≤ now + skew | client business time of sale |
| `device_id` | string | **yes** | ≤ 64 | offline device trace (also in `X-Device-Id`) |

- **Server-computed / server-owned** (never trusted from client): `invoice_no`,
  `gst_amount`/`line_total` per line, `subtotal`, `tax_amount`, `total`, `sync_status`.
  A client-sent `total` is treated as a checksum only.

- **Response `201`**

| Field | Type | Notes |
|---|---|---|
| `id` | integer | server sale id |
| `client_uuid` | string | echoed |
| `invoice_no` | string | **server-assigned**, per-GSTIN gapless, e.g. `GST1/26-27/000418` |
| `staff_id` / `gstin_id` | integer | |
| `subtotal` | string(dec) | Σ line pre-discount |
| `discount_amount` | string(dec) | |
| `discount_approved_by` | integer\|null | owner id when discounted |
| `tax_amount` | string(dec) | output GST |
| `total` | string(dec) | payable |
| `payment_mode` | enum | |
| `sold_at` | string(ISO) | business time |
| `sync_status` | enum | `synced` when applied directly |
| `items` | array | each with computed `gst_amount`, `line_total` |
| `reconciled_stock` | object | `{ "<product_id>": on_hand }` after applying `sale_out` |
| `oversold` | array | product_ids whose on-hand went `< 0` (empty in the normal case) |

```json
{ "ok": true,
  "data": {
    "id": 5012, "client_uuid": "0f8b…-uuid", "invoice_no": "GST1/26-27/000418",
    "staff_id": 4, "gstin_id": 1, "subtotal": "2998.00", "discount_amount": "0.00",
    "discount_approved_by": null, "tax_amount": "457.32", "total": "2998.00",
    "payment_mode": "upi", "sold_at": "2026-07-02T19:45:12+05:30",
    "sync_status": "synced",
    "items": [
      { "product_id": 22, "quantity": 2, "unit_price": "1499.00", "gst_rate": 18,
        "gst_amount": "457.32", "line_total": "2998.00" }
    ],
    "reconciled_stock": { "22": 5 }, "oversold": [] },
  "meta": { "request_id": "req_…" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | missing `staff_id`/`gstin_id`/`items`/`payment_mode`/`sold_at`; empty items; `quantity ≤ 0` |
| 401 | `UNAUTHENTICATED` | no/expired token |
| 403 | `FORBIDDEN` | `discount_amount > 0` without a valid `X-Owner-Pin-Token`/approval; PIN expired |
| 404 | `NOT_FOUND` | `product_id`/`gstin_id`/`staff_id` missing |
| 409 | `CONFLICT` | referenced `product_id` **not synced yet** (offline ordering) → retry after product create syncs |
| 409 | `DUPLICATE_IGNORED` | `client_uuid` already applied → returns original sale + `invoice_no` |
| 422 | `BUSINESS_RULE` | `gstin_id` inactive; `discount_amount > subtotal`; discount checksum/total mismatch |

> **Note — oversold is NOT an error.** If reconciled on-hand goes `< 0`, the sale is
> **still recorded** (goods left the shop). The response is `201` with `oversold` populated
> and an oversold flag/notification raised. See §5–6 and sync doc §5.

- **Example**

```bash
curl -X POST …/v1/sales \
  -H 'Authorization: Bearer …' -H 'X-Device-Id: dev-abc123' \
  -H 'Idempotency-Key: 0f8b…-uuid' -H 'Content-Type: application/json' \
  -d '{ "client_uuid": "0f8b…-uuid", "staff_id": 4, "gstin_id": 1,
        "payment_mode": "upi", "sold_at": "2026-07-02T19:45:12+05:30",
        "device_id": "dev-abc123", "discount_amount": "0",
        "items": [{ "product_id": 22, "quantity": 2, "unit_price": "1499.00" }] }'
```

Discounted example (owner PIN pre-verified):
```bash
curl -X POST …/v1/sales -H 'Authorization: Bearer …' \
  -H 'X-Device-Id: dev-abc123' -H 'X-Owner-Pin-Token: opt_5m_7Kd…' \
  -H 'Idempotency-Key: 1a2b…-uuid' -H 'Content-Type: application/json' \
  -d '{ "client_uuid": "1a2b…-uuid", "staff_id": 4, "gstin_id": 1,
        "payment_mode": "cash", "sold_at": "2026-07-02T20:03:00+05:30",
        "device_id": "dev-abc123", "discount_amount": "200.00",
        "discount_approved_by": 1,
        "items": [{ "product_id": 30, "quantity": 1, "unit_price": "2499.00" }] }'
```

---

### `GET /sales`
- **Purpose** — sales ledger with filters + export (web) and per-staff history (staff app).
- **Auth** — Bearer. `owner`/`accountant` see all; `staff` see **only their own**
  (server forces `staff_id = caller`).
- **Idempotency** — N/A (read).
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `staff_id` | query | integer | no | — | owner/accountant only; staff forced to self |
| `gstin_id` | query | integer | no | — | filter by registration |
| `from` / `to` | query | date | no | — | inclusive on `sold_at` (conventions §8) |
| `payment_mode` | query | enum | no | — | `cash\|upi\|card` |
| `q` | query | string | no | — | search `invoice_no` |
| `sync_status` | query | enum | no | — | `pending\|syncing\|synced\|failed` (ops) |
| `sort` | query | enum | no | `sold_at` | `sold_at\|total\|created_at` |
| `order` | query | enum | no | `desc` | |
| `format` | query | enum | no | `json` | `json\|csv\|xlsx` |
| `page`/`per_page` or `cursor` | query | | no | `1`/`50` | cursor for large ledgers |

- **Response `200`** — list envelope; each row: `id`, `invoice_no`, `staff_id`,
  `staff_name`, `gstin_id`, `subtotal`, `discount_amount`, `tax_amount`, `total`,
  `payment_mode`, `sold_at`, `sync_status`. `meta` carries rollups (`sum_total`,
  `sum_tax`, `count`) for the filtered set. `format=csv|xlsx` → file stream.

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | bad date/`format` |
| 401 | `UNAUTHENTICATED` | no token |
| 403 | `FORBIDDEN` | staff requesting another `staff_id` |

---

### `GET /sales/{id}`
- **Purpose** — full sale detail (receipt reprint, audit).
- **Auth** — Bearer; `owner`/`accountant`, or the owning `staff`.
- **Idempotency** — N/A.
- **Path params** — `id` (integer, required). *(A sibling lookup by `client_uuid` may be
  offered as `GET /sales?client_uuid=…` for the client to map its local sale to the server
  row.)*
- **Response `200`** — full `sales` row + `items[]` (with `product_name`) + `movements[]`
  (`sale_out` rows) + `discount_approval` (if any) + `oversold` flag.

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 403 | `FORBIDDEN` | staff requesting another staff's sale |
| 404 | `NOT_FOUND` | no such sale |

---

## 5. Business logic & validation

**Atomic transaction on `POST /sales` (per sync doc §6):**
```
BEGIN
  IF exists(client_uuid) → return {DUPLICATE_IGNORED, sale + invoice_no}   -- replay
  validate staff_id, gstin_id (active), every product_id (exists/synced)
  IF discount_amount > 0:
     require valid X-Owner-Pin-Token OR approved discount_approvals(sale_client_uuid)
     require discount_approved_by = that owner
  FOR each item:
     gst_amount = round( (unit_price × quantity − line_discount_share) × gst_rate/100 )
     line_total = unit_price × quantity + gst_amount        -- per pricing config
  subtotal   = Σ(unit_price × quantity)
  tax_amount = Σ gst_amount
  total      = subtotal − discount_amount (+ tax per inclusive/exclusive config)
  invoice_no = allocate_invoice(gstin_id)                   -- gapless per-GSTIN sequence
  INSERT sales(header, invoice_no, sync_status='synced')    -- server id
  INSERT sale_items(...)                                     -- per line
  INSERT stock_movements(sale_out, −quantity, ref_type='sale',
                         ref_id=sale_id, ref_client_uuid, staff_id, device_id,
                         occurred_at=sold_at)                -- per line
  INSERT sync_log(status='applied')
  reconciled = recompute_stock(affected product_ids)        -- SUM(quantity_delta)
  IF any on_hand < 0 → oversold[]; emit notification; flag product for count
COMMIT
return {sale, invoice_no, reconciled_stock, oversold}
```
All-or-nothing per sale; one failing sale in a `/sync/push` batch does not poison the rest.

**Invoice numbering** (sync doc §7, headline detail):
- Assigned **by the server on apply**, never by the client. The client shows a provisional
  local ref until sync returns the real `invoice_no` (pulled back onto the receipt/history).
- **Scope:** one gapless sequence per `gstin_id` per financial year (India FY = Apr–Mar).
- **Format:** `GST{gstin_seq}/{fy}/{seq}` → e.g. `GST1/26-27/000418` (GSTIN #1, FY 2026-27,
  418th invoice). `seq` is zero-padded, gapless.
- **Allocation:** `allocate_invoice(gstin_id)` atomically bumps
  `invoice_sequences.last_seq` *(proposed table §2)* under the same transaction as the
  `sales` INSERT — gapless even under concurrent applies. GST/legal reasons forbid gaps.
- **Replays** (`DUPLICATE_IGNORED`) return the **already-assigned** number; the sequence is
  **not** advanced again.

**Discount / owner-PIN gate** (`🔒`, cross-cutting principle 5):
- `discount_amount = 0` → no PIN needed.
- `discount_amount > 0` → must present a valid `X-Owner-Pin-Token` (from
  [`/auth/verify-pin`](../auth/auth-api.md), scope `discount:approve`, ~5 min TTL) **or** an
  `approved` `discount_approvals` row keyed by `sale_client_uuid` (async owner approval).
  `discount_approved_by` must equal the approving owner; mismatch/expired → `403`.
- Discount events write `audit_log` (`discount.approve`).

**GST computation:**
- `gst_rate` snapshotted per `sale_items` line at sale time (later product edits don't
  rewrite history).
- CGST/SGST vs IGST derived from `gst_registrations.state_code` of `gstin_id` vs the
  customer/place-of-supply (B2C intra-state → CGST+SGST; inter-state → IGST). `tax_amount`
  total is unaffected by the split; the split feeds [gst-api](../gst/gst-api.md) GSTR-1/3B.
- Server rounds half-up to paise and is authoritative (conventions §1).

**Denormalized caches:** on apply, `staff.total_lifetime_sales` and
`current_month_points` may be incremented for fast dashboards, but the **authoritative**
values come from `sales`; a nightly job reconciles (data-model §4). Incentive progress is
handled in [incentives-api](../incentives/incentives-api.md).

## 6. Sync & conflict handling
This endpoint is the concrete implementation of
[`sync-and-conflict-resolution.md`](../../../foundation/sync-and-conflict-resolution.md).

- **Idempotent by `client_uuid`** (UNIQUE `uq_sale_uuid`): retries and duplicate
  `/sync/push` pushes dedupe → `DUPLICATE_IGNORED`, same `invoice_no`, no double decrement.
  From the client's view `duplicate_ignored` is **success** — mark synced, don't retry.
- **Event-sourced stock, no lost updates:** two staff selling the same product offline both
  append `sale_out` rows; both count. Example (sync doc §5): on-hand 10, A sells 3, B sells
  4 → after both sync, on-hand **3**, regardless of arrival order. There is no "winner".
- **Last-write-wins applies to attributes, not deltas** — sales never edit shared mutable
  attributes, so there is no LWW conflict here; only product edits use LWW.
- **Oversold / negative-stock guard (headline rule):** the server **never rejects a
  completed sale** — the goods physically left. If reconciled on-hand < 0 it:
  1. still records the sale + `sale_out` movement,
  2. returns `oversold:[product_id…]` and raises an oversold notification
     *(type `oversold` — proposed; falls back to `low_stock`)*,
  3. flags the product for a physical stock-count review.
  This "prevents negative-stock errors after sync" by preventing **corrupt counters**, not
  by **refusing reality**.
- **Ordering dependency (FIFO):** a sale referencing a not-yet-synced product returns
  `409 CONFLICT`; the outbox pushes the product create first (creation order), then retries.
  `stock_movements.ref_client_uuid` ties the movement to the offline txn pre-server-id.
- **Invoice pull-back:** the server-assigned `invoice_no` is returned in the push ack and
  also via [`/sync/pull`](../sync/sync-api.md), which the client stamps onto its local sale
  and receipt.
- **Backoff:** failed pushes retry with exponential backoff (`min(2^attempts,300)s` +
  jitter); no tight retry loop (sync doc §3).

**Decision table (sales-specific, from sync doc §5):**

| Scenario | Resolution |
|---|---|
| Same product sold offline by 2+ staff | Both `sale_out` append; on-hand = sum. No conflict. |
| Duplicate push of same `client_uuid` | `duplicate_ignored`; original `invoice_no` returned; no double-count. |
| Sale references product not yet synced | FIFO pushes product create first; else `409` → retry after pull. |
| Reconciled on-hand < 0 | Record sale, return `oversold`, notify owner, request count. |
| Offline sale then product deactivated on server | Sale still applies; product auto-reactivated + flagged. |
| Discount PIN token expired between local sale and sync | `403`; client re-verifies PIN, resubmits same `client_uuid` (no dup). |

## 7. Edge cases & failure modes
1. **Duplicate submit / retry storm** → `client_uuid` guarantees exactly one sale; the rest
   are `duplicate_ignored`. Verified in sync testing checklist.
2. **App killed mid-sale** → the sale survives in Drift (written before receipt), syncs on
   relaunch; server assigns `invoice_no` then.
3. **Oversold** → recorded, flagged, owner notified; never dropped.
4. **Discount without approval** → `403 FORBIDDEN` before any row is written; local sale
   stays pending until the owner approves (async) or PIN is re-verified.
5. **`discount_amount > subtotal`** → `422 BUSINESS_RULE`.
6. **Clock skew on `sold_at`** → server accepts business time with bounded skew; large skew
   is clamped/flagged but the sale is not rejected (revenue > tidiness).
7. **Inactive GSTIN chosen** → `422`; client must pick an active registration (rare; usually
   only one).
8. **Partial batch** via `/sync/push` → each sale acked independently; a bad line rejects
   only its own sale.
9. **Product deleted between local sale and sync** → auto-reactivated; sale applies.
10. **Refund/void** — not in the create path; a void writes a `void_reversal` (+qty) movement
    and is owner-gated (parallel to [purchases void](../purchases/purchases-api.md)); modeled
    when the refund screen is specced.

## 8. Performance & indexing
- **Write path** is a short transaction (1 header + N items + N movements + 1 sequence bump);
  N is tiny (cart size). Batch the movement `INSERT`s. Target < ~50 ms server-side; the
  client is already unblocked regardless.
- **Invoice sequence contention:** the per-GSTIN counter is a hot row under concurrent
  applies — use `SELECT … FOR UPDATE` / atomic increment on `invoice_sequences` scoped by
  `(gstin_id, fy)`; contention is naturally low (one shop, few GSTINs).
- **Ledger reads** rely on `idx_staff_date (staff_id, sold_at)` and
  `idx_gstin_date (gstin_id, sold_at)`; `idx_sync (sync_status)` for ops queries. Cursor
  pagination for large ranges; `format=csv|xlsx` streams.
- **Stock recompute** uses `stock_movements.idx_product`; served via `v_current_stock` (or a
  materialized on-hand cache at scale — [stock-api](../stock/stock-api.md)).
- **Dashboards** read denormalized `staff` caches, not live aggregates, to stay glanceable.

## 9. Related docs
- Screens: [staff/new-sale](../../../mobile/staff/sales/new-sale.md) ·
  [staff/receipt](../../../mobile/staff/sales/receipt.md) ·
  [staff/my-sales-history](../../../mobile/staff/sales/my-sales-history.md) ·
  [owner/discount-approval](../../../mobile/owner/approvals/discount-approval.md) ·
  [web/sales-ledger](../../web/sales/sales-ledger.md)
- Sibling APIs: [sync-api](../sync/sync-api.md) · [auth-api](../auth/auth-api.md)
  (`X-Owner-Pin-Token`) · [products-api](../products/products-api.md) ·
  [stock-api](../stock/stock-api.md) · [gst-api](../gst/gst-api.md) ·
  [incentives-api](../incentives/incentives-api.md)
- Foundation: [sync-and-conflict-resolution](../../../foundation/sync-and-conflict-resolution.md)
  (read first) · [data-model](../../../foundation/data-model.md) ·
  [api-conventions](../../../foundation/api-conventions.md)
