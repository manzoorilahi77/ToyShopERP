# Staff Login — Staff · Mobile (Flutter, offline-first)

> Follows [`_templates/screen-doc-template.md`](../../../_templates/screen-doc-template.md).
> Foundation vocabulary is referenced, not repeated: envelope/auth/errors live in
> [`api-conventions.md`](../../../foundation/api-conventions.md), tokens & components in
> [`design-system.md`](../../../foundation/design-system.md), sync in
> [`sync-and-conflict-resolution.md`](../../../foundation/sync-and-conflict-resolution.md).
> Status legend: `✅ Specified` · `🧩 Derived (confirm with owner)` · `⚠️ Risk` · `🔒 Owner PIN`.

---

## 1. Purpose & context
- **What it is** — the first screen a shop boy sees: a grid of staff **photos + names**;
  tap your face, enter a 4–6 digit **PIN** on a big on-screen pad (or use fingerprint/Face)
  and you're in. No email, no username, no OS keyboard.
- **Who & when** — all 5–6 sales staff (and the owner, in a pinch), at shift start and
  after the app is backgrounded/locked. Heaviest at evening/weekend rush shift changes.
- **Why it exists** — the north-star bar: a non-technical 19-year-old logs in **in ~2 s**
  and **never picks the wrong staff account** (photo confirmation), because every sale is
  attributed to a `staff_id` that drives leaderboard, incentives and audit. Wrong login =
  wrong person credited for sales and untraceable stock movements.
- **Frequency / criticality** — 1–3 times/day/staff; low volume but **security- and
  attribution-critical**. A mistake here corrupts every downstream `sales.staff_id`.

## 2. Entry points & navigation
- **Cold start** when no valid session/token exists, or after **logout** (from
  [profile](../profile/profile.md)), or after the local session lock timeout.
- **Not** reachable by deep link while a valid session exists (guarded route).
- **Exit** → on success routes to [Staff Home/Dashboard](../dashboard/dashboard-home.md).
- **Back button** — on the staff-picker step: exits the app (Android). On the PIN step:
  returns to the staff-picker (does not exit).

```
(app launch / logout / lock) → Staff Picker → PIN Pad ──success──▶ Dashboard
                                    ▲             │
                                    └──back────────┘
```

## 3. Roles & permissions
- **Open to:** anybody physically holding the device — the screen is public by design.
- Identity is proven by the **PIN** (bcrypt-checked), not by reaching the screen.
- `owner`/`accountant` rows may also appear/PIN-in here on a `staff`-flavor build, but the
  owner normally uses email login on the [owner app](../../owner/auth/login.md). No action
  on this screen is `🔒 owner-PIN` gated (this screen *is* the credential step).

## 4. Screen layout (wireframe)

```
┌──────────────────────────────── Staff Login ─────────────┐   ← Step 1: pick
│  ToyShop            Working offline • cached roster  (chip)│
│                                                            │
│   Who's billing?                                           │
│   ┌───────┐  ┌───────┐  ┌───────┐                          │
│   │ (📷)  │  │ (📷)  │  │ (📷)  │     photo tiles ≥96dp     │
│   │ Ravi  │  │ Anbu  │  │ Meena │                          │
│   └───────┘  └───────┘  └───────┘                          │
│   ┌───────┐  ┌───────┐  ┌───────┐                          │
│   │ (📷)  │  │ (📷)  │  │  + ?  │  ← "Not listed / refresh" │
│   │ Karan │  │ Suraj │  │       │                          │
│   └───────┘  └───────┘  └───────┘                          │
└────────────────────────────────────────────────────────────┘

┌──────────────────────── Enter PIN ───────────────────────┐   ← Step 2: PIN
│  ◀ back            (📷) Ravi   ← confirm photo + name      │
│                                                            │
│              ● ● ● ○ ○ ○      (4–6 masked dots)            │
│              wrong PIN — 2 tries left      (inline, red)   │
│                                                            │
│        ┌─────┐ ┌─────┐ ┌─────┐                            │
│        │  1  │ │  2  │ │  3  │        NumericPad (56dp)    │
│        ├─────┤ ├─────┤ ├─────┤                            │
│        │  4  │ │  5  │ │  6  │                            │
│        ├─────┤ ├─────┤ ├─────┤                            │
│        │  7  │ │  8  │ │  9  │                            │
│        ├─────┤ ├─────┤ ├─────┤                            │
│        │ 👆  │ │  0  │ │  ⌫  │  ← biometric · 0 · delete  │
│        └─────┘ └─────┘ └─────┘                            │
└────────────────────────────────────────────────────────────┘
```

