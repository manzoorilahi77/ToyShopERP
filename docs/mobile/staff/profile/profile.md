# Profile — Staff · Mobile (Flutter, offline-first)

> Follows [`_templates/screen-doc-template.md`](../../../_templates/screen-doc-template.md).
> Tokens/components from [`design-system.md`](../../../foundation/design-system.md); envelope
> & errors from [`api-conventions.md`](../../../foundation/api-conventions.md); sync status
> from [`sync-and-conflict-resolution.md`](../../../foundation/sync-and-conflict-resolution.md) §8.
> Implements **Requirement 5** (staff profile — ownership & progress).
> Legend: `✅ Specified` · `🧩 Derived (confirm with owner)` · `⚠️ Risk` · `🔒 Owner PIN`.

---

## 1. Purpose & context
- **What it is** — the staff member's personal page: photo, name, join date, **badges
  earned**, lifetime stats (`total_lifetime_sales`), this month's points
  (`current_month_points`), a place to **manage personal favorites**, a **sync status**
  view, and **logout**.
- **Who & when** — a staff member checking their progress, showing off a badge, curating
  favorites, or logging out at shift end.
- **Why it exists** — R5: a simple profile (name, photo, join date, lifetime sales, badges)
  gives staff a sense of ownership and progress, reinforcing the gamified loop. It's also the
  home for account actions (logout) and personal catalog curation (favorites).
- **Frequency / criticality** — a few times a day; motivational + account control. Low write
  risk; logout is the only sensitive action.

## 2. Entry points & navigation
- **Arrive from:** the **Profile** bottom-nav tab; tapping the greeting/leaderboard "See
  full" on [dashboard](../dashboard/dashboard-home.md).
- **Exit to:** logout → [login](../auth/login.md); "manage favorites" →
  [product-search-browse](../catalog/product-search-browse.md) (favorites view) or an inline
  editor; back → dashboard.
- **Back button:** returns to dashboard.

```
Dashboard ─▶ Profile ─┬─ Manage favorites ─▶ Browse (favorites)
                      ├─ Badges ─▶ badge detail
                      └─ Logout ─▶ Login
```

## 3. Roles & permissions
- **Open to:** the logged-in `staff` — **own profile only** (read of own stats; a staff
  member cannot view another's profile here — that's [web staff-performance](../../../cloud/web/staff/staff-performance.md)).
- **Read-only stats.** Name/photo/PIN are **owner-managed** (edited in
  [owner staff-management](../../owner/staff/staff-management.md)); this screen does not edit
  identity. Editable by the user: **favorites** and app preferences (biometric opt-in, voice
  language). **Logout** is self-service.
- No `🔒 owner-PIN` actions here.

## 4. Screen layout (wireframe)

```
┌──────────────── Profile ────────────────── ✓ synced ─┐
│            ┌────────┐                                  │
│            │  📷    │   Ravi Kumar                      │
│            └────────┘   Staff · joined 12-01-2026      │
│                                                        │
│  ┌── Lifetime ─────────┐  ┌── This month ───────────┐  │
│  │ ₹ 8,42,300          │  │ 812 points              │  │
│  │ total sales         │  │ rank #2 of 6            │  │
│  └──────────────────────┘  └──────────────────────────┘ │
│                                                        │
│  🏅 Badges earned                                      │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                   │
│  │Top   │ │50    │ │Fast  │ │ + ?  │ ← locked (hint)    │
│  │Week  │ │Toys  │ │Biller│ │      │                   │
│  └──────┘ └──────┘ └──────┘ └──────┘                    │
│                                                        │
│  ⭐ My favorites            [ Manage ▸ ]               │
│  ┌────┐┌────┐┌────┐  → swipe                            │
│  │📷  ││📷  ││📷  │                                     │
│  └────┘└────┘└────┘                                     │
│                                                        │
│  ⚙ Preferences   Biometric [on]   Voice lang [EN ▾]    │
│  🔄 Sync           ✓ all synced · 0 pending  (tap)     │
│  ────────────────────────────────────────────         │
│              [  ⎋  Log out  ]                          │
└─────────────────────────────────────────────────────────┘
```

Responsive: phone single column; tablet two-column stat + badge layout. Numbers tabular; ₹
Indian grouping; join date DD-MM-YYYY.

## 5. UI components & field-by-field spec

| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Photo | image | `staff.photo_url` (cache) | — | avatar/initials fallback | — | owner-managed; read-only here |
| 2 | Name | text | `staff.name` | — | — | — | read-only |
| 3 | Role · join date | text | `staff.role`, `staff.join_date` | — | — | — | DD-MM-YYYY |
| 4 | Lifetime sales | `KpiCard` ₹ | `staff.total_lifetime_sales` (via `GET /staff/{id}`) | — | ₹0 | — | denormalized cache, reconciled nightly (data-model §4) |
| 5 | Month points | `KpiCard` | `staff.current_month_points` | — | 0 | — | leaderboard points |
| 6 | Rank | text | `GET /staff/leaderboard` (position) | — | — | — | "#2 of 6" |
| 7 | Badges earned | chip grid | `GET /staff/{id}/badges` (+ `badges` meta) | — | earned + next-locked | tap → badge detail (criteria, `earned_at`) | from `staff_badges` × `badges` |
| 8 | Locked badge | chip (dim) | `badges` not yet earned | — | — | tap → shows `criteria_json` hint | motivates next milestone |
| 9 | My favorites | strip | `staff_favorites` *(proposed, §10)* | product `is_active=1` | staff's pins | tap → product; **Manage** → editor | R3 favorites-per-staff |
| 10 | Manage favorites | link | — | — | — | → favorites editor / [Browse](../catalog/product-search-browse.md) | add/remove/reorder |
| 11 | Biometric toggle | switch | device `local_auth` + local pref | must be enrolled | off | enable/disable biometric unlock | client-only pref |
| 12 | Voice language | dropdown | supported STT locales | — | app locale | sets voice-search language | design-system §10 |
| 13 | Sync status | `SyncStatusChip` + row | sync worker | — | current | tap → sync sheet (counts + retry) | sync doc §8 |
| 14 | **Log out** | destructive button | — | confirm dialog | — | revoke tokens, clear session, → login | see rule 3/§8 |

## 6. States

| State | What the user sees / can do |
|---|---|
| **default / populated** | Photo, name, join date, lifetime + month stats, badges, favorites, preferences, sync, logout. |
| **empty** | New hire: stats show `₹0` / `0 points`, no badges yet ("Earn your first badge!"), empty favorites with a "pin from Browse" hint. |
| **loading** | Skeletons for stats/badges; cached values shown immediately (never blank). |
| **error** | A failed `GET /staff/{id}`/badges shows inline "couldn't refresh — showing last synced" + Retry; cached stats remain. |
| **offline** | Banner "Working offline"; stats/badges show last-synced values with an "as of <time>" note; favorites toggles + preference changes queue; logout still works locally (tokens cleared, server revocation queued). |
| **success** | Favorite/pref changes confirm subtly; a newly-synced badge may show a small "new badge!" marker. |
| **permission-denied** | Enabling biometric without enrolment → inline "set up fingerprint/Face in device settings". |

## 7. Interactions, gestures & hardware
- **Tap** badges (detail), favorites (product), Manage (editor); **swipe** favorites strip;
  **toggle** biometric; **select** voice language; **tap** sync row → sheet; **tap** Logout →
  confirm.
- **Biometric** uses `local_auth` (device hardware) only to set the unlock preference; no
  camera/printer/mic used for content here.
- **Latency:** paints from cache < 200 ms; logout completes locally instantly (server
  revocation is background).

## 8. Business rules & edge cases
1. **Own profile only.** All reads are scoped to the logged-in `staff_id`.
2. **Stats are denormalized caches.** `total_lifetime_sales` and `current_month_points` are
   fast-read caches reconciled nightly (data-model §4); the profile shows the cache and
   refreshes on `GET /staff/{id}` — small drift until reconciliation is expected, not an error.
3. **Badges source of truth** is `staff_badges` (with `badges` metadata); `staff.badges_earned`
   JSON is a mirror. Show a badge only when present in `staff_badges`; locked badges come from
   the `badges` catalog the staff hasn't earned.
4. **Identity is owner-managed.** Name, photo, and PIN are not editable here; a staff member
   requests changes via the owner ([owner staff-management](../../owner/staff/staff-management.md)).
5. **Logout** revokes the refresh token (`POST /auth/logout`), clears local tokens + biometric
   opt-in, and returns to [login](../auth/login.md). Offline logout clears the local session
   immediately and **queues** server revocation for next connectivity (⚠️ small window where
   the old refresh token is still valid server-side until it syncs/expires).
6. **Pending sync on logout** — if unsynced sales exist, logout warns "N sales still syncing —
   they'll sync when this device is back online" and does **not** drop the outbox (data
   survives; sync worker continues under the device token). Confirm copy with owner (🧩).
7. **Favorites** edits are per-staff writes, queued offline, idempotent on sync (shared
   `staff_favorites` proposal).
8. **Biometric/voice** are local device preferences, not server state; they don't sync across
   devices.

## 9. API interactions

| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Open / refresh | `GET /staff/{id}` | profile + `total_lifetime_sales`, `current_month_points`, join date, photo | cached snapshot |
| Open / refresh | `GET /staff/{id}/badges` | earned badges (+ `earned_at`, `period`) | cached snapshot |
| Rank | `GET /staff/leaderboard` | position for "#2 of 6" | cached snapshot |
| Manage favorites | `POST/DELETE /staff/{id}/favorites` *(proposed API)* | pin/unpin/reorder | queue in outbox |
| Log out | `POST /auth/logout` | revoke refresh token | clear local; queue revocation |

- Envelope/auth/errors per [`api-conventions.md`](../../../foundation/api-conventions.md). See
  [`staff-api`](../../../cloud/api/staff/staff-api.md),
  [`incentives-api`](../../../cloud/api/incentives/incentives-api.md),
  [`auth-api`](../../../cloud/api/auth/auth-api.md). Read-mostly; the only writes are favorites
  and logout.

## 10. Offline & sync behavior
- **Works offline** from cached `staff`/`staff_badges` snapshots; stats show "as of <sync
  time>". Favorites toggles and logout queue and reconcile on reconnect.
- Drift tables read: `staff` (name/photo/stats/badges mirror), cached `staff_badges`,
  `leaderboard_snapshot`. Writes: `staff_favorites` *(proposed)*, local session/preferences.
- Sync status here is the same subtle indicator used app-wide (sync doc §8); the sync row/sheet
  offers "retry now" and counts by state.

### Proposed schema addition (flag for schema owner)
Reuses the **`staff_favorites`** table proposed in
[product-search-browse](../catalog/product-search-browse.md) §10 and
[dashboard](../dashboard/dashboard-home.md) §10 (per-staff pinned products, R3). No other new
table is needed: badges, points, lifetime sales, and join date all map to existing canonical
columns (`staff`, `staff_badges`, `badges`). Biometric opt-in and voice language are **local
device preferences** (no server schema).

## 11. Analytics & events
- `profile_opened {staff_id}`, `badge_detail_viewed {badge_code}`,
  `favorite_managed {product_id, action}`, `biometric_pref_changed {on}`,
  `voice_lang_changed {locale}`, `sync_sheet_opened_from_profile`,
  `logout {online, pending_count}`.

## 12. Accessibility, localization & performance
- Tap targets ≥48 dp; logout clearly labelled + confirm dialog (destructive). WCAG AA contrast;
  badges/stat cards use icon + label, never color alone.
- Screen-reader: stat cards announce "lifetime sales, 8 lakh 42 thousand 300 rupees"; badges
  announce name + earned/locked; rank announced as "rank 2 of 6".
- i18n: ₹ Indian grouping, dates DD-MM-YYYY, GST-agnostic; voice language selectable.
- Perf: paints from cache < 200 ms; logout is instant locally.

## 13. Acceptance criteria
- [ ] Shows photo, name, role, and `join_date` (DD-MM-YYYY) for the logged-in staff.
- [ ] Shows `total_lifetime_sales` (₹) and `current_month_points` with rank, from cache first
      then refreshed.
- [ ] Earned badges render from `staff_badges` with detail (criteria, earned date); locked
      badges hint the next milestone.
- [ ] The favorites strip lists the staff's pinned products and "Manage" allows add/remove.
- [ ] Identity (name/photo/PIN) is **not** editable here.
- [ ] Logout revokes the session and returns to login; offline logout clears the local session
      and queues revocation, warning if unsynced sales exist.
- [ ] Offline, all stats show last-synced values with an "as of <time>" note and no red error.
- [ ] The sync status view shows counts by state and a retry action.

## 14. Related docs
- **Foundation:** [data-model](../../../foundation/data-model.md) (`staff`, `staff_badges`,
  `badges`) · [design-system](../../../foundation/design-system.md) ·
  [sync-and-conflict-resolution](../../../foundation/sync-and-conflict-resolution.md) ·
  [api-conventions](../../../foundation/api-conventions.md) ·
  [requirements](../../../requirements_and_prompt.md)
- **API:** [staff-api](../../../cloud/api/staff/staff-api.md) ·
  [incentives-api](../../../cloud/api/incentives/incentives-api.md) ·
  [auth-api](../../../cloud/api/auth/auth-api.md) ·
  [sync-api](../../../cloud/api/sync/sync-api.md)
- **Sibling staff screens:** [dashboard-home](../dashboard/dashboard-home.md) ·
  [login](../auth/login.md) · [product-search-browse](../catalog/product-search-browse.md)
- **Other surfaces:** [owner staff-management](../../owner/staff/staff-management.md) ·
  [web staff-performance](../../../cloud/web/staff/staff-performance.md)
