# Web Login — Owner / Accountant · Flutter Web

> Status: `✅ Specified` · Surface: **Owner Web Dashboard** (Flutter Web, desktop, mostly online).
> The single unauthenticated screen; the gate to every other web screen.

---

## 1. Purpose & context
- **What this screen is for** — lets the owner or accountant sign in to the web dashboard
  with an **email + password** and start a browser session for ledger work, GST filing and
  exports.
- **Who uses it** — `owner` and `accountant` roles only. Sales `staff` never sign in here
  (they use the mobile PIN login, [../../../mobile/staff/auth/login.md](../../../mobile/staff/auth/login.md)).
- **When** — start of a desktop work session; **heaviest at GST season** (monthly/quarterly)
  when the accountant opens the dashboard to compile GSTR-1/3B and pull ledgers.
- **Why it exists** — the mobile apps authenticate by 4–6 digit PIN bound to a device; that
  is unsafe and impractical on a shared desktop browser. Credential login gives the
  owner/accountant a real, revocable web session so GST/ledger data (the shop's most
  sensitive records) is not exposed on an unlocked machine. Ties to the brief's
  "OWNER/ACCOUNTANT (Web Dashboard) → 1. Login Screen — credential-based (web session)."
- **Frequency / criticality** — low frequency (once or twice a day, per session), **high
  criticality**: a leaked session exposes full financials. Lockout/rate-limit protects it.

> **⚠️ Proposed schema addition.** `data-model.md` `staff` has only `pin_hash` (mobile PIN).
> Web credential login requires **`staff.email VARCHAR(190) UNIQUE`** and
> **`staff.password_hash CHAR(60)`** (bcrypt), plus optional **`staff.last_login_at DATETIME`**.
> Forgot-password needs a **`password_reset_tokens`** table (`id, staff_id, token_hash,
> expires_at, used_at`). These are additive to the existing `staff` row; PIN login is unaffected.

---

## 2. Entry points & navigation
- **Arrival**
  - Direct URL `https://<env>-dashboard.toyshop.example/login` (or `/` → redirect to `/login`
    when no valid session).
  - Any deep link (e.g. `/gst`) while unauthenticated → bounced to `/login?next=/gst`.
  - Session/refresh expiry mid-session → toast "Session expired" → redirect to `/login?next=<current>`.
- **Exits**
  - **Sign in success** → the value of `?next=` if present, else **Dashboard Home**
    ([../dashboard/dashboard-home.md](../dashboard/dashboard-home.md)).
  - **Forgot password** → `/forgot-password` (in-page or modal) → back to `/login`.
- **Back-button** — after login, browser Back must **not** return to `/login` while a
  session is valid; guarded route redirects forward to Dashboard. After logout, Back must
  not restore an authenticated page (state cleared; guard re-checks).
- Nav diagram: `/(any) → /login → [auth] → Dashboard Home` · `/login → /forgot-password → /login`.

---

## 3. Roles & permissions
| Actor | Can open | Notes |
|---|---|---|
| Owner | ✅ | full dashboard after login |
| Accountant | ✅ | full dashboard; same web screens (GST/ledgers/exports) |
| Staff | ⛔ | `403 FORBIDDEN` on login attempt — web is owner/accountant only; message: "This dashboard is for owners and accountants. Use the staff app to sign in." |
- No `🔒 owner-PIN` gate on this screen (PIN gating applies to money actions inside the app,
  not to web sign-in). Credential auth replaces PIN for the web session.
- The sidebar shell (§4) is **not** rendered on this screen — login is outside the app shell.

---

## 4. Screen layout (wireframe)
Centered card on a calm brand background; **no sidebar** (unauthenticated shell).

