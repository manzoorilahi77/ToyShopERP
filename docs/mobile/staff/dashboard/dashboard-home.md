# Staff Home / Dashboard (gamified) — Staff · Mobile (Flutter, offline-first)

> Follows [`_templates/screen-doc-template.md`](../../../_templates/screen-doc-template.md).
> Tokens/components from [`design-system.md`](../../../foundation/design-system.md); envelope
> & errors from [`api-conventions.md`](../../../foundation/api-conventions.md); sync from
> [`sync-and-conflict-resolution.md`](../../../foundation/sync-and-conflict-resolution.md).
> Implements **Requirement 5** (staff app dashboard, gamified).
> Legend: `✅ Specified` · `🧩 Derived (confirm with owner)` · `⚠️ Risk` · `🔒 Owner PIN`.

---

## 1. Purpose & context
- **What it is** — the landing screen after login: a **motivating, glanceable** home that
  shows *your* numbers first (units + revenue for day/week/month), where you rank among the
  5–6 staff, your badges and progress to the next incentive tier, a **quick-pick** strip of
  your hot items, and one big **New Sale** button.
- **Who & when** — every staff member, immediately on login and between customers. Highest
  traffic during evening/weekend rush.
- **Why it exists** — R5: gamification (personal counter, leaderboard, badges, live
  incentive progress) is proven to boost floor engagement; showing wins **on login** is
  instant positive reinforcement and nudges the 80/20 quick-pick behavior that makes billing
  fast. It also gets the user to **New Sale** in one tap.
- **Frequency / criticality** — opened dozens of times/day. Not money-critical (read-mostly)
  but motivation- and navigation-critical; must render instantly from cache, never blank.

## 2. Entry points & navigation
- **Arrive:** straight after [Staff Login](../auth/login.md); the **Home** bottom-nav tab;
  tapping the app icon while a session is valid; back from a completed sale.
- **Exit to:** **New Sale** (primary) → [new-sale](../sales/new-sale.md); quick-pick tile →
  new-sale with that item pre-added; **My Sales** → [my-sales-history](../sales/my-sales-history.md);
  **Browse** → [product-search-browse](../catalog/product-search-browse.md); **Profile** →
  [profile](../profile/profile.md); leaderboard/badge tap → profile.
- **Back button** on Home = confirm-exit app (double-back to exit).

```
Login → Dashboard ─┬─ New Sale ─▶ Receipt ─▶ (Dashboard)
                   ├─ Quick-pick tile ─▶ New Sale (item pre-added)
                   ├─ My Sales · Browse · Profile   (bottom nav)
                   └─ Leaderboard / Badge ─▶ Profile
```

## 3. Roles & permissions
- **Open to:** the logged-in `staff` (own data only). Owner/accountant see their own but
  normally use the [owner dashboard](../../owner/dashboard/dashboard-home.md).
- **Read-only.** No `🔒 owner-PIN` actions. A staff member can see the leaderboard (all
  peers, points only) but not peers' revenue detail — leaderboard exposes rank + points/
  units, not another person's rupee totals (privacy 🧩, confirm with owner).

## 4. Screen layout (wireframe)

```
┌─────────────────────────── Home ───────────────── ✓ synced ─┐
│  Hi, Ravi 👋                         (top-right SyncStatusChip)│
│                                                               │
│  ┌── Your sales ─────────────────────────────────────────┐   │
│  │  [ Day ] Week  Month           ← segmented toggle       │  │
│  │   12 units            ₹ 48,300           (Display 34)   │  │
│  │   units sold          revenue    ▲ +18% vs yest.       │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌── Leaderboard (this month) ───────────────────────────┐   │
│  │  1. Meena   840 pts   🥇                                │  │
│  │  2. You     812 pts   ▲2   ← you highlighted            │  │
│  │  3. Karan   790 pts                                     │  │
│  │                              See full ▸ (→ Profile)     │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌── Next reward ────────────────────────────────────────┐   │
│  │  Monthly target: 500 units                              │  │
│  │  ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░  412 / 500   88 to go → ₹1,000 bonus │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                               │
│  🏅 Badges:  [Top Week] [50 Toys] [+ locked]                  │
│                                                               │
│  Quick pick  (your hot items)                                 │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐  → swipe                         │
│  │📷 ₹│ │📷 ₹│ │📷 ₹│ │📷 ₹│   1-tap add                      │
│  └────┘ └────┘ └────┘ └────┘                                  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐    │
│  │             ＋  N E W   S A L E   (56dp, primary)      │    │
│  └──────────────────────────────────────────────────────┘    │
│  [ Home ] [ Sales ] [ Browse ] [ Profile ]   ← bottom nav     │
└───────────────────────────────────────────────────────────────┘
```

