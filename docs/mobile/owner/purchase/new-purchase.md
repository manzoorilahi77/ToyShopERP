# New Purchase — Owner · Mobile (Owner App)

> The stock-in flow (Requirement 4 · Purchase). Select or add a supplier, add item(s) by
> photo/QR with **duplicate auto-suggest** (route quantity to the existing product or
> confirm-as-new), enter qty + cost price + GST rate, choose the **GSTIN** the purchase is
> filed under, capture the **supplier GSTIN** for input-tax-credit, review a summary, and
> confirm — which appends `stock_movements(purchase_in)` and updates stock instantly.

Status: `✅ Specified` · idempotent write (`purchases.client_uuid`). No `🔒` gate (owner
is already authenticated; creating a product may enqueue duplicate review).

---

## 1. Purpose & context
- **What this screen is for:** get newly arrived stock into the system correctly and fast,
  without creating duplicate products, and with GST captured for later filing.
- **Who & when:** the **owner** or a designated user, typically when a supplier delivery
  arrives (mornings / restock days), off the peak sales rush.
- **Why it exists:** products arrive with **no barcodes/SKUs**; sloppy intake causes
  "wrong pricing, lost stock counts, and aging stock piling up unnoticed"
  ([requirements](../../../requirements_and_prompt.md)). Correct purchase entry is also the
  source of **input tax credit** — missing supplier GSTIN is an ITC-risk flag at filing.
- **Frequency / criticality:** a few times a week, high value per transaction. A duplicate
  product here splits stock counts permanently, so duplicate-check is central.

---

## 2. Entry points & navigation
- **＋Purchase** quick-nav chip and bottom-nav **Purchase** tab on
  [Dashboard Home](../dashboard/dashboard-home.md).
- **"Create purchase order"** shortcut from a low-stock alert (pre-fills the low product).

```
Dashboard ─▶ New Purchase
   ①Supplier → ②Add items (photo/QR → dup-check → qty+cost+gst) → ③GSTIN & supplier GSTIN
   → ④Review summary → Confirm ─▶ stock updated ─▶ back to Dashboard (toast)
```
- **Back button:** within the multi-step flow, back = previous step; from step ① back =
  discard draft (confirm). A confirmed purchase cannot be edited here (void on web).

---

## 3. Roles & permissions
| Actor | Access |
|---|---|
| Owner | ✅ full: create supplier, create product, confirm purchase |
| Accountant | ✅ if designated `🧩` (create purchases, edit GSTIN fields) |
| Staff | ❌ (Owner-App screen; "designated staff" would use a granted owner build) |
- No owner-PIN gate on confirm. Creating a **new product** may enqueue a
  `duplicate_review_queue` row (reviewed later on [web catalog](../../../cloud/web/catalog/product-catalog-management.md)).

---

## 4. Screen layout (wireframe)