```
┌──────────────────────────────────────────────────────────────────────┐
│                                                                        │
│                        ╭──────────────────────────╮                    │
│                        │        🧸  ToyShop        │                    │
│                        │      Owner Dashboard      │                    │
│                        ├──────────────────────────┤                    │
│                        │  Email                    │                    │
│                        │  [ owner@toyshop.example ]│                    │
│                        │                           │                    │
│                        │  Password           👁     │                    │
│                        │  [ •••••••••••          ] │                    │
│                        │                           │                    │
│                        │  ☑ Remember me   Forgot?  │                    │
│                        │                           │                    │
│                        │  [       Sign in       ]  │  ← primary, 56dp   │
│                        │                           │                    │
│                        │  ! inline error region    │                    │
│                        ╰──────────────────────────╯                    │
│              Secure session · v1.4.0 · dev-dashboard                    │
└──────────────────────────────────────────────────────────────────────┘
```

**Responsive breakpoints** (card is fixed-max-width, background fluid):

| Name | Width | Layout |
|---|---|---|
| Compact | < 768 px | card fills width (16 px gutters), 100% height; logo smaller |
| Medium | 768–1199 px | 400 px centered card |
| Expanded | 1200–1599 px | 400 px centered card, subtle brand illustration panel optional |
| Wide | ≥ 1600 px | centered card; content max held, extra whitespace |

---

## 5. UI components & field-by-field spec
| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Email | text input (email) | user input | required; RFC-5322-ish; trimmed, lowercased | empty (or last email if Remember me) | inline validity on blur; enables Sign in when both fields non-empty | autofocus; `autocomplete="username"` |
| 2 | Password | password input | user input | required; min 8 chars (server is authority) | empty | never echoed; typed dots | `autocomplete="current-password"` |
| 3 | Show/hide password | toggle (👁) | — | — | hidden | toggles input type text/password | `aria-pressed`; does not persist |
| 4 | Remember me | checkbox | user | boolean | **off** | on → refresh cookie persisted ~30 d; off → session cookie (cleared on browser close) | see §8 R3 |
| 5 | Forgot password? | link | — | — | — | → `/forgot-password` | keyboard focusable |
| 6 | Sign in | primary button (56 dp) | — | disabled until both fields non-empty; disabled+spinner while in flight | disabled | calls `POST /auth/login` | `Enter` in either field submits |
| 7 | Inline error region | text (`--danger`) | server error | — | hidden | shows message for `UNAUTHENTICATED`/`FORBIDDEN`/`RATE_LIMITED`; icon + label (never color-alone) | polite live region |
| 8 | Footer meta | caption | build/env | — | — | shows app version + env; no PII | helps support |

Prose notes:
- **Autofill** — the form works with browser/password-manager autofill; Sign in enables once
  both fields are populated by autofill.
- **Generic failure copy** — never reveal whether the email exists. On bad email OR bad
  password: "Incorrect email or password."

---

## 6. States
- **default** — empty form (or email prefilled if Remember me), Sign in disabled, no error.
- **empty** — same as default; this screen has no list data.
- **loading** — after Sign in tap: button shows spinner + disabled, inputs disabled; if a
  valid session already exists on load, show a brief full-card skeleton while `/auth/refresh`
  is attempted (silent auto-login) before rendering the form.
- **populated** — both fields filled, Sign in enabled.
- **error (inline, retry)** — invalid credentials, forbidden role, rate-limited, or network
  error shown in the inline region with a retry affordance; fields retain email, clear password.
- **offline** — web is online-first; if the network is down, show a calm banner "You appear to
  be offline — check your connection" and keep Sign in disabled until connectivity returns
  (no offline auth on web).
- **success** — brief confirmation, then redirect to `?next=`/Dashboard; no lingering toast.
- **permission-denied** — staff role (or deactivated `is_active=0`) → inline "This dashboard
  is for owners and accountants."

---

## 7. Interactions, gestures & hardware
- **Keyboard** (desktop-first): `Tab`/`Shift+Tab` field order Email → Password → Remember me
  → Forgot → Sign in; `Enter` submits from any field; `Space` toggles Remember me; `Esc`
  clears the inline error. Show-password toggle reachable and operable by keyboard.
