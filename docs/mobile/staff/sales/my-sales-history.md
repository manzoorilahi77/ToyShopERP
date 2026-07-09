# My Sales History — Staff · Mobile (Flutter, offline-first)

> Follows [`_templates/screen-doc-template.md`](../../../_templates/screen-doc-template.md).
> Tokens/components from [`design-system.md`](../../../foundation/design-system.md); envelope,
> filters & pagination from [`api-conventions.md`](../../../foundation/api-conventions.md);
> sync-status icons from [`sync-and-conflict-resolution.md`](../../../foundation/sync-and-conflict-resolution.md) §8.
> Legend: `✅ Specified` · `🧩 Derived (confirm with owner)` · `⚠️ Risk` · `🔒 Owner PIN`.

---

## 1. Purpose & context
- **What it is** — a scrollable list of the sales **this staff member** made (today by
  default, filterable to any date range), with a per-row **sync-status** icon, a totals
  summary, and tap-through to the [receipt](./receipt.md) for reprint/re-share.
- **Who & when** — a staff member checking "did that sale go through?", reconciling their
  day, reprinting a bill a customer lost, or confirming their contribution to the
  leaderboard.
- **Why it exists** — offline-first billing means some sales sit **pending**; staff need a
  trustworthy, glanceable view of what's saved and what's still syncing, plus a fast reprint
  path. It also reinforces R5 (see your own output) and supports audit/traceability.
- **Frequency / criticality** — several times a day; low write-risk (read-only list) but
  important for confidence in the offline system and for customer-service reprints.

## 2. Entry points & navigation
- **Arrive from:** the **Sales** bottom-nav tab; a "My Sales" link on
  [dashboard](../dashboard/dashboard-home.md).
- **Exit to:** [receipt](./receipt.md) on row tap (reprint/re-share); **New Sale** FAB →
  [new-sale](./new-sale.md); back → dashboard.
- **Back button:** returns to dashboard.

```
Dashboard ─▶ My Sales History ─┬─ tap row ─▶ Receipt (reprint/share)
                               └─ + FAB ───▶ New Sale
```

## 3. Roles & permissions
- **Open to:** the logged-in `staff` — **scoped to their own `staff_id`** (a staff member
  cannot browse another staff member's sales here; that's owner/web territory —
  [web sales-ledger](../../../cloud/web/sales/sales-ledger.md)).
- Read-only. No edits, no voids (owner/web only). No `🔒` actions.

## 4. Screen layout (wireframe)

```
┌──────────────── My Sales ──────────────── • 3 pending ─┐
│  [ Today ▾ ]   02-07-2026            🔎 filter dates    │  ← date-range chip
│                                                         │
│  ┌── Summary ──────────────────────────────────────┐   │
│  │  14 sales   ·   28 units   ·   ₹ 54,300          │   │
│  │  Cash ₹32,100 · UPI ₹18,200 · Card ₹4,000        │   │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  19:45  Inv GST1/26-27/000418   3 items   ₹6,497  ✓    │  ← synced
│  19:32  Inv GST1/26-27/000417   1 item    ₹1,999  ✓    │
│  19:20  Prov #A3F9              2 items   ₹2,998  •    │  ← pending
│  19:05  Prov #7C21             1 item     ₹  750  ↻    │  ← syncing
│  18:58  Inv GST1/26-27/000414  2 items    ₹3,050  !    │  ← failed (tap)
│                                                         │
│              ⟳ pull to refresh                          │
│                                        ┌───────────┐    │
│                                        │  ＋ Sale   │    │  ← FAB
│                                        └───────────┘    │
└─────────────────────────────────────────────────────────┘
```

Responsive: phone single list; tablet may show list + selected receipt side-by-side.
Money uses tabular numerals + ₹ grouping; each row's status uses **icon + tooltip**.

## 5. UI components & field-by-field spec

| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Date-range chip | dropdown/picker | Today / Yesterday / This week / This month / Custom | `from ≤ to` | **Today** | re-query `GET /sales?from=&to=` (+ local) | inclusive range (api-conventions §8) |
| 2 | Custom range picker | date pickers | user | valid dates, `from ≤ to` | — | applies filter | DD-MM-YYYY |
| 3 | Summary card | computed | current filtered set | — | today's totals | recompute on filter change | count · units · revenue + payment split |
| 4 | Sale row | list item | `sales` (own) | — | — | tap → [receipt](./receipt.md) | time · invoice/prov ref · items · total · sync icon |
| 5 | Sync-status icon | status | `sales.sync_status` | — | per row | ✓ synced · ↻ syncing · • pending · ! failed | tap ! → retry/detail (sync §8) |
| 6 | Invoice/prov ref | text | `sales.invoice_no` or provisional (client_uuid) | — | — | swaps to real after sync | "Prov #…" while pending |
| 7 | `SyncStatusChip` (header) | status | sync worker | — | current | tap → global sync sheet | aggregate pending count |
| 8 | Pull-to-refresh | gesture | re-query + `GET /sync/pull` | — | — | refresh list/status | offline → refresh from cache only |
| 9 | New Sale FAB | primary | — | — | — | → [new-sale](./new-sale.md) | keep billing one tap away |
| 10 | Empty state | `EmptyState` | — | — | — | "No sales yet today — make your first!" + New Sale | friendly |
| 11 | Infinite scroll | pagination | cursor (api-conventions §7) | — | first page | load next page on scroll | large ranges |

## 6. States

| State | What the user sees / can do |
|---|---|
| **default / populated** | Summary + today's sale rows with sync icons; tap to reprint. |
| **empty** | No sales in range → `EmptyState` with a New Sale CTA. |
| **loading** | Skeleton rows (design-system §7); cached rows shown immediately if present. |
| **error** | Server fetch fails → inline "couldn't refresh — showing local sales" + Retry; **local Drift rows still render** (offline sales are always visible). |
| **offline** | Banner "Working offline — showing this device's sales"; list served from Drift; pending/failed rows clearly marked; totals computed locally. |
| **success** | Pull-to-refresh reconciles rows (pending→synced, provisional→real invoice) with a subtle update. |
| **permission-denied** | N/A (own data). Attempting to view a foreign sale is simply not offered. |

## 7. Interactions, gestures & hardware
- **Tap** a row → receipt; **tap** the `!` icon → retry that sale's sync + show the last
  error; **pull-to-refresh**; **scroll** for pagination; **tap** FAB → New Sale.
- No camera/printer/mic here (printing happens on the receipt).
- **Latency:** list paints from cache < 200 ms; filter change re-renders local instantly and
  fetches server data in the background.

## 8. Business rules & edge cases
1. **Own sales only.** Every query is server-side scoped to the caller's `staff_id`
   (`GET /sales?staff_id={me}`) and locally filtered the same way — no cross-staff leakage.
2. **Local + server union.** The list merges Drift rows (including `pending`/`failed`
   offline sales not yet on the server) with the server result, de-duplicated by
   `client_uuid`, so nothing "disappears" while syncing.
3. **Status truth.** Row icons reflect `sales.sync_status` (`pending/syncing/synced/failed`);
   a `failed` row is tappable to retry (sync §8) and, if retries are exhausted, the owner also
   gets a `sync_failure` notification.
4. **Provisional → real invoice.** Rows show a provisional ref until the server assigns
   `invoice_no` (sync §7); after a pull the row shows the real number.
5. **Totals reflect the filter.** Summary count/units/revenue and the payment-mode split are
   computed over the **current filtered range**, including pending local sales, so the day
   number matches what the staff actually rang up.
6. **Date basis.** Filtering uses the business time `sales.sold_at` (not server receipt time),
   so an offline sale from 7 pm appears under that day even if it synced at 10 pm.
7. **Voided/oversold sales.** A sale later voided (owner/web) shows a "void" badge and is
   excluded from totals; an oversold-flagged sale still appears normally (the sale is valid).
8. **Reprint is safe.** Tapping to receipt and reprinting never creates a new sale (receipt
   rule 6).