```
STEP ① SUPPLIER                         STEP ② ADD ITEMS
┌──────────────────────────────┐        ┌────────────────────────────────────┐
│ ← New Purchase        ✓sync   │        │ Supplier: Sunrise Toys ▾   Items(2) │
│ Supplier                      │        │ ┌───────────────────────────────┐   │
│ [ 🔍 search supplier…      ]  │        │ │ (photo) Red Racer Car         │   │
│  • Sunrise Toys (27ABC…1Z5)   │        │ │ Qty [ 12 ]  Cost ₹[ 850.00 ]  │   │
│  • Global Kids                │        │ │ GST [18%▾]  = ₹10,200 +₹1,836 │   │
│  • Playtime Distributors      │        │ │  [dup? matched existing ✓]    │   │
│  [ ＋ Add new supplier ]      │        │ └───────────────────────────────┘   │
│                               │        │ ┌───────────────────────────────┐   │
│ [ Continue ▸ ]                │        │ │ (photo) Blue Jet Bike (NEW)   │   │
└──────────────────────────────┘        │ │ Qty [ 6 ] Cost ₹[ 1,900.00 ]  │   │
                                          │ │ GST [18%▾]                    │   │
   [ 📷 Add item ] [ 🔳 Scan QR ]         │ └───────────────────────────────┘   │
                                          │ [ 📷 Add item ]  [ Review ▸ ]       │
                                          └────────────────────────────────────┘

STEP ③ GSTIN & SUPPLIER GSTIN            STEP ④ REVIEW SUMMARY
┌──────────────────────────────┐        ┌────────────────────────────────────┐
│ File under GSTIN              │        │ Supplier: Sunrise Toys              │
│ [ 27ABCDE1234F1Z5 ▾ ] (active)│        │ File under: 27ABCDE1234F1Z5         │
│ Supplier GSTIN (ITC)          │        │ Supplier GSTIN: 27PQRS…  ✓          │
│ [ 27PQRSX9876G1Z2  ]  ✓valid  │        │ Invoice: [INV-4471] Date[30-06-2026]│
│ Invoice no [ INV-4471       ] │        │ ─────────────────────────────────── │
│ Invoice date [ 30-06-2026 ]   │        │ Items 2 · Qty 18                    │
│ [ Continue ▸ ]                │        │ Subtotal      ₹  21,600.00          │
└──────────────────────────────┘        │ Total GST     ₹   3,888.00          │
                                          │ Total cost    ₹  25,488.00          │
                                          │        [  ✓ Confirm Purchase  ]     │
                                          └────────────────────────────────────┘
```

- **Responsive:** phone = step-by-step; tablet may show supplier + item list side by side.

---

## 5. UI components & field-by-field spec

### 5a. Supplier step
| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Supplier search | search input | `GET /suppliers?q=` (`suppliers.name`) | required to continue | empty | live results | fuzzy on name |
| 2 | Supplier result | list row | `suppliers.id/name/gstin` | — | — | select → sets purchase supplier | shows supplier GSTIN if known |
| 3 | Add new supplier | button → sheet | `POST /suppliers` | `name` required; `gstin` optional (format if given); `phone/address` optional | — | creates + selects | missing GSTIN allowed → ITC flag later |

### 5b. Item entry row (per `purchase_items` line) — field by field
| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 4 | Add item / Scan QR | button | camera (`image_picker`) / `mobile_scanner` | — | — | photo → dup-check; QR → resolve `internal_qr_code` | R3 QR is one-tap resolve |
| 5 | Duplicate suggestion | inline card | `POST /products/check-duplicate` | — | — | "same item? [Yes, add stock] / [No, it's new]" | see [duplicate-detection](../../../foundation/duplicate-detection.md) |
| 6 | Product (resolved) | photo + name | existing `products` or new draft | product identity required | — | sets `purchase_items.product_id` | new draft needs §5c fields |
| 7 | Quantity | integer stepper | user | required; integer `> 0` | 1 | recomputes line + summary | `purchase_items.quantity` |
| 8 | Cost price (per unit) | money input | user | required; `≥ 0`; `DECIMAL(12,2)` | product `cost_price` if known | updates `products.cost_price` on confirm (latest cost) | `purchase_items.cost_price` |
| 9 | GST rate | dropdown 0/5/12/18/28 | `products.gst_rate` default | required; ∈ {0,5,12,18,28} | product `gst_rate` (18) | recomputes `gst_amount` | snapshot to `purchase_items.gst_rate` |
| 10 | GST amount (line) | computed money | `round(qty × cost × rate/100)` | server re-computes | — | display only | `purchase_items.gst_amount` |
| 11 | Line total | computed money | `qty × cost + gst_amount` | — | — | display only | `purchase_items.line_total` |
| 12 | Remove line | swipe / ✗ | — | — | — | removes item | undoable via toast |

