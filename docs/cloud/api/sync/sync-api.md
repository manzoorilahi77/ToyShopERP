# Sync API

> Base URL, envelope, headers, error codes and pagination live in
> [`api-conventions.md`](../../../foundation/api-conventions.md) — referenced, not repeated.
> Paths are relative to `…/v1`. **This is the concrete REST surface for
> [`sync-and-conflict-resolution.md`](../../../foundation/sync-and-conflict-resolution.md)** —
> that foundation doc is the design; this doc is the wire contract. They must stay in lockstep.

---

## 1. Overview

The staff app is **offline-first**: every sale/purchase/stock-adjustment is written to local
Drift **first** and the receipt is shown in < 100 ms; the network is never on the critical
path (R1, cross-cutting principle 1). A background **WorkManager** worker drains the local
outbox to the server and pulls server changes back.

This module is that server boundary:

| Endpoint | Direction | Purpose |
|---|---|---|
| `POST /sync/push` | client → server | batch-upload self-describing, idempotent outbox items; per-item ack |
| `GET /sync/pull` | server → client | fetch server changes since a cursor (reconciled stock, invoice numbers, approvals, new products, notifications) |
| `GET /sync/status` | diagnostic | server-side view of this device's sync health |

Push does not implement business logic itself — it **dispatches** each item to the same apply
logic as the direct endpoints ([`/sales`](../sales/sales-api.md),
[`/purchases`](../purchases/purchases-api.md),
[`/products`](../products/products-api.md), stock adjust). The value it adds is **batching,
FIFO ordering, per-item acking, and idempotent dedupe**.

## 2. Data model touched

Source of truth: [`data-model.md`](../../../foundation/data-model.md).

| Table | R/W | Role |
|---|---|---|
| `sync_log` | write | one row per received item: `transaction_type`, `transaction_id`, `client_uuid`, `device_id`, `status` (`received\|applied\|duplicate_ignored\|failed`), `error_message`, `retry_count`, `synced_at`. **Idempotency + audit trail.** |
| `sales`, `sale_items` | write | via sale apply (idempotent by `client_uuid`). |
| `purchases`, `purchase_items` | write | via purchase apply. |
| `products` | write | via product create apply. |
| `stock_movements` | write | `sale_out` / `purchase_in` / `adjustment` appended (source of truth). |
| `devices` | read/write | `last_seen`, cursor bookkeeping. |
| `notifications`, `discount_approvals`, `gst_registrations` | read | surfaced by `/sync/pull`. |

### Proposed schema addition

| Addition | Where | Why |
|---|---|---|
| a monotonic change feed — either rely on `updated_at`+`id` per entity, or add `change_feed(id BIGINT AUTO, entity_type, entity_id, op, changed_at)` | new (optional) | `GET /sync/pull?since=<cursor>` needs a **totally-ordered** stream of server changes. `updated_at` cursors work at this scale but can tie on equal timestamps; a dedicated append-only feed gives a gapless, resumable cursor. Treated as `🧩 Derived`. |

## 3. Auth & permissions

| Endpoint | Auth | Roles | Notes |
|---|---|---|---|
| `POST /sync/push` | Bearer + `X-Device-Id` | `staff`, `owner` | worker uses the logged-in staff's token (conventions §2) |
| `GET /sync/pull` | Bearer + `X-Device-Id` | `staff`, `owner`, `accountant` | |
| `GET /sync/status` | Bearer + `X-Device-Id` | any | own device only |

- **Per-item authorization** inside a push still applies (e.g. a `discount_amount > 0` sale
  item requires owner-PIN authorization — that item is `rejected` while others apply).
- `X-Device-Id` must match the batch `device_id`; mismatch → `403`.

---

## 4. Endpoints

### `POST /sync/push`
- **Purpose** — upload a batch of outbox items; apply each idempotently; ack each
  independently.
- **Auth** — Bearer (`staff`/`owner`) + `X-Device-Id`.
- **Idempotency** — **every item carries `client_uuid`**; the whole endpoint is safe to
  replay. Already-applied items return `duplicate_ignored` (a **success** for the client).
  An optional batch-level `Idempotency-Key` may dedupe an entire re-pushed batch.
- **Path / query params** — none.
- **Request body**

| Field | Type | Required | Validation | Notes |
|---|---|---|---|---|
| `device_id` | string | **yes** | ≤ 64, = `X-Device-Id` | source device |
| `items` | array | **yes** | 1–200 items | pushed in **FIFO / creation order** |
| `items[].entity_type` | enum | yes | `sale\|purchase\|product\|stock_adjustment` | dispatch target |
| `items[].client_uuid` | string(uuid) | yes | UNIQUE per entity | idempotency key |
| `items[].occurred_at` | string(ISO) | yes | business time | maps to `sold_at`/`invoice_date`/`occurred_at` |
| `items[].payload` | object | yes | schema of the target endpoint | the create body (see sibling API docs) |
| `items[].seq` | integer | no | client outbox order | server preserves order; ties broken by array index |

