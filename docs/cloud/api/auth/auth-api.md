# Auth API

> Base URL, response envelope, standard headers, error codes and pagination are defined
> once in [`api-conventions.md`](../../../foundation/api-conventions.md) and are **not**
> repeated here. All paths below are relative to `…/v1`.

---

## 1. Overview

The Auth module issues and refreshes the credentials every other endpoint depends on. It
serves three surfaces with two different login styles:

| Caller | Login style | Endpoint |
|---|---|---|
| **Staff App** (5–6 shop boys) | 4–6 digit **PIN** + `device_id`, photo-confirmed | `POST /auth/pin-login` |
| **Owner App / Web** (owner, accountant) | **email + password** | `POST /auth/login` |
| Any surface | token refresh, logout, device registration | `POST /auth/refresh`, `POST /auth/logout`, `POST /devices/register` |
| Owner (in-app) | **PIN re-verification** to unlock a `🔒` discount approval | `POST /auth/verify-pin` |

Business risks addressed (see [`requirements_and_prompt.md`](../../../requirements_and_prompt.md)):
- **Speed on the floor** — a 19-year-old on his 3rd day logs in with a PIN in ~2 seconds,
  photo-confirmed so he never picks the wrong staff account (R6 Staff/Login).
- **Owner-PIN gates money leaks** — discounts require a fresh owner PIN; `verify-pin`
  mints a short-lived `X-Owner-Pin-Token` so the owner isn't re-typing the PIN for every
  line (cross-cutting principle 5).
- **Auditable, device-traceable** — every session is bound to a `device_id`; offline
  sales carry the device that generated them.

## 2. Data model touched

Source of truth: [`data-model.md`](../../../foundation/data-model.md).

| Table | R/W | Role in this module |
|---|---|---|
| `staff` | read | `pin_hash` (bcrypt), `role`, `is_active`, `photo_url`, `name`. **Source of truth** for identity. |
| `devices` | read/write | upsert `device_id`, `staff_id`, `platform`, `app_flavor`, `push_token`, `last_seen`. |
| `audit_log` | write | `login`, `logout`, `pin.verify`, `auth.lockout` actions. |

### Proposed schema additions
These columns/tables are **not** in `data-model.md` and are required to fully implement
this module. Flagged for the schema owner:

| Addition | Where | Why |
|---|---|---|
| `email VARCHAR(150) UNIQUE NULL`, `password_hash CHAR(60) NULL` | `staff` | `POST /auth/login` is **email+password**; the canonical `staff` table only has `pin_hash`. Owner/accountant rows need email credentials. |
| `failed_pin_attempts SMALLINT DEFAULT 0`, `locked_until DATETIME NULL` | `staff` | PIN **lockout** after N failures. |
| `refresh_tokens(id, staff_id, token_hash CHAR(64) UNIQUE, device_id, expires_at, revoked_at NULL, created_at)` | new table | server-side **refresh rotation + logout revocation**; JWT refresh alone can't be revoked. |

Until these land, treat email login and lockout as `🧩 Derived` and confirm with the
schema owner.

## 3. Auth & permissions

| Endpoint | Auth to call | Roles | PIN |
|---|---|---|---|
| `POST /auth/pin-login` | none (public) | `staff`, `owner`, `accountant` | PIN is the credential |
| `POST /auth/login` | none (public) | `owner`, `accountant` | — |
| `POST /auth/refresh` | valid **refresh token** | any | — |
| `POST /auth/verify-pin` | Bearer access token | `owner` only | 🔒 PIN in body |
| `POST /auth/logout` | Bearer access token | any | — |
| `POST /devices/register` | Bearer access token | any | — |

**Token lifetimes**

| Token | TTL | Transport | Notes |
|---|---|---|---|
| Access (JWT) | ~15 min | `Authorization: Bearer` | claims: `sub`(staff_id), `role`, `device_id`, `exp`, `iat`, `jti` |
| Refresh | ~30 d | body / secure store | rotated on every `/auth/refresh`; old one revoked |
| `X-Owner-Pin-Token` | ~5 min | response header + body | single scope `discount:approve`, bound to `staff_id`+`device_id` |

