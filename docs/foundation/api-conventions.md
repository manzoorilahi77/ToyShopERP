# Foundation — API Conventions

Shared contract for **every** endpoint in `cloud/api/**`. API docs reference this file
instead of repeating the envelope, auth, error and pagination rules.

---

## 1. Basics
- **Base URL:** `https://<env>-api.toyshop.example/v1` (version pinned in path).
- **Format:** JSON only. `Content-Type: application/json; charset=utf-8`.
- **Money:** strings or numbers with 2 decimals, rupees. Server is authoritative on
  rounding (round-half-up to paise).
- **Time:** ISO-8601 with offset (`2026-07-02T19:45:12+05:30`). Server stores UTC;
  `occurred_at`/`sold_at` are business times sent by the client.
- **IDs:** server integer ids in responses; clients also send `client_uuid` for writes.

## 2. Auth
- **Login** returns a JWT **access token** (~15 min) + **refresh token** (~30 d).
  Header: `Authorization: Bearer <access>`.
- **Staff PIN login** → short-lived session bound to `device_id`.
- **Device token:** the sync worker authenticates with the logged-in staff's token; each
  request also sends `X-Device-Id: <device_id>`.
- **Roles:** `staff | owner | accountant`. Endpoint docs state allowed roles.
- **PIN-gated actions** (`🔒`, e.g. discount approve) require a fresh `owner_pin` in the
  body or an `X-Owner-Pin-Token` obtained from `POST /auth/verify-pin`.

## 3. Standard headers

| Header | Direction | Purpose |
|---|---|---|
| `Authorization: Bearer …` | req | auth |
| `X-Device-Id` | req | device tracing, sync |
| `X-Client-Version` | req | app version (for compat gates) |
| `Idempotency-Key` | req (writes) | = `client_uuid`; dedupes replays |
| `X-Request-Id` | both | trace id, echoed in responses & logs |

## 4. Response envelope

**Success:**
```json
{ "ok": true, "data": { … }, "meta": { "request_id": "…" } }
```
**List:**
```json
{ "ok": true, "data": [ … ],
  "meta": { "page": 1, "per_page": 50, "total": 214, "cursor": "eyJ…" } }
```
**Error:**
```json
{ "ok": false,
  "error": { "code": "VALIDATION_ERROR", "message": "supplier_id is required",
             "field": "supplier_id", "details": [ … ] },
  "meta": { "request_id": "…" } }
```

## 5. Error codes (canonical)

| HTTP | `error.code` | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | bad/missing field |
| 401 | `UNAUTHENTICATED` | missing/expired token |
| 403 | `FORBIDDEN` | role not allowed / PIN not verified |
| 404 | `NOT_FOUND` | resource missing |
| 409 | `CONFLICT` | version conflict, missing dependency (e.g. product not synced yet) |
| 409 | `DUPLICATE_IGNORED` | `client_uuid` already applied (treated as success by client) |
| 422 | `BUSINESS_RULE` | e.g. discount without approval, inactive GSTIN |
| 429 | `RATE_LIMITED` | throttled; honor `Retry-After` |
| 500 | `INTERNAL` | unexpected |

## 6. Idempotency & sync writes
- All create endpoints for `sale`, `purchase`, `stock_adjustment`, `product` accept an
  `Idempotency-Key` (= `client_uuid`). Repeat with the same key → same result, no
  duplicate row (returns `DUPLICATE_IGNORED` or the original resource).
- Bulk offline replay goes through `POST /sync/push` (see [api/sync](../cloud/api/sync/sync-api.md)).

## 7. Pagination, filtering, sorting
- **Cursor** pagination for large ledgers (`?cursor=…&per_page=50`); page-based allowed
  for small lists (`?page=1&per_page=50`).
- **Filtering:** explicit query params (`?from=2026-06-01&to=2026-06-30&staff_id=4&gstin_id=1`).
- **Sorting:** `?sort=sold_at&order=desc`. Whitelist sortable fields per endpoint.
- **Field selection / export:** ledger endpoints accept `?format=json|csv|xlsx`.

## 8. Filtering conventions for reports
- Date ranges are inclusive `from`/`to` on the entity's business date.
- GST endpoints take `gstin_id` + `period=YYYY-MM` or `period=YYYY-Qn`.
- Aging/low-stock thresholds default from `app_settings`, overridable via query.

## 9. Versioning & deprecation
- Breaking changes → new path version (`/v2`). Additive fields are non-breaking.
- Deprecated fields flagged in `meta.deprecations`.

## 10. Rate limiting & security
- Per-device + per-token limits; `429` + `Retry-After`. Auth endpoints stricter.
- All traffic HTTPS. PINs bcrypt-hashed, never returned. Image uploads virus/size-checked.
- Audit-sensitive actions write `audit_log` (see [data-model.md](data-model.md)).

## 11. Related docs
- [data-model.md](data-model.md) · [sync-and-conflict-resolution.md](sync-and-conflict-resolution.md)
- every file under [../cloud/api/](../cloud/api/)
