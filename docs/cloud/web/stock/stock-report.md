# Stock Report — Owner / Accountant · Flutter Web

> Status: `✅ Specified` · Implements **Requirement 4 — STOCK REPORTS FLOW** on the web.
> Four views in one screen: **Current stock · Aging stock · Low stock · Movement/audit ledger.**

---

## 1. Purpose & context
- **What this screen is for** — a tabbed report over inventory: current on-hand (from
  `v_current_stock`), **aging stock** (unsold beyond 30/60/90-day thresholds, with a *push for
  clearance* action), **low stock** (below reorder threshold, with a *create purchase order*
  shortcut), and a **filterable stock-movement/audit ledger** (every movement with timestamp +
  responsible staff/owner).
- **Who uses it** — `owner` (kill dead stock, restock before a stockout, audit a shortage) and
  `accountant` (stock valuation, movement audit).
- **When** — weekly stock reviews, before purchasing, and whenever the Dashboard aging/low
  alerts fire.
- **Why it exists** — the brief's core operational risk: with no barcodes, "aging stock piles up
  in the backyard unnoticed for months," and stockouts lose sales. Stock is **derived from the
  immutable `stock_movements` event log** (never a mutable counter), so this report is also the
  audit trail for the whole reconciliation model.
- **Frequency / criticality** — frequent; **high** — aging stock ties up cash and low stock
  loses revenue; the movement ledger is the ground truth when a physical count disagrees.

---

## 2. Entry points & navigation
- **Arrival** — sidebar **Stock** (4th item); `g k`; Dashboard **Aging** tile → Aging tab;
  Dashboard **Low stock** tile → Low tab; a `low_stock`/`aging_stock` notification tap.
- **Exits**
  - **Push for clearance** (Aging) → confirm dialog → raises visibility (see §8 R3); optionally
    → discount/clearance tagging.
  - **Create purchase order** (Low) → pre-filled purchase **draft** → owner mobile
    [../../../mobile/owner/purchase/new-purchase.md](../../../mobile/owner/purchase/new-purchase.md)
    or a web draft (Proposed).
  - **Product row** → [../catalog/product-catalog-management.md](../catalog/product-catalog-management.md).
  - Movement row → the source sale/purchase (Sales/Purchase ledger).
  - **Export** per tab → download.
- **Back-button** — Back switches to the previous tab / leaves; the active tab + filters are in
  the URL query.
- Nav diagram: `Dashboard alert → Stock (tab) → {Clearance | Purchase draft | Product | Movement source}`.

---

## 3. Roles & permissions
| Actor | Access | Notes |
|---|---|---|
| Owner | full read; **push for clearance**, **create PO** | those two are writes/actions |
| Accountant | full read + export | actions (clearance/PO) hidden or disabled (read-only analytics) |
| Staff | ⛔ | not on web |
- **Push for clearance** and **Create purchase order** are owner actions. No `🔒 owner-PIN`
  needed to view; creating a purchase draft follows the purchase flow's own rules. Manual stock
  **adjustments** are **not** made here (they belong to a controlled adjustment flow); this
  screen *reports* movements, it doesn't let you silently edit stock.

---

## 4. Screen layout (wireframe)
Sidebar shell + tab bar + per-tab dense `DataTable`.

```
┌──────────┬──────────────────────────────────────────────────────────────────────┐
│ 🧸       │  Stock Report                                       ⟳   Export ▾  ⚙cols│
│ Dashboard│  [ Current ] [ Aging ⏳14 ] [ Low 🟠6 ] [ Movements ]   ← tabs         │
│ Sales    │  Category[All▾] Supplier[All▾] Shelf[All▾]  🔍…                         │
│ Purchases│ ── AGING tab ───────────────────────────────────────────────────────  │
│ ▸Stock   │ ┌────────────────────────────────────────────────────────────────────┐│
│ GST      │ │ Product          Cat        On-hand  Days idle▼  Value₹   Action    ││
│ Staff    │ ├────────────────────────────────────────────────────────────────────┤│
│ Catalog  │ │ 🧸 Blue Jeep     Battery Cars   7      118d 🔴   17,493  [Clearance]││
│ Settings │ │ 🧸 Pink Scooter  Ride-ons       3       92d 🔴    4,497  [Clearance]││
│          │ │ 🧸 Farm Playset  Play Sets      5       64d 🟠    3,995  [Clearance]││
│ ──────   │ │ …  (buckets: 🟢<30 · 🟠30–60 · 🔴>60/90 by threshold)               ││
│ 👤 Owner │ ├────────────────────────────────────────────────────────────────────┤│
│ ✓ synced │ │ 14 aging items · ₹ 62,000 tied up · threshold 30d (Settings)        ││
└──────────┴─┴────────────────────────────────────────────────────────────────────┘
```

