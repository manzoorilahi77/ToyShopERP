# Web Dashboard Home — Owner / Accountant · Flutter Web

> Status: `✅ Specified` · Implements **Requirement 5** (modern dashboard) for the web
> surface. The landing screen after login; the glanceable command centre.

---

## 1. Purpose & context
- **What this screen is for** — a single, glanceable command centre: today's money and
  volume KPIs, a sales-trend chart, the staff leaderboard, and a profit-margin-by-category
  breakdown, plus one-tap drill-down into alerts (aging/low stock, GST liability).
- **Who uses it** — `owner` (pulse of the business) and `accountant` (starting point before
  ledgers/GST). Desktop; **mostly online**.
- **When** — start of a session; the owner glances several times a day; the accountant lands
  here before drilling into GST/ledgers, especially at **GST season**.
- **Why it exists** — the brief (R5) demands "full KPI cards, sales trend charts, staff
  leaderboard, category profit margin breakdown." It replaces the owner's memory-based
  gut-feel with real numbers, and surfaces the two biggest cash risks — **aging stock**
  (dead inventory) and **low stock** (missed sales) — where they can't be ignored.
- **Frequency / criticality** — high frequency, medium per-glance criticality; the data must
  be **trustworthy and fresh** (it drives purchasing and staffing decisions).

---

## 2. Entry points & navigation
- **Arrival** — default post-login landing ([../auth/login.md](../auth/login.md)); sidebar
  **Dashboard** item (always first); logo click; `g d` shortcut.
- **Exits (drill-downs)**
  - KPI **Pending GST liability** → [../gst/gst-filing.md](../gst/gst-filing.md).
  - **Aging stock** alert tile → [../stock/stock-report.md](../stock/stock-report.md) (Aging tab).
  - **Low stock** alert tile → [../stock/stock-report.md](../stock/stock-report.md) (Low tab).
  - **Staff leaderboard** row → [../staff/staff-performance.md](../staff/staff-performance.md) for that staff.
  - **Category margin** bar → [../sales/sales-ledger.md](../sales/sales-ledger.md) filtered to that category.
  - Any sidebar item → its screen.
- **Back-button** — Dashboard is the shell root; Back from a drill-down returns here.
- Nav diagram: `Login → Dashboard → {GST | Stock | Staff | Sales} → Dashboard`.

---

## 3. Roles & permissions
| Actor | Access | Notes |
|---|---|---|
| Owner | full | all KPIs, charts, drill-downs |
| Accountant | full read | same view; every widget is **read-only analytics** (no writes on this screen) |
| Staff | ⛔ | cannot reach the web dashboard at all |
- Nothing here is `🔒 owner-PIN` gated — it's all read-only reporting. Money-moving actions
  live on other screens.

---

## 4. Screen layout (wireframe)
Left **sidebar shell** (persistent on all authenticated web screens) + content grid.

```
┌────────────┬───────────────────────────────────────────────────────────────┐
│ 🧸 ToyShop │  Dashboard                         🔄 Updated 2 min ago  ⟳  👤 │  ← top bar
│            │  Period: [ Today ▾ ]  GSTIN: [ All ▾ ]                          │
│ ▸Dashboard │ ┌──────────┐┌──────────┐┌──────────┐┌──────────┐               │
│  Sales     │ │₹ 84,250  ││₹ 21,100  ││   47     ││₹ 12,380  │  ← KPI cards   │
│  Purchases │ │Sales tdy ││Profit est││Items sold││GST due  ▲ │               │
│  Stock     │ │  ▲ 12%   ││  ▲ 8%    ││  ▲ 4     ││ this mo. │               │
│  GST       │ └──────────┘└──────────┘└──────────┘└──────────┘               │
│  Staff     │ ┌───────────────────────────────┐┌─────────────────────────┐   │
│  Catalog   │ │ Sales trend   [D][W][M] [▮][/]│││ Staff leaderboard        │  │
│  Settings  │ │                              ╱ │││ 1 Ravi   ₹ 31,200  🥇   │  │
│            │ │        ╱╲      ╱╲    ╱╲  ╱╲╱   │││ 2 Anu    ₹ 24,500       │  │
│            │ │   ╱╲╱    ╲╱╲╱    ╲╱      (line)│││ 3 Kumar  ₹ 18,900       │  │
│            │ │ Mon Tue Wed Thu Fri Sat Sun    │││ 4 …                      │  │
│            │ └───────────────────────────────┘│└─────────────────────────┘   │
│            │ ┌───────────────────────────────┐┌─────────────────────────┐   │
│ ───────    │ │ Profit margin by category     │││ ⏳ Aging stock   14 items│  │
│ 👤 Owner   │ │ Battery Cars ███████░ 34%     │││    ₹ 62,000 tied  →      │  │
│ ✓ synced   │ │ Ride-ons     █████░░░ 26%     │││ 🟠 Low stock     6 items │  │
│ Logout     │ │ Play Sets    ████████ 41%     │││    reorder now   →       │  │
└────────────┴─┴───────────────────────────────┴┴─────────────────────────┴───┘
```