PINs and passwords are **bcrypt**-hashed (`pin_hash`, `password_hash`, cost ≥ 10), never
returned. Auth endpoints are **rate-limited more strictly** than the rest of the API
(conventions §10).

---

## 4. Endpoints

### `POST /auth/pin-login`
- **Purpose** — staff/owner logs in with a numeric PIN on a known device; returns tokens
  + the profile card shown on the login screen.
- **Auth** — public. Throttled per `device_id` + per `staff_id`.
- **Idempotency** — N/A (login is naturally repeatable; no row created besides `devices`
  upsert + audit).
- **Path / query params** — none.
- **Request body**

| Field | Type | Required | Validation | Notes |
|---|---|---|---|---|
| `staff_id` | integer | yes\* | exists, `is_active=1` | \*either `staff_id` or `pin_login_code` |
| `pin` | string | yes | 4–6 digits | matched against `staff.pin_hash` (bcrypt) |
| `device_id` | string | yes | ≤ 64 chars, stable UUID | bound into the access token |
| `platform` | enum | no | `android\|ios\|web` | upserts `devices.platform` |
| `app_flavor` | enum | no | `staff\|owner\|web` | upserts `devices.app_flavor` |

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `access_token` | string | JWT, ~15 min |
| `refresh_token` | string | ~30 d |
| `expires_in` | integer | access TTL seconds (900) |
| `staff` | object | `{ id, name, photo_url, role, join_date }` — for login confirmation card |
| `device_registered` | boolean | true if `devices` row upserted |

```json
{ "ok": true,
  "data": {
    "access_token": "eyJhbGciOi…",
    "refresh_token": "rt_9f2c…",
    "expires_in": 900,
    "staff": { "id": 4, "name": "Ravi", "photo_url": "https://…/ravi.jpg",
               "role": "staff", "join_date": "2026-01-12" },
    "device_registered": true },
  "meta": { "request_id": "req_01H…" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | missing `pin`/`device_id`, malformed PIN |
| 401 | `UNAUTHENTICATED` | wrong PIN / unknown `staff_id` (generic message, no enumeration) |
| 403 | `FORBIDDEN` | `staff.is_active=0` (deactivated account) |
| 423 | `LOCKED` | too many failed attempts → `locked_until` in the future |
| 429 | `RATE_LIMITED` | brute-force throttle; honor `Retry-After` |

- **Example**

```bash
curl -X POST …/v1/auth/pin-login \
  -H 'Content-Type: application/json' -H 'X-Device-Id: dev-abc123' \
  -d '{ "staff_id": 4, "pin": "4821", "device_id": "dev-abc123",
        "platform": "android", "app_flavor": "staff" }'
