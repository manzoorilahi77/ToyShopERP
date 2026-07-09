# Staff API

> Base URL, auth, the response envelope, error codes, pagination and export are defined
> once in [api-conventions.md](../../../foundation/api-conventions.md) — referenced, not
> repeated here.

---

## 1. Overview

The Staff module manages the shop's people (staff, owner, accountant) and powers the
**gamified motivation layer** (R5): personal counters, leaderboard, performance stats and
badges. It owns identity + PIN auth material and the **denormalized dashboard caches**.

Callers:

| Caller | Uses |
|---|---|
| Staff App | `GET /staff/{id}/dashboard` (day/week/month counters on login), `/leaderboard`, `/badges` (profile) |
| Owner App | `GET /staff` CRUD, `reset-pin`, `deactivate`, per-staff performance ([owner/staff-management](../../../mobile/owner/staff/staff-management.md)) |
| Owner Web | detailed [web/staff-performance](../../web/staff/staff-performance.md) |

**Denormalized caches vs authoritative sources** — the crux of this module:

| Cache column (`staff`) | Fast read for | Authoritative source | Refresh |
|---|---|---|---|
| `total_lifetime_sales` | profile lifetime figure | `Σ sales.total` where `staff_id` | nightly reconcile + incremental on sale apply |
| `current_month_points` | leaderboard | points rule over `sales`/`sale_items` this month | incremental on sale apply + nightly |
| `badges_earned` (JSON) | profile badge row | `staff_badges` join `badges` | on badge award + nightly |

Caches make the login dashboard instant; the nightly job recomputes them from the
authoritative tables so drift (from voids, reconciles, oversold corrections) self-heals.

---

## 2. Data model touched

Canonical names from [data-model.md](../../../foundation/data-model.md):

| Table | Role | R/W |
|---|---|---|
| `staff` | identity, `pin_hash`, `role`, `join_date`, `is_active` + caches | read + write |
| `sales` / `sale_items` | authoritative units + revenue per `staff_id` | read (aggregate) |
| `staff_incentive_progress` | tier progress (see [incentives-api](../incentives/incentives-api.md)) | read |
| `badges` / `staff_badges` | awarded milestones | read |
| `devices` | last device per staff (login/sync) | read |
| `audit_log` | create/edit/deactivate/reset-pin | write |

Source of truth = `sales`, `staff_badges`, `staff_incentive_progress`. `staff.*` cache
columns are **derived**.

---

## 3. Auth & permissions

| Endpoint | staff | owner | accountant | Notes |
|---|---|---|---|---|
| `GET /staff` | ❌ | ✅ | ✅ | roster |
| `GET /staff/{id}` | 🧩 self | ✅ | ✅ | staff may read own profile |
| `POST /staff` | ❌ | ✅ | ❌ | onboard |
| `PATCH /staff/{id}` | 🧩 self (photo only) | ✅ | ❌ | owner edits role/PIN policy |
| `POST /staff/{id}/reset-pin` | ❌ | ✅ 🔒 | ❌ | **owner PIN required** |
| `POST /staff/{id}/deactivate` | ❌ | ✅ 🔒 | ❌ | **owner PIN required** |
| `GET /staff/{id}/dashboard` | ✅ self | ✅ | ✅ | staff see only their own |
| `GET /staff/leaderboard` | ✅ | ✅ | ✅ | all staff visible (gamification) |
| `GET /staff/{id}/performance` | 🧩 self | ✅ | ✅ | |
| `GET /staff/{id}/badges` | ✅ self | ✅ | ✅ | |

`🔒` = requires a fresh `owner_pin` in the body or `X-Owner-Pin-Token` from
`POST /auth/verify-pin` (api-conventions §2). `pin_hash` is **never** returned by any endpoint.

---

## 4. Endpoints

### `GET /staff`

- **Purpose** — list staff (roster / staff-management).
- **Auth** — owner/accountant.
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `role` | query | enum | no | — | `staff \| owner \| accountant` |
| `is_active` | query | bool | no | `true` | include deactivated with `false`/omit-filter |
| `q` | query | string | no | — | name search |
| `sort` | query | enum | no | `name` | `name \| join_date \| total_lifetime_sales` |
| `page` / `per_page` | query | int | no | `1` / `50` | |

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `data[].id` | int | |
| `data[].name` | string | |
| `data[].photo_url` | string | |
| `data[].role` | enum | |
| `data[].join_date` | date | |
| `data[].total_lifetime_sales` | decimal | cache |
| `data[].current_month_points` | int | cache |
| `data[].is_active` | bool | |