**Sidebar nav placement** — Stock is the **4th** item. Four **tabs** with live badge counts
(Aging ⏳N, Low 🟠N). **Dense-table behavior** — shared web `DataTable` per tab (sticky header,
sticky first product column, 40/32 px rows, right-aligned tabular numerics, header sort +
multi-sort, per-column filters, cursor pagination, export). Stock status uses **icon + label**
(🟢 healthy / 🟠 low / 🔴 out/oversold / ⏳ aging), never color-alone.

**Responsive breakpoints** — same table rules as Sales; on Compact the action buttons collapse
into a row `⋯` menu; secondary columns (Supplier, Shelf, Value) hide first, keeping Product /
On-hand / the tab's key metric.

---

## 5. UI components & field-by-field spec
### Shared filters
| # | Element | Type | Source | Default | Notes |
|---|---|---|---|---|---|
| 1 | Category | multi-select | `categories` | All | narrows every tab |
| 2 | Supplier | multi-select | `suppliers` | All | provenance |
| 3 | Shelf/location | multi-select | `products.shelf_location` | All | "Rack A2" (R3) |
| 4 | Quick filter | text | user | empty | name/QR/color |
| 5 | Export ▾ / Refresh ⟳ / Columns ⚙ | menu/btn/popover | — | — | per active tab |

### Tab 1 — Current stock (`v_current_stock`)
| Column | Source (canonical) | Sort | Format | Notes |
|---|---|---|---|---|
| Product | `products.name` (+ `image_url` thumb) | ✅ | photo + name | link to catalog |
| QR | `products.internal_qr_code` | — | code / "—" | R3 sticker |
| Category | `products.category_id`→`categories.name` | ✅ | name | |
| Shelf | `products.shelf_location` | ✅ | "Rack A2" | |
| Color | `products.color_tag` | — | color chip + label | |
| On-hand | `v_current_stock.on_hand` (=`SUM(stock_movements.quantity_delta)`) | ✅ | integer | 🟢/🟠/🔴 status icon |
| Cost | `products.cost_price` | ✅ | `₹` | latest cost |
| Stock value | `on_hand × cost_price` | ✅ | `₹` | valuation |
| Status | derived | ✅ | 🟢/🟠/🔴 + label | vs `reorder_threshold` |

### Tab 2 — Aging stock
| Column | Source | Sort | Notes |
|---|---|---|---|
| Product | `products` | ✅ | thumb + name |
| Category | `categories.name` | ✅ | |
| On-hand | `v_current_stock.on_hand` | ✅ | only `> 0` shown |
| **Days idle** | derived: days since last `sale_out` (or since first `purchase_in` if never sold) | ✅ **(default ▼)** | bucketed 🟢<30 / 🟠 30–60 / 🔴 >60 or >90 |
| Value tied | `on_hand × cost_price` | ✅ | cash locked up |
| Threshold | `products.aging_threshold_days` ?? `app_settings.aging_threshold_days` | — | per-product override respected |
| **Action** | button | — | **[Push for clearance]** |

### Tab 3 — Low stock
| Column | Source | Sort | Notes |
|---|---|---|---|
| Product | `products` | ✅ | thumb + name |
| On-hand | `v_current_stock.on_hand` | ✅ (default ▲) | 🟠/🔴 |
| Reorder threshold | `products.reorder_threshold` | ✅ | trigger level |
| Shortfall | `reorder_threshold − on_hand` | ✅ | suggest qty |
| Supplier | `suppliers.name` | ✅ | who to reorder from |
| Avg daily sales | derived (last 30 d) | ✅ | days-of-cover hint |
| **Action** | button | — | **[Create purchase order]** |

### Tab 4 — Movement / audit ledger (`stock_movements`)
| Column | Source (canonical) | Sort | Filter | Notes |
|---|---|---|---|---|
| Occurred at | `stock_movements.occurred_at` | ✅ (default ▼) | date range | business time |
| Product | `stock_movements.product_id`→`products.name` | ✅ | multi-select | thumb |
| Type | `movement_type` | ✅ | multi-select | purchase_in / sale_out / adjustment / return_in / void_reversal |
| Δ Qty | `quantity_delta` | ✅ | — | **+in / −out**, colored ▲/▼ + sign |
| Ref | `ref_type` + `ref_id` / `ref_client_uuid` | — | multi-select | link to sale/purchase |
| Staff/Owner | `stock_movements.staff_id`→`staff.name` | ✅ | multi-select | **who caused it** |
| Device | `stock_movements.device_id` | — | — | offline-device trace |
| Note | `stock_movements.note` | — | contains | manual-adjust reason |