- **Request example** (mirrors sync doc §4):

```json
{
  "device_id": "dev-abc123",
  "items": [
    {
      "entity_type": "sale",
      "client_uuid": "0f8b…-uuid",
      "occurred_at": "2026-07-02T19:45:12+05:30",
      "payload": {
        "staff_id": 4, "gstin_id": 1, "payment_mode": "upi",
        "items": [{ "product_id": 22, "quantity": 2, "unit_price": "1499.00" }],
        "discount_amount": "0", "total": "2998.00"
      }
    }
  ]
}
```

- **Response `200`** — per-item results in **the same order as the request** (envelope
  `data.results`):

| Field | Type | Notes |
|---|---|---|
| `client_uuid` | string | echoes the item |
| `entity_type` | enum | echoes |
| `status` | enum | `applied \| duplicate_ignored \| rejected` |
| `server_id` | integer\|null | assigned id (present on `applied`; on `duplicate_ignored` the original id) |
| `invoice_no` | string\|null | sale only — server-assigned, per-GSTIN gapless |
| `reconciled_stock` | object\|null | `{ "<product_id>": on_hand }` after apply |
| `oversold` | array | product_ids that went `< 0` (sale/purchase-void) |
| `error` | object\|null | on `rejected`: `{ code, message, field }` (canonical error codes) |

```json
{ "ok": true,
  "data": { "results": [
    { "client_uuid": "0f8b…-uuid", "entity_type": "sale", "status": "applied",
      "server_id": 5012, "invoice_no": "GST1/26-27/000418",
      "reconciled_stock": { "22": 7 }, "oversold": [], "error": null }
  ]},
  "meta": { "request_id": "req_…", "applied": 1, "duplicate_ignored": 0, "rejected": 0 } }
```

- **`status` semantics**

| `status` | Client action |
|---|---|
| `applied` | mark local row `synced`, delete from outbox, stamp `server_id`/`invoice_no` |
| `duplicate_ignored` | **success** — already recorded; mark synced, **do not** retry |
| `rejected` | inspect `error.code`: retryable (`409 CONFLICT` missing dep) → backoff & retry after pull; terminal (`400/422`) → surface for manual fix |

- **Status codes & errors** (batch-level; per-item errors ride inside `results`)

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | batch accepted; see per-item `status` (partial success is normal) |
| 400 | `VALIDATION_ERROR` | malformed batch, > 200 items, unknown `entity_type` |
| 401 | `UNAUTHENTICATED` | no/expired token → worker refreshes and retries |
| 403 | `FORBIDDEN` | `device_id` ≠ `X-Device-Id` |
| 429 | `RATE_LIMITED` | throttle; honor `Retry-After` + backoff |

> **A failing item never poisons the batch** — others still apply (sync doc §6). The HTTP
> status is `200` even if some items are `rejected`.

---

### `GET /sync/pull`
- **Purpose** — fetch everything that changed on the server since the client's cursor:
  reconciled stock, invoice numbers assigned to this device's sales, new/edited products,
  approvals, notifications.
- **Auth** — Bearer + `X-Device-Id`. **Idempotency** — N/A (read; cursor is resumable).
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `since` | query | string | no | — | opaque cursor from the previous pull; omit for a full baseline sync |
| `entity_types` | query | csv | no | all | limit to e.g. `products,stock,invoices` |
| `limit` | query | integer | no | `500` | page size; use `next_cursor` to continue |

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `changes` | object | grouped by entity type (below) |
| `changes.products` | array | created/edited products (LWW by `updated_at`) |
| `changes.stock` | array | `{ product_id, on_hand }` reconciled snapshots |
| `changes.invoices` | array | `{ client_uuid, sale_id, invoice_no }` numbers assigned to this device's sales |
| `changes.approvals` | array | resolved `discount_approvals` (`approved/rejected`) |
| `changes.notifications` | array | `low_stock`, `aging_stock`, oversold, `sync_failure`, `discount_request` |
| `next_cursor` | string | pass as `since` next time |
| `has_more` | boolean | true if more pages remain |
| `server_time` | string(ISO) | for clock-skew correction |