### 5c. New-product fields (only when confirm-as-new)
| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 13 | Product name | text | user | required; fuzzy-checked | — | re-runs text dup-check | `products.name` |
| 14 | Category | picker | `categories` | **required (R2)** | — | narrows dup scope | `products.category_id` |
| 15 | Supplier | prefilled | current supplier | **required (R2)** | selected supplier | — | `products.supplier_id` |
| 16 | Selling price | money | user | required; `DECIMAL(12,2)` | — | — | `products.selling_price` (needed to sell) |
| 17 | HSN code | text | user | optional; ≤10 chars | — | — | `products.hsn_code` (GST) |
| 18 | Primary photo | image | camera | required for dup-embedding | captured | uploads → `image_embedding` | `products.image_url` |

### 5d. GSTIN & summary step
| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 19 | File under GSTIN | dropdown | active `gst_registrations` | required; must be `is_active=1` | sole active GSTIN, else none | sets `purchases.gstin_id` | inactive GSTIN not selectable (`422`) |
| 20 | Supplier GSTIN (ITC) | text | user; may prefill from `suppliers.gstin` | optional but **recommended**; format `^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$` | `suppliers.gstin` | validates checksum-format | `purchases.supplier_gstin`; blank → ITC-risk flag |
| 21 | Invoice no | text | user | optional; ≤40 | — | — | `purchases.invoice_no` |
| 22 | Invoice date | date `DD-MM-YYYY` | picker | optional; ≤ today | today | — | `purchases.invoice_date` |
| 23 | Subtotal | computed money | `Σ line qty×cost` | — | — | display | `purchases.subtotal` |
| 24 | Total GST | computed money | `Σ line gst_amount` | — | — | display | `purchases.total_gst` (ITC total) |
| 25 | Total cost | computed money | `subtotal + total_gst` | — | — | display | `purchases.total_cost` |
| 26 | Confirm Purchase | primary 56 dp | — | ≥1 item, supplier + GSTIN set | disabled until valid | `POST /purchases` (idempotent) → `stock_movements` | writes `purchase_in` per line |

**Prose notes**
- **Duplicate-check is mandatory before creating a product.** Photo capture → embedding →
  `check-duplicate` with `name + category_id + supplier_id`. Strong single match →
  "Yes, add stock" routes the quantity to the **existing** `product_id` (no new row — the
  core anti-duplicate win). Ambiguous → save provisionally + `duplicate_review_queue`.
  QR scan of a known `internal_qr_code` **skips** dup-check (identity already certain).
- **State-code drives tax split:** `gst_registrations.state_code` vs supplier state (first
  two digits of `supplier_gstin`) determines IGST vs CGST+SGST at filing; this screen
  captures the inputs, the [GST module](../../../cloud/api/gst/gst-api.md) computes it.
- On confirm, the server: inserts `purchases` + `purchase_items`, appends one
  `stock_movements(movement_type='purchase_in', quantity_delta=+qty, ref_type='purchase',
  ref_id, staff_id, device_id)` per line, and updates each product's latest `cost_price`.

---

## 6. States
- **Default:** step ① supplier search; **Add item** disabled until a supplier is chosen.
- **Empty:** no items yet → "Add your first item by photo or QR."
- **Loading:** dup-check runs a short inline spinner on the item card; confirm shows inline
  progress (offline path returns instantly, see §10).
- **Error:** field-level validation inline; a missing GSTIN blocks confirm with a clear
  message; supplier GSTIN invalid → warning (not blocking) noting ITC risk.
- **Offline:** the whole flow works; confirm writes locally (`sync_status='pending'`) and
  shows success. Duplicate-check runs against the **local catalog cache**; a server re-check
  on sync may still enqueue a review item.
- **Success:** toast "Purchase saved · 18 units in" → return to Dashboard; stock counts
  update (server-reconciled once synced).
- **Permission-denied:** non-owner build without designation cannot open the screen.

---