**Sidebar nav placement** — Dashboard is the **first** item; the shell order is fixed across
all web screens: Dashboard · Sales · Purchases · Stock · GST · Staff · Catalog · Settings.
Footer: user avatar + role, global sync/last-refresh chip, Logout.

**Responsive breakpoints** (shared across web screens):

| Name | Width | Sidebar | Content grid |
|---|---|---|---|
| Compact | < 768 px | hidden → hamburger drawer | 1 col: KPIs stack 2×2 → 1×4; charts full-width stacked |
| Medium | 768–1199 px | 72 px icon rail (labels on hover) | 2 cols; KPIs 2×2; trend over leaderboard |
| Expanded | 1200–1599 px | full 248 px sidebar | 4 KPIs in a row; trend + leaderboard side-by-side; margins + alerts row |
| Wide | ≥ 1600 px | full sidebar | content max 1440 px centred; charts get more breathing room |

---

## 5. UI components & field-by-field spec
| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Period selector | dropdown | Today · Yesterday · This week · This month · Custom | valid range | **Today** | refetches all widgets for the range | persists per user |
| 2 | GSTIN filter | dropdown | `gst_registrations` (active) + "All" | must be active | **All** | scopes KPIs/trend to a registration | matches GST multi-registration reality |
| 3 | KPI: Sales today | `KpiCard` | `reports/owner-dashboard.sales_total` | — | — | tabular ₹, trend arrow vs prior period | Display 34/40, `₹1,23,456` grouping |
| 4 | KPI: Profit estimate | `KpiCard` | `…profit_estimate` (Σ(unit_price−cost_price)×qty) | — | — | ▲/▼ vs prior | "est." label — derived from last cost_price |
| 5 | KPI: Items sold | `KpiCard` | `…units_sold` | — | — | integer count | tabular |
| 6 | KPI: GST due (period) | `KpiCard` | `…gst_liability` | — | — | tap → GST Filing | `--warning` accent when due date near |
| 7 | Sales trend chart | line/bar | `reports/sales-trend` | — | line | see §chart | granularity + type toggles |
| 8 | Granularity toggle | segmented | Daily · Weekly · Monthly | — | Daily | refetch trend at granularity | keyboard `d/w/m` |
| 9 | Chart-type toggle | segmented | Line (`/`) · Bar (`▮`) | — | Line | swaps mark, same data/axis | one y-axis only |
| 10 | Staff leaderboard | ranked list | `staff/leaderboard` | — | by revenue | row → staff performance | badge/medal on top 3 |
| 11 | Leaderboard metric | toggle | Revenue · Units | — | Revenue | resort list | metric label shown |
| 12 | Category margin chart | horizontal bar | `reports/category-margins` | — | by margin % | bar → filtered Sales Ledger | sequential ramp by magnitude |
| 13 | Aging stock alert | `AlertTile` | `reports/owner-dashboard.aging` | — | — | → Stock Report (Aging) | count + ₹ tied up |
| 14 | Low stock alert | `AlertTile` | `reports/owner-dashboard.low_stock` | — | — | → Stock Report (Low) | count |
| 15 | Refresh / last-updated | button + timestamp | client | — | auto | `⟳` refetch all; shows "Updated N min ago" | `r` shortcut |

### Chart / dataviz approach (reference [dataviz] method, conceptual)
Following the dataviz procedure (form → color-by-job → validate → marks → hover → a11y):
- **Sales trend** — job is *change over time* → a **line** (default) with a **bar** alternate;
  **one y-axis only** (₹). Daily/Weekly/Monthly re-aggregates the same series; **never a
  dual-axis** overlay of units + revenue (use the Units toggle to switch the single series
  instead). Crosshair + tooltip on hover; recessive gridlines; tabular ₹ on the axis.
- **Staff leaderboard** — job is *identity/ranking* → **categorical** color, one fixed hue per
  staff (color follows the staff, not the rank position); top-3 get a medal **icon + label**,
  never color-alone. A 7th+ staff folds into the list, not a new generated hue.
- **Category margin** — job is *magnitude* (a %) → **sequential** single-hue ramp
  (light→dark by margin), not a rainbow. Direct-label each bar with its %.
- **KPI cards / trend arrows** — `--success` up / `--danger` down are **status** colors, paired
  with ▲/▼ glyphs (not color-alone), and never reused as a series hue.
