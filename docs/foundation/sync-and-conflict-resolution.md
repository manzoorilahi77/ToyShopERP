# Foundation — Continuous Sync + Offline Fallback + Conflict Resolution

Implements **Requirement 1**. This is the highest-risk component in the system because
multiple staff can sell the same product offline at the same time, and naive stock
counters would go negative or drift. Build and test this before any Flutter UI.

---

## 1. Principles

1. **The sale never blocks.** Every staff action writes to local Drift **first** and
   returns success instantly. Network is never on the critical path.
2. **Server owns stock truth.** The client's local stock number is a *hint* for UX only.
   The server recomputes real stock from the immutable `stock_movements` event log.
3. **Idempotent by `client_uuid`.** Every offline transaction gets a UUID at creation.
   Replays (retries, duplicate pushes) are deduped server-side — safe to push twice.
4. **Event-sourced stock.** We never `UPDATE stock SET qty = qty - 1`. We `INSERT` a
   movement row. Stock is `SUM(quantity_delta)`. This makes concurrent offline sales
   *additive*, not conflicting.

---

## 2. Client write path (staff app)

```
User confirms sale
   │
   ├─ 1. INSERT into Drift: sales(client_uuid, …, sync_status='pending')
   │        + sale_items + a local stock_movements(sale_out, −qty) row
   ├─ 2. Optimistically decrement local cached stock (UX hint only)
   ├─ 3. Show receipt / success  ← user is done, <100ms
   │
   └─ 4. Fire-and-forget: enqueue outbox item → try immediate POST /sync/push
            success → mark synced
            offline/fail → leave 'pending'; WorkManager will retry
```

**Outbox table (Drift):** `sync_outbox(id, entity_type, client_uuid, payload_json,
sync_status, attempts, next_attempt_at, last_error, created_at)`.

---

## 3. Background sync worker

- **Scheduler:** Android **WorkManager** periodic + expedited task; iOS BGTaskScheduler;
  web falls back to an in-tab timer (web is mostly online anyway).