Responsive: phone single column; tablet places the counter and leaderboard side-by-side.
Numbers use **tabular numerals**; ₹ with Indian grouping (design-system §3).

## 5. UI components & field-by-field spec

| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Greeting | text | `staff.name` (cache) | — | "Hi, <name>" | — | friendly, first-name |
| 2 | `SyncStatusChip` | status icon | sync worker (sync doc §8) | — | current state | tap → sync sheet (counts + retry) | never intrusive |
| 3 | Period toggle | segmented (Day/Week/Month) | user choice | one selected | **Day** | re-queries dashboard scope; instant from cache | persists last choice |
| 4 | Units counter | `KpiCard` number | `GET /staff/{id}/dashboard` → `units.{period}` | — | 0 | animates count-up on load | tabular |
| 5 | Revenue counter | `KpiCard` ₹ | dashboard → `revenue.{period}` | — | ₹0 | count-up; trend arrow vs prior period | ₹ + grouping |
| 6 | Trend arrow | delta chip | dashboard → `trend.{period}` | — | — | ▲/▼ + % vs previous | color + icon (not color alone) |
| 7 | Leaderboard rows | list (5–6) | `GET /staff/leaderboard` → rank, name, `current_month_points`, movement | — | — | "You" row highlighted, rank-change ▲/▼ | peers show points/units, not ₹ |
| 8 | See full ▸ | link | — | — | — | → [profile](../profile/profile.md) leaderboard | |
| 9 | Incentive progress bar | progress + label | `GET /incentives/progress` → `current_value`, `target_value`, `tier_reached`, `reward_description` | — | 0/target | fills; shows "N to go → reward" | from `staff_incentive_progress` × `incentive_rules` |
| 10 | Badge strip | chips | `GET /staff/{id}/dashboard` (or cache `staff.badges_earned`) | — | earned + next-locked | tap → profile/badges | locked badge shows criteria hint |
| 11 | Quick-pick strip | `QuickPickStrip` | frequent/recent items + staff favorites *(see §10)* | product `is_active=1` | top 8 | **1-tap** → New Sale with item pre-added to cart | 80/20 speed path (R2-B) |
| 12 | New Sale button | primary 56 dp | — | — | — | → [new-sale](../sales/new-sale.md) | thumb-reachable, always visible |
| 13 | Bottom nav | tab bar | — | — | Home | switch tab | Home/Sales/Browse/Profile |
| 14 | Pull-to-refresh | gesture | re-calls the 3 GETs | — | — | refresh KPIs/leaderboard/progress | offline → refreshes from cache only |

## 6. States

| State | What the user sees / can do |
|---|---|
| **default / populated** | Counters, leaderboard, progress, badges, quick-pick, New Sale — all from cache, refreshed in background. |
| **empty** | New staff, no sales yet → counter shows `0 units · ₹0`, progress `0/target`, quick-pick shows shop-wide bestsellers as a starter, encouraging copy "Make your first sale!". |
| **loading** | Skeleton cards for counters/leaderboard/progress (design-system §7); New Sale + quick-pick remain tappable from cache (never block the floor). |
| **error** | A failed GET shows an **inline** "couldn't refresh — showing last synced" line with Retry; stale cached numbers stay visible (never a dead-end). |
| **offline** | Calm banner "Working offline — your live stats update when you're back online"; counters show the **last-synced** values with a small "as of <time>" note; New Sale fully works. |
| **success** | After returning from a completed sale, the counter animates the increment (optimistic, from local sales). |
| **permission-denied** | N/A (own data; nothing gated here). |