- **Password managers** — supported via standard `autocomplete` tokens; no custom widgets
  that break autofill.
- **No hardware** — no camera/scanner/printer/mic on this screen (`N/A`).
- **Latency** — auth round-trip target < 1.5 s on broadband; button stays in spinner state so
  the user never double-submits (button disabled during flight; idempotent by design).

---

## 8. Business rules & edge cases
1. **R1 — Roles.** Only `owner`/`accountant` may obtain a web session; `staff` → `403 FORBIDDEN`.
2. **R2 — Deactivated user.** `staff.is_active = 0` → treated as invalid login (`403`),
   generic-ish message; existing sessions for that user are revoked on next `/auth/refresh`.
3. **R3 — Remember me.** ON → server sets a **persistent httpOnly, Secure, SameSite=Strict
   refresh cookie** (~30 d). OFF → **session cookie** (no `Max-Age`; dies on browser close).
   The short-lived **access token** (~15 min, see [api-conventions.md](../../../foundation/api-conventions.md) §2)
   is kept in memory only, never in `localStorage`.
4. **R4 — Silent refresh.** On app load with a valid refresh cookie, the app calls
   `POST /auth/refresh` to mint a fresh access token and **skips** the login form
   (auto-login). Access-token expiry mid-session triggers a transparent background refresh;
   only when refresh fails do we bounce to `/login`.
5. **R5 — Rate limiting / lockout.** Auth endpoints are stricter (api-conventions §10). After
   N failed attempts (server policy, e.g. 5 / 15 min) → `429 RATE_LIMITED` with `Retry-After`;
   the form disables Sign in and shows a countdown. Never leak which field was wrong.
6. **R6 — CSRF.** Refresh cookie is `SameSite=Strict`; state-changing calls also carry the
   `Authorization: Bearer` access token (double-submit) so a cookie alone cannot act.
7. **R7 — `next` allow-list.** `?next=` is only honored for **same-origin internal paths**
   (regex on known routes); external/absolute URLs are ignored (open-redirect guard) →
   fall back to Dashboard.
8. **R8 — Forgot password.** `/forgot-password` accepts an email and **always** shows the same
   "If that email exists, we've sent a reset link" message (no account enumeration). Reset
   link consumes a single-use, time-boxed token (Proposed `password_reset_tokens`).
9. **R9 — Concurrent sessions.** Multiple browsers allowed; logout on one does not kill others
   unless the user chooses "sign out everywhere" (Proposed, in Settings).
10. **R10 — Clock/skew** — access-token expiry checked with a small leeway; expired tokens
    never render protected data (guard blocks before fetch).

---

## 9. API interactions
| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Tap **Sign in** | `POST /auth/login` | exchange email+password → access token (body) + refresh cookie | Blocked offline (banner); no local auth on web |
| App load w/ refresh cookie | `POST /auth/refresh` | silent re-auth → new access token | Blocked offline; stay on `/login` |
| Access token ~expiry | `POST /auth/refresh` | transparent token renewal | On fail → `/login?next=<current>` |
| **Forgot password** submit | `POST /auth/forgot-password` *(Proposed in auth-api)* | email a reset link | Blocked offline |
| Reset link submit | `POST /auth/reset-password` *(Proposed)* | set new password via token | Blocked offline |
| **Logout** (from shell) | `POST /auth/logout` *(Proposed)* | revoke refresh cookie/session | Best-effort; clears client state regardless |

**`POST /auth/login` — key fields used here**
- Request: `{ "email": "owner@toyshop.example", "password": "…", "remember_me": true }`
  plus headers `X-Device-Id` (stable per-browser UUID), `X-Client-Version`.
- Response `data`: `{ "access_token", "expires_in", "staff": { "id", "name", "role",
  "photo_url" } }`; refresh token delivered as a **Set-Cookie** (httpOnly), not in the body.
