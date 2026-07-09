# Purchases API

> Base URL, envelope, headers, error codes and pagination live in
> [`api-conventions.md`](../../../foundation/api-conventions.md) — referenced, not repeated.
> Paths are relative to `…/v1`.

---

## 1. Overview

The Purchases module records **stock coming in** from suppliers and the **Input Tax Credit
(ITC)** that comes with it. A confirmed purchase does three things atomically: writes the
`purchases` header + `purchase_items`, appends `purchase_in` rows to the immutable
`stock_movements` log (**+qty**), and updates each product's latest `cost_price`.

Business drivers ([`requirements_and_prompt.md`](../../../requirements_and_prompt.md) R4):
- **Stock auto-updates instantly** on confirm — no manual counter edits (goods arrive → tap
  confirm → on-hand rises).
- **ITC tracking** — each purchase captures which `gstin_id` (own registration) it's under
  and the **supplier's GSTIN**; a missing supplier GSTIN is an ITC-risk flag at filing time.
- **Supplier-wise + exportable** — the purchase ledger filters supplier-wise and exports
  CSV/XLSX for GST season.

| Caller | Uses |
|---|---|
| **Owner App** | `POST /purchases` from [new purchase](../../../mobile/owner/purchase/new-purchase.md). |
| **Owner Web** | `GET /purchases` ledger + export, `GET /purchases/{id}`, `POST /purchases/{id}/void`. |
| **Sync worker** | replays offline purchases via [`/sync/push`](../sync/sync-api.md); this module is the direct HTTP surface with identical apply logic. |

## 2. Data model touched

Source of truth: [`data-model.md`](../../../foundation/data-model.md).

| Table | R/W | Role |
|---|---|---|
| `purchases` | write | header: `client_uuid` (idempotency), `supplier_id`, `gstin_id`, `supplier_gstin`, `invoice_no`, `invoice_date`, `subtotal`, `total_gst`, `total_cost`, `status`. |
| `purchase_items` | write | lines: `product_id`, `quantity`, `cost_price`, `gst_rate`, `gst_amount`, `line_total`. |
| `stock_movements` | write | **source of truth for stock.** One `purchase_in` (+qty) per line; `void_reversal` (−qty) on void. |
| `products` | read/write | validate ids; **update `cost_price`** to the latest purchase cost. |
| `suppliers` | read | validate `supplier_id`; carry `supplier_gstin` snapshot. |
| `gst_registrations` | read | validate `gstin_id`, derive `state_code` for CGST/SGST vs IGST. |
| `sync_log` | write | idempotency + status trail (`received`/`applied`/`duplicate_ignored`/`failed`). |
| `audit_log` | write | `purchase.create`, `purchase.void`. |

`stock_movements` is the **source of truth**; `products.cost_price` is a **derived cache**.

## 3. Auth & permissions

| Endpoint | Auth | Roles |
|---|---|---|
| `POST /purchases` | Bearer + `X-Device-Id` | `owner`, `accountant` (staff per config) |
| `GET /purchases` | Bearer | `owner`, `accountant` |
| `GET /purchases/{id}` | Bearer | `owner`, `accountant` |
| `POST /purchases/{id}/void` | Bearer | `owner` only |

---

## 4. Endpoints

### `POST /purchases`
- **Purpose** — record a confirmed purchase; transactionally raises stock and updates cost.
- **Auth** — Bearer (`owner`/`accountant`) + `X-Device-Id`.
- **Idempotency** — **`Idempotency-Key` = `client_uuid`** (conventions §6, sync doc §6).
  Repeat key → returns the original purchase, no double stock. `purchases.client_uuid` is
  UNIQUE.
- **Path / query params** — none.
- **Request body**

| Field | Type | Required | Validation | Notes |
|---|---|---|---|---|
| `client_uuid` | string(uuid) | yes | UNIQUE | idempotency key |
| `supplier_id` | integer | **yes** | exists, active | |
| `gstin_id` | integer | **yes** | exists, `is_active=1` | which own registration this ITC belongs to |
| `supplier_gstin` | string\|null | no | 15-char if present | **null → ITC-risk flag**; snapshot for the invoice |
| `invoice_no` | string | no | ≤ 40 | supplier's invoice number |
| `invoice_date` | string(date) | no | ≤ today | supplier invoice date |
| `items` | array | **yes** | ≥ 1 line | see below |
| `items[].product_id` | integer | yes | exists | |
| `items[].quantity` | integer | yes | > 0 | units received |
| `items[].cost_price` | string(dec) | yes | ≥ 0 | per-unit cost |
| `items[].gst_rate` | number | no | `0/5/12/18/28` | defaults to product's `gst_rate` |
| `status` | enum | no | `confirmed`(default)\|`draft` | draft = no stock movement yet |

