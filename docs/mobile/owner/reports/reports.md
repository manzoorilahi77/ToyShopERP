# Reports (condensed) — Owner · Mobile (Owner App)

> The mobile, glanceable slice of reporting (Requirement 4/5): a **sales summary**
> (today / week / month), a **stock-aging** tile + list, a **low-stock** list, and a
> **quick GST snapshot** per GSTIN. Each section drills down; the heavy ledgers and exports
> live on the [web dashboard](../../../cloud/web/dashboard/dashboard-home.md).

Status: `✅ Specified` · read-only. Drill-downs link to lists; deep analysis defers to web.

---

## 1. Purpose & context
- **What this screen is for:** let the owner answer "how are we doing, what's stuck, what do
  I owe in GST" in a few taps, on the floor.
- **Who & when:** the **owner** (accountant read-only). Checked through the day and near
  month/quarter GST time.
- **Why it exists:** R4/R5 call for a condensed mobile view — "sales summary, stock aging,
  quick GST snapshot" — with aging stock ("unsold beyond 30/60/90 days") and low stock
  ("below reorder threshold") as first-class tiles
  ([requirements R4, R5](../../../requirements_and_prompt.md)).
- **Frequency / criticality:** high frequency; the aging/low tiles directly prevent cash
  tied up in dead stock and stockouts.

---

## 2. Entry points & navigation
- **KPI taps** on [Dashboard Home](../dashboard/dashboard-home.md) land on the matching
  section here; **More → Reports** opens the top.
- **Alert tiles** (dashboard low/aging) deep-link to the corresponding list here.

```
Dashboard KPI/AlertTile ─▶ Reports ─┬─▶ Sales summary (today/week/month)
                                    ├─▶ Aging stock list → product → New Purchase (reorder)
                                    ├─▶ Low stock list → "Create purchase order"
                                    └─▶ GST snapshot (per GSTIN) → web GST filing
```
- **Back:** section list → Reports home → Dashboard.

---

## 3. Roles & permissions
| Actor | Access |
|---|---|
| Owner | ✅ all sections + drill-downs |
| Accountant | ✅ read all (esp. GST snapshot) |
| Staff | ❌ (staff see only their own [sales history](../../staff/sales/my-sales-history.md)) |
- Fully read-only. Action shortcuts (e.g. "Create purchase order") navigate to
  [New Purchase](../purchase/new-purchase.md); no `🔒` gate on this screen.

---

## 4. Screen layout (wireframe)

```
┌──────────────────────────────────────────────┐
│ ← Reports                        ✓sync        │
│  Sales   [ Today | Week | Month ]             │  ← period segmented
│  ┌───────────────┐  ┌───────────────┐          │
│  │ SALES ₹1.24L  │  │ PROFIT ₹31.2K │          │
│  └───────────────┘  └───────────────┘          │
│  Items 86 · Sales 41 · Avg ₹3,045              │
│  [ view sales on web → ]                        │
├──────────────────────────────────────────────┤
│  ⏳ AGING STOCK   [30|60|90 ▾]        (12)     │  ← tile + threshold picker
│  • Blue Jet Bike     72 days   ₹4,299  [reorder?]│
│  • Play Set A        95 days   ₹  899           │
│  • …                                            │
├──────────────────────────────────────────────┤
│  🟠 LOW STOCK                          (7)     │
│  • Red Racer Car   on-hand 2 / reorder 3  [＋PO]│
│  • Mini Bike       on-hand 1 / reorder 3  [＋PO]│
├──────────────────────────────────────────────┤
│  🧾 GST SNAPSHOT (this month)                  │
│  27ABCDE1234F1Z5   output ₹18,940  ITC ₹3,888  │
│                    net payable ₹15,052         │
│  29XYZAB5678K1Z0   output ₹ 4,120  ITC ₹  600  │
│  [ open GST filing on web → ]                   │
└──────────────────────────────────────────────┘
```

- **Responsive:** phone = stacked sections. Tablet = 2-column (sales+GST | aging+low).

---

## 5. UI components & field-by-field spec

| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Sales period | segmented | Today \| Week \| Month | — | Today | re-query `sales-summary` | drives all sales figures |
| 2 | Sales total | `KpiCard` money | `GET /reports/sales-summary` `sales_total` | — | ₹0.00 | tap → web sales ledger | excl. void |
| 3 | Profit (est.) | `KpiCard` money | summary `profit_estimate` | — | ₹0.00 | — | labelled est. (latest cost) |
| 4 | Items / count / avg | stat line | summary `items_sold`, `sales_count`, avg | — | 0 | — | tabular |
| 5 | Aging threshold | dropdown 30/60/90 | `app_settings.aging_threshold_days` default; overridable | — | global default | re-query `/stock/aging` | per [api-conventions §8](../../../foundation/api-conventions.md) |
| 6 | Aging list row | list row | `GET /stock/aging` (product, days-in-stock, value) | — | — | tap → product / reorder | sorted longest-sitting first |
| 7 | Aging count | badge | `/stock/aging` total | — | 0 | — | matches dashboard tile |
| 8 | Low-stock list row | list row | `GET /stock/low` (product, on-hand, reorder_threshold) | — | — | tap → product; **＋PO** → New Purchase | on-hand from `v_current_stock` |
| 9 | Create PO shortcut | button | — | — | — | opens [New Purchase](../purchase/new-purchase.md) prefilled | R4 low-stock action |
| 10 | GST snapshot row | per-GSTIN card | `GET /gst/summary` (output, ITC, net) | — | — | tap → web GST filing | one row per **active** GSTIN |
| 11 | GST period | inherited | current month/quarter | — | this month | switch period | `period=YYYY-MM`/`YYYY-Qn` |
| 12 | "open on web" links | link | — | — | — | deep-link to web ledgers/filing | heavy work is web-first |

**Prose notes**
- **Aging stock** = products whose most-recent inbound (`stock_movements.purchase_in`) or
  last sale is older than the threshold and still on hand; each row shows days-in-stock and
  tied-up value (`on_hand × cost_price`). Threshold resolves per-product
  (`products.aging_threshold_days`) then global (`app_settings.aging_threshold_days`).
- **Low stock** = `on_hand ≤ products.reorder_threshold` (on-hand from `v_current_stock`);
  **oversold** (on-hand < 0 after reconciliation) shows distinctly (🔴 "needs count", see
  [sync §5](../../../foundation/sync-and-conflict-resolution.md)).
- **GST snapshot** = per-GSTIN, for the period: output GST (`Σ sales.tax_amount`), ITC
  (`Σ purchases.total_gst` with a supplier GSTIN), net payable; a missing-supplier-GSTIN
  ITC-risk count is noted. Authoritative GSTR-1/3B and export live on
  [web GST filing](../../../cloud/web/gst/gst-filing.md).
- **Mobile is condensed by design:** big lists, sorting and CSV/XLSX export are web-only.

---

## 6. States
- **Default / populated:** all four sections filled for the current periods.
- **Empty:** "No sales in this period" / "All stock healthy — nothing aging or low" /
  "No GST activity this period."
- **Loading:** skeletons per section (independent; sales can load before stock).
- **Error:** per-section inline retry; one failing section never blanks the others.
- **Offline:** cached figures with an "as of <time>" stamp + offline banner; drill-downs
  open cached lists; "open on web" links noted as needing connection.
- **Success:** pull-to-refresh updates the freshness stamp.
- **Permission-denied:** n/a (all allowed roles are read).

---

## 7. Interactions, gestures & hardware
- **Segmented control** switches sales period; **threshold dropdown** switches aging bucket.
- **Tap** any row → product detail / reorder / web link; **＋PO** → New Purchase.
- **Pull-to-refresh** re-queries all sections.
- No hardware.
- **Latency:** cached paint < 200 ms; fresh section fetch < 1 s each.

---

## 8. Business rules & edge cases
1. Money uses `DECIMAL`-derived values, `₹` + Indian grouping + tabular; profit is an
   **estimate** (latest `cost_price`).
2. Void/returned sales excluded from sales summary and profit.
3. Aging & low-stock thresholds obey per-product override then `app_settings`.
4. GST snapshot covers **active** GSTINs only; period defaults to current month.
5. ITC only counts purchases that have a `supplier_gstin`; the missing-GSTIN count is the
   ITC-risk flag surfaced for follow-up before filing.
6. Stock figures derive from `v_current_stock` (`SUM(quantity_delta)`), never a mutable
   counter; **oversold** products are flagged for a physical count.
7. All numbers reflect **synced** server state; the freshness stamp exposes any lag from the
   owner's own queued items.
8. Drill-down date/threshold windows are passed through so the detail matches the summary.