```json
{ "ok": true, "data": [
  { "id": 4, "name": "Arun", "photo_url": "https://cdn.toyshop.example/s/4.jpg",
    "role": "staff", "join_date": "2025-11-03", "total_lifetime_sales": 482300.00,
    "current_month_points": 640, "is_active": true }
], "meta": { "page": 1, "per_page": 50, "total": 6, "request_id": "req_s10" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | ok |
| 403 | `FORBIDDEN` | staff role |

---

### `GET /staff/{id}`

- **Purpose** — one staff profile (never includes `pin_hash`).
- **Auth** — owner/accountant; staff for self only.
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Notes |
|---|---|---|---|---|
| `id` | path | int | yes | |

- **Response `200`** — list-row fields plus `badges_earned` (array of badge codes) and
  `last_device` (`{ device_id, platform, last_seen }`).

```json
{ "ok": true, "data": {
  "id": 4, "name": "Arun", "photo_url": "https://cdn.toyshop.example/s/4.jpg",
  "role": "staff", "join_date": "2025-11-03", "total_lifetime_sales": 482300.00,
  "current_month_points": 640, "badges_earned": ["sold_50_month", "top_seller_week"],
  "is_active": true, "last_device": { "device_id": "dev-abc123",
  "platform": "android", "last_seen": "2026-07-02T20:00:00+05:30" }
}, "meta": { "request_id": "req_s11" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | ok |
| 403 | `FORBIDDEN` | staff reading another staff |
| 404 | `NOT_FOUND` | no such staff |

---

### `POST /staff`

- **Purpose** — onboard a new staff member (name, photo, role, join_date, PIN).
- **Auth** — owner. (Setting another user's PIN is inherently owner-privileged; a fresh
  owner PIN token is recommended but the create itself is role-gated.)
- **Idempotency** — N/A (rare, online-only).
- **Request body**

| Field | Type | Required | Validation | Notes |
|---|---|---|---|---|
| `name` | string | yes | ≤ 100 | |
| `photo_url` | string | no | uploaded via media endpoint first | |
| `role` | enum | no | `staff \| owner \| accountant`; default `staff` | |
| `join_date` | date | no | ≤ today; default today | |
| `pin` | string | yes | 4–6 digits | **bcrypt-hashed** into `pin_hash`; never stored/returned plaintext |
| `reorder_notify` 🧩 | bool | no | — | (proposed) receive owner notifications |

- **Response `201`** — the created staff (no PIN). Caches initialize to 0 / `[]`.

```json
// Request
{ "name": "Priya", "role": "staff", "join_date": "2026-07-01", "pin": "4821" }
// Response 201
{ "ok": true, "data": {
  "id": 7, "name": "Priya", "photo_url": null, "role": "staff",
  "join_date": "2026-07-01", "total_lifetime_sales": 0.00,
  "current_month_points": 0, "badges_earned": [], "is_active": true },
  "meta": { "request_id": "req_s12" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 201 | — | created |
| 400 | `VALIDATION_ERROR` | PIN not 4–6 digits, missing name |
| 403 | `FORBIDDEN` | role not owner |

---

### `PATCH /staff/{id}`

- **Purpose** — edit profile (name, photo, role, join_date, active toggle). Not for PIN
  (use reset-pin) or caches (system-managed).
- **Auth** — owner; staff may PATCH **only their own `photo_url`**.
- **Idempotency** — N/A.
- **Path / query params** — `id` (path, int, required).
- **Request body** — any subset of `name`, `photo_url`, `role`, `join_date`, `is_active`.
  `pin`, `total_lifetime_sales`, `current_month_points`, `badges_earned` are **rejected**
  (`422 BUSINESS_RULE`) — they have dedicated flows / are system-owned.
- **Response `200`** — updated staff.
- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | updated |
| 403 | `FORBIDDEN` | staff editing another / editing non-photo field |
| 404 | `NOT_FOUND` | no such staff |
| 422 | `BUSINESS_RULE` | attempt to set PIN or a cache column here |

---

### `POST /staff/{id}/reset-pin` 🔒

- **Purpose** — set a new login PIN for a staff member.
- **Auth** — owner. **PIN-gated:** requires `owner_pin` (or `X-Owner-Pin-Token`).
- **Idempotency** — N/A.
- **Path / query params** — `id` (path, int, required).
- **Request body**

| Field | Type | Required | Validation | Notes |
|---|---|---|---|---|
| `new_pin` | string | yes | 4–6 digits | bcrypt-hashed → `pin_hash` |
| `owner_pin` | string | conditionally | fresh owner PIN | omit if `X-Owner-Pin-Token` header sent |

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `staff_id` | int | |
| `pin_reset_at` | datetime | audit timestamp |

```json
{ "ok": true, "data": { "staff_id": 4, "pin_reset_at": "2026-07-02T20:15:00+05:30" },
  "meta": { "request_id": "req_s13" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | reset |
| 400 | `VALIDATION_ERROR` | PIN not 4–6 digits |
| 403 | `FORBIDDEN` | not owner / owner PIN wrong or not verified |
| 404 | `NOT_FOUND` | no such staff |

Writes `audit_log(action='staff.reset_pin')`. Any active sessions for that staff are
invalidated 🧩.

---

### `POST /staff/{id}/deactivate` 🔒

- **Purpose** — soft-disable a staff member (`is_active = 0`). Never row-deletes — sales
  history/leaderboard integrity is preserved.
- **Auth** — owner. **PIN-gated.**
- **Idempotency** — safe to repeat (already-inactive returns `200`, no-op).
- **Path / query params** — `id` (path, int, required).
- **Request body** — `owner_pin` (conditional), optional `reason` (≤ 255).
- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `staff_id` | int | |
| `is_active` | bool | `false` |
| `deactivated_at` | datetime | |

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | deactivated (or already inactive) |
| 403 | `FORBIDDEN` | not owner / PIN not verified |
| 404 | `NOT_FOUND` | no such staff |
| 422 | `BUSINESS_RULE` | cannot deactivate the **last active owner** |

---

### `GET /staff/{id}/dashboard`

- **Purpose** — the **personal counters** shown on staff login (R5): units + revenue for
  day / week / month, plus rank snippet and next-badge nudge.
- **Auth** — staff (self), owner, accountant.
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `id` | path | int | yes | — | |
| `tz` | query | string | no | `Asia/Kolkata` | day/week boundaries |

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `staff_id` | int | |
| `day.units` / `day.revenue` | int / decimal | today's sold units + `Σ total` |
| `week.units` / `week.revenue` | int / decimal | current week (Mon–Sun) |
| `month.units` / `month.revenue` | int / decimal | current calendar month |
| `current_month_points` | int | cache (leaderboard) |
| `rank` | int | current leaderboard rank |
| `next_badge` | object / null | `{ code, name, progress, target }` closest unearned badge |

```json
{ "ok": true, "data": {
  "staff_id": 4,
  "day":   { "units": 12, "revenue": 18450.00 },
  "week":  { "units": 61, "revenue": 92100.00 },
  "month": { "units": 214, "revenue": 341200.00 },
  "current_month_points": 640, "rank": 2,
  "next_badge": { "code": "sold_250_month", "name": "250 Toys This Month",
                  "progress": 214, "target": 250 }
}, "meta": { "request_id": "req_s20" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | ok |
| 403 | `FORBIDDEN` | staff requesting another staff's dashboard |
| 404 | `NOT_FOUND` | no such staff |

---

### `GET /staff/leaderboard`

- **Purpose** — ranked list of staff by points or revenue for a period (gamification, R5).
- **Auth** — any authenticated role. Staff see all peers (motivating).
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `metric` | query | enum | no | `points` | `points \| revenue \| units` |
| `period` | query | enum | no | `month` | `day \| week \| month \| YYYY-MM` |
| `limit` | query | int | no | `10` | top N |

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `metric` | enum | echoed |
| `period` | string | echoed |
| `data[].rank` | int | 1-based; ties share rank |
| `data[].staff_id` | int | |
| `data[].name` | string | |
| `data[].photo_url` | string | |
| `data[].value` | number | the metric (points / ₹ / units) |
| `data[].delta_rank` | int / null | change vs previous period 🧩 |

```json
{ "ok": true, "data": [
  { "rank": 1, "staff_id": 5, "name": "Deepa",
    "photo_url": "https://cdn.toyshop.example/s/5.jpg", "value": 720, "delta_rank": 1 },
  { "rank": 2, "staff_id": 4, "name": "Arun",
    "photo_url": "https://cdn.toyshop.example/s/4.jpg", "value": 640, "delta_rank": -1 }
], "meta": { "metric": "points", "period": "2026-07", "request_id": "req_s21" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | ok |
| 400 | `VALIDATION_ERROR` | bad `metric`/`period` |

---

### `GET /staff/{id}/performance`

- **Purpose** — detailed per-staff stats for the web performance screen: trend, best
  category, average basket, incentive tier progress.
- **Auth** — owner/accountant; staff for self.
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `id` | path | int | yes | — | |
| `from` / `to` | query | date | no | last 30d | inclusive range on `sold_at` |
| `granularity` | query | enum | no | `daily` | `daily \| weekly \| monthly` for trend |

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `staff_id` | int | |
| `range` | object | `{ from, to }` |
| `totals` | object | `{ units, revenue, invoices, avg_basket, total_discount }` |
| `top_categories[]` | array | `{ category_id, name, units, revenue }` |
| `payment_mix` | object | `{ cash, upi, card }` revenue share |
| `trend[]` | array | `{ bucket, units, revenue }` per granularity |
| `incentive_progress[]` | array | mirror of [incentives progress](../incentives/incentives-api.md): `{ rule_id, rule_type, current_value, target_value, tier_reached }` |
| `badges_count` | int | earned in range |

```json
{ "ok": true, "data": {
  "staff_id": 4, "range": { "from": "2026-06-01", "to": "2026-06-30" },
  "totals": { "units": 214, "revenue": 341200.00, "invoices": 176,
              "avg_basket": 1938.64, "total_discount": 4200.00 },
  "top_categories": [ { "category_id": 3, "name": "Battery Cars", "units": 121,
                        "revenue": 210500.00 } ],
  "payment_mix": { "cash": 120400.00, "upi": 190800.00, "card": 30000.00 },
  "trend": [ { "bucket": "2026-06-01", "units": 9, "revenue": 15200.00 } ],
  "incentive_progress": [ { "rule_id": 2, "rule_type": "monthly_target",
                            "current_value": 214, "target_value": 250, "tier_reached": 0 } ],
  "badges_count": 2
}, "meta": { "request_id": "req_s22" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | ok |
| 403 | `FORBIDDEN` | staff requesting another |
| 404 | `NOT_FOUND` | no such staff |

---

### `GET /staff/{id}/badges`

- **Purpose** — badges earned by a staff member (profile screen).
- **Auth** — staff (self), owner, accountant.
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `id` | path | int | yes | — | |
| `include_locked` | query | bool | no | `false` | also list not-yet-earned badges with progress |

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `data[].badge_id` | int | |
| `data[].code` | string | e.g. `top_seller_week` |
| `data[].name` | string | |
| `data[].description` | string | |
| `data[].icon` | string | icon key |
| `data[].earned` | bool | |
| `data[].earned_at` | datetime / null | from `staff_badges` |
| `data[].period` | string / null | `YYYY-MM` for period-scoped badges |
| `data[].progress` | object / null | when `include_locked`: `{ current, target }` |

```json
{ "ok": true, "data": [
  { "badge_id": 11, "code": "sold_50_month", "name": "50 Toys This Month",
    "description": "Sell 50 units in a calendar month", "icon": "medal_bronze",
    "earned": true, "earned_at": "2026-06-18T17:00:00+05:30", "period": "2026-06",
    "progress": null }
], "meta": { "request_id": "req_s23" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | ok |
| 403 | `FORBIDDEN` | staff requesting another |
| 404 | `NOT_FOUND` | no such staff |

---

## 5. Business logic & validation

**PIN handling.** PINs are 4–6 digits, **bcrypt-hashed** into `pin_hash` on create/reset;
never stored or returned in plaintext. Login/verify is in [auth-api](../auth/auth-api.md).
`reset-pin` and `deactivate` are PIN-gated owner actions and write `audit_log`.

**Cache vs authoritative (the reconcile model).**
- **Incremental update:** when a sale is *applied* (sync), the server adds its `total` to
  the seller's `total_lifetime_sales`, adds computed points to `current_month_points`, and
  evaluates badge criteria; a *void/reversal* subtracts.
- **Nightly reconcile job** recomputes each cache from the authoritative tables:
  ```
  total_lifetime_sales = Σ sales.total       WHERE staff_id AND status ≠ void
  current_month_points = points_rule( sales this month )
  badges_earned        = codes from staff_badges (current + period-scoped)
  ```
  This self-heals drift from voids, oversold corrections, or a missed incremental update.
- **Dashboard/performance endpoints read authoritative aggregates** for accuracy in the
  requested window; only the *headline* cache columns (`total_lifetime_sales`,
  `current_month_points`) are served from cache for instant login.

**Points formula (default 🧩, owner-tunable via incentives).** `points = units_sold` (1
point/unit) unless a `revenue_tier`/`per_unit_bonus` rule overrides — see
[incentives-api](../incentives/incentives-api.md).

**Leaderboard ties** share a rank (dense ranking). Deactivated staff drop off current-period
boards but remain in historical `YYYY-MM` boards.

---

## 6. Sync & conflict handling

- Staff **reads** are online (owner app/web) — not part of the offline outbox.
- The **write side effect that matters** is on *sale apply*: caches update inside the same
  transaction that inserts the sale (idempotent by `sales.client_uuid`), so a duplicate sale
  push (`DUPLICATE_IGNORED`) does **not** double-credit a staff member. See
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md).
- Nightly reconcile is the backstop for any missed increment.

---

## 7. Edge cases & failure modes

1. **Duplicate sale push.** Cache credited exactly once (guarded by `client_uuid`).
2. **Voided/oversold-corrected sale.** Incremental decrement + nightly reconcile restore
   correct totals.
3. **Deactivated then re-onboarded staff.** Reactivate the existing row (`PATCH is_active`),
   never create a duplicate — preserves lifetime history.
4. **Last active owner deactivation.** Blocked (`422`) — the shop must retain one owner.
5. **PIN reset mid-shift.** Existing sessions invalidated; staff re-logs with new PIN;
   offline outbox items already signed stay valid (bound to `device_id`).
6. **Cache/authoritative mismatch surfaced.** The web performance screen shows authoritative
   numbers; a large gap vs cache triggers an out-of-band reconcile 🧩.

---

## 8. Performance & indexing

| Query | Index relied on |
|---|---|
| per-staff day/week/month aggregates | `sales.idx_staff_date (staff_id, sold_at)` |
| leaderboard current month | `current_month_points` cache (top-N sort in `staff`) |
| badges | `staff_badges UNIQUE (staff_id, badge_id, period)` |

- **Dashboard reads** hit the caches → sub-100ms on login (critical for staff UX).
- **Performance/period aggregates** are the heavier queries; cache per `(staff_id, period)`
  and refresh nightly.
- Leaderboard is a small set (5–6 staff) → trivial to sort.

---

## 9. Related docs

- Foundation: [data-model.md](../../../foundation/data-model.md) ·
  [api-conventions.md](../../../foundation/api-conventions.md) ·
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md)
- Sibling APIs: [incentives-api](../incentives/incentives-api.md) (progress/tiers) ·
  [sales-api](../sales/sales-api.md) (authoritative sales) ·
  [auth-api](../auth/auth-api.md) (PIN login) ·
  [reports-notifications-api](../reports-notifications/reports-notifications-api.md) (top performer, incentive notifications)
- Screens: [staff/dashboard](../../../mobile/staff/dashboard/dashboard-home.md) ·
  [staff/profile](../../../mobile/staff/profile/profile.md) ·
  [owner/staff-management](../../../mobile/owner/staff/staff-management.md) ·
  [web/staff-performance](../../web/staff/staff-performance.md)