- **Server-computed fields** (not trusted from client): `gst_amount`, `line_total`,
  `subtotal`, `total_gst`, `total_cost` (see Business logic §5). Any client-sent totals are
  recomputed and used only as a checksum.

- **Response `201`**

| Field | Type | Notes |
|---|---|---|
| `id` | integer | server purchase id |
| `client_uuid` | string | echoed |
| `supplier_id` / `gstin_id` | integer | |
| `supplier_gstin` | string\|null | |
| `invoice_no` / `invoice_date` | string | |
| `subtotal` / `total_gst` / `total_cost` | string(dec) | server-computed |
| `status` | enum | `confirmed` |
| `items` | array | each line with computed `gst_amount`, `line_total` |
| `reconciled_stock` | object | `{ "<product_id>": on_hand }` after applying `purchase_in` |
| `itc_risk` | boolean | `supplier_gstin IS NULL` |

```json
{ "ok": true,
  "data": {
    "id": 812, "client_uuid": "b7d1…-uuid", "supplier_id": 3, "gstin_id": 1,
    "supplier_gstin": "33ABCDE1234F1Z5", "invoice_no": "SUN/2026/1187",
    "invoice_date": "2026-07-01", "subtotal": "16400.00", "total_gst": "2952.00",
    "total_cost": "19352.00", "status": "confirmed",
    "items": [
      { "product_id": 22, "quantity": 20, "cost_price": "820.00", "gst_rate": 18,
        "gst_amount": "2952.00", "line_total": "19352.00" }
    ],
    "reconciled_stock": { "22": 27 }, "itc_risk": false },
  "meta": { "request_id": "req_…" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | missing `supplier_id`/`gstin_id`/`items`; empty items; `quantity ≤ 0` |
| 401 | `UNAUTHENTICATED` | no token |
| 403 | `FORBIDDEN` | role not allowed |
| 404 | `NOT_FOUND` | supplier / gstin / product id missing |
| 409 | `CONFLICT` | referenced `product_id` **not synced yet** (offline ordering) → retry after product create syncs |
| 409 | `DUPLICATE_IGNORED` | `client_uuid` already applied → returns original purchase |
| 422 | `BUSINESS_RULE` | `gstin_id` inactive; `invoice_date` in the future |

- **Example**

```bash
curl -X POST …/v1/purchases \
  -H 'Authorization: Bearer …' -H 'X-Device-Id: dev-owner1' \
  -H 'Idempotency-Key: b7d1…-uuid' -H 'Content-Type: application/json' \
  -d '{ "client_uuid": "b7d1…-uuid", "supplier_id": 3, "gstin_id": 1,
        "supplier_gstin": "33ABCDE1234F1Z5", "invoice_no": "SUN/2026/1187",
        "invoice_date": "2026-07-01",
        "items": [{ "product_id": 22, "quantity": 20, "cost_price": "820.00",
                    "gst_rate": 18 }] }'