```json
{ "ok": true,
  "data": {
    "changes": {
      "products": [ { "id": 231, "name": "Blue Speedster Bike", "selling_price": "1799.00",
                      "updated_at": "2026-07-02T18:10:04+05:30" } ],
      "stock":    [ { "product_id": 22, "on_hand": 7 } ],
      "invoices": [ { "client_uuid": "0f8b…-uuid", "sale_id": 5012,
                      "invoice_no": "GST1/26-27/000418" } ],
      "approvals":[ { "sale_client_uuid": "1a2b…-uuid", "status": "approved",
                      "approved_by": 1 } ],
      "notifications": [ { "id": 77, "type": "low_stock", "title": "Red Racer low (2 left)",
                           "ref_type": "product", "ref_id": 22 } ]
    },
    "next_cursor": "eyJ0IjoiMjAyNi0wNy0wMlQxODoxMDowNCswNTozMCIsImlkIjo1MDEyfQ",
    "has_more": false,
    "server_time": "2026-07-02T20:12:00+05:30"
  },
  "meta": { "request_id": "req_…" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | malformed `since` cursor |
| 401 | `UNAUTHENTICATED` | no token |
| 409 | `CONFLICT` | cursor too old / feed truncated → client does a full baseline pull (`since` omitted) |

---

### `GET /sync/status`
- **Purpose** — diagnostic snapshot the sync-status indicator can corroborate; also for
  support ("why is this device stuck?").
- **Auth** — Bearer + `X-Device-Id`. **Idempotency** — N/A.
- **Path / query params** — none (scoped to the calling device).
- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `device_id` | string | |
| `server_pending` | integer | items received but not yet `applied` (should be ~0) |
| `last_applied_at` | string(ISO)\|null | last successful apply for this device |
| `last_pull_cursor` | string\|null | server's view of the device cursor |
| `failed_items` | array | `[{ client_uuid, entity_type, error_code, retry_count }]` from `sync_log` |
| `clock_skew_ms` | integer | `server_time − client_time` estimate (send `?client_time=`) |

```json
{ "ok": true,
  "data": { "device_id": "dev-abc123", "server_pending": 0,
            "last_applied_at": "2026-07-02T20:11:58+05:30",
            "last_pull_cursor": "eyJ0Ijoi…", "failed_items": [], "clock_skew_ms": 120 },
  "meta": { "request_id": "req_…" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 401 | `UNAUTHENTICATED` | no token |

---

## 5. Business logic & validation

**Server apply loop for `POST /sync/push`** (mirrors sync doc §6; per item, transactional):
```
results = []
FOR item IN items ORDERED BY (seq, index):        -- FIFO / causal order
  BEGIN
    INSERT sync_log(status='received')
    IF exists(client_uuid for entity_type):
       results += { status:'duplicate_ignored', server_id, invoice_no }
       UPDATE sync_log(status='duplicate_ignored'); COMMIT; CONTINUE
    validate payload against target endpoint schema (refs must exist / be synced)
    dispatch by entity_type:
       sale     → apply_sale(payload)        -- INSERT sale+items+sale_out; allocate invoice_no
       purchase → apply_purchase(payload)    -- INSERT purchase+items+purchase_in; cost update
       product  → apply_product(payload)     -- INSERT product (+ dup re-check → review queue)
       stock_adjustment → INSERT stock_movements(adjustment, ±qty)
    reconciled = recompute_stock(affected product_ids)     -- SUM(quantity_delta)
    IF any on_hand < 0 → oversold; emit notification; flag for count
    UPDATE sync_log(status='applied', transaction_id=server_id)
    results += { status:'applied', server_id, invoice_no, reconciled_stock, oversold }
    COMMIT
  EXCEPTION → ROLLBACK this item only;
    UPDATE sync_log(status='failed', error_message);
    results += { status:'rejected', error:{code,message} }
return { results }
```
- **All-or-nothing per item**, never per batch — one bad item rolls back only itself.
- **FIFO ordering** preserves causality: a "create product" item is applied before the "sell
  it" item that follows it in the same device's outbox (sync doc §3). Independent entities may
  interleave; `client_uuid` makes accidental reordering safe.
- **Dedupe** is the `client_uuid` existence check up front → `duplicate_ignored`.
- **Reconciliation** = recompute on-hand from `stock_movements` after each apply; returned as
  `reconciled_stock`. Never `UPDATE qty = qty − 1`.
- **Invoice allocation** happens inside `apply_sale`, per-GSTIN gapless
  ([sales-api](../sales/sales-api.md) §5).

**Pull semantics:**
- `since` is an **opaque, resumable** cursor (encodes last `updated_at` + tiebreak `id`, or a
  `change_feed` position). Omitting it → full baseline. Paginate via `next_cursor`/`has_more`.
- Pull returns **only what this device needs**: invoice numbers for *its* sales, reconciled
  stock for touched products, catalog edits (LWW), resolved approvals, and notifications
  targeted to the role/staff.

## 6. Sync & conflict handling
This **is** the sync module; the conflict rules from
[`sync-and-conflict-resolution.md`](../../../foundation/sync-and-conflict-resolution.md) §5
apply verbatim:

| Scenario | Resolution |
|---|---|
| Same product sold offline by 2+ staff | Both `sale_out` append; on-hand = sum. No conflict. |
| Product attribute edited on 2 devices | Latest `updated_at` wins (LWW) — surfaced via `/sync/pull`. |
| Duplicate push of same `client_uuid` | `duplicate_ignored`; no double-count. |
| Sale references product not yet synced | FIFO pushes product first; else item `rejected` (`409`) → retry after next pull. |
| Reconciled on-hand < 0 | Apply anyway; return `oversold`; notify owner; flag for count. |
| Offline sale then item deleted on server | Sale applies; product auto-reactivated + flagged. |

**Backoff (client worker, sync doc §3):** on `rejected`-retryable or transport failure,
increment `attempts`, set `next_attempt_at = min(2^attempts, 300)s + jitter`; keep `failed`;
no tight loop. `429` honors `Retry-After`. Owners get a `sync_failure` notification when an
item exceeds the retry ceiling.

**Ordering guarantee:** items for the same entity are pushed sequentially; independent
entities may batch. Because every item is idempotent by `client_uuid`, accidental reordering
or double-send is always safe.

## 7. Edge cases & failure modes
1. **Partial batch success** → `200` with mixed `applied`/`rejected`; client marks the good
   ones synced, retries only the retryable rejects.
2. **Duplicate push (retry after a lost ack)** → all items `duplicate_ignored`; client
   reconciles state and clears the outbox. (Tested: same `client_uuid` 3× → one row, two
   `duplicate_ignored`.)
3. **Missing dependency** (`product` not yet applied) → dependent `sale`/`purchase` item
   `rejected` with `409`; FIFO usually prevents this, but a reordered/interleaved batch
   retries after the product applies.
4. **Cursor expired/truncated** on pull → `409`; client drops its cursor and does a full
   baseline pull.
5. **Token expiry mid-sync** → `401`; worker silently `/auth/refresh`es
   ([auth-api](../auth/auth-api.md)) and retries; refresh revoked → re-login without losing
   the outbox.
6. **Clock skew** → `server_time`/`clock_skew_ms` let the client correct `occurred_at`
   drift; server accepts business times with bounded skew (never rejects a real sale).
7. **Oversold surfaced on pull** → an oversold notification arrives; owner triggers a
   physical count; the sale itself is never reverted.
8. **Very large outbox after long offline** → batches capped at 200 items; worker loops
   batches in FIFO order until drained, pulling between cycles.
9. **Network flaps mid-batch** → items already acked are `synced` locally; unacked items stay
   `pending` and re-push (idempotent), so no double application.

## 8. Performance & indexing
- **Push** cost ≈ N short transactions; cap N at 200 to bound latency and lock hold time.
  `sync_log` is append-mostly; index `KEY (client_uuid)` and `KEY (device_id, synced_at)` for
  dedupe lookups and status queries.
- **Idempotency check** hits the UNIQUE `client_uuid` on `sales`/`purchases`/`products` — an
  index seek, not a scan.
- **Pull** is served from `updated_at` indexes per entity (or the `change_feed`); keep
  `limit ≤ 500` and paginate. Baseline pulls (no `since`) are the heaviest — throttle and
  allow resumable paging.
- **Stock reconciliation** uses `stock_movements.idx_product`; at scale, maintain a
  materialized on-hand cache updated in the apply transaction (see
  [stock-api](../stock/stock-api.md)) so pull doesn't recompute sums repeatedly.
- **Rate limiting** per device + token (conventions §10); the worker respects `Retry-After`
  and its own backoff so it never hammers the server.

## 9. Related docs
- Foundation (read first): [sync-and-conflict-resolution](../../../foundation/sync-and-conflict-resolution.md) ·
  [data-model](../../../foundation/data-model.md) (`sync_log`, `stock_movements`) ·
  [api-conventions](../../../foundation/api-conventions.md)
- Sibling APIs (dispatch targets): [sales-api](../sales/sales-api.md) ·
  [purchases-api](../purchases/purchases-api.md) · [products-api](../products/products-api.md) ·
  [stock-api](../stock/stock-api.md) · [auth-api](../auth/auth-api.md)
- Screens: consumed by every staff screen — esp.
  [staff/new-sale](../../../mobile/staff/sales/new-sale.md) and the sync-status indicator on
  [staff/dashboard](../../../mobile/staff/dashboard/dashboard-home.md)
