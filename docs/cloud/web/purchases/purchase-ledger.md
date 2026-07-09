# Purchase Ledger — Owner / Accountant · Flutter Web

> Status: `✅ Specified` · Implements the brief's "Purchase Ledger — full filterable/sortable
> table of all purchases, supplier-wise breakdown, export to Excel." The inbound-goods and
> **Input Tax Credit (ITC)** read model.

---

## 1. Purpose & context
- **What this screen is for** — a dense, filterable table of **every purchase**, with
  **supplier-wise grouping/breakdown**, a GSTIN column, a **`supplier_gstin`** column that
  **flags when missing** (ITC risk), date-range filtering, and Excel/CSV export.
- **Who uses it** — `owner` (what did we buy, from whom, at what cost) and `accountant`
  (compile **ITC** for GSTR-3B and chase suppliers with missing GSTINs before filing).
- **When** — during purchasing review and, critically, at **GST season** when input tax credit
  must be reconciled and any missing supplier GSTINs followed up.
- **Why it exists** — the brief: at GST time the owner "struggles to compile purchase/sales data
  across possibly multiple GSTIN manually." Purchases drive **ITC**; a purchase with **no
  supplier GSTIN cannot be claimed** → real money lost. This ledger makes that gap visible and
  exportable.
- **Frequency / criticality** — moderate reads; **high** money-criticality — a missed
  `supplier_gstin` directly reduces the claimable ITC and raises net GST payable.

---

