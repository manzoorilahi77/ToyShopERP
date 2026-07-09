# Owner Dashboard Home — Owner · Mobile (Owner App)

> The owner's glanceable pulse of the shop (Requirement 5). One screen, big tabular
> numbers: today's sales, today's profit estimate, items sold, pending GST liability;
> a top-performer card; and one-tap alert tiles for low & aging stock. Backed by a single
> aggregate read: `GET /reports/owner-dashboard`.

Status: `✅ Specified` · read-only KPIs, no `🔒` actions on this screen.

---

## 1. Purpose & context
- **What this screen is for:** give the owner a 3-second read on how the day is going and
  what needs attention, without opening reports.
- **Who & when:** the **owner** (`role='owner'`, accountant read-only allowed). Checked
  repeatedly through the day, especially during evening/weekend rushes.
- **Why it exists:** the owner "needs a real-time pulse on sales/stock without being glued
  to a screen" and R5 mandates a "top row: today's sales total, today's profit estimate,
  items sold today, pending GST liability … top performer … aging & low stock alert tiles
  with one-tap drill-down" ([requirements R5](../../../requirements_and_prompt.md)).
- **Frequency / criticality:** the most-opened Owner-App screen. Wrong numbers here erode
  trust in the whole system, so every figure states its freshness and its source of truth.

---

## 2. Entry points & navigation
- **Post-login landing** (default) and the **Home** bottom-nav tab.
- **Notification tap** for a KPI-related alert can deep-link straight to a drill-down.

```
Login ─▶ Dashboard Home ─┬─▶ Reports (KPI tap: sales / profit / items / GST)
                         ├─▶ Reports · Low Stock   (Low-stock AlertTile)
                         ├─▶ Reports · Aging Stock  (Aging-stock AlertTile)
                         ├─▶ Staff Management/Perf   (Top-performer card)
                         ├─▶ Discount Approval       (pending badge)
                         └─▶ Notifications (bell)
```
- **Bottom nav:** Home · Approvals · Purchase · More (Catalog, Staff, Reports, GST,
  Notifications).
- **Back button:** from Home, back exits the app (root of the nav stack).

---

## 3. Roles & permissions
| Actor | Access |
|---|---|
| Owner | ✅ full: all KPIs, tiles, drill-downs |
| Accountant | ✅ read-only KPIs & GST tile; top-performer visible; no discount action |
| Staff | ❌ not applicable (Staff App has its own gamified dashboard) |
- No `🔒` actions on this screen; it is entirely read. The pending-discount badge merely
  **navigates** to the gated [Discount Approval](../approvals/discount-approval.md).

---

## 4. Screen layout (wireframe)

```
┌──────────────────────────────────────────────┐
│  ToyShop · Owner            🔔(3)  ✓sync  ⋮   │  ← AppScaffold: bell + SyncStatusChip
│  Tue 02-07-2026 · updated 2 min ago  ↻        │
├──────────────────────────────────────────────┤
│  ┌───────────────┐  ┌───────────────┐          │
│  │ TODAY SALES   │  │ PROFIT (est.) │          │  ← KpiCard row 1
│  │ ₹ 1,24,850.00 │  │ ₹ 31,210.00   │          │
│  │ ▲ 12% vs avg  │  │ ~25% margin   │          │
│  └───────────────┘  └───────────────┘          │
│  ┌───────────────┐  ┌───────────────┐          │
│  │ ITEMS SOLD    │  │ GST LIABILITY │          │  ← KpiCard row 2
│  │      86       │  │ ₹ 18,940.00 ⓘ │          │     (pending / unfiled)
│  │ 41 sales      │  │ this month    │          │
│  └───────────────┘  └───────────────┘          │
├──────────────────────────────────────────────┤
│  🏆 TOP PERFORMER TODAY                        │
│  ┌────────────────────────────────────────┐    │
│  │ (photo) Ravi K.  ₹ 42,300 · 23 units   │ ▶ │  ← tap → staff performance
│  └────────────────────────────────────────┘    │
├──────────────────────────────────────────────┤
│  ⚠ ALERTS                                      │
│  ┌───────────────┐  ┌───────────────┐          │
│  │ 🟠 LOW STOCK  │  │ ⏳ AGING STOCK │          │  ← AlertTile (tap → drill-down)
│  │  7 items      │  │  12 items >60d │          │
│  └───────────────┘  └───────────────┘          │
├──────────────────────────────────────────────┤
│  QUICK NAV                                      │
│  [＋Purchase] [Catalog] [Staff] [Reports] [GST] │
├──────────────────────────────────────────────┤
│  [ Home ]  [ Approvals•2 ] [ Purchase ] [ More ]│  ← bottom nav
└──────────────────────────────────────────────┘
```

- **Responsive:** phone = 2×2 KPI grid. Tablet = single row of 4 KPIs and side-by-side
  top-performer + alerts. Pull-to-refresh at the top.

---

## 5. UI components & field-by-field spec

| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Today Sales | `KpiCard` money | `SUM(sales.total)` where `DATE(sold_at)=today`, `status` counted (excl. void) | — | ₹0.00 | tap → [Reports](../reports/reports.md) sales-summary (today) | tabular, `₹` Indian grouping |
| 2 | Profit (est.) | `KpiCard` money | `Σ (sale_items.unit_price − products.cost_price) × quantity − discount_amount` today | — | ₹0.00 | tap → Reports profit view | labelled **est.** — uses latest `cost_price` |
| 3 | Items Sold | `KpiCard` count | `SUM(sale_items.quantity)` today; sub-label `COUNT(sales)` | — | 0 | tap → Reports | tabular numerals |
| 4 | GST Liability | `KpiCard` money + ⓘ | `SUM(sales.tax_amount) − eligible ITC` for current period, unfiled | — | ₹0.00 | tap → [GST snapshot in Reports](../reports/reports.md) | ⓘ explains "pending/unfiled, this month, all GSTINs" |
| 5 | Freshness line | caption + ↻ | last successful `owner-dashboard` fetch time | — | — | tap ↻ → re-fetch | shows "updated N min ago" / "offline — last synced …" |
| 6 | Top Performer card | card | best `staff` today by revenue (default) or units | — | "No sales yet" | tap → [staff performance](../staff/staff-management.md) | photo + name + ₹ + units |
| 7 | Perf metric toggle | segmented (revenue \| units) `🧩` | user pref | — | revenue | re-ranks top performer | optional; persists per owner |
| 8 | Low-Stock `AlertTile` | tile w/ count | products with `on_hand ≤ reorder_threshold` (from `v_current_stock`) | — | "0 — all healthy" | tap → [Reports low-stock list](../reports/reports.md) | 🟠 icon + label (not color alone) |
| 9 | Aging-Stock `AlertTile` | tile w/ count | products unsold ≥ `aging_threshold_days` (per-product override or `app_settings`) | — | "0" | tap → [Reports aging list](../reports/reports.md) | ⏳ icon; shows oldest bucket |
| 10 | Quick-nav chips | button row | static routes | — | — | navigate to module | ＋Purchase, Catalog, Staff, Reports, GST |
| 11 | Notification bell | icon + unread badge | `GET /notifications` unread count | — | 0 | tap → [Notifications](../notifications/notifications.md) | badge = unread |
| 12 | `SyncStatusChip` | status chip | [sync §8](../../../foundation/sync-and-conflict-resolution.md) | — | ✓ | tap → sync sheet | non-intrusive |
| 13 | Approvals nav badge | badge on nav | pending `discount_approvals` count | — | 0 | tap → Discount Approval | real-time via push |

**Prose notes**
- **Profit is an estimate**, not audited margin: `cost_price` is the *latest/last purchase
  cost* ([data-model](../../../foundation/data-model.md) §3), so it approximates COGS. The
  label always reads "Profit (est.)" to set expectation.
- **GST liability** is the *output tax not yet filed* for the current period, summed across
  active GSTINs; the authoritative, per-GSTIN filing figures live on the
  [web GST filing](../../../cloud/web/gst/gst-filing.md) screen.
- **Today** = business day in shop timezone (Asia/Kolkata), keyed on `sales.sold_at`, not
  server receipt time, so late-synced offline sales still land on the correct day.

---

## 6. States
- **Default / populated:** all cards filled with today's aggregates + freshness stamp.
- **Empty (new shop / start of day):** KPIs show ₹0.00 / 0; top-performer card shows
  "No sales yet today"; alert tiles show healthy states.
- **Loading:** skeleton shimmer cards (not blank, not a spinner) for < 1 s while
  `owner-dashboard` resolves.
- **Error:** inline card-level error with **Retry** ("Couldn't load KPIs"); the rest of the
  screen (cached tiles) still renders — never a full dead-end.
- **Offline:** calm banner "Working offline — showing last synced numbers"; freshness line
  reads "as of <time>"; tiles still tappable to cached drill-downs.
- **Success:** pull-to-refresh completes with a subtle check + updated stamp.
- **Permission-denied:** accountant sees KPIs but the Approvals badge/route is hidden.

---

## 7. Interactions, gestures & hardware
- **Tap** any KPI/tile/card → its drill-down (see §5 routes).
- **Pull-to-refresh** re-runs `GET /reports/owner-dashboard`.
- **Long-press** a KPI → tooltip explaining its formula/source (educates the owner).
- No camera/printer/scanner on this screen.
- **Latency budget:** first meaningful paint from cache < 200 ms; fresh fetch target < 1 s.

---

## 8. Business rules & edge cases
1. All money is `DECIMAL`-derived, rendered with `₹` + Indian grouping + tabular numerals;
   never floats.
2. Void/returned sales are excluded from Today Sales, Profit and Items Sold.
3. Profit excludes tax and subtracts `discount_amount`; it is explicitly an **estimate**.
4. GST liability aggregates **active** GSTINs only; inactive registrations are excluded.
5. Aging/low-stock counts obey per-product overrides first, then `app_settings`
   (`aging_threshold_days`, low-stock default), per [api-conventions §8](../../../foundation/api-conventions.md).