Responsive: phone shows a 3-col photo grid (2-col on very narrow); tablet 4–5 cols. The
`NumericPad` keys are 56 dp tall (design-system §5) and thumb-reachable at the bottom.

## 5. UI components & field-by-field spec

| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Staff photo tile | tappable card (`ProductTile`-like) | cached staff roster (`staff.id`, `name`, `photo_url`, `is_active=1`) | tile only shown if `is_active=1` | — | tap → go to PIN step with that `staff_id` | ≥96 dp, image + name; avatar fallback initials if `photo_url` null/offline |
| 2 | Sync/roster chip | `SyncStatusChip` | connectivity + roster freshness | — | reflects real state | tap → refresh roster (online) | shows "cached roster" line offline |
| 3 | "Not listed / refresh" tile | button | — | — | — | online: re-pull roster; offline: hint "connect once to add new staff" | covers a brand-new hire not yet cached |
| 4 | Confirm header (photo+name) | static | selected `staff` | — | selected staff | — | the anti-wrong-account guard (R6 Staff/Login) |
| 5 | PIN dots | masked indicator | derives from PIN buffer length | 4–6 digits | empty | fills as digits typed; shakes on wrong | never renders the digits |
| 6 | `NumericPad` 0–9 | big-key pad | on-screen only | `[0-9]` | — | appends to PIN buffer | no OS keyboard (design-system §6) |
| 7 | Delete key ⌫ | pad key | — | — | — | pops last digit | long-press clears all |
| 8 | Biometric key 👆 | pad key | `local_auth` (device) | shown only if enrolled **and** opted-in | hidden | triggers OS fingerprint/Face prompt | on success unlocks with the last-used `staff_id`; see rule B8 |
| 9 | Submit | auto | — | fires at min length; explicit ✓ if 5–6 digit PIN | — | auto-submit on the configured PIN length; else confirm key | most PINs are 4-digit → auto-submit on 4th |
| 10 | Error banner | inline text | attempt result | — | hidden | shows "wrong PIN — N tries left" / "locked" / offline note | inline + non-blocking (design-system §7) |

Prose notes:
- **PIN length** — the pad accepts 4–6 digits. If the staff's PIN length is known from the
  last successful login it auto-submits at that length; otherwise a small ✓ confirm key
  appears once ≥4 digits are entered.
- **Biometric** is a *convenience unlock* for the **same device + same last staff** only;
  it never substitutes for first-time PIN enrolment and is disabled after a logout/lockout.

## 6. States

| State | What the user sees / can do |
|---|---|
| **default** | Staff photo grid (Step 1). |
| **empty** | Roster cache empty (fresh install, never synced) → `EmptyState`: "Connect to the internet once to load staff." Primary action: Retry. Cannot PIN-in until at least one roster pull succeeds. |
| **loading** | Roster pull → skeleton tiles (not a blank screen, design-system §7). PIN verify → the ✓/pad briefly disabled with a subtle spinner; never a full-screen blocker. |
| **populated** | Grid filled from cache; PIN step ready. |
| **error (wrong PIN)** | Dots shake, inline "wrong PIN — N tries left", pad stays active. |
| **locked** | After N failures → PIN pad disabled, countdown "Try again in mm:ss", note "Ask the owner to reset your PIN". |
| **offline** | Calm banner "Working offline — login uses this device's saved PIN". Grid from cache; PIN checked locally (see §10). No red error. |
| **success** | Brief check animation → navigate to Dashboard; device registered in background. |
| **permission-denied** | Selected a deactivated staff (`is_active=0`, learned on online verify) → inline "This account is disabled — see the owner." |

