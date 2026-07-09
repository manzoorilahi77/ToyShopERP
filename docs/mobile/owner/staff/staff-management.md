# Staff Management — Owner · Mobile (Owner App)

> The owner's people console: add / edit the 5–6 sales staff (name, photo, role, join
> date), assign or reset their login **PIN**, activate / deactivate accounts, and glance at
> an individual **performance snapshot** (sales, points, badges, incentive progress).

Status: `✅ Specified` · `🔒` on **PIN assign/reset**, **role change**, and **deactivate**.

---

## 1. Purpose & context
- **What this screen is for:** onboard/offboard staff and control who can log into the
  Staff App, plus a quick read of how each person is performing.
- **Who & when:** the **owner**. Used when hiring, when a staff member forgets a PIN
  (mid-shift, needs a fast reset), or when reviewing performance.
- **Why it exists:** the system needs to know "which staff member sells best" (R5) and each
  staff login/PIN and gamified profile depend on these records
  ([requirements R5, R6](../../../requirements_and_prompt.md)).
- **Frequency / criticality:** low frequency, but a wrong PIN reset or accidental
  deactivation locks a working staff member out during a rush — so those are `🔒` gated.

---

## 2. Entry points & navigation
- **More → Staff** / **Staff** quick-nav chip on
  [Dashboard Home](../dashboard/dashboard-home.md).
- **Top-performer card** on the dashboard deep-links to that staff member's snapshot.

```
Dashboard ─▶ Staff (list) ─┬─▶ Add Staff (name, photo, role, join_date, PIN)
                           ├─▶ Staff Detail (edit · performance snapshot)
                           │        ├─ Reset PIN 🔒
                           │        └─ Activate/Deactivate 🔒
                           └─▶ (view full history → web performance)
```
- **Back:** list → Dashboard; detail → list (unsaved-changes confirm).

---

## 3. Roles & permissions
| Actor | Access |
|---|---|
| Owner | ✅ add / edit / assign+reset PIN / activate+deactivate / view snapshot |
| Accountant | 👁 view list + snapshot; no PIN/role/active changes `🧩` |
| Staff | ❌ (staff see only their own [profile](../../staff/profile/profile.md)) |
- **`🔒`** Assign/Reset PIN, change `role`, and Activate/Deactivate require owner PIN
  (`POST /auth/verify-pin`). Editing name/photo/join_date is owner-authenticated but not
  per-action PIN-gated.
- **Guard:** the owner cannot deactivate or demote their **own** only owner account (lockout
  prevention).

---

## 4. Screen layout (wireframe)

```
LIST                                    STAFF DETAIL
┌──────────────────────────────┐        ┌────────────────────────────────────┐
│ ← Staff            🔍  ✓sync  │        │ ← Ravi Kumar               ⋮        │
│ ┌────────────────────────┐    │        │ ┌──────┐ Name [ Ravi Kumar ]       │
│ │(photo) Ravi K.  staff  │ 🟢 │        │ │photo │ Role [ staff ▾ ] 🔒       │
│ │  joined 12-03-2025     │ ▶ │        │ │ 📷   │ Joined [ 12-03-2025 ]      │
│ ├────────────────────────┤    │        │ └──────┘ Status: 🟢 Active         │
│ │(photo) Meena S. staff  │ 🟢 │        │ ─── Performance snapshot ───────── │
│ │  joined 03-06-2025     │ ▶ │        │ Today ₹42,300 · 23 units           │
│ ├────────────────────────┤    │        │ Month ₹6,80,400 · pts 1,240        │
│ │(photo) Arun (inactive) │ ⚪ │        │ Lifetime ₹41,20,000                │
│ └────────────────────────┘    │        │ Badges: 🏅Top Week  🏅50 Toys      │
│        [ ＋ Add Staff ]        │        │ Incentive: ▓▓▓▓░ 82% to tier 2     │
└──────────────────────────────┘        │ [ 🔒 Reset PIN ] [ 🔒 Deactivate ] │
                                          │ [ View full history → web ]        │
                                          └────────────────────────────────────┘

ASSIGN / RESET PIN
┌────────────────────────────────────────────┐
│ Set a new 4–6 digit PIN for Ravi            │
│  New PIN     ● ● ● ●                          │
│  Confirm PIN ● ● ● ●                          │
│  (verify with your owner PIN)  ● ● ● ●        │
│           [  Save PIN  ] 🔒                    │
└────────────────────────────────────────────┘
```

- **Responsive:** phone = list then detail (push nav). Tablet = master-detail split.

---

## 5. UI components & field-by-field spec

