# Owner Login — Owner · Mobile (Owner App)

> Entry screen for the Owner App (`app_flavor = 'owner'`). The owner authenticates with
> a **quick PIN** (default, on-the-floor) or **email + password** (credential, first
> sign-in / new device), the device is registered for push + sync, and biometric unlock
> is offered as an optional shortcut for return visits.

Status: `✅ Specified` · contains `🔒` PIN-gated surface · one `⚠️` schema gap (see §5).

---

## 1. Purpose & context
- **What this screen is for:** let the shop owner get into the Owner App in one or two
  taps so they can approve discounts and glance at KPIs *while walking the floor*.
- **Who & when:** the **owner** (`staff.role = 'owner'`). Opened many times a day — every
  cold start, every session timeout, and every time a discount push wakes the app.
- **Why it exists:** the owner "floats the floor, personally approves discounts and needs a
  real-time pulse on sales/stock without being glued to a screen"
  ([requirements](../../../requirements_and_prompt.md)). Auth must be near-instant; a slow
  login means a customer waits at the counter for a discount decision.
- **Frequency / criticality:** high frequency, high criticality. A locked-out owner blocks
  every `🔒` discount approval in the shop. Auth is also the gate that binds a `device_id`
  to the owner for the discount push channel and the sync worker.

---

## 2. Entry points & navigation
- **Cold start / logged-out:** app launches here when no valid refresh token exists.
- **Session expiry:** an expired access token that cannot be refreshed routes back here.
- **Notification tap while logged out:** a `discount_request` push opens Login first, then
  deep-links to [Discount Approval](../approvals/discount-approval.md) after success.
- **Manual logout:** from [Dashboard Home](../dashboard/dashboard-home.md) overflow menu.

```
(cold start) ─▶ Owner Login ─▶ Dashboard Home
                     │
                     └─(deep link pending)─▶ Discount Approval / Notifications
```

- **Back button:** on the login screen, back exits the app (no screen behind it).
- **Forward exits:** on success → Dashboard Home, or the pending deep-link target.

---

## 3. Roles & permissions
| Actor | Can open | Notes |
|---|---|---|
| Owner (`role='owner'`) | ✅ full access | only role the Owner App admits |
| Accountant (`role='accountant'`) | ✅ if flavor allows | may be granted read reports/GST; discount approval stays owner-only |
| Staff (`role='staff'`) | ❌ rejected | wrong flavor → `403 FORBIDDEN`, "Use the Staff App" message |
- The **PIN entered here is the owner's own PIN**; the same PIN later satisfies `🔒`
  owner-PIN gates (discount approve, product deactivate) via `POST /auth/verify-pin`.
- Nothing on this screen is read-only; it is the authentication boundary itself.

---

## 4. Screen layout (wireframe)

```
┌───────────────────────────────────────────┐
│                 [ Shop logo ]              │
│              ToyShop · Owner               │
│                                            │
│        ┌───────────────────────────┐       │
│        │   (owner photo, if known) │       │  ← photo_url of last owner on device
│        │      Welcome, <name>      │       │
│        └───────────────────────────┘       │
│                                            │
│              Enter owner PIN               │
│            ●  ●  ●  ●   ( _ _ )            │  ← 4–6 masked dots
│                                            │
│              ┌───┬───┬───┐                 │
│              │ 1 │ 2 │ 3 │                 │
│              │ 4 │ 5 │ 6 │   NumericPad    │
│              │ 7 │ 8 │ 9 │                 │
│              │ ⌫ │ 0 │ ☺ │                 │  ← ☺ = biometric (if enrolled)
│              └───┴───┴───┘                 │
│                                            │
│   [ Use email & password instead ]         │  ← switches to credential mode
│   [ SyncStatusChip ✓ ]      v1.0 · dev     │
└───────────────────────────────────────────┘
```

**Credential mode (first sign-in / new device):**
```
┌───────────────────────────────────────────┐
│  Email    [ owner@shop.in            ]     │
│  Password [ ••••••••••          👁 ]       │
│  [ Remember this device ]  ☑               │
│           [   Sign in   ]  (56dp)          │
│  [ Use PIN instead ]   [ Forgot password ] │
└───────────────────────────────────────────┘
```

- **Responsive:** phone-first, single column. On tablet the `NumericPad` and credential
  card are centred at ~360 dp width; no layout change. Web flavor uses the
  [web login](../../../cloud/web/auth/login.md) instead.

---

## 5. UI components & field-by-field spec

| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Owner photo + name | avatar + label | `staff.photo_url`, `staff.name` of last owner cached on this `device_id` | — | last owner, else generic | shown only if a prior owner logged in on this device | skipped on a brand-new device |
| 2 | PIN field | masked numeric, 4–6 digits | user input via `NumericPad` | required; `[0-9]{4,6}`; matches `staff.pin_hash` (bcrypt) server-side | empty | auto-submits when min length reached **and** user pauses / taps ✓ | never shows digits; dots only |
| 3 | `NumericPad` | keypad `0-9`, ⌫, biometric | design-system `NumericPad` | — | — | large 48×48+ keys, no OS keyboard | fast one-hand entry |
| 4 | Biometric button ☺ | icon action | device fingerprint/Face ID (`local_auth`) | enrolled + previously opted in | hidden if not enrolled | success → unlocks with cached refresh token | never replaces server PIN for `🔒` actions |
| 5 | Email | text/email input | user input | required (cred mode); RFC email; maps to `staff.email` **⚠️ proposed** | empty | inline error under field | credential mode only |
| 6 | Password | secure text input | user input | required; min 8; maps to `staff.password_hash` **⚠️ proposed** | empty | 👁 toggles visibility | credential mode only |
| 7 | Remember this device | checkbox | user | — | checked | on = store refresh token + register `devices.push_token` | enables PIN + biometric next time |
| 8 | Sign in | primary button 56 dp | — | enabled when fields valid | disabled | calls `POST /auth/login` | shows inline spinner, not full-screen |
| 9 | Mode switch link | text button | — | — | PIN mode | toggles PIN ⇄ credential | preserves entered email |
| 10 | Forgot password | text link | — | — | — | opens owner-recovery flow (email OTP) | out of scope of this screen |
| 11 | `SyncStatusChip` | status chip | [sync doc §8](../../../foundation/sync-and-conflict-resolution.md) | — | ✓ | reflects last sync state of cached data | glanceable, non-blocking |
| 12 | Version / env footer | caption | `X-Client-Version`, build env | — | — | — | aids support |

**Prose notes**
- **PIN vs credential:** PIN is a *convenience unlock* of an already-registered device; it
  produces the same JWT session as credential login. On a **new device with no stored
  refresh token**, PIN alone is not accepted — the owner must complete a credential login
  once to bind the device, after which PIN unlock is enabled.
- **Biometric** unlocks the locally-stored refresh token only; it is **not** a substitute
  for the fresh PIN required by `🔒` actions elsewhere in the app.

> **⚠️ Proposed schema addition:** `staff.email VARCHAR(150) UNIQUE NULL` and
> `staff.password_hash CHAR(60) NULL` (bcrypt). The canonical `staff` table
> ([data-model.md](../../../foundation/data-model.md) §4) defines only `pin_hash`; owner
> **email + password** credential login needs these two columns. Until added, credential
> mode is `🧩 Derived` and blocked in code.

---

## 6. States
- **Default:** PIN mode, cached owner photo/name if present, `NumericPad` ready.
- **Empty (new device):** no cached owner → generic avatar, credential mode shown first.
- **Loading:** inline spinner inside the Sign in / PIN submit control; keypad disabled;
  never a full-screen blocker (owner may be mid-conversation with a customer).
- **Populated:** — (n/a; this screen has no list content).
- **Error:** inline red text below the field: wrong PIN → "PIN incorrect · 2 tries left";
  wrong credentials → "Email or password incorrect"; wrong flavor → "This is the Owner App
  — staff should use the Staff App". No modal dialogs.
- **Offline:** if the app has a **valid, unexpired refresh token** cached, PIN/biometric
  unlock succeeds fully offline against the local session; a calm banner "Working offline —
  showing last synced data" appears. If **no cached session** and offline, a credential
  login cannot reach the server → "No connection — connect once to sign in."
- **Success:** brief check animation → route to Dashboard Home (or pending deep link).
- **Permission-denied:** valid staff credentials but `role='staff'` → `403 FORBIDDEN`,
  "You do not have owner access."

---

## 7. Interactions, gestures & hardware
- **NumericPad taps:** each tap fills one dot; ⌫ removes last; auto-submit at min length.
- **Biometric:** tap ☺ or auto-prompt on screen open if enrolled and opted-in.
- **Show/hide password:** tap 👁.
- **Lockout backoff:** after **5** failed PIN attempts, disable entry for 30 s (client)
  and rely on server rate-limit (`429 RATE_LIMITED`, honor `Retry-After`).
- **Latency budget:** PIN unlock with cached session should feel instant (< 150 ms);
  credential login is network-bound but must show progress within 100 ms.

---

## 8. Business rules & edge cases
1. Only `staff.role IN ('owner','accountant')` may complete Owner-App login; `staff` role
   is rejected with `403 FORBIDDEN`.
2. `staff.is_active = 0` → login rejected ("Account deactivated — contact admin").
3. PIN unlock requires a previously **registered device** (a stored refresh token bound to
   this `device_id`); otherwise force credential login once.
4. Every successful login **upserts `devices`** (`device_id`, `staff_id`, `platform`,
   `app_flavor='owner'`, `push_token`, `last_seen`) so the discount push channel and sync
   worker can reach this owner.
5. `🔒` actions later in the app re-verify the PIN via `POST /auth/verify-pin`; a login PIN
   does not silently satisfy them past its short token TTL.