## 7. Interactions, gestures & hardware
- **Tap** a photo (Step 1); **tap** number keys (Step 2). **Long-press** ⌫ clears PIN.
- **Back gesture/button**: PIN step → picker; picker → exit app.
- **Biometric**: `local_auth` triggers the OS prompt; hardware-backed, never leaves device.
- **No camera / printer / scanner** on this screen.
- **Latency budget**: photo→PIN transition <200 ms; local PIN verify <250 ms (bcrypt cost
  bounded, api-conventions §... auth §8); biometric unlock is instant on OS success.

## 8. Business rules & edge cases
1. **Photo confirmation is mandatory** — you always pass through the confirm header before
   the PIN commits, so you cannot silently bill under the wrong `staff_id`. (R6 Staff/Login)
2. **PIN is 4–6 digits**, bcrypt-checked against `staff.pin_hash`. Never stored or logged
   in plaintext; the local cache holds only the bcrypt hash (see §10).
3. **Lockout after N failures** — default **5** → locked for **15 min** (mirrors
   [`auth-api`](../../../cloud/api/auth/auth-api.md) `423 LOCKED`). Counter resets on
   success. Owner can reset the PIN from
   [owner staff-management](../../owner/staff/staff-management.md).
4. **Generic failure message** — never reveal whether the staff or the PIN was wrong
   (no account enumeration); UI says only "wrong PIN".
5. **Deactivated account** — if `is_active=0`, online login is rejected `403`; offline, the
   app still allows unlock only if the cached roster hasn't yet learned the deactivation
   (⚠️ trade-off, see §10 R6).
6. **Device registration** — on success, the app upserts this `device_id` via
   `POST /devices/register`; the `device_id` then stamps every offline `sales.device_id`
   and `stock_movements.device_id` for traceability.
7. **Session lock vs logout** — a short inactivity lock re-shows the PIN (biometric allowed)
   without clearing tokens; an explicit **logout** clears tokens + biometric opt-in and
   forces a full PIN entry.
8. **Biometric fallback** — three failed biometric attempts fall back to PIN automatically.
9. **New hire not in cache** — cannot appear until one online roster pull; the "Not
   listed / refresh" tile explains this rather than dead-ending.
10. **Clock skew** — irrelevant to local login; only affects server token `iat/exp` handled
    by the sync worker's silent refresh (auth-api §6).

## 9. API interactions

| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Load staff picker | (cached roster; refreshed by `GET /sync/pull`) | staff `id`, `name`, `photo_url`, `is_active` for the grid | reads Drift `staff` cache; no call |
| First-run roster (no cache) | `GET /staff` *(roster subset)* | seed the picker on a fresh install | **blocked** until online (see rule 9 / §10) |
| Submit PIN (online) | `POST /auth/pin-login` | verify PIN, mint access+refresh tokens, return profile card | falls back to **local** bcrypt check (§10) |
| After success | `POST /devices/register` | register/refresh `device_id`, `push_token` | queued; retried by sync worker |

- Envelope, headers (`X-Device-Id`), error codes and lockout (`423`) per
  [`api-conventions.md`](../../../foundation/api-conventions.md) and
  [`auth-api`](../../../cloud/api/auth/auth-api.md). Key `pin-login` request fields used
  here: `staff_id`, `pin`, `device_id`, `platform`, `app_flavor`; key response fields:
  `access_token`, `refresh_token`, `expires_in`, `staff{ id,name,photo_url,role,join_date }`.

## 10. Offline & sync behavior
- **Fully offline-capable unlock.** The staff app caches the roster (`staff.id`, `name`,
  `photo_url`, **`pin_hash`**, `is_active`) in Drift on each successful `GET /sync/pull`.
  Offline, the PIN is verified with a **local bcrypt compare** against the cached
  `pin_hash`, so a shift can start with no connectivity — the sale flow must never wait on a
  network login (R1, sync doc §1).