### 5a. List
| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Search | search input | `GET /staff?q=` (`staff.name`) | — | empty | filter list | |
| 2 | Staff row | list row | `staff` (name, photo_url, role) + active chip | — | — | tap → detail | 🟢 active / ⚪ inactive (icon+label) |
| 3 | Add Staff | primary button | — | — | — | opens add form | |

### 5b. Add / Edit — field by field
| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 4 | Photo | image + camera | `staff.photo_url` | optional; size/type-checked | — | upload | shown on staff login & profile |
| 5 | Name | text | user | required; ≤100 | — | — | `staff.name` |
| 6 | Role `🔒` | dropdown | `staff.role` enum: staff \| owner \| accountant | required; change is PIN-gated | staff | changes app access | cannot demote last owner |
| 7 | Join date | date `DD-MM-YYYY` | picker | optional; ≤ today | today | — | `staff.join_date` |
| 8 | PIN (on add) `🔒` | masked numeric 4–6 | owner sets | required on create; `[0-9]{4,6}`; confirm match | — | hashed → `staff.pin_hash` (bcrypt) | never displayed/returned |
| 9 | Save | primary button | — | valid | — | `POST`/`PATCH /staff` | idempotent create |
| 10 | Reset PIN `🔒` | button → sheet | new PIN + confirm + owner PIN | as #8 + owner PIN verify | — | `PATCH /staff/{id}` `{ pin, owner_pin }` | for forgotten PINs mid-shift |
| 11 | Activate/Deactivate `🔒` | toggle/danger | `staff.is_active` | owner PIN; not self-lockout | active | `PATCH /staff/{id}` `is_active` | inactive = cannot log in |

### 5c. Performance snapshot (read-only)
| # | Element | Type | Source / options | Notes |
|---|---|---|---|---|
| 12 | Today revenue / units | KPI | `GET /staff/{id}/performance` (period=today) | tabular ₹ + count |
| 13 | Month revenue / points | KPI | `staff.current_month_points` + month sales | points = leaderboard cache |
| 14 | Lifetime sales | KPI | `staff.total_lifetime_sales` (nightly-reconciled cache) | denormalized |
| 15 | Badges | chip row | `staff_badges` → `badges` (`badges_earned` mirror) | icons + names |
| 16 | Incentive progress | progress bar | `staff_incentive_progress` vs `incentive_rules.target_value` | "% to next tier" |
| 17 | View full history → web | link | — | deep to [web staff performance](../../../cloud/web/staff/staff-performance.md) |

**Prose notes**
- **PIN handling:** the owner sets/resets the PIN; it is bcrypt-hashed into `staff.pin_hash`
  and **never displayed or returned** ([api-conventions §10](../../../foundation/api-conventions.md)).
  The staff member uses it on the [staff login](../../staff/auth/login.md).
- **Snapshot is a glance, not the ledger.** `total_lifetime_sales`, `current_month_points`
  and `badges_earned` are **denormalized caches** reconciled nightly; the authoritative
  figures come from `sales`, `staff_incentive_progress` and `staff_badges`
  ([data-model §4, §7](../../../foundation/data-model.md)). Deep numbers live on the web.
- **Deactivate is a soft state** (`is_active=0`): the staff member disappears from login and
  leaderboards but all their `sales`/`stock_movements` history and audit trail remain.

---

## 6. States
- **Default / populated:** roster list with active chips.
- **Empty:** `EmptyState` "No staff yet — add your team" (unlikely after setup).
- **Loading:** skeleton rows; snapshot skeleton on detail.
- **Error:** inline retry on list; save error preserves the form.
- **Offline:** browse/edit against cache (queued); **`🔒` PIN reset / role change /
  deactivate require online** (PIN verify) — buttons disabled with "connect to change."
  Performance snapshot shows cached values with an "as of" stamp.
- **Success:** toast "Staff saved" / "PIN reset" / "Deactivated."
- **Permission-denied:** accountant sees view-only; owner blocked from self-deactivation.

---

## 7. Interactions, gestures & hardware
- **Camera** for staff photo capture/upload.
- **`NumericPad` + `PinDialog`** for setting/resetting and owner-verifying PINs.
- **Tap** a row → detail; **pull-to-refresh** re-loads the roster and snapshot.
- No printer/scanner on this screen.
- **Latency:** roster loads < 1 s; snapshot from cache instant, fresh < 1 s.

---

## 8. Business rules & edge cases
1. **PIN assign/reset, role change, and deactivate are `🔒`** (owner PIN verified).
2. **No self-lockout:** the owner cannot deactivate or demote the last active `owner`.
3. **Deactivated staff cannot log in** and are removed from leaderboards, but history stays.
4. **PIN is write-only:** never displayed/returned; a reset overwrites `pin_hash`.
5. **Role governs app access:** `staff` → Staff App only; `owner`/`accountant` → Owner
   App/Web per grant. Changing role takes effect at the staff member's next login.