6. Failed-attempt throttling: client soft-lock at 5 tries; server enforces the hard limit
   and returns `429`.
7. Wrong-flavor guard: a staff PIN used here must not leak whether the PIN was valid — the
   error is role-based, not PIN-based, to avoid enumeration.
8. Biometric is opt-in and stored per device; disabling OS biometrics removes the ☺ option
   automatically at next launch.
9. Session refresh: an expired **access** token is refreshed silently; an expired
   **refresh** token forces a return to this screen.

---

## 9. API interactions

| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Credential sign-in | `POST /auth/login` | email + password → JWT access + refresh, owner profile | requires network; if offline & cached session valid, skip |
| PIN unlock | `POST /auth/pin-login` | `{ pin, device_id }` → session bound to device | if valid cached refresh token exists, verify locally offline |
| Register device | upsert on login (piggybacked) / `POST /auth/register-device` `🧩` | write `devices` row incl. `push_token` | queued until online |
| `🔒` re-verify (used later) | `POST /auth/verify-pin` | short-lived `X-Owner-Pin-Token` for gated actions | must be online at the moment of the gated action |
| Silent refresh | `POST /auth/refresh` | swap refresh → new access | fails offline → fall back to cached session |

Request/response fields used here (see [api/auth](../../../cloud/api/auth/auth-api.md)):
- **login req:** `{ email, password, device: { device_id, platform, app_flavor:'owner',
  push_token } }`
- **pin-login req:** `{ staff_id | email_hint, pin, device_id }`
- **success data:** `{ access_token, refresh_token, staff: { id, name, role, photo_url } }`
- Envelope, error codes (`UNAUTHENTICATED`, `FORBIDDEN`, `RATE_LIMITED`) per
  [api-conventions.md](../../../foundation/api-conventions.md).

---

## 10. Offline & sync behavior
- **Works offline:** PIN + biometric unlock when a valid cached session exists; the app
  then shows last-synced KPIs with an offline banner.
- **Queued:** `devices` push-token upsert and `last_seen` update queue until online.
- **Blocked offline:** first-time credential login, `POST /auth/verify-pin` for `🔒`
  actions, and refresh-token renewal.
- **Local storage:** owner profile + refresh token in secure storage (Keychain/Keystore),
  not in Drift; no transactional Drift tables are written here. `sync_status` values are
  not set on this screen. See
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md).

---

## 11. Analytics & events
- `login_screen_viewed` (mode: pin | credential)
- `login_succeeded` (method: pin | credential | biometric)
- `login_failed` (reason: bad_pin | bad_credentials | wrong_role | deactivated | rate_limited)
- `device_registered` (device_id, platform)
- `biometric_unlock_used`

---

## 12. Accessibility, localization & performance
- Keypad keys and buttons ≥ 48×48 dp; primary Sign in 56 dp; PIN dots high-contrast.
- Screen-reader labels on masked dots ("PIN, 3 of 4 entered") and on the biometric icon.
- Localizable strings; dates elsewhere in app use **DD-MM-YYYY**; currency `₹` with Indian
  grouping. Error copy is plain-language, not codes.
- Cold-start to interactive < 1.5 s on a low-end Android; PIN unlock < 150 ms.
- Never rely on color alone for the error state (icon + text).

---

## 13. Acceptance criteria
- [ ] A registered owner unlocks with a 4–6 digit PIN in ≤ 2 taps beyond entry.
- [ ] Wrong PIN shows an inline error with remaining attempts; 5 failures soft-lock 30 s.
- [ ] A brand-new device forces one credential login, then enables PIN + biometric.
- [ ] Every successful login upserts a `devices` row with `app_flavor='owner'` and push token.
- [ ] A `staff`-role account is rejected with a role-based (not PIN-based) message.
- [ ] With a valid cached session and no network, PIN/biometric unlock still succeeds and an
      offline banner appears.
- [ ] A `discount_request` push received while logged out routes: Login → Discount Approval.
- [ ] No full-screen blocking spinner appears at any point (inline only).
- [ ] Biometric unlock does **not** satisfy a later `🔒` action without a fresh `verify-pin`.

---

## 14. Related docs
- Foundation: [overview](../../../foundation/overview.md) ·
  [data-model](../../../foundation/data-model.md) ·
  [api-conventions](../../../foundation/api-conventions.md) ·
  [design-system](../../../foundation/design-system.md) ·
  [sync](../../../foundation/sync-and-conflict-resolution.md)
- API: [auth-api](../../../cloud/api/auth/auth-api.md)
- Sibling screens: [Dashboard Home](../dashboard/dashboard-home.md) ·
  [Discount Approval](../approvals/discount-approval.md) ·
  [Notifications](../notifications/notifications.md)
- Counterparts: [staff login](../../staff/auth/login.md) · [web login](../../../cloud/web/auth/login.md)