---

## 9. API interactions

| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Sales section | `GET /reports/sales-summary?period=today\|week\|month` | totals, profit est., items, count | cached "as of" |
| Aging section | `GET /stock/aging?threshold_days=30\|60\|90` | aging products + days + value | cached list |
| Low-stock section | `GET /stock/low` | products ≤ reorder_threshold | cached list |
| GST snapshot | `GET /gst/summary?period=YYYY-MM` | per-GSTIN output/ITC/net | cached snapshot |
| Reorder shortcut | → [New Purchase](../purchase/new-purchase.md) | prefill supplier/product | queued write path |

Key response fields (see
[reports-notifications-api](../../../cloud/api/reports-notifications/reports-notifications-api.md),
[stock-api](../../../cloud/api/stock/stock-api.md), [gst-api](../../../cloud/api/gst/gst-api.md)):
- **sales-summary:** `{ period, sales_total, profit_estimate, items_sold, sales_count }`
- **stock/aging:** `[{ product_id, name, days_in_stock, on_hand, tied_value }]` sorted desc
- **stock/low:** `[{ product_id, name, on_hand, reorder_threshold, oversold: bool }]`
- **gst/summary:** `[{ gstin_id, gstin, output_gst, itc, net_payable, itc_risk_count }]`
- Envelope/errors per [api-conventions](../../../foundation/api-conventions.md).

---

## 10. Offline & sync behavior
- **Works offline:** all four sections render from the last cached payloads, clearly stamped
  "as of <time>."
- **Queued / written:** nothing here (read-only); the reorder shortcut hands off to the
  purchase write path.
- **Blocked offline:** fresh recompute and the "open on web" deep-links.
- See [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md);
  stock truth is the reconciled `stock_movements` sum.

---

## 11. Analytics & events
- `reports_viewed`
- `sales_period_changed` (today | week | month)
- `aging_threshold_changed` (30 | 60 | 90)
- `low_stock_reorder_started` (product_id)
- `gst_snapshot_viewed` (period, gstin count)
- `report_web_deeplink_tapped` (target: sales | gst)

---

## 12. Accessibility, localization & performance
- KPI numbers large + tabular; stock statuses use **icon + label** (⏳ aging, 🟠 low,
  🔴 oversold), never color alone.
- `₹` Indian grouping; dates **DD-MM-YYYY**; GST terms (output/ITC/net) localized.
- Per-section skeletons; each section fetch < 1 s on 4G; cached paint < 200 ms.
- Screen-reader reads rows as "product, days in stock, value, tap to reorder."

---

## 13. Acceptance criteria
- [ ] Sales summary switches between today/week/month and excludes void sales.
- [ ] Aging list respects the 30/60/90 threshold (per-product override then `app_settings`)
      and sorts longest-sitting first with tied-up value.
- [ ] Low-stock list shows on-hand vs reorder_threshold from `v_current_stock` and offers a
      "create purchase order" shortcut into New Purchase.
- [ ] GST snapshot shows per active-GSTIN output GST, ITC and net payable, plus an ITC-risk
      (missing supplier GSTIN) count.
- [ ] Each section drills down and passes its date/threshold window to the detail.
- [ ] Offline renders cached figures with an "as of <time>" stamp; a failing section shows
      inline retry without blanking the others.
- [ ] Oversold products are flagged distinctly in the low-stock list.

---

## 14. Related docs
- Foundation: [data-model](../../../foundation/data-model.md) (`sales`, `stock_movements`,
  `v_current_stock`, `gst_registrations`) · [sync](../../../foundation/sync-and-conflict-resolution.md) ·
  [api-conventions](../../../foundation/api-conventions.md) · [design-system](../../../foundation/design-system.md)
- API: [reports-notifications-api](../../../cloud/api/reports-notifications/reports-notifications-api.md) ·
  [stock-api](../../../cloud/api/stock/stock-api.md) · [gst-api](../../../cloud/api/gst/gst-api.md)
- Sibling screens: [Dashboard Home](../dashboard/dashboard-home.md) ·
  [New Purchase](../purchase/new-purchase.md) · [GST Registrations](../gst/gst-registrations.md)
- Counterparts: [web dashboard](../../../cloud/web/dashboard/dashboard-home.md) ·
  [web stock report](../../../cloud/web/stock/stock-report.md) ·
  [web GST filing](../../../cloud/web/gst/gst-filing.md)
