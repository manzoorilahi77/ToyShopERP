# Staff Performance — Owner / Accountant · Flutter Web

> Status: `✅ Specified` · Implements **Requirement 5** (incentives/gamification) for the web:
> detailed per-staff sales stats, **incentive tier progress**, and **badge history**, with
> date-range and cross-staff comparison.

---

## 1. Purpose & context
- **What this screen is for** — a deep dive on one staff member (or a comparison across the
  5–6 staff): sales stats over a date range, **incentive tier progress** toward configured
  rules, and **badge history** — the analytical counterpart to the mobile gamified dashboard.
- **Who uses it** — `owner` (who sells best, who to coach, who earned an incentive) and
  `accountant` (verify incentive payouts against the rules).
- **When** — end-of-month incentive review, performance conversations, and whenever the
  Dashboard leaderboard prompts a drill-down.
- **Why it exists** — the brief (R5): the owner had "no visibility into which staff member sells
  best," and incentive rules need a live, auditable progress view. Breaking big targets into
  visible tiers keeps staff engaged; the owner needs the numbers behind the leaderboard.
- **Frequency / criticality** — moderate; **medium-high** when it drives real incentive money —
  the stats must reconcile with the Sales Ledger exactly.

---

## 2. Entry points & navigation
- **Arrival** — sidebar **Staff** (6th item); `g f`; Dashboard **leaderboard** row → this staff;
  Sales Ledger drawer "View staff".
- **Exits**
  - **View sales** → [../sales/sales-ledger.md](../sales/sales-ledger.md) filtered to this
    `staff_id` + range.
  - **Incentive rules** → [../settings/settings.md](../settings/settings.md) (rule config).
  - **Compare** → adds a second/third staff column (in-screen).
  - **Export** → per-staff or comparison CSV/XLSX.
- **Back-button** — returns to the staff list / previous screen; selected staff + range in URL.
- Nav diagram: `Dashboard leaderboard → Staff Performance → {Sales Ledger | Settings rules}`.

---

## 3. Roles & permissions
| Actor | Access | Notes |
|---|---|---|
| Owner | full read + export | sees all staff, incentives, badges |
| Accountant | full read + export | same, to verify payouts; **read-only** |
| Staff | ⛔ | web is owner/accountant only; staff see their own stats in the mobile app |
- Read-only analytics. Editing incentive **rules** happens in Settings (owner). No `🔒 owner-PIN`
  gate here. This screen never awards/removes a badge manually (badges are earned by criteria).

---

## 4. Screen layout (wireframe)
Sidebar shell + staff picker + range + stat cards + tier-progress + badge history + optional
comparison.

```
┌──────────┬──────────────────────────────────────────────────────────────────────┐
│ 🧸       │  Staff Performance          Staff[ Ravi ▾ ] + Compare   ⟳   Export ▾  │
│ Dashboard│  Range[ 01-06-2026 – 30-06-2026 ▾ ]  vs prev period                    │
│ Sales    │ ┌──────────┐┌──────────┐┌──────────┐┌──────────┐                       │
│ Purchases│ │₹ 31,200  ││   142    ││ ₹ 219    ││  #1 / 6  │  ← stat cards          │
│ Stock    │ │Revenue   ││Units sold││Avg sale  ││ Rank     │                        │
│ GST      │ │ ▲ 14%    ││ ▲ 12     ││ ▲ ₹8     ││ leaderbd │                        │
│ Staff ▸  │ └──────────┘└──────────┘└──────────┘└──────────┘                       │
│ Catalog  │  ── Incentive tier progress ──────────────────────────────────────     │
│ Settings │  Monthly target: 150 units   [██████████████░░░]  142 / 150 (Tier 2)   │
│          │  Reward: ₹500 bonus @150 · next tier 200 units → ₹1,000                 │
│ ──────   │  Revenue tier: ₹30k [████████████████████] reached ✓                   │
│ 👤 Owner │  ── Badge history ────────────────────────────────────────────────     │
│ ✓ synced │  🏅 Top Seller (Jun)   🏅 50 Toys Club   🏅 Fast Starter               │
│          │  ── Daily units (Jun) ──── ╱╲  ╱╲╱╲  ╱  (sparkline)                     │
└──────────┴──────────────────────────────────────────────────────────────────────┘
```

**Sidebar nav placement** — Staff is the **6th** item. **Comparison mode** adds columns
side-by-side (up to the 5–6 staff). Stat cards are big tabular numbers with ▲/▼ vs prior period.

**Responsive breakpoints**

| Name | Width | Layout |
|---|---|---|
| Compact | < 768 px | staff picker + range stack; stat cards 2×2; tiers stacked; comparison → swipeable columns |
| Medium | 768–1199 px | stat cards in a row; single staff; comparison max 2 |
| Expanded | 1200–1599 px | full stat row + tiers + badges + sparkline; comparison up to 3 |
| Wide | ≥ 1600 px | comparison up to 6 staff columns; extra chart space |

---