## 7. Interactions, gestures & hardware
- **Tap** New Sale / quick-pick tile / leaderboard / badge; **swipe** the quick-pick strip
  horizontally; **pull-to-refresh** the page; **tap** the sync chip for the detail sheet.
- No camera/printer/mic on this screen (those live in New Sale / Browse).
- **Latency budget:** screen paints from cache < 200 ms; New Sale opens < 200 ms; counter
  count-up animation is cosmetic and never delays interaction.

## 8. Business rules & edge cases
1. **Own data only** — the dashboard scopes every stat to the logged-in `staff_id`; the
   leaderboard is the only cross-staff view and hides peers' rupee detail.
2. **Counters are optimistic + reconciled** — the day counter includes locally-pending
   (unsynced) sales so the number feels live; on sync the server value from
   `GET /staff/{id}/dashboard` reconciles it (may adjust for voids/oversold).
3. **Points source** — leaderboard uses `staff.current_month_points` (denormalized cache),
   authoritative via incentives; a nightly job reconciles (data-model §4 note).
4. **Period boundaries** — Day = business day in shop-local time; Week = Mon–Sun; Month =
   calendar month `YYYY-MM` (matches `staff_incentive_progress.period`).
5. **Incentive with no active rule** — if no `incentive_rules.is_active=1` for the period,
   hide the progress card (don't show an empty bar).
6. **Badge just earned** — a newly-earned badge (from a pull) triggers a one-time celebratory
   toast/confetti on next open; do not re-celebrate on subsequent opens.
7. **Quick-pick fallback** — with too little personal history, fall back to shop bestsellers
   so the strip is never empty for a new hire (R2-B graceful fallback).
8. **Stale-while-offline** — offline stats are clearly time-stamped "as of <sync time>" so
   staff aren't misled by frozen numbers; never show a red error for staleness.
9. **Owner-configured rules change** — a mid-month change to `incentive_rules` re-bases the
   target on next pull; the bar animates to the new ratio without losing recorded progress.

## 9. API interactions

| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| On load / pull-to-refresh | `GET /staff/{id}/dashboard` | day/week/month units + revenue + trend + badge summary | serve cached snapshot; refresh on reconnect |
| On load / refresh | `GET /staff/leaderboard?period=YYYY-MM` | ranked peers by `current_month_points` (+ units) | cached last snapshot |
| On load / refresh | `GET /incentives/progress?staff_id={id}&period=YYYY-MM` | `current_value`, `target_value`, `tier_reached`, `reward_description` | cached snapshot |
| Quick-pick add | (local) → feeds [new-sale](../sales/new-sale.md) | pre-add item to cart | fully local |

- Endpoints resolve through the shared API client (envelope/auth per
  [`api-conventions.md`](../../../foundation/api-conventions.md)). See
  [`staff-api`](../../../cloud/api/staff/staff-api.md) and
  [`incentives-api`](../../../cloud/api/incentives/incentives-api.md). These are **GET/read**
  endpoints — not sync-outbox writes — so they simply show cached data when offline.

## 10. Offline & sync behavior
- **Works offline** with the **last-synced** dashboard/leaderboard/progress snapshots cached
  in Drift; New Sale and quick-pick are fully offline (the whole point of R1).
- **Local increment**: the day counter adds locally-`pending` sales from Drift `sales`
  (`sync_status IN ('pending','syncing')`) on top of the server snapshot for a live feel;
  reconciled on the next `GET /sync/pull` + dashboard refresh.
- Drift tables read: `staff` (name/badges cache), cached `dashboard_snapshot`,
  `leaderboard_snapshot`, `incentive_progress_snapshot`, local `sales` (pending increment).
  No writes originate here.
- **Quick-pick / favorites source** — see the proposed `staff_favorites` addition below;
  until it lands, the quick-pick strip is derived purely from recent/frequent local sales.

### Proposed schema addition (flag for schema owner)
Not in [`data-model.md`](../../../foundation/data-model.md); required for "favorites per
staff" (R3) that seeds this quick-pick strip and is managed on [profile](../profile/profile.md):

| Addition | Shape | Why |
|---|---|---|
| `staff_favorites` | `id BIGINT UN PK, staff_id BIGINT UN FK→staff, product_id BIGINT UN FK→products, sort_order INT DEFAULT 0, created_at TIMESTAMP, UNIQUE(staff_id, product_id)` | R3 "favorites per staff" / personal quick-access row. The schema has no per-staff pin table; quick-pick otherwise relies only on derived frequency. Confirm with owner. |

Until then, treat the pinned quick-pick as `🧩 Derived` from sales frequency.

## 11. Analytics & events
- `dashboard_shown {staff_id}`, `period_toggled {period}`, `leaderboard_viewed`,
  `incentive_progress_viewed {rule_id, pct}`, `badge_celebrated {badge_code}`,
  `quickpick_tapped {product_id, source: favorite|frequent}`,
  `new_sale_tapped {source: dashboard}`, `dashboard_refresh {source, online}`.

## 12. Accessibility, localization & performance
- Big KPI numbers ≥ Display 34, tabular, WCAG AA; trend uses arrow **and** sign, not color
  alone. Tap targets ≥48 dp; New Sale 56 dp; quick-pick tiles ≥96 dp.
- Screen-reader: counters announce "12 units, 48,300 rupees, up 18 percent versus
  yesterday"; progress bar announces "412 of 500, 88 to go".
- i18n: ₹ Indian grouping, GST-agnostic here, DD-MM-YYYY where dates appear; leaderboard
  names as stored. Reduce-motion disables count-up/confetti.
- Perf: paint from cache < 200 ms cold-from-warm; background refresh non-blocking.

## 13. Acceptance criteria
- [ ] On login the personal counter (units + revenue) for the selected period renders from
      cache in < 200 ms, before any network response.
- [ ] Day/Week/Month toggle switches the counter and trend without a reload spinner.
- [ ] The leaderboard highlights the current user's row and shows rank movement; peers show
      points/units, not rupee detail.
- [ ] The incentive bar shows `current_value / target_value`, remaining-to-go and the reward,
      and hides when no active rule exists for the period.
- [ ] Quick-pick shows the user's favorites/frequent items and adds one to the cart in a
      single tap, opening New Sale.
- [ ] Offline, all four regions show last-synced values with an "as of <time>" note and no
      red error; New Sale still works.
- [ ] A newly earned badge celebrates exactly once.
- [ ] New Sale is always visible and reachable in one tap.

## 14. Related docs
- **Foundation:** [overview](../../../foundation/overview.md) ·
  [design-system](../../../foundation/design-system.md) ·
  [data-model](../../../foundation/data-model.md) ·
  [sync-and-conflict-resolution](../../../foundation/sync-and-conflict-resolution.md) ·
  [api-conventions](../../../foundation/api-conventions.md) ·
  [requirements](../../../requirements_and_prompt.md)
- **API:** [staff-api](../../../cloud/api/staff/staff-api.md) ·
  [incentives-api](../../../cloud/api/incentives/incentives-api.md) ·
  [sync-api](../../../cloud/api/sync/sync-api.md)
- **Sibling staff screens:** [login](../auth/login.md) · [new-sale](../sales/new-sale.md) ·
  [my-sales-history](../sales/my-sales-history.md) ·
  [product-search-browse](../catalog/product-search-browse.md) · [profile](../profile/profile.md)
- **Other surfaces:** [owner dashboard](../../owner/dashboard/dashboard-home.md)