## 2. Entry points & navigation
- **Arrival** — sidebar **Purchases** (3rd item); `g u` shortcut; from
  [../gst/gst-filing.md](../gst/gst-filing.md) reconciliation ("view purchases missing supplier
  GSTIN"); from [../stock/stock-report.md](../stock/stock-report.md) low-stock ("recent
  purchases of this product").
- **Exits**
  - **Row click / `Enter`** → **Purchase detail drawer** (items, GST, supplier, GSTIN).
  - Drawer → supplier profile (within purchases), a product
    ([../catalog/product-catalog-management.md](../catalog/product-catalog-management.md)).
  - **"Fix supplier GSTIN"** flag → supplier edit (Proposed inline; else deep-link to owner
    mobile supplier flow).
  - **Export** → download.
- **Back-button** — closes drawer first, then leaves; filters live in the URL query for
  shareable views.
- Nav diagram: `GST/Stock → Purchase Ledger → Purchase drawer → {Supplier | Product}`.

---

## 3. Roles & permissions
| Actor | Access | Notes |
|---|---|---|
| Owner | full read + export; may fix supplier GSTIN | editing supplier data may deep-link/inline (Proposed) |
| Accountant | full read + export | flags gaps; **cannot** create purchases here (they originate on owner mobile) |
| Staff | ⛔ | not on web |
- Read-only ledger for the purchase rows themselves (purchases are entered on the owner mobile
  app, [../../../mobile/owner/purchase/new-purchase.md](../../../mobile/owner/purchase/new-purchase.md)).
  No `🔒 owner-PIN` gate for viewing.

---

## 4. Screen layout (wireframe)
Sidebar shell + filter bar + **grouped** dense `DataTable` + detail drawer.

```
┌──────────┬──────────────────────────────────────────────────────────────────────┐
│ 🧸       │  Purchase Ledger              Group by:[Supplier▾]  ⟳  Export▾  ⚙cols │
│ Dashboard│  From[01-06-2026] To[30-06-2026] GSTIN[All▾] Supplier[All▾] ITC[All▾] │
│ Sales    │  🔍 quick filter…                                    58 purchases     │
│ ▸Purch.  │ ┌────────────────────────────────────────────────────────────────────┐│
│ Stock    │ │  ▾ SunToys Distributors        12 bills · ₹ 2,14,000 · ITC ✓        ││ ← group hdr
│ GST      │ │    Inv#     Date     Items  Subtotal  GST(ITC)  Total   GSTIN  SupGST││
│ Staff    │ │    ST-4471  28-06   6 items  40,000   7,200     47,200  …85F   ✓22..││
│ Catalog  │ │    ST-4460  20-06   4 items  25,000   4,500     29,500  …85F   ✓22..││
│ Settings │ │  ▾ Playmax Traders             3 bills · ₹ 46,500 · ITC ⚠ missing   ││
│          │ │    (no inv) 24-06   2 items  18,000   3,240     21,240  …85F  ⚠ none││ ← flag
│ ──────   │ │    …                                                                 ││
│ 👤 Owner │ ├────────────────────────────────────────────────────────────────────┤│
│ ✓ synced │ │ Σ 58 bills · ₹ 6,40,000 · ITC ₹ 1,04,300 · ⚠ 5 missing GSTIN        ││
└──────────┴─┴────────────────────────────────────────────────────────────────────┘
```

**Sidebar nav placement** — Purchases is the **3rd** item. **Dense-table behavior** — same
shared web `DataTable` as Sales (sticky header, sticky first column, 40/32 px rows, zebra,
right-aligned tabular `₹`, header sort + Shift multi-sort, per-column filters, column
show/hide/resize, cursor pagination, running totals) **plus grouped rows**: collapsible
supplier group headers with per-group bill count, total cost, and ITC status.

**Responsive breakpoints** — same table as Sales; on Compact/Medium the `supplier_gstin` and
GSTIN columns stay visible (they're the point of this screen) while `Items` collapses first.

---

## 5. UI components & field-by-field spec
### Filters & toolbar
| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | From / To | date-range | user | `from ≤ to` | current month | refetch | on `purchases.invoice_date` |
| 2 | GSTIN filter | multi-select | `gst_registrations` | — | All | refetch | which registration bought (`gstin_id`) |
| 3 | Supplier filter | multi-select | `suppliers` | — | All | refetch | `supplier_id` |
| 4 | ITC filter | segmented | All · Has GSTIN · **Missing GSTIN** | — | All | filters `supplier_gstin IS NULL` | headline reconciliation filter |
| 5 | Group by | dropdown | Supplier · GSTIN · None | — | **Supplier** | regroups rows | supplier-wise breakdown |
| 6 | Quick filter | text | user | — | empty | debounced; matches invoice_no/supplier | 🔍 |
| 7 | Export ▾ | menu | CSV · XLSX | — | — | export flow (respects filters) | |
| 8 | Columns ⚙ / Refresh ⟳ | popover / button | — | — | — | col config / refetch | |

### DataTable columns
| # | Column | Data source (canonical) | Sortable | Filter | Format | Notes |
|---|---|---|---|---|---|---|
| C1 | ☐ select | — | no | — | checkbox | bulk export |
| C2 | Supplier | `purchases.supplier_id` → `suppliers.name` | ✅ | multi-select | name | group header when grouped |
| C3 | Invoice No | `purchases.invoice_no` | ✅ | contains | text | supplier's bill no; "(no inv)" if null |
| C4 | Invoice Date | `purchases.invoice_date` | ✅ (default ▼) | date range | DD-MM-YYYY | |
| C5 | Items | derived from `purchase_items` | ✅ | — | "N items" | tooltip lists products/qty |
| C6 | Subtotal | `purchases.subtotal` | ✅ | numeric range | `₹` right tabular | pre-tax |
| C7 | GST (ITC) | `purchases.total_gst` | ✅ | numeric range | `₹` | claimable input tax credit |
| C8 | Total | `purchases.total_cost` | ✅ | numeric range | `₹` | subtotal + gst |
| C9 | GSTIN | `purchases.gstin_id` → `gst_registrations.gstin` | ✅ | multi-select | last-4 chip | our registration |
| C10 | Supplier GSTIN | `purchases.supplier_gstin` | ✅ | ITC filter | ✓`22AAAAA…` or **⚠ Missing** | **null → amber `⚠` ITC-risk flag** |
| C11 | Status | `purchases.status` | ✅ | multi-select | draft/confirmed/void | confirmed default |
| C12 | Sync | `purchases.sync_status` | ✅ | multi-select | ✓/↻/•/! + label | mostly synced (owner online) |

### Purchase detail drawer
| Field | Source | Notes |
|---|---|---|
| Header | `invoice_no`, `invoice_date`, supplier | + our GSTIN legal name |
| Supplier GSTIN | `purchases.supplier_gstin` | if null → prominent "Add supplier GSTIN to claim ITC" CTA |
| Line items | `purchase_items` (product, qty, `cost_price`, `gst_rate`, `gst_amount`, `line_total`) | photo thumb |
| Totals | `subtotal`, `total_gst`, `total_cost` | tabular ₹ |
| Meta | `created_by` (staff), `device_id`, `sync_status`, `status` | audit |
| Actions | View supplier · View product · Fix GSTIN · Print/PDF | |

---

## 6. States
- **default / populated** — current-month purchases grouped by supplier, newest first, with a
  per-group and grand-total footer including total ITC and a **missing-GSTIN count**.
- **empty** — no purchases in range → `EmptyState` ("No purchases match — widen dates / clear
  filters").
- **loading** — skeleton group headers + rows; footer "…".
- **error (inline, retry)** — inline "Couldn't load purchases — Retry".
- **offline** — banner "Offline — last loaded page"; Export/Load-more disabled.
- **success** — export ready toast + download; ITC filter apply updates the missing-count chip.
- **permission-denied** — `N/A` for allowed roles.

---

## 7. Interactions, gestures & hardware
- **Keyboard** — `g u` open; `/` quick filter; `↑/↓` row focus, `Enter` open drawer, `Esc`
  close; `Ctrl/Cmd+E` export; `[`/`]` page; group headers toggle with `Space`/click; `Shift+
  click` header multi-sort.
- **Mouse** — collapse/expand supplier groups; hover Items → product tooltip; hover
  supplier-GSTIN `⚠` → "Missing supplier GSTIN — ITC cannot be claimed for this bill".
- **No hardware** — desktop.
- **Latency** — filter/group apply < 1 s; drawer instant from loaded row.

---

## 8. Business rules & edge cases
1. **R1 — Missing `supplier_gstin` = ITC risk.** Any row with `purchases.supplier_gstin IS NULL`
   is flagged amber `⚠` (icon + "Missing" label, never color-alone); its `total_gst` is
   **excluded** from claimable ITC in the footer and in GST reconciliation
   ([../gst/gst-filing.md](../gst/gst-filing.md)).
2. **R2 — Supplier-wise breakdown.** Grouping by supplier shows per-supplier bill count, total
   cost, total ITC, and a group-level ITC status (✓ all have GSTIN / ⚠ some missing).
3. **R3 — Which registration.** `gstin_id` is **our** buying registration; `supplier_gstin` is
   the **vendor's** — both are shown and must not be confused.
4. **R4 — Date filter on `invoice_date`** (supplier's bill date), inclusive range, IST — this is
   the date that matters for the GST period, not server receipt time.
5. **R5 — Draft/void purchases.** `status='draft'` (unconfirmed) and `status='void'` are
   excluded from ITC totals; a Status filter isolates them. Draft appears if a low-stock
   "create purchase order" started a draft.
6. **R6 — Export WYSIWYG** — respects active filters/grouping/sort; a dedicated "Missing GSTIN"
   export helps the accountant email suppliers. Reference export flow in
   [api-conventions.md](../../../foundation/api-conventions.md) §7.
7. **R7 — Cost feeds margin.** `purchase_items.cost_price` updates the product's latest
   `cost_price`, which the Dashboard profit estimate and category-margins use; the ledger is
   where an unexpected margin can be traced to a cost change.
8. **R8 — Multi-line GST rates.** A bill may mix `gst_rate` (5/12/18/28) across items;
   `total_gst` is the sum; the drawer shows per-line rates for GSTR-2/ITC detail.
9. **R9 — Duplicate bill guard.** Same supplier + `invoice_no` + `invoice_date` entered twice is
   surfaced as a possible duplicate (info flag) so ITC isn't double-claimed. **⚠ Proposed:** no
   unique constraint on (`supplier_id`,`invoice_no`) exists — add or soft-detect.
10. **R10 — Cursor pagination** for large ledgers; grouped totals are server-computed across all
    pages (not just the loaded page).

---

## 9. API interactions
| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Load / filter / group / sort / page | `GET /purchases?from=&to=&gstin_id=&supplier_id=&itc=missing\|present&group_by=&sort=&order=&cursor=&per_page=` | page of purchases + group + grand totals | last loaded page; Load-more disabled |
| Row open | row data or `GET /purchases/{id}` | drawer line items | loaded rows only |
| Export | `GET /purchases?<filters>&format=csv\|xlsx` | download / async | disabled offline |
| Fix supplier GSTIN | `PATCH /suppliers/{id}` *(Proposed inline)* | set `suppliers.gstin` / backfill `supplier_gstin` | blocked offline |

- List reads are **GET, read-only**. Fixing a supplier GSTIN is a write (owner) — Proposed to be
  inline; otherwise handled in owner mobile supplier management.
- Conventions: [api-conventions.md](../../../foundation/api-conventions.md) §7–8.
- API doc: [../../api/purchases/purchases-api.md](../../api/purchases/purchases-api.md) ·
  suppliers: [../../api/suppliers/suppliers-api.md](../../api/suppliers/suppliers-api.md).

**`GET /purchases` — key response fields**
`data[]`: `{ id, invoice_no, invoice_date, supplier:{id,name}, gstin:{id,gstin},
supplier_gstin, item_count, subtotal, total_gst, total_cost, status, sync_status,
created_by }`; `meta`: `{ cursor, total, sum_total_cost, sum_itc, missing_gstin_count,
groups:[{supplier_id, bill_count, sum_total_cost, sum_itc, itc_status}] }`.

---

## 10. Offline & sync behavior
- **Read-only; no outbox, no Drift on web** (session cache only).
- Displays each purchase's server-side `purchases.sync_status` (✓/↻/•/!). Purchases are
  entered on the owner mobile app and may briefly be `pending` if entered offline there —
  reconciled server-side per
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md); the
  web ledger shows the reconciled truth.
- The only write this screen may issue (fix supplier GSTIN) is online-only.

---

## 11. Analytics & events
| Event | When | Properties |
|---|---|---|
| `web_purchase_ledger_viewed` | load | `from`,`to`, filters |
| `web_purchase_grouped` | group change | `group_by` |
| `web_purchase_itc_filter` | ITC filter | `value` (missing/present) |
| `web_purchase_drawer_opened` | row open | `purchase_id` |
| `web_purchase_gstin_fixed` | supplier GSTIN set | `supplier_id` |
| `web_purchase_exported` | export | `format`, `scope`, `row_count`, `missing_gstin_count` |

---

## 12. Accessibility, localization & performance
- **A11y** — grouped table exposes group headers as row-group semantics; `aria-sort` on sortable
  headers; the `⚠` missing-GSTIN flag pairs an icon + text ("Missing"); drawer is focus-trapped.
  WCAG AA light/dark.
- **Localization** — `₹` Indian grouping; DD-MM-YYYY (`invoice_date`); GSTIN format
  `22AAAAA0000A1Z5`; export headers stable for CA tools.
- **Performance** — server-side grouping + cursor pagination; grand/group totals computed
  server-side; export streamed/async for big ranges.

---

## 13. Acceptance criteria
- [ ] Table shows Supplier, Invoice No, Invoice Date, Items, Subtotal, GST(ITC), Total, GSTIN,
      **Supplier GSTIN**, Status, Sync from correct canonical sources.
- [ ] Rows with `supplier_gstin` null are flagged with an amber `⚠` icon + "Missing" label and
      their GST is excluded from claimable-ITC totals.
- [ ] Group-by Supplier shows per-supplier bill count, total cost, total ITC, and group ITC status.
- [ ] ITC filter isolates "Missing GSTIN" purchases for supplier follow-up.
- [ ] Date filter is on `invoice_date`, inclusive; GSTIN and Supplier filters combine.
- [ ] Footer shows filtered bill count, total cost, **total claimable ITC**, and **missing-GSTIN
      count** across all pages.
- [ ] Export CSV/XLSX reproduces active filters/grouping/sort; a "Missing GSTIN" export is possible.
- [ ] Draft/void purchases are excluded from ITC totals and isolable via Status filter.
- [ ] Fully keyboard-operable; screen-reader announces groups and the missing-GSTIN flag.

---

## 14. Related docs
- Foundation: [data-model.md](../../../foundation/data-model.md) (`purchases`, `purchase_items`,
  `suppliers`) · [api-conventions.md](../../../foundation/api-conventions.md) ·
  [design-system.md](../../../foundation/design-system.md) (`DataTable`) ·
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md)
- API: [../../api/purchases/purchases-api.md](../../api/purchases/purchases-api.md) ·
  [../../api/suppliers/suppliers-api.md](../../api/suppliers/suppliers-api.md)
- Sibling web screens: [../gst/gst-filing.md](../gst/gst-filing.md) (ITC reconciliation) ·
  [../stock/stock-report.md](../stock/stock-report.md) ·
  [../sales/sales-ledger.md](../sales/sales-ledger.md)
- Mobile origin of purchases: [../../../mobile/owner/purchase/new-purchase.md](../../../mobile/owner/purchase/new-purchase.md)