- Errors used: `401 UNAUTHENTICATED` (bad creds), `403 FORBIDDEN` (staff role / inactive),
  `429 RATE_LIMITED` (+`Retry-After`), `400 VALIDATION_ERROR` (malformed email).

See API doc: [../../api/auth/auth-api.md](../../api/auth/auth-api.md). Envelope, headers, and
error codes: [api-conventions.md](../../../foundation/api-conventions.md).

---

## 10. Offline & sync behavior
- **Web is online-only for auth.** Nothing on this screen works offline; there is **no Drift
  outbox** on web (see [overview.md](../../../foundation/overview.md) §2 — Owner Web has no
  local DB, session only).
- No `sync_status` is written by this screen (it produces no domain rows).
- On losing connectivity **after** login, protected screens show their own offline banners;
  auth simply retries refresh when the network returns. Reference
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md)
  for the mobile outbox model this screen deliberately does **not** use.

---

## 11. Analytics & events
| Event | When | Properties |
|---|---|---|
| `web_login_viewed` | screen shown | `env`, `next_present` |
| `web_login_submitted` | Sign in tapped | `remember_me` |
| `web_login_succeeded` | 200 | `staff_id`, `role`, `duration_ms` |
| `web_login_failed` | 401/403/429 | `error_code` (no email/password values) |
| `web_login_locked` | 429 | `retry_after_s` |
| `web_silent_refresh` | auto-login | `success` |
| `web_forgot_password_requested` | forgot submit | — (no email in payload) |
| `web_logout` | logout | `staff_id` |
- Never log passwords, tokens, cookie values, or full emails (hash/omit).

---

## 12. Accessibility, localization & performance
- **A11y** — labeled inputs (`<label for>`), visible focus rings, error region is an
  `aria-live="polite"` region; show/hide toggle has `aria-pressed`; Sign in is a real
  `<button>`; color never the sole error signal (icon + text). WCAG AA contrast on the card.
- **Keyboard-first** — full flow completable without a mouse (§7).
- **Localization** — English default + regional; labels/errors localizable. Dates elsewhere
  are DD-MM-YYYY; `₹` grouping applies on data screens, not here.
- **Performance** — this is the web app's cold-start path: keep the login bundle lean;
  target first-paint < 1.5 s on broadband; silent-refresh decision (show form vs auto-login)
  resolved < 500 ms after cookie check.

---

## 13. Acceptance criteria
- [ ] Valid owner/accountant credentials → redirected to `?next=` or Dashboard; access token
      held in memory, refresh token only in an httpOnly cookie (never in `localStorage`).
- [ ] Staff-role or deactivated account → `403`, blocked, generic message, no data leaked.
- [ ] Wrong email vs wrong password produce the **same** message ("Incorrect email or password").
- [ ] Remember me ON → survives browser restart (persistent cookie); OFF → logged out on restart.
- [ ] With a valid refresh cookie, reloading the app auto-logs-in via `/auth/refresh` without
      showing the form.
- [ ] Access-token expiry mid-session refreshes transparently; refresh failure → `/login?next=`.
- [ ] After 5 failed attempts within the window → `429` + countdown; Sign in disabled until
      `Retry-After`.
- [ ] `?next=` only honors same-origin internal paths; external URLs fall back to Dashboard.
- [ ] Full flow operable by keyboard; error region announced by screen readers.
- [ ] Offline → calm banner, Sign in disabled, no crash; recovers when back online.
- [ ] Forgot-password returns the same message whether or not the email exists.

---

## 14. Related docs
- Foundation: [api-conventions.md](../../../foundation/api-conventions.md) ·
  [overview.md](../../../foundation/overview.md) ·
  [design-system.md](../../../foundation/design-system.md) ·
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md)
- API: [../../api/auth/auth-api.md](../../api/auth/auth-api.md)
- Sibling web screen (post-login landing): [../dashboard/dashboard-home.md](../dashboard/dashboard-home.md)
- Mobile counterpart (PIN): [../../../mobile/staff/auth/login.md](../../../mobile/staff/auth/login.md)