- Legend present for any ≥ 2-series chart; a table view is available; dark mode is a
  first-class selected variant (both must pass WCAG AA on their own surface).

---

## 6. States
- **default / populated** — KPIs + charts filled for the selected period/GSTIN.
- **empty** — a brand-new shop with no sales: KPIs show `₹0`/`0`; charts show a friendly
  `EmptyState` ("No sales yet for this period"); alerts hidden when zero.
- **loading** — **skeleton** KPI cards and shimmer chart placeholders (never blank); each
  widget loads independently so a slow one doesn't block the rest.
- **error (inline, retry)** — a failed widget shows an inline "Couldn't load — Retry" card in
  its own slot; the rest of the dashboard still renders (isolated failures).
- **offline** — calm top banner "You're offline — showing last loaded figures at HH:MM";
  widgets show last successful data, dimmed, with a stale badge; `⟳` disabled until online.
- **success** — refresh completes → "Updated just now" + subtle checkmark on the refresh chip.
- **permission-denied** — not reachable by staff; if an accountant hits an owner-only future
  widget, that widget shows a lock note (currently none).

---

## 7. Interactions, gestures & hardware
- **Keyboard shortcuts** — global: `?` shortcuts overlay · `Ctrl/Cmd+K` jump/command palette ·
  `g d` Dashboard, `g s` Sales, `g u` Purchases, `g k` Stock, `g g` GST, `g f` Staff,
  `g c` Catalog, `g ,` Settings · `r` refresh · `/` focus Period selector. Screen-local:
  `d/w/m` trend granularity, `l` toggle line/bar, `v` toggle Revenue/Units leaderboard.
- **Hover** — charts show crosshair + tooltip; leaderboard/margin rows highlight and reveal a
  "→ open" affordance.
- **Click** — KPI GST / alert tiles / leaderboard rows / margin bars all drill down (§2).
- **No hardware** — desktop only (`N/A` camera/printer/scanner).
- **Latency** — dashboard should feel instant from cache; target first meaningful widget
  < 800 ms, all widgets < 2.5 s on broadband; refresh is non-blocking (skeleton over stale).

---

## 8. Business rules & edge cases
1. **R1 — Period + GSTIN scope everything.** Every KPI/chart respects the two top filters;
   "All GSTIN" aggregates across registrations. Inactive GSTINs are not offered.
2. **R2 — Profit is an estimate.** Profit = Σ((`sale_items.unit_price` − product
   `cost_price`) × qty) − discounts, using the product's **last** `cost_price` (no
   per-lot FIFO). Labelled "est." to set expectations.
3. **R3 — GST due = current open period liability** for the selected GSTIN (output GST − ITC),
   computed like [../gst/gst-filing.md](../gst/gst-filing.md); shown `--warning` as the filing
   due date approaches.
4. **R4 — Trend granularity vs range.** Daily for ≤ ~90 days, Weekly for longer, Monthly for
   year+; picking a granularity coarser/finer than the range re-aggregates server-side.
5. **R5 — Leaderboard source of truth.** Ranked from `sales` aggregated by `staff_id` over the
   period (not the denormalized `staff.current_month_points` cache, which may lag); ties
   broken by units then earliest first-sale.
6. **R6 — Only synced/confirmed data counts.** Rows with `sales.sync_status IN ('pending',
   'failed')` are **not** in web KPIs (web reads the server's source of truth); the count of
   unsynced items may be surfaced as an info note, never mixed into totals.
7. **R7 — Void/return handling.** Voided sales and `return_in` movements are netted out so KPIs
   and margins aren't inflated.
8. **R8 — Aging/low thresholds** come from `app_settings.aging_threshold_days` and
   `products.reorder_threshold` (per-product override respected) — see Stock Report.
9. **R9 — Timezone.** "Today" is the shop's local day (IST, `Asia/Kolkata`); server converts
   from stored UTC using business dates (`sold_at`).
10. **R10 — Empty categories** (no sales in period) are omitted from the margin chart, not
    shown as 0% clutter.

---

## 9. API interactions
| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Load / period or GSTIN change | `GET /reports/owner-dashboard?period=&gstin_id=` | KPIs + alert counts (sales, profit, units, GST due, aging, low) | show last cached; stale badge |
| Load / trend toggle | `GET /reports/sales-trend?period=&granularity=daily|weekly|monthly&metric=revenue|units&gstin_id=` | trend series | cached |
| Load / margin | `GET /reports/category-margins?period=&gstin_id=` | margin % per category | cached |
| Load / leaderboard toggle | `GET /staff/leaderboard?period=&metric=revenue|units&gstin_id=` | ranked staff | cached |
| Manual refresh `⟳` / `r` | all four above | refetch | disabled offline |

- All are **GET, read-only, no idempotency key** (no writes on this screen).
- Response shape follows the list/object envelope in
  [api-conventions.md](../../../foundation/api-conventions.md) §4.
- API docs: [../../api/reports-notifications/reports-notifications-api.md](../../api/reports-notifications/reports-notifications-api.md)
  (dashboard/trend/margins), [../../api/staff/staff-api.md](../../api/staff/staff-api.md) (leaderboard).

**`GET /reports/owner-dashboard` — key response fields**
`{ sales_total, profit_estimate, units_sold, gst_liability, sales_delta_pct,
   aging: { count, value_tied }, low_stock: { count } }`.

---

## 10. Offline & sync behavior
- **Read-only; no writes, no outbox.** Web keeps only an **in-session cache** of the last
  successful responses; there is no Drift DB on web (see [overview.md](../../../foundation/overview.md) §2).
- Offline → serve last cache with a "stale as of HH:MM" badge; `⟳` disabled; recovers on
  reconnect.
- Sets no `sync_status`. It **reads** server-reconciled figures, so it never shows negative or
  double-counted stock — reconciliation is upstream, per
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md).