## 5. UI components & field-by-field spec
| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Staff picker | dropdown | `staff` (role=staff, active + inactive toggle) | — | from entry / top performer | reloads all widgets | photo + name |
| 2 | Compare | multi-add | `staff` | ≤ 6 | off | adds comparison columns | color per staff (categorical, fixed) |
| 3 | Date range | range picker | user | `from ≤ to` | current month | refetch | on `sold_at` |
| 4 | vs previous | toggle | — | — | on | shows ▲/▼ deltas | prior comparable period |
| 5 | Stat: Revenue | `KpiCard` | `Σ sales.total` for staff/range | — | — | tabular ₹ + Δ | reconciles with Sales Ledger |
| 6 | Stat: Units | `KpiCard` | `Σ sale_items.quantity` | — | — | integer + Δ | |
| 7 | Stat: Avg sale | `KpiCard` | revenue / sale count | — | — | ₹ + Δ | |
| 8 | Stat: Rank | `KpiCard` | leaderboard position in range | — | — | "#1 / 6" | ties → units then earliest |
| 9 | Incentive tier progress | progress bars | `staff_incentive_progress` × `incentive_rules` | — | active rules | `current_value / target_value`, `tier_reached` | one bar per active rule |
| 10 | Badge history | badge chips | `staff_badges` × `badges` | — | all earned | hover → criteria + `earned_at` + `period` | icon + name |
| 11 | Daily trend | sparkline/line | derived daily units/revenue | — | units | toggle metric | one axis |
| 12 | Export ▾ / Refresh ⟳ | menu/btn | CSV · XLSX | — | — | per-staff or comparison export | |

### Incentive tier progress (detail)
| Field | Source (canonical) | Notes |
|---|---|---|
| Rule | `incentive_rules.rule_type` (`per_unit_bonus`/`monthly_target`/`revenue_tier`) + `reward_description` | shown to owner |
| Target | `incentive_rules.target_value` | e.g. 150 units, ₹30,000 |
| Current | `staff_incentive_progress.current_value` | progress this `period` (`YYYY-MM`) |
| Tier reached | `staff_incentive_progress.tier_reached` | milestone index |
| Reward | `incentive_rules.reward_description` / `reward_value` | next-tier hint |
| Period | `staff_incentive_progress.period` | `YYYY-MM`, unique per (staff, rule, period) |

---

## 6. States
- **default / populated** — selected staff's stats, active incentive bars, badges, trend.
- **empty** — staff with no sales in range → stats `0`; "No sales in this range"; incentive bars
  at 0/target; "No badges earned yet".
- **loading** — skeleton stat cards + shimmer bars/sparkline.
- **error (inline, retry)** — per-widget "Couldn't load — Retry".
- **offline** — banner "Offline — last loaded stats as of HH:MM"; Export disabled.
- **success** — export ready → download.
- **permission-denied** — `N/A` for allowed roles.

---

## 7. Interactions, gestures & hardware
- **Keyboard** — `g f` open; `/` focus staff picker; `←/→` step staff (prev/next in leaderboard
  order); `c` add to comparison; `r` refresh; `Ctrl/Cmd+E` export; `Enter` on a stat card →
  Sales Ledger filtered.
- **Mouse** — hover badge → criteria/date tooltip; hover progress bar → exact `current/target`;
  click Revenue/Units stat → Sales Ledger for staff+range.
- **No hardware** — desktop.
- **Latency** — stats < 1 s; comparison fetches in parallel per staff.

---

## 8. Business rules & edge cases
1. **R1 — Stats reconcile with the Sales Ledger.** Revenue/units for a staff+range must equal the
   Sales Ledger filtered identically (`sales.staff_id` + `sold_at` range) — same source of truth.
2. **R2 — Denormalized caches are display hints, not truth.** `staff.total_lifetime_sales`,
   `current_month_points`, `badges_earned` are **caches** (recomputed nightly, per
   [data-model.md](../../../foundation/data-model.md) §4); ranged stats are computed live from
   `sales`; badge/incentive detail from `staff_badges`/`staff_incentive_progress`.