- **Connectivity:** `connectivity_plus` stream; on `online` transition, kick the worker.
- **Loop:**
  1. Read all `pending`/`failed` outbox items **in creation order** (FIFO preserves
     causal order: product created before it's sold, etc.).
  2. Batch-push via `POST /sync/push` (see [api/sync](../cloud/api/sync/sync-api.md)).
  3. On per-item ack: mark `synced`, delete from outbox, update local row `sync_status`.
  4. On per-item failure: increment `attempts`, set `next_attempt_at` with **exponential
     backoff** (`min(2^attempts, 300) s` + jitter), keep as `failed`.
  5. After a full pull cycle, `GET /sync/pull?since=<cursor>` to fetch server changes
     (new products, reconciled stock, invoice numbers assigned to your sales, approvals).
- **Ordering guarantee:** items for the same entity are pushed sequentially; independent
  entities may batch. `client_uuid` makes any accidental reordering safe.

---

## 4. The sync envelope

**Push** (`POST /sync/push`) sends a batch; each item is self-describing and idempotent:

```json
{
  "device_id": "dev-abc123",
  "items": [
    {
      "entity_type": "sale",
      "client_uuid": "0f8b...-uuid",
      "occurred_at": "2026-07-02T19:45:12+05:30",
      "payload": { "staff_id": 4, "gstin_id": 1, "payment_mode": "upi",
                   "items": [{ "product_id": 22, "quantity": 2, "unit_price": 1499.00 }],
                   "discount_amount": 0, "total": 2998.00 }
    }
  ]
}
```

**Response** acks each item independently:

```json
{ "results": [
  { "client_uuid": "0f8b...-uuid", "status": "applied",
    "server_id": 5012, "invoice_no": "GST1/26-27/000418",
    "reconciled_stock": { "22": 7 } }
]}
```

`status ∈ applied | duplicate_ignored | rejected`. `duplicate_ignored` is a **success**
from the client's view (already recorded) — mark synced, don't retry.

---

## 5. Conflict resolution: "last-write-wins with quantity reconciliation"

The brief's rule, made concrete:

- **Stock quantity is never "won" by one client.** Because stock is `SUM(quantity_delta)`,
  two offline sales of the same product both append `sale_out` rows and *both count*.
  There is no lost update. Example: on-hand 10, Staff A sells 3 offline, Staff B sells 4
  offline; after both sync, server has movements `−3` and `−4` → on-hand **3**. Correct,
  no matter the arrival order.
- **Last-write-wins applies to mutable *attributes*, not to stock deltas.** For product
  edits (price, name, shelf), the row with the latest `updated_at` wins; deltas never
  conflict.
- **Negative-stock guard:** the server accepts the movement (never rejects a completed
  sale — the goods physically left the shop) but if reconciled on-hand goes **< 0**, it:
  1. still records the sale,
  2. sets on-hand's floor logic and raises a `low_stock`/`oversold` notification,
  3. flags the product for a physical stock-count review.
  Rationale: a real sale happened; we surface the data error rather than silently drop
  revenue. This is the "preventing negative-stock errors after sync" intent — prevent
  *corrupt counters*, not *refuse reality*.

```
Reconcile(product_id):
  on_hand = SUM(quantity_delta) over stock_movements WHERE product_id
  cache v_current_stock / materialized table = on_hand
  if on_hand < 0:  emit notification(type='oversold'), flag for count
```

### Decision table

| Scenario | Resolution |
|---|---|
| Same product sold offline by 2+ staff | Both movements append; stock = sum. No conflict. |
| Product attribute edited on 2 devices | Latest `updated_at` wins (LWW). |
| Duplicate push of same `client_uuid` | Server returns `duplicate_ignored`; no double-count. |
| Sale references product not yet synced | Outbox FIFO pushes the `product` create first; if still missing, server 409 → retry after pull. |
| Reconciled stock < 0 | Record sale, flag oversold, notify owner, request count. |
| Offline sale then item deleted on server | Sale still applies (goods left); product auto-reactivated + flagged. |

---

## 6. Server apply logic (per item, transactional)

```
BEGIN
  IF exists(client_uuid) → return {status: duplicate_ignored, server_id}
  validate payload (schema, refs)
  INSERT sale (+ items)                      -- assign server id, invoice_no by GSTIN seq
  INSERT stock_movements(sale_out, −qty) …   -- one per line
  UPDATE sync_log(status='applied')
  reconciled = recompute_stock(affected_product_ids)
COMMIT
return {status: applied, server_id, invoice_no, reconciled_stock}
```

All-or-nothing per item; a failing item doesn't poison the batch (others still apply).

---

## 7. Invoice numbering

Invoice numbers are **assigned by the server on apply**, per `gstin_id`, from a gapless
sequence (`GST{gstin}/{fy}/{seq}`). Clients show a provisional local ref until sync
returns the real `invoice_no` (pulled back and shown on the receipt/history).

---

## 8. Sync status indicator (UX)

A subtle icon, never intrusive during billing (Requirement 1):

| State | Icon | Meaning |
|---|---|---|
| synced | ✓ cloud (muted) | all local data confirmed by server |
| syncing | ↻ spinning | pushing/pulling now |
| pending | • dot (amber) | N items queued, will sync when online |
| failed | ! (red, tappable) | retries exhausted for some item → tap for detail |

Long-press/tap opens a small sheet: counts by state + "retry now". Owners also get a
`sync_failure` notification if an item exceeds the retry ceiling.

---

## 9. Testing checklist (must pass before UI work)

- [ ] Two devices sell the same product offline; after sync, on-hand = start − total.
- [ ] Push the same `client_uuid` 3× → exactly one sale, two `duplicate_ignored`.
- [ ] Kill the app mid-sale → sale survives in Drift, syncs on relaunch.
- [ ] Backoff schedule observed; no tight retry loop hammering the server.
- [ ] Oversold path records the sale and raises the flag/notification.
- [ ] Pull applies server-assigned `invoice_no` back onto the local sale.
- [ ] FIFO ordering: offline "create product → sell it" both apply in order.

## 10. Related docs
- [api/sync](../cloud/api/sync/sync-api.md) · [data-model.md](data-model.md) (`stock_movements`, `sync_log`)
- consumed by every staff screen — esp. [new-sale](../mobile/staff/sales/new-sale.md)