```

---

### `GET /purchases`
- **Purpose** — purchase ledger with filters + export for GST season.
- **Auth** — Bearer (`owner`/`accountant`). **Idempotency** — N/A (read).
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `supplier_id` | query | integer | no | — | supplier-wise breakdown |
| `gstin_id` | query | integer | no | — | filter by own registration |
| `from` / `to` | query | date | no | — | inclusive on `invoice_date` (conventions §8) |
| `status` | query | enum | no | `confirmed` | `confirmed\|draft\|void\|all` |
| `itc_risk` | query | boolean | no | — | `true` → only purchases with null `supplier_gstin` |
| `q` | query | string | no | — | search `invoice_no` |
| `sort` | query | enum | no | `invoice_date` | `invoice_date\|total_cost\|created_at` |
| `order` | query | enum | no | `desc` | |
| `format` | query | enum | no | `json` | `json\|csv\|xlsx` (conventions §7) |
| `page`/`per_page` or `cursor` | query | | no | `1`/`50` | cursor for large ledgers |

- **Response `200`** — list envelope; each row: `id`, `supplier_id`, `supplier_name`,
  `gstin_id`, `supplier_gstin`, `invoice_no`, `invoice_date`, `subtotal`, `total_gst`,
  `total_cost`, `status`, `itc_risk`, `created_at`. `meta` includes rollups
  (`sum_total_cost`, `sum_total_gst`) for the filtered set.
- **`format=csv|xlsx`** → returns a file stream (Content-Disposition attachment) with the
  same columns, ready for CA handoff / GST portal.

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | bad date range / `format` |
| 401 | `UNAUTHENTICATED` | no token |
| 403 | `FORBIDDEN` | role not allowed |

---

### `GET /purchases/{id}`
- **Purpose** — full purchase detail with line items + linked stock movements.
- **Auth** — Bearer (`owner`/`accountant`). **Idempotency** — N/A.
- **Path params** — `id` (integer, required).
- **Response `200`** — full `purchases` row + `items[]` (with `product_name`) +
  `movements[]` (`purchase_in` / `void_reversal` rows linked via `ref_type='purchase'`,
  `ref_id`) + `itc_risk`.

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 404 | `NOT_FOUND` | no such purchase |

---

### `POST /purchases/{id}/void`
- **Purpose** — reverse a purchase (wrong entry, returned goods) by writing compensating
  `void_reversal` movements — the log stays **append-only** (no deletes).
- **Auth** — Bearer; `owner` only.
- **Idempotency** — safe to repeat: a purchase already `void` returns `200` with the
  existing reversal, no second reversal.
- **Path params** — `id` (integer, required).
- **Request body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `reason` | string | no | stored in movement `note` + `audit_log` *(see proposed column below)* |

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `id` | integer | purchase id |
| `status` | enum | now `void` |
| `reversal_movements` | array | the `void_reversal` (−qty) rows written |
| `reconciled_stock` | object | `{ "<product_id>": on_hand }` after reversal |

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 404 | `NOT_FOUND` | no such purchase |
| 409 | `CONFLICT` | already `void` (returns existing reversal) |
| 422 | `BUSINESS_RULE` | voiding would drive on-hand **< 0** because the received stock was already sold → still records the reversal, sets `warnings:["oversold_after_void"]`, raises an oversold flag (see §7) |

> **Proposed schema addition:** `purchases` has `status ENUM(... 'void')` but no
> `void_reason` / `voided_by` / `voided_at`. Add `void_reason VARCHAR(255) NULL`,
> `voided_by BIGINT UN NULL`, `voided_at DATETIME NULL` to `purchases` for a first-class
> void trail. Until then, the void reason lives in `stock_movements.note` + `audit_log`.

---

## 5. Business logic & validation

**Atomic transaction on `POST /purchases` (status `confirmed`):**
```
BEGIN
  IF exists(client_uuid) → return {DUPLICATE_IGNORED, original purchase}
  validate supplier_id, gstin_id (active), every product_id (exists/synced)
  FOR each item:
     gst_amount  = round(quantity × cost_price × gst_rate/100)
     line_total  = quantity × cost_price + gst_amount
  subtotal   = Σ(quantity × cost_price)
  total_gst  = Σ gst_amount
  total_cost = subtotal + total_gst
  INSERT purchases(header, computed totals, status='confirmed')      -- server id
  INSERT purchase_items(...)                                          -- per line
  INSERT stock_movements(purchase_in, +quantity, ref_type='purchase',
                         ref_id=purchase_id, ref_client_uuid, staff_id, device_id,
                         occurred_at=invoice_date/now)                -- per line
  UPDATE products.cost_price = item.cost_price                        -- latest cost cache
  INSERT sync_log(status='applied')
  reconciled = recompute_stock(affected product_ids)                 -- SUM(quantity_delta)
COMMIT
```
- **All-or-nothing:** if any line fails validation the whole purchase rolls back; nothing
  half-applies.
- **Server owns money math:** `gst_amount`, `line_total`, and all totals are recomputed
  server-side (round-half-up to paise); client-sent totals are only a checksum
  (`422 BUSINESS_RULE` if they disagree beyond a paisa tolerance — configurable).
- **`gst_rate` snapshot:** each `purchase_items.gst_rate` is snapshotted at purchase time so
  later product rate edits don't rewrite ITC history.
- **CGST/SGST vs IGST:** determined by comparing the `gst_registrations.state_code` of
  `gstin_id` with the `supplier_gstin` state code — same state → CGST+SGST split, different
  → IGST. Stored/derived for the GST module ([gst-api](../gst/gst-api.md)); the total
  `total_gst` is unaffected by the split.
- **`cost_price` update:** confirming a purchase updates `products.cost_price` to the line's
  cost (latest-cost model, used for profit estimates). Voids do **not** revert `cost_price`
  (it's a cache; the next purchase corrects it).
- **`draft` status:** a draft purchase writes header/items but **no** `stock_movements` and
  **no** `cost_price` update; confirming the draft later applies both.

**Void logic:**
```
BEGIN
  load purchase (must be 'confirmed'); if 'void' → return existing reversal
  FOR each purchase_item:
     INSERT stock_movements(void_reversal, −quantity, ref_type='purchase',
                            ref_id=purchase_id, note=reason)
  UPDATE purchases.status='void'
  reconciled = recompute_stock(affected product_ids)
  IF any on_hand < 0 → emit oversold flag/notification (goods already sold)