6. If reconciliation flagged an **oversold** product (on-hand < 0, see
   [sync §5](../../../foundation/sync-and-conflict-resolution.md)), the Low-Stock tile
   surfaces it distinctly (🔴 "needs count").
7. Top performer ties break by units, then earliest first-sale time; "No sales yet" until
   at least one non-void sale exists today.
8. Numbers reflect **synced** server state; if the owner's own device has queued (unsynced)
   items, the freshness line notes potential lag.
9. Deep-linking from a KPI passes the same date window so the drill-down matches the tile.

---

## 9. API interactions

| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Screen open / refresh | `GET /reports/owner-dashboard` | one aggregate: today's sales, profit est., items, GST liability, top performer, low/aging counts | serve last cached payload + offline banner |
| Bell badge | `GET /notifications?is_read=false&per_page=1` | unread count | cached count |
| Approvals badge | `GET /discount-approvals?status=pending&per_page=1` | pending count (also pushed) | cached / push-updated |

Key response fields used (see
[reports-notifications-api](../../../cloud/api/reports-notifications/reports-notifications-api.md)):
```json
{ "date": "2026-07-02",
  "sales_total": "124850.00", "profit_estimate": "31210.00",
  "items_sold": 86, "sales_count": 41,
  "gst_liability": { "amount": "18940.00", "period": "2026-07" },
  "top_performer": { "staff_id": 4, "name": "Ravi K.", "revenue": "42300.00", "units": 23 },
  "low_stock_count": 7, "aging_stock_count": 12, "generated_at": "…" }
```
- Stock counts may alternatively source from
  [stock-api](../../../cloud/api/stock/stock-api.md) (`/stock/low`, `/stock/aging`) if the
  dashboard aggregate defers to them. Envelope/errors per
  [api-conventions](../../../foundation/api-conventions.md).

---

## 10. Offline & sync behavior
- **Works offline:** renders the **last cached** `owner-dashboard` payload with a clear
  "as of <time>" stamp; all drill-down tiles remain tappable against cached lists.
- **Queued:** nothing is written here (read-only screen).
- **Blocked offline:** a fresh recompute (needs server). The freshness line makes staleness
  obvious rather than showing wrong-but-confident numbers.
- **Local storage:** Owner App keeps a light cache (not the full Drift outbox); no
  `sync_status` is set here. See
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md).

---

## 11. Analytics & events
- `owner_dashboard_viewed`
- `kpi_tapped` (kpi: sales | profit | items | gst)
- `alert_tile_tapped` (type: low_stock | aging_stock)
- `top_performer_tapped` (staff_id)
- `dashboard_refreshed` (source: pull | auto)
- `dashboard_offline_shown`

---

## 12. Accessibility, localization & performance
- KPI numbers use Display 34/40 tabular for legibility at arm's length; contrast WCAG AA.
- Every status uses **icon + label**, never color alone (🟠 low, ⏳ aging, 🔴 oversold).
- Screen-reader reads each KPI as "label, value, trend" and tiles as "count, tap to open".
- `₹` Indian grouping (`1,24,850.00`), dates **DD-MM-YYYY**, GST terms localized.
- Cold cache paint < 200 ms; fresh fetch < 1 s on 4G; skeletons during load.

---

## 13. Acceptance criteria
- [ ] Top row shows exactly the four R5 KPIs: today's sales, profit (est.), items sold,
      pending GST liability — each tabular with `₹`/Indian grouping where money.
- [ ] Profit KPI is labelled "est." and equals `Σ(unit_price − cost_price)·qty − discount`.
- [ ] Tapping any KPI opens the matching Reports drill-down for the same day window.
- [ ] Top-performer card shows the best staff today by revenue (toggle to units) with photo.
- [ ] Low-stock and aging-stock tiles show counts and deep-link to their lists in one tap.
- [ ] Void/returned sales are excluded from all today totals.
- [ ] Offline shows cached numbers with an "as of <time>" stamp and an offline banner.
- [ ] A freshly synced day boundary attributes late offline sales to their `sold_at` day.
- [ ] First paint from cache < 200 ms; no full-screen spinner (skeletons only).

---

## 14. Related docs
- Foundation: [overview](../../../foundation/overview.md) ·
  [data-model](../../../foundation/data-model.md) ·
  [design-system](../../../foundation/design-system.md) ·
  [sync](../../../foundation/sync-and-conflict-resolution.md) ·
  [api-conventions](../../../foundation/api-conventions.md)
- API: [reports-notifications-api](../../../cloud/api/reports-notifications/reports-notifications-api.md) ·
  [stock-api](../../../cloud/api/stock/stock-api.md)
- Sibling screens: [Reports](../reports/reports.md) ·
  [Discount Approval](../approvals/discount-approval.md) ·
  [Staff Management](../staff/staff-management.md) ·
  [Notifications](../notifications/notifications.md) · [GST Registrations](../gst/gst-registrations.md)
- Counterpart: [web dashboard](../../../cloud/web/dashboard/dashboard-home.md)
