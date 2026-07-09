# Incentives API

> Base URL, auth, the response envelope, error codes and pagination are defined once in
> [api-conventions.md](../../../foundation/api-conventions.md) — referenced, not repeated.

---

## 1. Overview

The Incentives module lets the owner define **motivation rules** (R5) and exposes each
staff member's **live progress toward the next tier** — the visible progress bar that keeps
sellers engaged. It complements the badges/leaderboard in [staff-api](../staff/staff-api.md).

Three rule types (canonical `incentive_rules.rule_type`):

| `rule_type` | Meaning | `target_value` | Progress metric |
|---|---|---|---|
| `per_unit_bonus` | reward per unit sold above a target | units threshold | units sold in period |
| `monthly_target` | hit a monthly unit/revenue target | units **or** ₹ target | units (or revenue) this month |
| `revenue_tier` | tiered ₹ revenue milestones | ₹ threshold (tier boundary) | revenue this period |

Callers: Owner ([owner/staff-management](../../../mobile/owner/staff/staff-management.md),
web [settings](../../web/settings/settings.md)) to configure rules; Staff app + web
[staff-performance](../../web/staff/staff-performance.md) to show progress bars.

---

## 2. Data model touched

Canonical names from [data-model.md](../../../foundation/data-model.md):

| Table | Role | R/W |
|---|---|---|
| `incentive_rules` | rule definitions: `rule_type`, `target_value`, `reward_description`, `reward_value`, `active_from`, `active_to`, `is_active` | read + write |
| `staff_incentive_progress` | per `(staff_id, rule_id, period)`: `current_value`, `tier_reached` | read (system-written) |
| `sales` / `sale_items` | authoritative source progress is computed from | read (aggregate) |
| `staff` | `current_month_points`, points/badges cross-effects | read |
| `badges` / `staff_badges` | milestone awards triggered alongside tiers | write (side-effect) |
| `audit_log` | rule create/edit | write |

**Source of truth:** `sales`/`sale_items`. `staff_incentive_progress` is a **derived,
period-keyed cache** recomputed incrementally on sale apply and by the nightly job.

---

## 3. Auth & permissions

| Endpoint | staff | owner | accountant |
|---|---|---|---|
| `GET /incentives/rules` | ✅ (read-only, to see targets) | ✅ | ✅ |
| `POST /incentives/rules` | ❌ | ✅ | 🧩 |
| `PATCH /incentives/rules/{id}` | ❌ | ✅ | 🧩 |
| `GET /incentives/progress` | ✅ self | ✅ | ✅ |

JWT + `X-Device-Id`. Rule mutations are owner-level.

---

## 4. Endpoints

### `GET /incentives/rules`

- **Purpose** — list incentive rules (active and/or historical).
- **Auth** — any authenticated role (staff see targets to chase).
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `is_active` | query | bool | no | `true` | |
| `rule_type` | query | enum | no | — | `per_unit_bonus \| monthly_target \| revenue_tier` |
| `active_on` | query | date | no | today | rules whose `[active_from, active_to]` covers this date |

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `data[].id` | int | |
| `data[].rule_type` | enum | |
| `data[].target_value` | decimal | units or ₹ (interpretation depends on `rule_type`/`metric`) |
| `data[].metric` 🧩 | enum | (proposed) `units \| revenue` — see note below |
| `data[].reward_description` | string | shown to staff |
| `data[].reward_value` | decimal / null | optional cash value |
| `data[].active_from` | date | |
| `data[].active_to` | date / null | null = open-ended |
| `data[].is_active` | bool | |

```json
{ "ok": true, "data": [
  { "id": 2, "rule_type": "monthly_target", "target_value": 250.00, "metric": "units",
    "reward_description": "₹2000 bonus at 250 toys this month", "reward_value": 2000.00,
    "active_from": "2026-07-01", "active_to": null, "is_active": true }
], "meta": { "request_id": "req_i10" } }
```

> **Proposed schema addition (`incentive_rules.metric`).** `monthly_target` can be measured
> in **units** or **revenue (₹)**, but the canonical table has only a single numeric
> `target_value`. Add `metric ENUM('units','revenue') DEFAULT 'units'` to disambiguate. Until
> then, `per_unit_bonus`/`monthly_target` default to **units** and `revenue_tier` to
> **revenue (₹)**.

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | ok |
| 400 | `VALIDATION_ERROR` | bad `rule_type` |

---

### `POST /incentives/rules`

- **Purpose** — create an incentive rule.
- **Auth** — owner (accountant 🧩).
- **Idempotency** — N/A.
- **Request body**