9. **Large ranges** page via cursor; the summary for a wide server range may show a
   "computed on server" note rather than summing every page client-side (🧩).

## 9. API interactions

| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Open / filter | `GET /sales?staff_id={me}&from=&to=&sort=sold_at&order=desc` | fetch the staff's sales for the range | read Drift `sales` cache; union with local pending |
| Pull-to-refresh | `GET /sync/pull?since=` + re-query | reconcile status + invoice numbers | cache-only when offline |
| Row tap | (local) → [receipt](./receipt.md); may `GET /sales/{id}` | open receipt | local render |

- Filters/pagination/sorting per [`api-conventions.md`](../../../foundation/api-conventions.md)
  §7–8. See [`sales-api`](../../../cloud/api/sales/sales-api.md) and
  [`sync-api`](../../../cloud/api/sync/sync-api.md). Read-only screen — no writes originate
  here.

## 10. Offline & sync behavior
- **Fully readable offline.** The list is served from Drift `sales`/`sale_items`; offline and
  pending sales are always present with their live `sync_status`. This is the staff's proof
  that "the sale is saved even though it hasn't synced".
- Drift tables read: `sales`, `sale_items` (for item counts/receipt), `gst_registrations`
  cache (invoice display). No writes originate here except **retry** on a `failed` row, which
  re-enqueues the existing `sync_outbox` item (same `client_uuid`, idempotent — no duplicate).
- `sync_status` values surfaced 1:1 from the sync doc §8; the header chip aggregates counts.

### Proposed schema addition
None. Everything here reads canonical `sales`/`sale_items`/`gst_registrations`. A `void`
state, if surfaced, uses an existing status concept (owner/web void flow) rather than a new
column on this screen.

## 11. Analytics & events
- `sales_history_opened`, `history_filter_changed {range}`, `history_row_tapped {client_uuid}`,
  `history_retry_tapped {client_uuid}`, `history_pull_refresh {online}`,
  `history_empty_shown`.

## 12. Accessibility, localization & performance
- Rows ≥48 dp; status icons paired with an accessible label ("synced", "pending", "syncing",
  "sync failed, tap to retry"). WCAG AA contrast; never color-only status.
- Money tabular + ₹ grouping; dates DD-MM-YYYY; range labels localizable.
- Screen-reader reads each row as "7:45 pm, invoice …418, 3 items, 6,497 rupees, synced".
- Perf: cache paint < 200 ms; smooth 60 fps scroll; cursor pagination for long ranges.

## 13. Acceptance criteria
- [ ] Opens to **today's** sales for the logged-in staff, scoped to their `staff_id`.
- [ ] Each row shows time, invoice/provisional ref, item count, total, and a `sync_status`
      icon matching the sync doc (✓/↻/•/!).
- [ ] Offline and pending sales appear in the list (from Drift) and are not hidden.
- [ ] The date-range filter (Today/Week/Month/Custom) re-scopes both the list and the summary,
      based on `sold_at`.
- [ ] The summary shows count, units, revenue and a payment-mode split for the filtered range.
- [ ] Tapping a `failed` row retries its sync without creating a duplicate sale.
- [ ] Tapping a row opens its receipt for reprint/re-share.
- [ ] After sync, provisional refs update to real `invoice_no` and statuses reconcile.

## 14. Related docs
- **Foundation:** [api-conventions](../../../foundation/api-conventions.md) (filters/pagination)
  · [sync-and-conflict-resolution](../../../foundation/sync-and-conflict-resolution.md)
  (status icons §8) · [data-model](../../../foundation/data-model.md) ·
  [design-system](../../../foundation/design-system.md)
- **API:** [sales-api](../../../cloud/api/sales/sales-api.md) ·
  [sync-api](../../../cloud/api/sync/sync-api.md)
- **Sibling staff screens:** [new-sale](./new-sale.md) · [receipt](./receipt.md) ·
  [dashboard-home](../dashboard/dashboard-home.md)
- **Other surfaces:** [web sales-ledger](../../../cloud/web/sales/sales-ledger.md)