---

## 11. Analytics & events
| Event | When | Properties |
|---|---|---|
| `web_dashboard_viewed` | load | `period`, `gstin_id` |
| `web_dashboard_filter_changed` | period/GSTIN change | `field`, `value` |
| `web_trend_toggled` | granularity/type/metric | `granularity`, `chart_type`, `metric` |
| `web_leaderboard_metric_toggled` | toggle | `metric` |
| `web_kpi_drilldown` | KPI/alert click | `target` (`gst`\|`aging`\|`low`) |
| `web_dashboard_refresh` | `⟳`/`r` | `duration_ms` |

---

## 12. Accessibility, localization & performance
- **A11y** — every chart has an equivalent **table view** toggle; series identity via legend
  **and** direct labels (never color-alone); ▲/▼ glyphs accompany success/danger; KPI numbers
  are large (Display 34/40) tabular for legibility; charts respect "reduce motion";
  keyboard-navigable legends and drill targets; WCAG AA in light **and** dark.
- **Localization** — `₹` with Indian grouping `1,23,456.00`; DD-MM-YYYY dates; period/GST
  terms localizable; number/date formatting via locale.
- **Performance** — widgets load in parallel and independently; skeletons over blanks; first
  KPI < 800 ms, full board < 2.5 s; charts virtualize long series; refresh never blocks
  interaction.

---

## 13. Acceptance criteria
- [ ] Four KPI cards (Sales today, Profit est., Items sold, GST due) render with tabular `₹`
      Indian grouping and a ▲/▼ trend vs the prior comparable period.
- [ ] Period + GSTIN filters re-scope **all** widgets; inactive GSTINs are not selectable.
- [ ] Sales-trend chart toggles Daily/Weekly/Monthly and Line/Bar on **one** y-axis (never dual-axis).
- [ ] Leaderboard ranks staff by revenue **or** units for the period; top 3 show a medal icon
      + label (not color-alone); a row opens that staff's performance screen.
- [ ] Category margin chart uses a single-hue sequential ramp with a % direct label per bar;
      a bar opens the Sales Ledger filtered to that category.
- [ ] Aging/low alert tiles show live counts and drill to the Stock Report tabs.
- [ ] Only server-synced (`synced`) data is counted; pending/failed/void excluded from totals.
- [ ] Each widget fails and retries independently; one failure doesn't blank the dashboard.
- [ ] Every chart offers a table-view alternative and passes WCAG AA in light and dark.
- [ ] Offline shows last-loaded figures with a stale badge; recovers on reconnect.

---

## 14. Related docs
- Foundation: [design-system.md](../../../foundation/design-system.md) (`KpiCard`, `AlertTile`) ·
  [data-model.md](../../../foundation/data-model.md) ·
  [api-conventions.md](../../../foundation/api-conventions.md) ·
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md)
- API: [../../api/reports-notifications/reports-notifications-api.md](../../api/reports-notifications/reports-notifications-api.md) ·
  [../../api/staff/staff-api.md](../../api/staff/staff-api.md)
- Sibling web screens: [../gst/gst-filing.md](../gst/gst-filing.md) ·
  [../stock/stock-report.md](../stock/stock-report.md) ·
  [../staff/staff-performance.md](../staff/staff-performance.md) ·
  [../sales/sales-ledger.md](../sales/sales-ledger.md)
- Mobile counterpart: [../../../mobile/owner/dashboard/dashboard-home.md](../../../mobile/owner/dashboard/dashboard-home.md)