- **⚠️ Security trade-off (call it out):** caching `pin_hash` on-device means a compromised
  device exposes bcrypt hashes to offline brute-force. Mitigations: (a) store the cache in
  the OS **secure keystore / encrypted Drift**, not plaintext SQLite; (b) enforce the same
  **local lockout** (5 tries / 15 min) as the server; (c) a **stale roster** cannot learn a
  server-side PIN change or deactivation until the next pull — so PIN rotation/deactivation
  has an offline lag. Owner should be told: deactivating a staff only fully takes effect
  once that device syncs. Confirm cache-encryption approach with the schema/security owner.
- **Local lockout counters** (`failed_pin_attempts`, `locked_until`) live in Drift and are
  reconciled with the server's counters (proposed columns flagged in
  [`auth-api`](../../../cloud/api/auth/auth-api.md)) on next sync.
- **Tokens**: obtained online; when offline the app runs in a **local session** and the sync
  worker fetches real tokens on the next connectivity transition (auth-api §6).
- Drift tables touched: **read** `staff` (roster cache), local `session`/`device` prefs;
  **write** local session + `failed_pin_attempts`. No `sync_status` transitions originate
  here (login is not a sync-replayable write).

## 11. Analytics & events
- `login_screen_shown`, `staff_selected {staff_id}`, `pin_submitted {result}`,
  `login_success {staff_id, mode: online|offline|biometric}`, `login_failed {reason}`,
  `login_locked {staff_id}`, `biometric_used {result}`, `roster_refresh {source}`.
- Never log the PIN or `pin_hash`. `login_failed.reason` is coarse (`wrong_pin`,
  `locked`, `deactivated`, `offline_no_cache`) — no enumeration.

## 12. Accessibility, localization & performance
- Tap targets ≥48 dp (photo tiles ≥96 dp; pad keys 56 dp). WCAG AA contrast; PIN error uses
  icon + text, never color alone (design-system §8, §10).
- Screen-reader labels: each tile "Staff, <name>, tap to enter PIN"; pad keys announce
  digit; masked dots announce "PIN, N of M entered" without speaking digits.
- i18n: English + regional; names/labels localizable; dates DD-MM-YYYY (join date shown on
  profile, not here). Biometric prompt uses the OS locale.
- Perf: cold start to interactive picker < 1.5 s from warm cache; PIN verify < 250 ms.

## 13. Acceptance criteria
- [ ] Staff picker renders photo + name tiles for every `is_active=1` staff from cache,
      offline included.
- [ ] Selecting a tile always shows the confirm photo+name header before any PIN is accepted.
- [ ] A correct 4-digit PIN auto-submits and lands on the Dashboard in < ~2 s online.
- [ ] A wrong PIN shows an inline "N tries left" and shakes the dots without leaving the pad.
- [ ] After 5 wrong PINs the pad locks for 15 min with a visible countdown; success before
      lockout resets the counter.
- [ ] With no connectivity, a valid PIN unlocks via the cached bcrypt hash and the sale flow
      is reachable without any network call.
- [ ] A fresh install with an empty roster cache shows the "connect once" empty state and
      cannot PIN-in until a roster pull succeeds.
- [ ] On success the device is (re)registered and the resulting `device_id` appears on the
      next offline sale's `device_id`.
- [ ] Biometric key appears only when enrolled + opted-in, and falls back to PIN after 3
      failures.
- [ ] The PIN is never rendered, logged, or transmitted in plaintext.

## 14. Related docs
- **Foundation:** [overview](../../../foundation/overview.md) ·
  [api-conventions](../../../foundation/api-conventions.md) ·
  [sync-and-conflict-resolution](../../../foundation/sync-and-conflict-resolution.md) ·
  [design-system](../../../foundation/design-system.md) ·
  [data-model](../../../foundation/data-model.md) ·
  [requirements](../../../requirements_and_prompt.md)
- **API:** [auth-api](../../../cloud/api/auth/auth-api.md) (`pin-login`, `verify-pin`,
  `devices/register`) · [sync-api](../../../cloud/api/sync/sync-api.md)
- **Sibling staff screens:** [dashboard-home](../dashboard/dashboard-home.md) ·
  [new-sale](../sales/new-sale.md) · [profile](../profile/profile.md)
- **Other surfaces:** [owner login](../../owner/auth/login.md) ·
  [owner staff-management](../../owner/staff/staff-management.md)