---

## 6. States
- **default / populated** — Current tab first; each tab shows its table + a summary footer
  (aging value tied up / low count / movement count).
- **empty** — per tab: "All stock healthy — no aging items", "Nothing below reorder level",
  "No movements in range" (`EmptyState`).
- **loading** — skeleton rows; tab badge counts show "…" until loaded.
- **error (inline, retry)** — inline "Couldn't load stock — Retry" per tab.
- **offline** — banner "Offline — last loaded stock as of HH:MM"; actions (clearance/PO) and
  Export disabled; movement ledger read from cache.
- **success** — clearance pushed → toast "Marked for clearance"; PO draft created → toast +
  link; export ready → download.
- **permission-denied** — accountant sees tables but action buttons are hidden/disabled.

---

## 7. Interactions, gestures & hardware
- **Keyboard** — `g k` open; `1/2/3/4` switch tabs; `/` quick filter; `↑/↓` row focus, `Enter`
  open product/movement; `c` push-for-clearance on focused aging row; `o` create-PO on focused
  low row; `Ctrl/Cmd+E` export; `[`/`]` page.
- **Mouse** — action buttons per row; hover status icon → tooltip ("118 days idle — over 30-day
  threshold"); click product → catalog; click movement Ref → source txn.
- **No hardware** — desktop.
- **Latency** — tab switch reuses cached data instantly; movement ledger uses cursor pagination
  for large logs.

---

## 8. Business rules & edge cases
1. **R1 — On-hand is derived, never stored.** Every on-hand = `SUM(stock_movements.quantity_delta)`
   via `v_current_stock`; the report never trusts a mutable counter
   ([data-model.md](../../../foundation/data-model.md) §6,
   [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md) §5).
2. **R2 — Aging threshold** defaults from `app_settings.aging_threshold_days`, overridable
   per-product via `products.aging_threshold_days`; the Aging tab respects the per-product value
   when set. Buckets shown at 30/60/90 with icons.
3. **R3 — Push for clearance.** Confirm dialog → the item is surfaced for clearance: emits an
   `aging_stock` **notification** and marks the product for clearance so it stands out in
   catalog/sales. **⚠ Proposed schema addition:** there is no clearance flag/target — add
   `products.clearance_flag TINYINT(1)` (or `clearance_since DATETIME`), or model clearance via
   a discount/tag; today it can only raise a notification. Action is **traceable** in `audit_log`.
4. **R4 — Low stock** = `on_hand < products.reorder_threshold` (per-product; a global default
   from Settings applies when unset). Shortfall suggests reorder qty; Avg daily sales gives
   days-of-cover.
5. **R5 — Create purchase order** pre-fills a purchase **draft** (`purchases.status='draft'`)
   for that supplier + product + suggested qty. **⚠ Proposed:** the web has no native
   new-purchase screen — this either deep-links to owner mobile or creates a web draft
   (`POST /purchases` with `status='draft'`).
6. **R6 — Oversold / negative on-hand.** If reconciliation yields `on_hand < 0` (a real sale
   exceeded recorded stock; sync doc §5), the row shows 🔴 **Oversold** with a "needs physical
   count" flag — the sale is **not** dropped; the data error is surfaced.
7. **R7 — Movement ledger is append-only & immutable.** No edits/deletes here; corrections are
   **new** `adjustment` movements (with a `note` + `staff_id`), preserving audit integrity.
8. **R8 — Attribution.** Every movement shows `staff_id` (who) + `device_id` (which device) +
   `occurred_at` (when) for "full audit traceability" (brief R4).
9. **R9 — Filters compose across tabs** (category/supplier/shelf) so "aging Battery Cars from
   SunToys on Rack A2" is one query.
10. **R10 — Valuation basis.** Stock value uses latest `products.cost_price` (no FIFO lots);
    labelled as an estimate for accounting hand-off.

---

## 9. API interactions
| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Current tab | `GET /stock?category_id=&supplier_id=&shelf=&sort=&cursor=` | on-hand + valuation from `v_current_stock` | last cache; read-only |
| Aging tab | `GET /stock/aging?threshold_days=&category_id=&sort=days_idle` | aging items + days idle + value tied | cache |
| Low tab | `GET /stock/low?category_id=&supplier_id=` | items below reorder threshold + shortfall | cache |
| Movements tab | `GET /stock/movements?from=&to=&product_id=&type=&staff_id=&cursor=` | audit ledger | cache |
| Push for clearance | `POST /stock/{product_id}/clearance` *(Proposed)* | flag + `aging_stock` notification | blocked offline |
| Create PO | `POST /purchases {status:'draft', …}` *(Proposed web draft)* or deep-link | reorder draft | blocked offline |
| Export (per tab) | same GET + `&format=csv\|xlsx` | download | disabled offline |

- Reads are **GET, read-only**. Clearance/PO are owner **writes** (audited).
- Thresholds default from `app_settings`, overridable via query (api-conventions §8).
- API docs: [../../api/stock/stock-api.md](../../api/stock/stock-api.md) ·
  purchases (draft PO): [../../api/purchases/purchases-api.md](../../api/purchases/purchases-api.md) ·
  notifications: [../../api/reports-notifications/reports-notifications-api.md](../../api/reports-notifications/reports-notifications-api.md).

---

## 10. Offline & sync behavior
- **Read-only reports; no outbox, no Drift on web** (session cache only).
- On-hand and movements come from the **server-reconciled** event log, so the web never shows a
  client's optimistic local stock — it shows the reconciled `SUM(quantity_delta)`
  ([sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md) §5–6).
- Writes (clearance/PO draft) are online-only; if attempted offline, they're blocked with a
  toast (not queued — web has no outbox).

---

## 11. Analytics & events
| Event | When | Properties |
|---|---|---|
| `web_stock_viewed` | load | `tab`, filters |
| `web_stock_tab_changed` | tab switch | `tab` |
| `web_aging_clearance_pushed` | clearance action | `product_id`, `days_idle`, `value_tied` |
| `web_low_stock_po_created` | create PO | `product_id`, `supplier_id`, `suggested_qty` |
| `web_movements_filtered` | movement filter | `type`, `staff_id`, range |
| `web_stock_exported` | export | `tab`, `format`, `row_count` |

---

## 12. Accessibility, localization & performance
- **A11y** — status conveyed by **icon + label** (🟢/🟠/🔴/⏳), never color-alone; `aria-sort`;
  movement Δ shows a `+`/`−` sign in addition to ▲/▼; action buttons have descriptive labels
  ("Push Blue Jeep for clearance"). WCAG AA light/dark.
- **Localization** — `₹` Indian grouping; DD-MM-YYYY + HH:MM (IST) on movements; "days idle"
  localizable; export headers stable.
- **Performance** — `v_current_stock` is a view/materialized cache; movement ledger uses cursor
  pagination + virtualization; tab data cached per session; thresholds read once from Settings.

---

## 13. Acceptance criteria
- [ ] Current tab shows on-hand from `v_current_stock` (= `SUM(quantity_delta)`), stock value,
      and a 🟢/🟠/🔴 status icon + label per product.
- [ ] Aging tab lists on-hand>0 items sorted by **days idle** desc, bucketed against the
      configured threshold (per-product override respected), with total value tied up.
- [ ] Each aging row has a **Push for clearance** action that raises an aging notification and is
      written to `audit_log`.
- [ ] Low tab lists items with `on_hand < reorder_threshold`, shows shortfall + supplier, and a
      **Create purchase order** shortcut that starts a purchase draft.
- [ ] Movement ledger shows every movement (type, ±Δ qty, ref, **staff/owner**, device,
      timestamp) and is filterable by date/product/type/staff; it is append-only (no edits).
- [ ] Oversold/negative on-hand renders 🔴 with a "needs physical count" flag; the sale is not dropped.
- [ ] Category/supplier/shelf filters compose across all tabs; each tab exports to CSV/XLSX.
- [ ] Accountant sees all tables but no clearance/PO write actions.
- [ ] Fully keyboard-operable; status never conveyed by color alone.

---

## 14. Related docs
- Foundation: [data-model.md](../../../foundation/data-model.md) (`stock_movements`,
  `v_current_stock`, `products`) ·
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md) (reconciliation) ·
  [api-conventions.md](../../../foundation/api-conventions.md) ·
  [design-system.md](../../../foundation/design-system.md) (`DataTable`, `AlertTile`, stock icons)
- API: [../../api/stock/stock-api.md](../../api/stock/stock-api.md) ·
  [../../api/purchases/purchases-api.md](../../api/purchases/purchases-api.md) ·
  [../../api/reports-notifications/reports-notifications-api.md](../../api/reports-notifications/reports-notifications-api.md)
- Sibling web screens: [../dashboard/dashboard-home.md](../dashboard/dashboard-home.md) (alert tiles) ·
  [../purchases/purchase-ledger.md](../purchases/purchase-ledger.md) ·
  [../catalog/product-catalog-management.md](../catalog/product-catalog-management.md) ·
  [../settings/settings.md](../settings/settings.md) (thresholds)
- Mobile: [../../../mobile/owner/purchase/new-purchase.md](../../../mobile/owner/purchase/new-purchase.md)