```

---

### `POST /auth/login`
- **Purpose** — owner/accountant email+password login for the owner app and web dashboard.
- **Auth** — public. Strictly throttled.
- **Idempotency** — N/A.
- **Request body**

| Field | Type | Required | Validation | Notes |
|---|---|---|---|---|
| `email` | string | yes | email format | matched against `staff.email` *(proposed column)* |
| `password` | string | yes | ≥ 8 chars | bcrypt-compared to `staff.password_hash` *(proposed)* |
| `device_id` | string | no | ≤ 64 | web may omit; then session-only |
| `app_flavor` | enum | no | `owner\|web` | |

- **Response `200`** — same shape as `pin-login` (`access_token`, `refresh_token`,
  `expires_in`, `staff`). `staff.role` is `owner` or `accountant`.

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | missing email/password |
| 401 | `UNAUTHENTICATED` | wrong email/password (generic) |
| 403 | `FORBIDDEN` | account deactivated, or role is `staff` (must use PIN login) |
| 423 | `LOCKED` | lockout |
| 429 | `RATE_LIMITED` | throttle |

---

### `POST /auth/refresh`
- **Purpose** — exchange a valid refresh token for a new access token (+ rotated refresh).
- **Auth** — the refresh token itself (not the access token).
- **Idempotency** — **single-use**: a refresh token is consumed and rotated; replaying the
  old token fails (rotation detects token reuse → revoke the whole chain).
- **Request body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `refresh_token` | string | yes | validated against `refresh_tokens.token_hash` *(proposed)* |
| `device_id` | string | no | must match the token's bound device if present |

- **Response `200`** — `{ access_token, refresh_token, expires_in }`.

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 401 | `UNAUTHENTICATED` | expired / unknown / revoked refresh token |
| 403 | `FORBIDDEN` | token reuse detected → chain revoked, re-login required |

---

### `POST /auth/verify-pin` 🔒
- **Purpose** — owner re-verifies their PIN to unlock discount approvals; returns a
  short-lived elevated token consumed by [`POST /sales`](../sales/sales-api.md) and
  the [discount approval screen](../../../mobile/owner/approvals/discount-approval.md).
- **Auth** — Bearer access token, role `owner`.
- **Idempotency** — N/A (mints a fresh token each call).
- **Request body**

| Field | Type | Required | Validation | Notes |
|---|---|---|---|---|
| `owner_pin` | string | yes | 4–6 digits | bcrypt-compared to the caller's `pin_hash` |
| `scope` | string | no | default `discount:approve` | future-proofing for other gated actions |

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `owner_pin_token` | string | also returned in header `X-Owner-Pin-Token` |
| `expires_in` | integer | seconds (~300) |
| `scope` | string | granted scope |

```json
{ "ok": true,
  "data": { "owner_pin_token": "opt_5m_7Kd…", "expires_in": 300,
            "scope": "discount:approve" },
  "meta": { "request_id": "req_…" } }