| Field | Type | Required | Validation | Notes |
|---|---|---|---|---|
| `rule_type` | enum | yes | `per_unit_bonus \| monthly_target \| revenue_tier` | |
| `target_value` | decimal | yes | > 0 | units or ₹ per `metric` |
| `metric` 🧩 | enum | no | `units \| revenue` | proposed; defaults per `rule_type` |
| `reward_description` | string | yes | ≤ 255 | staff-facing text |
| `reward_value` | decimal | no | ≥ 0 | optional cash value |
| `active_from` | date | yes | | |
| `active_to` | date | no | ≥ `active_from` | null = open-ended |
| `is_active` | bool | no | default `true` | |

- **Response `201`** — created rule (same shape as list row).

```json
// Request
{ "rule_type": "revenue_tier", "target_value": 500000.00, "metric": "revenue",
  "reward_description": "Silver tier: ₹5L monthly revenue", "reward_value": 5000.00,
  "active_from": "2026-07-01" }
// Response 201
{ "ok": true, "data": {
  "id": 5, "rule_type": "revenue_tier", "target_value": 500000.00, "metric": "revenue",
  "reward_description": "Silver tier: ₹5L monthly revenue", "reward_value": 5000.00,
  "active_from": "2026-07-01", "active_to": null, "is_active": true },
  "meta": { "request_id": "req_i11" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 201 | — | created |
| 400 | `VALIDATION_ERROR` | bad enum / `target_value ≤ 0` / `active_to < active_from` |
| 403 | `FORBIDDEN` | role not owner/accountant |

---

### `PATCH /incentives/rules/{id}`

- **Purpose** — edit a rule (adjust target, reward, dates) or deactivate it.
- **Auth** — owner (accountant 🧩).
- **Idempotency** — N/A.
- **Path / query params** — `id` (path, int, required).
- **Request body** — any subset of `target_value`, `metric`, `reward_description`,
  `reward_value`, `active_to`, `is_active`. `rule_type` is **immutable** (changing the meaning
  of accrued progress) → `422 BUSINESS_RULE`.
- **Response `200`** — updated rule.
- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | updated |
| 403 | `FORBIDDEN` | role |
| 404 | `NOT_FOUND` | no such rule |
| 422 | `BUSINESS_RULE` | attempt to change `rule_type`; or shrink `target_value` below a staff's already-reached tier mid-period 🧩 |

> **Retroactivity note:** editing `target_value` recomputes `tier_reached` for the **current**
> period on next progress read/reconcile; already-**earned** badges/rewards are not clawed back.

---

### `GET /incentives/progress`

- **Purpose** — a staff member's progress toward each active rule's target for a period:
  `current_value`, `tier_reached`, and the gap to the next tier (the live progress bar).
- **Auth** — staff (self), owner, accountant.
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `staff_id` | query | int | yes | — | staff role forced to self |
| `period` | query | string | no | current `YYYY-MM` | `YYYY-MM` |
| `rule_id` | query | int | no | — | limit to one rule |
| `active_only` | query | bool | no | `true` | only rules active in the period |

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `staff_id` | int | |
| `period` | string | `YYYY-MM` |
| `data[].rule_id` | int | |
| `data[].rule_type` | enum | |
| `data[].metric` | enum | `units \| revenue` |
| `data[].target_value` | decimal | tier boundary / target |
| `data[].current_value` | decimal | progress this period (from `staff_incentive_progress`) |
| `data[].progress_pct` | decimal | `min(current_value / target_value, 1) × 100` |
| `data[].tier_reached` | int | how many tier boundaries crossed (revenue_tier) or 0/1 |
| `data[].next_tier` | object / null | `{ target_value, remaining }` gap to the next milestone |
| `data[].reward_description` | string | what they earn |
| `data[].earned` | bool | target met this period |

```json
{ "ok": true, "data": {
  "staff_id": 4, "period": "2026-07",
  "rules": [
    { "rule_id": 2, "rule_type": "monthly_target", "metric": "units",
      "target_value": 250.00, "current_value": 214.00, "progress_pct": 85.60,
      "tier_reached": 0, "next_tier": { "target_value": 250.00, "remaining": 36.00 },
      "reward_description": "₹2000 bonus at 250 toys this month", "earned": false },
    { "rule_id": 5, "rule_type": "revenue_tier", "metric": "revenue",
      "target_value": 500000.00, "current_value": 341200.00, "progress_pct": 68.24,
      "tier_reached": 0, "next_tier": { "target_value": 500000.00, "remaining": 158800.00 },
      "reward_description": "Silver tier: ₹5L monthly revenue", "earned": false }
  ]
}, "meta": { "request_id": "req_i20" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | ok |
| 400 | `VALIDATION_ERROR` | bad `period` |
| 403 | `FORBIDDEN` | staff requesting another staff's progress |
| 404 | `NOT_FOUND` | no such `staff_id` |

---

## 5. Business logic & validation

**How progress is computed from sales.** For a staff member + period + rule:

```
metric_value =
   rule.metric == 'units'   →  Σ sale_items.quantity  (via sales.staff_id, sold_at in period)
   rule.metric == 'revenue' →  Σ sales.total          (same scope)

current_value = metric_value
tier_reached  =
   per_unit_bonus : max(current_value − target_value, 0)     -- units above threshold
   monthly_target : (current_value >= target_value) ? 1 : 0
   revenue_tier   : floor(current_value / tier_step)          -- number of tiers crossed 🧩
```

Only **synced, non-void** sales count (a void reverses its contribution). Discounts reduce
`revenue` metric (uses `sales.total`, post-discount).

**Update path.**
- **Incremental:** on each sale apply, the server upserts `staff_incentive_progress`
  (`current_value += this sale's contribution`) for every active rule and re-derives
  `tier_reached`. Guarded by `sales.client_uuid` so a duplicate push never double-counts.
- **Nightly reconcile:** recomputes `current_value` from `sales` for the open period,
  self-healing any drift (voids, oversold corrections, missed increments).

**Badge awarding logic (side-effect).** When `tier_reached` crosses a boundary or a
`monthly_target` is met, the server awards the matching badge:
```
if crossing tier AND badge with criteria_json matches (rule_id/threshold/period)
   INSERT staff_badges(staff_id, badge_id, earned_at, period)   -- UNIQUE(staff_id,badge_id,period)
   append code to staff.badges_earned (cache)
   emit notification(type='incentive', target_staff_id)         -- see reports-notifications
```
The `UNIQUE (staff_id, badge_id, period)` constraint makes awarding **idempotent** — a badge
is granted once per period even if progress updates fire repeatedly.

**Validation.** `target_value > 0`; `active_to ≥ active_from`; `rule_type` immutable after
create; overlapping rules of the same type are allowed (a staff can chase several at once).

---

## 6. Sync & conflict handling

- Rule CRUD is **online-only** owner config — not in the offline outbox.
- Progress is **derived from `sales`**, which *are* sync-replayable. Because increments are
  keyed by `sales.client_uuid` and badge awards by `UNIQUE(staff_id,badge_id,period)`, replays
  and duplicate pushes are safe (no double credit, no duplicate badge). See
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md).
- The nightly reconcile is the authoritative backstop.

---

## 7. Edge cases & failure modes

1. **Rule edited mid-period.** New `target_value` re-derives `tier_reached` on next
   read/reconcile; already-earned rewards/badges are **not** clawed back.
2. **Sale voided after a tier was reached.** `current_value` drops on reconcile; the badge
   already awarded for that period stays (business decision 🧩) — surface, don't punish.
3. **Duplicate sale push.** No double credit (`client_uuid` guard).
4. **Overlapping rules.** A single sale can advance multiple rules; each is upserted
   independently.
5. **Period rollover.** New month → fresh `staff_incentive_progress` rows (period-keyed);
   prior period frozen for history.
6. **Deactivated staff.** Progress freezes; historical rows retained.

---

## 8. Performance & indexing

| Query | Index relied on |
|---|---|
| progress read | `staff_incentive_progress UNIQUE (staff_id, rule_id, period)` |
| recompute from sales | `sales.idx_staff_date (staff_id, sold_at)` + `sale_items.sale_id` |
| active rules lookup | filter `is_active` + `[active_from, active_to]` (small table) |

- `incentive_rules` is tiny (dozens of rows) → fully cacheable in-process.
- `staff_incentive_progress` is `staff × active_rules × months` — small; reads are point
  lookups on the unique key.
- Incremental upsert on sale apply keeps progress reads O(1).

---

## 9. Related docs

- Foundation: [data-model.md](../../../foundation/data-model.md) ·
  [api-conventions.md](../../../foundation/api-conventions.md) ·
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md)
- Sibling APIs: [staff-api](../staff/staff-api.md) (badges, leaderboard, caches) ·
  [sales-api](../sales/sales-api.md) (authoritative sales) ·
  [reports-notifications-api](../reports-notifications/reports-notifications-api.md) (incentive notifications)
- Screens: [staff/dashboard](../../../mobile/staff/dashboard/dashboard-home.md) ·
  [web/staff-performance](../../web/staff/staff-performance.md) ·
  [web/settings](../../web/settings/settings.md) ·
  [owner/staff-management](../../../mobile/owner/staff/staff-management.md)