## 7. Interactions, gestures & hardware
- **Camera** for item photos (feeds duplicate embedding); **QR scanner** (`ScannerOverlay`,
  torch, manual-entry fallback) resolves `internal_qr_code` in one step.
- **Stepper + `NumericPad`** for quantity and cost; big keys for fast entry.
- **Swipe-to-remove** a line; undo toast.
- **Latency budget:** dup-check result < 800 ms (server) / instant (on-device cache);
  confirm returns instantly offline, < 1.5 s online.

---

## 8. Business rules & edge cases
1. **Idempotent write:** `purchases.client_uuid` + `Idempotency-Key` header; a retried
   confirm never double-adds stock (`DUPLICATE_IGNORED`), per
   [api-conventions §6](../../../foundation/api-conventions.md).
2. **Duplicate prevention (R2):** a new product may not be saved without passing
   `check-duplicate`; category + supplier are **mandatory** scoping fields.
3. **"Yes, same item"** routes quantity to the existing `product_id` — no new product row.
4. **GSTIN required & active:** `purchases.gstin_id` must reference an `is_active=1`
   `gst_registrations` row; inactive → `422 BUSINESS_RULE`.
5. **Supplier GSTIN optional but flagged:** blank `supplier_gstin` records an ITC-risk flag
   surfaced in the [web GST reconciliation](../../../cloud/web/gst/gst-filing.md).
6. **Stock is event-sourced:** confirm appends `purchase_in` movements; on-hand is
   `SUM(quantity_delta)` — never a mutable counter
   ([sync §5](../../../foundation/sync-and-conflict-resolution.md)).
7. **Cost price updates** the product's latest `cost_price` (affects future profit
   estimates), but historical `purchase_items.cost_price` snapshots the paid price.
8. **GST amounts** are computed client-side for preview but **server is authoritative** on
   rounding (round-half-up to paise).
9. **Void, not edit:** a confirmed purchase is corrected by voiding on web
   (`purchases.status='void'` → `void_reversal` movement), never silently edited on mobile.
10. **Offline FIFO:** if a product was created offline in the same session, the outbox
    pushes the `product` create before the `purchase` that references it
    ([sync §3 ordering](../../../foundation/sync-and-conflict-resolution.md)); a still-missing
    ref returns `409 CONFLICT` → retry after pull.

---

## 9. API interactions

| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Supplier search | `GET /suppliers?q=` | find supplier | cached list |
| Add supplier | `POST /suppliers` | create supplier | queued; local id until sync |
| Add item photo | `POST /products/check-duplicate` | ranked dup candidates (image+text) | on-device cache check |
| Confirm-as-new | `POST /products` | create product (+ image upload → embedding) | queued (FIFO before purchase) |
| QR scan | `GET /products?internal_qr_code=` | resolve existing product | cache lookup |
| Confirm purchase | `POST /purchases` (`Idempotency-Key`=`client_uuid`) | write purchase + items → `stock_movements(purchase_in)` | **write locally, `sync_status='pending'`, success shown** |
| GSTIN options | `GET /gst/registrations?is_active=1` | populate "file under" | cached |

Key request fields (`POST /purchases`, see
[purchases-api](../../../cloud/api/purchases/purchases-api.md)):
```json
{ "client_uuid": "…", "supplier_id": 12, "gstin_id": 1,
  "supplier_gstin": "27PQRSX9876G1Z2", "invoice_no": "INV-4471",
  "invoice_date": "2026-06-30",
  "items": [ { "product_id": 22, "quantity": 12, "cost_price": "850.00",
               "gst_rate": "18.00" } ],
  "device_id": "dev-abc123" }
```
Response returns server `id`, computed `subtotal/total_gst/total_cost`, and
`reconciled_stock` per product. Errors: `VALIDATION_ERROR`, `409 CONFLICT` (missing ref),
`422 BUSINESS_RULE` (inactive GSTIN). Also see
[suppliers-api](../../../cloud/api/suppliers/suppliers-api.md),
[products-api](../../../cloud/api/products/products-api.md),
[duplicate-detection-api](../../../cloud/api/duplicate-detection/duplicate-detection-api.md).