COMMIT
```

## 6. Sync & conflict handling
- **Idempotent replay:** `client_uuid` (UNIQUE) dedupes retries and duplicate `/sync/push`
  pushes; a second arrival returns `DUPLICATE_IGNORED` — **never** double stock
  (sync doc §5–6).
- **Event-sourced stock:** purchases only ever **append** `purchase_in` movements; on-hand =
  `SUM(quantity_delta)`. Concurrent purchases/sales are additive, never a lost update.
- **Ordering dependency:** a purchase line referencing a not-yet-synced `product_id` returns
  `409 CONFLICT`; the outbox FIFO pushes the product create first, then retries (sync doc
  decision table). `ref_client_uuid` ties the movement to the offline txn before the server
  id exists.
- **Reconciliation:** after apply/void the server recomputes on-hand for affected products
  and returns `reconciled_stock`; the client replaces its optimistic hint with this truth.
- Owner purchase entry is usually online, but the apply path is identical whether it arrives
  direct (`POST /purchases`) or batched (`/sync/push`).

## 7. Edge cases & failure modes
1. **Duplicate submit / retry** → same `client_uuid` → one purchase, `DUPLICATE_IGNORED` on
   the rest.
2. **Partial batch via `/sync/push`** → one bad purchase item is rejected independently; the
   rest of the batch still applies (sync doc §6).
3. **Product not synced yet** → `409 CONFLICT`; retried after the product create pushes.
4. **Void after the received stock was already sold** → reversal still recorded; on-hand may
   go negative → oversold flag + physical-count request (mirrors the sale oversold path in
   [sales-api](../sales/sales-api.md) §; sync doc §5).
5. **Missing `supplier_gstin`** → accepted; `itc_risk=true`; surfaced in the GST
   reconciliation view for follow-up before filing.
6. **Future `invoice_date`** → `422 BUSINESS_RULE`.
7. **Money checksum mismatch** → server totals win; if the client checksum is off beyond
   tolerance, `422` so the client can re-derive and resubmit under the same `client_uuid`.
8. **Draft never confirmed** → no stock impact; appears in ledger only with `status=all`.

## 8. Performance & indexing
- **Write path** is a short transaction (1 header + N items + N movements + N cost updates);
  N is small (a supplier invoice). Batch the movement `INSERT`s.
- **Ledger reads** rely on `purchases` supplier FK, `gstin_id`, and `invoice_date`; add/keep
  a `KEY (gstin_id, invoice_date)` and `KEY (supplier_id, invoice_date)` for supplier-wise
  and period rollups. Cursor pagination for large date ranges.
- **Stock recompute** uses `stock_movements.idx_product`; on-hand served via
  `v_current_stock` (or a materialized cache at scale — see [stock-api](../stock/stock-api.md)).
- **Export (`csv/xlsx`)** streams to avoid buffering large ledgers in memory.

## 9. Related docs
- Screens: [owner/new-purchase](../../../mobile/owner/purchase/new-purchase.md) ·
  [web/purchase-ledger](../../web/purchases/purchase-ledger.md) ·
  [web/gst-filing](../../web/gst/gst-filing.md)
- Sibling APIs: [suppliers-api](../suppliers/suppliers-api.md) ·
  [products-api](../products/products-api.md) · [stock-api](../stock/stock-api.md) ·
  [gst-api](../gst/gst-api.md) · [sync-api](../sync/sync-api.md)
- Foundation: [sync-and-conflict-resolution](../../../foundation/sync-and-conflict-resolution.md) ·
  [data-model](../../../foundation/data-model.md) ·
  [api-conventions](../../../foundation/api-conventions.md)