6. **Idempotent create** via `client_uuid`; duplicate submits don't create two staff rows.
7. **Snapshot freshness:** cached denormalized fields may lag the live ledger by up to the
   nightly reconciliation; the UI marks them "as of <date>."
8. **PIN uniqueness is not enforced** across staff (PINs are per-account secrets, not
   identifiers); login also carries `device_id`/context.
9. **Audit:** PIN reset, role change and (de)activation write `audit_log`
   (`staff.reset_pin`, `staff.role_change`, `staff.deactivate`).

---

## 9. API interactions

| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| List / search | `GET /staff?q=` | roster | cached read |
| Open staff | `GET /staff/{id}` | detail | cached |
| Snapshot | `GET /staff/{id}/performance?period=today\|month\|lifetime` | KPIs, points, badges, incentive progress | cached "as of" |
| Create | `POST /staff` (`Idempotency-Key`=`client_uuid`) | add staff (+ PIN, role, join_date) | queued |
| Edit | `PATCH /staff/{id}` | name/photo/join_date/role | queued (role change needs online PIN) |
| Reset PIN `🔒` | `PATCH /staff/{id}` `{ pin, owner_pin }` | overwrite `pin_hash` | **online** |
| Activate/Deactivate `🔒` | `PATCH /staff/{id}` `{ is_active, owner_pin }` | soft state | **online** |

Key fields (see [staff-api](../../../cloud/api/staff/staff-api.md),
[incentives-api](../../../cloud/api/incentives/incentives-api.md)):
- **create body:** `{ name, photo_url?, role, join_date, pin, owner_pin }`
- **performance resp:** `{ revenue, units, points, lifetime_sales, badges:[…],
  incentive:{ rule_id, current_value, target_value, tier_reached } }`
- Errors: `403 FORBIDDEN` (PIN/role/self-lockout), `VALIDATION_ERROR`. Envelope per
  [api-conventions](../../../foundation/api-conventions.md).

---

## 10. Offline & sync behavior
- **Works offline:** view roster + cached snapshot; add/edit name/photo/join_date (queued
  `sync_status='pending'`).
- **Blocked offline:** `🔒` PIN reset, role change, activate/deactivate (need live PIN
  verify) — critical to avoid stale security changes.
- **LWW:** concurrent staff edits reconcile last-write-wins by `updated_at`
  ([sync §5](../../../foundation/sync-and-conflict-resolution.md)); PIN/active changes go
  through the server directly (not the offline outbox).

---

## 11. Analytics & events
- `staff_list_viewed` · `staff_created` · `staff_edited`
- `staff_pin_reset` · `staff_role_changed` (from→to) · `staff_activated` / `staff_deactivated`
- `staff_snapshot_viewed` (staff_id, period)

---

## 12. Accessibility, localization & performance
- Active/inactive shown by **icon + label** (🟢/⚪), never color alone.
- `PinDialog` announces masked entry; snapshot KPIs read as "label, value."
- `₹` Indian grouping + tabular numerals; dates **DD-MM-YYYY**; incentive bar has a text %.
- Tap targets ≥ 48 dp; photo upload compressed client-side.

---

## 13. Acceptance criteria
- [ ] Owner can add a staff member with name, role, join date and an initial PIN.
- [ ] Assigning/resetting a PIN and changing role/active state each require an owner PIN.
- [ ] The PIN is bcrypt-hashed into `staff.pin_hash` and never displayed or returned.
- [ ] The owner cannot deactivate or demote the last active owner account.
- [ ] Deactivated staff cannot log into the Staff App; their history remains intact.
- [ ] The performance snapshot shows today/month/lifetime figures, badges and incentive
      progress, labelled "as of" its cache freshness.
- [ ] All `🔒` changes write an `audit_log` entry.
- [ ] Offline blocks PIN/role/active changes (buttons disabled with a "connect" hint).

---

## 14. Related docs
- Foundation: [data-model](../../../foundation/data-model.md) (`staff`, `staff_badges`,
  `staff_incentive_progress`, `incentive_rules`) · [api-conventions](../../../foundation/api-conventions.md) ·
  [design-system](../../../foundation/design-system.md) · [sync](../../../foundation/sync-and-conflict-resolution.md)
- API: [staff-api](../../../cloud/api/staff/staff-api.md) ·
  [incentives-api](../../../cloud/api/incentives/incentives-api.md) ·
  [auth-api](../../../cloud/api/auth/auth-api.md)
- Sibling screens: [Dashboard Home](../dashboard/dashboard-home.md) ·
  [Reports](../reports/reports.md)
- Counterparts: [web staff performance](../../../cloud/web/staff/staff-performance.md) ·
  [staff profile](../../staff/profile/profile.md)