```
Response also sets header `X-Owner-Pin-Token: opt_5m_7Kd…`.

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 401 | `UNAUTHENTICATED` | access token missing/expired |
| 403 | `FORBIDDEN` | caller role ≠ `owner`, or wrong `owner_pin` |
| 423 | `LOCKED` | PIN lockout after repeated failures |
| 429 | `RATE_LIMITED` | throttle |

Writes `audit_log` action `pin.verify`.

---

### `POST /auth/logout`
- **Purpose** — revoke the current refresh token (and optionally all device sessions).
- **Auth** — Bearer access token.
- **Idempotency** — safe to repeat (already-revoked → still `200`).
- **Request body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `refresh_token` | string | no | the token to revoke; if omitted, revoke the one bound to `device_id` |
| `all_devices` | boolean | no | default `false`; revoke every refresh token for this staff |

- **Response `200`** — `{ "revoked": true }`. Access token is left to expire naturally
  (≤ 15 min); refresh is revoked immediately. Writes `audit_log` action `logout`.

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 401 | `UNAUTHENTICATED` | no/expired access token |

---

### `POST /devices/register`
- **Purpose** — register/update the calling device for sync tracing and push
  notifications; called right after login and on push-token refresh.
- **Auth** — Bearer access token.
- **Idempotency** — upsert keyed on `device_id` (UNIQUE in `devices`); repeat = update.
- **Request body**

| Field | Type | Required | Validation | Notes |
|---|---|---|---|---|
| `device_id` | string | yes | ≤ 64, UNIQUE | client-generated stable UUID |
| `platform` | enum | yes | `android\|ios\|web` | |
| `app_flavor` | enum | yes | `staff\|owner\|web` | |
| `push_token` | string | no | ≤ 255 | FCM/APNs token |

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `device_id` | string | echoed |
| `staff_id` | integer | last logged-in staff bound |
| `last_seen` | string (ISO-8601) | server-set |

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | missing/invalid `platform` / `app_flavor` |
| 401 | `UNAUTHENTICATED` | no access token |

---

## 5. Business logic & validation
- **PIN verification** — constant-time bcrypt compare against `pin_hash`; never reveal
  whether it was the `staff_id` or the PIN that was wrong (return generic
  `UNAUTHENTICATED`).
- **Lockout** — on each failed PIN, increment `failed_pin_attempts` *(proposed)*; at ≥ 5
  set `locked_until = now + 15 min` and return `423 LOCKED`. Reset counter on success.
- **Access token claims** — `{ sub, role, device_id, jti, iat, exp }`. `device_id` in the
  token is cross-checked against the `X-Device-Id` header by downstream write endpoints.
- **Refresh rotation** — every `/auth/refresh` issues a new refresh token and revokes the
  presented one; reuse of a revoked token revokes the entire chain (theft detection).
- **Owner-PIN token** — a separate short-lived JWT with scope `discount:approve`, bound to
  `staff_id`+`device_id`; `POST /sales` accepts it via `X-Owner-Pin-Token` to authorize
  `discount_amount > 0` without a per-line PIN prompt.
- **Device upsert** — login and `/devices/register` both `INSERT … ON DUPLICATE KEY UPDATE`
  `devices` on `device_id`, refreshing `staff_id`, `last_seen`, `push_token`.

## 6. Sync & conflict handling
Auth is **not** a sync-replayable write, so `Idempotency-Key`/`client_uuid` do not apply.
Relevance to sync:
- The **`device_id`** minted/registered here is what every offline `sale`/`purchase`
  stamps into `stock_movements.device_id` and `sales.device_id` for traceability.
- The sync worker authenticates each `POST /sync/push` with the logged-in staff's access
  token + `X-Device-Id` (conventions §2). A `401` mid-sync triggers a silent `/auth/refresh`
  then retry; a `403`/revoked refresh surfaces a re-login prompt without dropping the
  outbox. See [`sync-and-conflict-resolution.md`](../../../foundation/sync-and-conflict-resolution.md).

## 7. Edge cases & failure modes
1. **Wrong PIN repeatedly** → `423 LOCKED` with `Retry-After`; owner can reset the staff
   PIN from [staff management](../../../mobile/owner/staff/staff-management.md).
2. **Deactivated staff still holds a valid access token** → downstream requests re-check
   `is_active`; a deactivated user is rejected `403` even before token expiry (short 15-min
   window bounds exposure).
3. **Clock skew on refresh** → tokens carry `iat/exp`; allow ±60 s leeway; large skew →
   client re-syncs time then retries.
4. **`device_id` collision / reinstall** → same `device_id` upserts (no dup row); a *new*
   `device_id` after reinstall creates a new `devices` row (old one ages out via `last_seen`).
5. **Owner-PIN token expiry mid-checkout** → `POST /sales` returns `403 FORBIDDEN` (PIN not
   verified); client re-calls `/auth/verify-pin` and resubmits — the sale `client_uuid` is
   unchanged so no duplicate results.
6. **Refresh-token theft** → rotation reuse-detection revokes the chain; both the attacker
   and the legitimate device are forced to re-login (fail-safe).
7. **Offline login** — the staff app validates the PIN against a **locally cached bcrypt
   hash** to unlock the app while offline; server tokens are obtained on next connectivity.
   (Client-side behavior; documented in [staff login](../../../mobile/staff/auth/login.md).)

## 8. Performance & indexing
- Volume is tiny (≤ ~10 users, a handful of logins/day) — the cost is bcrypt CPU, not I/O.
- Indexes relied on: `staff` PK, proposed `UNIQUE(email)`, `devices.device_id UNIQUE`,
  proposed `refresh_tokens.token_hash UNIQUE`.
- Keep bcrypt cost ≥ 10 but bounded so PIN login stays < ~250 ms on the API host.
- Rate-limit buckets per `device_id` and per `staff_id`; auth limits are stricter than the
  global limit (conventions §10). Lockout state is cheap (two columns on `staff`).

## 9. Related docs
- Screens: [staff/login](../../../mobile/staff/auth/login.md) ·
  [owner/login](../../../mobile/owner/auth/login.md) ·
  [web/login](../../web/auth/login.md) ·
  [owner/discount-approval](../../../mobile/owner/approvals/discount-approval.md)
- Sibling APIs: [sales-api](../sales/sales-api.md) (consumes `X-Owner-Pin-Token`) ·
  [sync-api](../sync/sync-api.md) (uses the session + `device_id`)
- Foundation: [api-conventions](../../../foundation/api-conventions.md) ·
  [data-model](../../../foundation/data-model.md) ·
  [sync-and-conflict-resolution](../../../foundation/sync-and-conflict-resolution.md)