---

## 10. Offline & sync behavior
- **Works fully offline:** supplier add, on-device duplicate-check against the local
  catalog cache, product create, and purchase confirm all succeed locally.
- **Queued (Drift outbox):** `product` creates, `supplier` creates, and the `purchase`
  (with `purchase_items` + local `stock_movements(purchase_in)` rows) — all
  `sync_status='pending'`, pushed FIFO so dependencies apply in order.
- **Server reconciliation:** on sync the server re-runs duplicate-check (may enqueue a
  `duplicate_review_queue` row), recomputes stock from `stock_movements`, and returns the
  server `purchases.id`. Idempotency via `client_uuid` makes replays safe.
- See [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md)
  §2–§6.

---

## 11. Analytics & events
- `purchase_started` · `purchase_confirmed` (items, qty, total_cost, gstin_id, offline: bool)
- `purchase_item_added` (source: photo | qr | search)
- `duplicate_prompt_shown` / `duplicate_resolved` (action: add_stock | new | review_queued)
- `supplier_created`
- `supplier_gstin_missing` (ITC-risk flag)

---

## 12. Accessibility, localization & performance
- Money inputs use `NumericPad` (large keys); all money `₹` + Indian grouping + tabular.
- Dates **DD-MM-YYYY**; GST rate options labelled with `%`.
- Supplier-GSTIN validity shown by icon + text (✓ valid / ! check), not color alone.
- Scanner overlay has torch + manual-entry fallback for poor light in the stockroom.
- Duplicate prompt shows both photos side-by-side at ≥ 96 dp for a confident visual compare.

---

## 13. Acceptance criteria
- [ ] A purchase cannot be confirmed without a supplier, ≥1 item, and an **active** GSTIN.
- [ ] Adding an item by photo runs `check-duplicate` before any new product is created.
- [ ] "Yes, same item" adds quantity to the existing product — no duplicate product row.
- [ ] Confirm appends one `stock_movements(purchase_in, +qty)` per line and updates on-hand.
- [ ] Each line snapshots `cost_price`, `gst_rate`, `gst_amount`, `line_total`; totals match
      `subtotal + total_gst = total_cost` (server-rounded).
- [ ] Blank supplier GSTIN saves but raises an ITC-risk reconciliation flag.
- [ ] Retrying confirm with the same `client_uuid` does not double-add stock.
- [ ] Offline confirm returns success instantly and queues FIFO (product before purchase).
- [ ] A new product created here carries mandatory `category_id` + `supplier_id`.

---

## 14. Related docs
- Foundation: [duplicate-detection](../../../foundation/duplicate-detection.md) ·
  [data-model](../../../foundation/data-model.md) (`purchases`, `purchase_items`,
  `stock_movements`) · [sync](../../../foundation/sync-and-conflict-resolution.md) ·
  [api-conventions](../../../foundation/api-conventions.md) ·
  [design-system](../../../foundation/design-system.md)
- API: [purchases-api](../../../cloud/api/purchases/purchases-api.md) ·
  [suppliers-api](../../../cloud/api/suppliers/suppliers-api.md) ·
  [products-api](../../../cloud/api/products/products-api.md) ·
  [duplicate-detection-api](../../../cloud/api/duplicate-detection/duplicate-detection-api.md) ·
  [gst-api](../../../cloud/api/gst/gst-api.md) · [stock-api](../../../cloud/api/stock/stock-api.md)
- Sibling screens: [Product Catalog Management](../catalog/product-catalog-management.md) ·
  [GST Registrations](../gst/gst-registrations.md) · [Reports](../reports/reports.md)
- Counterpart: [web purchase ledger](../../../cloud/web/purchases/purchase-ledger.md)