3. **R3 — Incentive progress is monthly.** `staff_incentive_progress` is keyed by
   `(staff_id, rule_id, period=YYYY-MM)`; a custom range spanning months shows per-rule progress
   for each covered month (or the selected month's progress) — not a blurred sum across months.
4. **R4 — Only synced sales count** (`sync_status='synced'`); pending/failed excluded so
   incentive figures aren't inflated by not-yet-confirmed mobile sales.
5. **R5 — Void/return adjust** revenue/units so a returned sale doesn't count toward a tier.
6. **R6 — Rank & comparison.** Rank is within the same range across active staff; comparison
   colors are **categorical, fixed per staff** (color follows the person, not their rank), each
   with a legend + label (never color-alone).
7. **R7 — Inactive staff** remain viewable for historical audits (a former employee's incentive
   history) but are excluded from the live leaderboard by default.
8. **R8 — Discount attribution.** A sale's discount reduces its revenue; the incentive rule
   defines whether it targets gross or net (per `incentive_rules`) — shown so the owner knows the
   basis.
9. **R9 — Badge integrity.** Badges are earned by `badges.criteria_json`; this screen **displays**
   history, it does not manually grant/revoke (no data-entry of achievements).
10. **R10 — Payout verification.** For `reward_value` rules, the screen shows reached tiers so the
    accountant can verify the exact bonus owed for the period.

---

## 9. API interactions
| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Load / staff / range change | `GET /staff/{id}/performance?from=&to=` | revenue, units, avg, rank, daily trend | last cache; read-only |
| Load | `GET /incentives/progress?staff_id=&period=` | tier progress per active rule | cache |
| Load | `GET /staff/{id}/badges` | badge history (earned_at, period, criteria) | cache |
| Compare | the above per added staff | comparison columns | cache |
| Export | any of the above + `&format=csv\|xlsx` | download | disabled offline |

- All **GET, read-only, no idempotency key**.
- API docs: [../../api/staff/staff-api.md](../../api/staff/staff-api.md) (performance, badges) ·
  [../../api/incentives/incentives-api.md](../../api/incentives/incentives-api.md) (progress).

**`GET /staff/{id}/performance` — key response fields**
`{ staff:{id,name,photo_url,is_active}, range:{from,to}, revenue, units, sale_count, avg_sale,
rank, of_total, deltas:{revenue_pct,units,avg}, daily:[{date,units,revenue}] }`.

---

## 10. Offline & sync behavior
- **Read-only; no outbox, no Drift on web** (session cache only).
- Reads the **server-reconciled** sales aggregates (only `synced` rows), so figures are correct
  and conflict-resolved ([sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md));
  the web never uses a device's optimistic local counts.
- Sets no `sync_status`.

---

## 11. Analytics & events
| Event | When | Properties |
|---|---|---|
| `web_staff_perf_viewed` | load | `staff_id`, range |
| `web_staff_compared` | add compare | `staff_ids` |
| `web_staff_range_changed` | range change | `from`,`to` |
| `web_incentive_progress_viewed` | load | `staff_id`, `rule_ids`, `period` |
| `web_staff_drilldown_sales` | stat → ledger | `staff_id` |
| `web_staff_perf_exported` | export | `format`, `staff_count` |

---

## 12. Accessibility, localization & performance
- **A11y** — progress bars expose `aria-valuenow/max` + a text "142 / 150"; badges have text
  names + tooltips (not icon-only); comparison series carry a legend + label; stat deltas use
  ▲/▼ + color. WCAG AA light/dark.
- **Localization** — `₹` Indian grouping; DD-MM-YYYY; incentive/badge names localizable; period
  `YYYY-MM`.
- **Performance** — comparison staff fetched in parallel; sparklines lightweight; caches used for
  glance data with a live recompute for the selected range.

---

## 13. Acceptance criteria
- [ ] Selecting a staff + range shows Revenue, Units, Avg sale, and Rank, each with a ▲/▼ delta
      vs the prior period, and these reconcile exactly with the Sales Ledger filtered identically.
- [ ] Incentive tier progress renders one bar per active `incentive_rules`, showing
      `current_value / target_value` and `tier_reached` from `staff_incentive_progress` for the
      period.
- [ ] Badge history lists `staff_badges` with name, `earned_at`, `period`, and criteria tooltip;
      the screen never manually grants/revokes badges.
- [ ] Comparison mode overlays up to the 5–6 staff with fixed categorical colors (color follows
      the person) + legend/labels.
- [ ] Only `synced` sales count; void/returns are netted out.
- [ ] A stat card drills to the Sales Ledger filtered to that staff + range.
- [ ] Reached reward tiers are shown clearly enough to verify an incentive payout.
- [ ] Export produces per-staff or comparison CSV/XLSX.
- [ ] Fully keyboard-operable; progress/badges/series are not conveyed by color alone.

---

## 14. Related docs
- Foundation: [data-model.md](../../../foundation/data-model.md) (`staff`,
  `staff_incentive_progress`, `incentive_rules`, `badges`, `staff_badges`) ·
  [api-conventions.md](../../../foundation/api-conventions.md) ·
  [design-system.md](../../../foundation/design-system.md) (`KpiCard`) ·
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md)
- API: [../../api/staff/staff-api.md](../../api/staff/staff-api.md) ·
  [../../api/incentives/incentives-api.md](../../api/incentives/incentives-api.md)
- Sibling web screens: [../dashboard/dashboard-home.md](../dashboard/dashboard-home.md) (leaderboard) ·
  [../sales/sales-ledger.md](../sales/sales-ledger.md) ·
  [../settings/settings.md](../settings/settings.md) (incentive rule config)
- Mobile counterparts: [../../../mobile/staff/dashboard/dashboard-home.md](../../../mobile/staff/dashboard/dashboard-home.md) ·
  [../../../mobile/owner/staff/staff-management.md](../../../mobile/owner/staff/staff-management.md)
