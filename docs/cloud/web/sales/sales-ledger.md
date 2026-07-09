# Sales Ledger — Owner / Accountant · Flutter Web

> Status: `✅ Specified` · Implements the brief's "Sales Ledger — full filterable/sortable
> table of all sales … export to Excel." The primary read model for every sale.

---

## 1. Purpose & context
- **What this screen is for** — a dense, filterable, sortable table of **every sale** across
  all staff/GSTINs, with a date-range filter, column filters, cursor pagination, one-click
  **Excel/CSV export**, and a per-row **sale detail drawer**.
- **Who uses it** — `owner` (verify a sale, chase a discount, audit a staff member) and
  `accountant` (reconcile sales for GST, export for a CA). Desktop; mostly online.
- **When** — throughout the month for spot-checks; **intensively at GST season** when the
  accountant exports the period's outward supplies.
- **Why it exists** — the shop had no queryable record of sales; disputes ("did we sell that at
  ₹1,499?"), staff accountability, and GST outward-supply compilation were all memory/paper.
  This is the auditable, exportable ledger behind those needs.
- **Frequency / criticality** — frequent reads; **high** correctness bar — figures feed GST
  and payroll-adjacent incentive decisions, so filters and exports must be exact.

---

## 2. Entry points & navigation
- **Arrival** — sidebar **Sales** (2nd item); `g s` shortcut; from Dashboard (category-margin
  bar → Sales filtered by category; a KPI drill); from
  [../staff/staff-performance.md](../staff/staff-performance.md) ("view this staff's sales");
  from [../gst/gst-filing.md](../gst/gst-filing.md) ("view outward supplies for period").
- **Exits**
  - **Row click / `Enter`** → **Sale detail drawer** (right slide-over) with line items, taxes,
    payment, staff, discount approver, sync status.
  - Drawer links → the selling staff ([../staff/staff-performance.md](../staff/staff-performance.md)),
    a product ([../catalog/product-catalog-management.md](../catalog/product-catalog-management.md)).
  - **Export** → file download (no navigation).
- **Back-button** — Back closes the drawer first, then leaves to the previous screen. Deep-link
  filters are encoded in the URL query so a shared link reproduces the exact view.
- Nav diagram: `Dashboard/Staff/GST → Sales Ledger → Sale drawer → {Staff | Product}`.

---

## 3. Roles & permissions
| Actor | Access | Notes |
|---|---|---|
| Owner | full read + export | can see discount approver, device, sync status |
| Accountant | full read + export | same table; **read-only** (no edits/voids here) |
| Staff | ⛔ | not on web |
- The ledger is **read-only** — no create/edit/void from this screen (sales originate on the
  staff app). No `🔒 owner-PIN` gate (viewing is not PIN-gated; the sale's discount was already
  PIN-approved upstream).

---

## 4. Screen layout (wireframe)
Sidebar shell + filter bar + dense `DataTable` + right detail drawer.

```
┌──────────┬──────────────────────────────────────────────────────────────────────┐
│ 🧸       │  Sales Ledger                                     ⟳   Export ▾   ⚙cols │
│ Dashboard│  From[01-06-2026] To[30-06-2026]  Staff[All▾] GSTIN[All▾] Pay[All▾]    │
│ ▸Sales   │  Sync[All▾]   🔍 quick filter…                          214 sales      │
│ Purchases│ ┌────────────────────────────────────────────────────────────────────┐│
│ Stock    │ │☐ Date ▼    Invoice No       Staff  Items      Amount₹  GSTIN  Pay Sy││
│ GST      │ ├────────────────────────────────────────────────────────────────────┤│
│ Staff    │ │☐ 30-06 19:12 GST1/26-27/000418 Ravi  3 items  2,998.00 …85F  UPI  ✓ ││
│ Catalog  │ │☐ 30-06 18:40 GST1/26-27/000417 Anu   1 item     499.00 …85F  Cash ✓ ││
│ Settings │ │☐ 30-06 18:05 (local-ref)       Kumar 2 items  1,750.00 …85F  Card • ││ ← pending
│          │ │  …                                                                   ││
│ ──────   │ ├────────────────────────────────────────────────────────────────────┤│
│ 👤 Owner │ │ Σ 214 sales · ₹ 4,82,300.00   Rows[50▾]   ‹ 1–50 of 214 ›  Load more││
│ ✓ synced │ └────────────────────────────────────────────────────────────────────┘│
└──────────┴─────────────────────────────────────────┬────────────────────────────┘
                                        Sale drawer → │ Invoice GST1/26-27/000418   │
                                                       │ 30-06-2026 19:12 · Ravi     │
                                                       │ ─ Line items ─────────────  │
                                                       │ Red Racer ×2  1,499  2,998  │
                                                       │ Subtotal 2,998 · Disc 0     │
                                                       │ CGST 9% 229 · SGST 9% 229   │
                                                       │ Total ₹ 2,998 · UPI · ✓sync │
                                                       │ [View staff] [Print copy]   │
                                                       └────────────────────────────┘
```

**Sidebar nav placement** — Sales is the **2nd** item. **Dense-table behavior** (shared web
`DataTable`): sticky header + sticky first (Date) column on horizontal scroll; 40 px rows
(32 px dense toggle); zebra + hover; right-aligned tabular `₹`; click header to sort,
Shift-click multi-sort; per-column filter chips; column show/hide/resize/reorder (persisted);
selection checkboxes for bulk export; cursor-pagination footer with running totals.

**Responsive breakpoints**

| Name | Width | Sidebar | Table |
|---|---|---|---|
| Compact | < 768 px | hamburger drawer | horizontal scroll; secondary cols (GSTIN, Items) hidden; or stacked cards |
| Medium | 768–1199 px | icon rail | horizontal scroll; Items/GSTIN collapsible |
| Expanded | 1200–1599 px | full sidebar | all columns visible, dense |
| Wide | ≥ 1600 px | full sidebar | all columns + drawer side-by-side without overlay |

---

## 5. UI components & field-by-field spec
### Filters & toolbar
| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | From / To date | date-range picker | user | `from ≤ to`; ≤ 366-day span | current month | refetch page 1 | filters on `sold_at` (business date) |
| 2 | Staff filter | multi-select | `staff` (active+inactive) | — | All | refetch | maps `staff_id` |
| 3 | GSTIN filter | multi-select | `gst_registrations` | — | All | refetch | maps `gstin_id` |
| 4 | Payment mode filter | multi-select | cash · upi · card | — | All | refetch | `sales.payment_mode` |
| 5 | Sync status filter | multi-select | synced · pending · syncing · failed | — | All | refetch | `sales.sync_status` |
| 6 | Quick filter | text | user | — | empty | debounced client filter over loaded page + server `q` for invoice/staff | 🔍 |
| 7 | Export ▾ | menu | CSV · XLSX | — | — | see export flow | respects active filters/sort |
| 8 | Columns ⚙ | popover | toggle/reorder columns | — | default set | persists per user | |
| 9 | Refresh ⟳ | button | — | — | — | refetch current view | `r` |

### DataTable columns
| # | Column | Data source (canonical) | Sortable | Filter | Format | Notes |
|---|---|---|---|---|---|---|
| C1 | ☐ select | — | no | — | checkbox | bulk export scope |
| C2 | Date | `sales.sold_at` | ✅ (default ▼) | date range | DD-MM-YYYY HH:MM | business time (IST) |
| C3 | Invoice No | `sales.invoice_no` | ✅ | contains | text | pending rows show local ref + `•` (server assigns on sync — see sync doc §7) |
| C4 | Staff | `sales.staff_id` → `staff.name` | ✅ | multi-select | name (+ photo chip) | link to staff perf |
| C5 | Items | derived from `sale_items` | ✅ (by count) | — | "N items" | tooltip lists first few product names |
| C6 | Amount | `sales.total` | ✅ | numeric range | `₹1,23,456.00` right-aligned tabular | payable incl. tax |
| C7 | Discount | `sales.discount_amount` | ✅ | — | `₹` | 🔒 approver shown in drawer |
| C8 | GSTIN | `sales.gstin_id` → `gst_registrations.gstin` | ✅ | multi-select | last-4 chip + full on hover | which registration |
| C9 | Payment | `sales.payment_mode` | ✅ | multi-select | Cash/UPI/Card chip | |
| C10 | Sync | `sales.sync_status` | ✅ | multi-select | ✓/↻/•/! icon + label | never color-alone |

### Sale detail drawer
| Field | Source | Notes |
|---|---|---|
| Header | `invoice_no`, `sold_at`, `staff` | + GSTIN legal/trade name |
| Line items | `sale_items` (product, qty, `unit_price`, `gst_rate`, `gst_amount`, `line_total`) | photo thumb per line |
| Subtotal / Discount / Approver | `sales.subtotal`, `discount_amount`, `discount_approved_by` | 🔒 approver = owner who PIN-approved |
| Tax split | `tax_amount` → CGST/SGST (intra-state) or IGST | see §8 R6 |
| Total | `sales.total` | tabular ₹ |
| Payment | `sales.payment_mode` | |
| Sync / device | `sales.sync_status`, `sales.device_id` | traces offline device (audit) |
| Actions | View staff · Print/PDF copy · Copy invoice no | read-only |

---

## 6. States
- **default / populated** — current-month sales, newest first, footer totals for the filtered set.
- **empty** — no sales in range → `EmptyState` ("No sales match these filters — widen the dates
  or clear filters" + "Reset filters" button).
- **loading** — skeleton rows (10–15) with shimmer; footer count as "…"; filters stay usable.
- **error (inline, retry)** — a banner row "Couldn't load sales — Retry"; last good page kept if
  it was a pagination fetch.
- **offline** — banner "Offline — showing last loaded page"; Export/Load-more disabled; drawer
  works for already-loaded rows.
- **success** — export ready → toast "Export ready" + auto-download; filter apply → subtle count update.
- **permission-denied** — `N/A` for allowed roles; staff can't reach it.

---

## 7. Interactions, gestures & hardware
- **Keyboard** — global `g s` open; `/` focus quick filter; table `↑/↓` move row focus,
  `Enter` open drawer, `Esc` close drawer, `Ctrl/Cmd+E` export, `[`/`]` prev/next page,
  `Space` toggle row select, `Shift+click` header multi-sort, `Ctrl/Cmd+A` select page.
- **Mouse** — click header to sort; hover row highlight; hover Items → product tooltip; hover
  GSTIN chip → full GSTIN; click row → drawer.
- **Drag** — column resize/reorder in header; layout persists per user.
- **No hardware** — desktop; "Print copy" uses the browser print/PDF, not a BT printer.
- **Latency** — filter apply → first rows < 1 s target; drawer open is instant from the loaded
  row (no fetch unless full line-item detail is lazy-loaded).

---

## 8. Business rules & edge cases
1. **R1 — Date filter is on business time** (`sold_at`), inclusive `from`/`to`
   (api-conventions §8), IST day boundaries — not server receipt time.
2. **R2 — Pending/unsynced sales.** Sales still `pending`/`failed` on a device may not yet be on
   the server; web shows what the server has. If surfaced, they carry a `•`/`!` sync icon and a
   **local reference** instead of a real `invoice_no` (assigned on sync, sync doc §7). Excluded
   from GST/period totals until synced.
3. **R3 — Export respects the active filter + sort exactly** (WYSIWYG). Scope selectable:
   *Current view* (filtered) vs *All* (ignores filters). See export flow below.
4. **R4 — Totals footer** reflects the **filtered** set across all pages (server-computed), not
   just the visible page, so an accountant reading "₹4,82,300 / 214 sales" trusts it.
5. **R5 — Discount transparency.** Any `discount_amount > 0` shows the `🔒 discount_approved_by`
   owner in the drawer; a discount with no approver is flagged as a data anomaly (should never
   happen — staff-app enforces PIN, `BUSINESS_RULE` upstream).
6. **R6 — Tax split.** For intra-state B2C (buyer state = `gst_registrations.state_code`),
   `tax_amount` splits **CGST = SGST = tax_amount / 2**; inter-state would be **IGST**. Retail
   toy sales are B2C intra-state by default. **⚠️ Proposed schema addition:** `sales` has no
   `place_of_supply_state_code`; add it if inter-state B2B sales must be represented for GSTR-1
   line-level splits — otherwise intra-state split is computed.
7. **R7 — Void/return.** Voided sales appear with a `void` badge (Proposed `sales.status`, or via
   `void_reversal` movements) and are excluded from totals; a Sync/Status filter can isolate them.
8. **R8 — Large ranges** use **cursor** pagination (`per_page` up to 100); the UI never loads all
   214+ into memory — "Load more"/Next fetches the next cursor.
9. **R9 — Deleted/deactivated product** still shows its snapshot name/price from `sale_items`
   (snapshots, not live joins) so historical sales stay truthful.
10. **R10 — Multi-GSTIN.** With "All GSTIN", the invoice_no column mixes sequences; grouping/sort
    by GSTIN is available for clean per-registration reading.

**Export flow** (shared, ref [api-conventions.md](../../../foundation/api-conventions.md) §7):
Export ▾ → pick **CSV/XLSX** + **scope** (Current view / Selected rows / All) → client calls
`GET /sales?<current filters>&format=csv|xlsx` → small result streams to browser download;
large result → `202` async job → toast "Preparing export…" → download link (+ optional email)
when ready. Filename `sales_<gstin?>_<from>_<to>.xlsx` (DD-MM-YYYY). *(Async export is a
Proposed refinement if the sales API returns only sync exports today.)*

---

## 9. API interactions
| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Load / filter / sort / page | `GET /sales?from=&to=&staff_id=&gstin_id=&payment_mode=&sync_status=&q=&sort=&order=&cursor=&per_page=` | fetch page of sales + footer totals | show last loaded page; Load-more disabled |
| Row open | (data already in row) or `GET /sales/{id}` | full line items for drawer if lazy | drawer works for loaded rows only |
| Export | `GET /sales?<filters>&format=csv\|xlsx` | download / async job | disabled offline |
| Print copy | client render → browser print/PDF | invoice copy | works from loaded data |

- **All GET, read-only** — no idempotency keys, no writes.
- Filtering/sorting/pagination/export conventions: [api-conventions.md](../../../foundation/api-conventions.md) §7–8.
- API doc: [../../api/sales/sales-api.md](../../api/sales/sales-api.md).

**`GET /sales` — key response fields used here**
`data[]`: `{ id, invoice_no, sold_at, staff:{id,name,photo_url}, item_count, subtotal,
discount_amount, discount_approved_by, tax_amount, total, gstin:{id,gstin}, payment_mode,
sync_status, device_id }`; `meta`: `{ cursor, per_page, total, sum_total }`.

---

## 10. Offline & sync behavior
- **Read-only; no outbox, no Drift on web.** Only an in-session cache of the last page(s).
- Sets **no** `sync_status` — it **displays** each sale's server-side `sales.sync_status`
  (✓/↻/•/! per [design-system.md](../../../foundation/design-system.md) §8 and
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md) §8).
- Because the web reads the server's reconciled truth, amounts/quantities are already
  conflict-resolved; the ledger never shows a client's optimistic local counter.

---

## 11. Analytics & events
| Event | When | Properties |
|---|---|---|
| `web_sales_ledger_viewed` | load | `from`, `to`, filter set |
| `web_sales_filter_changed` | filter/sort | `field`, `value` |
| `web_sale_drawer_opened` | row open | `sale_id` |
| `web_sales_exported` | export | `format`, `scope`, `row_count` |
| `web_sales_export_async` | large export queued | `job_id` |

---

## 12. Accessibility, localization & performance
- **A11y** — `DataTable` uses proper table semantics (row/col headers, `aria-sort`); row focus
  ring; drawer is a focus-trapped dialog with `Esc` to close; sync icons carry text labels;
  numeric right-aligned tabular for scan-ability. WCAG AA light/dark.
- **Localization** — `₹` Indian grouping `1,23,456.00`; DD-MM-YYYY dates; GST/payment terms
  localizable; CSV/XLSX headers localizable but stable machine keys for CA tools.
- **Performance** — cursor pagination + row virtualization for long lists; server-side
  filter/sort (no client mega-load); debounced quick filter; export streamed/async for large sets.

---

## 13. Acceptance criteria
- [ ] Table shows Date, Invoice No, Staff, Items, Amount, Discount, GSTIN, Payment, Sync with
      correct canonical sources; Amount/Discount right-aligned tabular `₹`.
- [ ] Date-range + Staff + GSTIN + Payment + Sync filters all apply server-side and combine;
      "Reset filters" clears them.
- [ ] Any column header sorts (Shift-click multi-sort); Date-desc is the default.
- [ ] Cursor pagination loads more without re-loading the whole set; footer shows filtered
      count **and** filtered ₹ sum across all pages.
- [ ] Row click / `Enter` opens the sale drawer with line items, tax split, discount approver,
      payment, and sync/device; `Esc` closes it.
- [ ] Export CSV/XLSX reproduces exactly the active filters + sort (WYSIWYG); large exports go
      async with a ready toast/link.
- [ ] Pending/unsynced sales show a sync icon + local ref (no fake invoice_no) and are excluded
      from GST-facing totals.
- [ ] Deactivated products still display their historical snapshot name/price.
- [ ] Fully keyboard-operable; screen-reader announces sort state and drawer.

---

## 14. Related docs
- Foundation: [data-model.md](../../../foundation/data-model.md) (`sales`, `sale_items`) ·
  [api-conventions.md](../../../foundation/api-conventions.md) ·
  [design-system.md](../../../foundation/design-system.md) (`DataTable`) ·
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md)
- API: [../../api/sales/sales-api.md](../../api/sales/sales-api.md)
- Sibling web screens: [../gst/gst-filing.md](../gst/gst-filing.md) ·
  [../staff/staff-performance.md](../staff/staff-performance.md) ·
  [../purchases/purchase-ledger.md](../purchases/purchase-ledger.md) ·
  [../dashboard/dashboard-home.md](../dashboard/dashboard-home.md)
- Mobile origin of sales: [../../../mobile/staff/sales/new-sale.md](../../../mobile/staff/sales/new-sale.md)
