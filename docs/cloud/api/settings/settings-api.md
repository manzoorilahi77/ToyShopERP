# Settings API

Owns the key–value `app_settings` store and backup configuration. Thin module: most
values are owner-tunable knobs (thresholds, duplicate sensitivity, backup schedule) that
other modules read. Incentive-rule CRUD lives in [incentives-api](../incentives/incentives-api.md);
GSTIN CRUD lives in [gst-api](../gst/gst-api.md); this module links to both from the
Settings screen but does not duplicate them.

Shared envelope, auth headers, error codes and pagination: [api-conventions](../../../foundation/api-conventions.md).

---

## 1. Overview
- **Callers:** Owner mobile ([reports/settings via owner app]) and primarily the web
  [Settings screen](../../web/settings/settings.md).
- **Risk addressed:** the owner must tune aging/reorder thresholds, duplicate sensitivity
  and backups **without a code release** (R4/R5, R2 threshold in `app_settings`).

## 2. Data model touched
- [`app_settings`](../../../foundation/data-model.md) (`key`, `value`, `updated_by`, `updated_at`) — source of truth.
- New keys ratified in [data-model §10.4](../../../foundation/data-model.md): `default_reorder_threshold`,
  `dup_text_ratio`, `backup_frequency`, `backup_time`, `backup_retention_days`,
  `backup_target`, `last_backup_at` (existing: `aging_threshold_days`, `dup_similarity_threshold`).
- Optional `backups` table (or object-store manifest) if backup history is kept.

## 3. Auth & permissions
- All endpoints require `Bearer` JWT, role **`owner`** (accountant read-only). Writes are
  audited via `app_settings.updated_by` + `audit_log`.

## 4. Endpoints

### `GET /settings`
- **Purpose** — return all `app_settings` as a typed object.
- **Auth** — owner or accountant.
- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `aging_threshold_days` | int | default 30 |
| `default_reorder_threshold` | int | fallback when product has none |
| `dup_similarity_threshold` | number | 0–1 image cosine cutoff |
| `dup_text_ratio` | number | 0–1 fuzzy-text cutoff |
| `backup_frequency` | enum `daily\|weekly\|off` | |
| `backup_time` | string `HH:mm` | shop-local |
| `backup_retention_days` | int | |
| `backup_target` | string | e.g. `s3://…` (secret parts masked) |
| `last_backup_at` | datetime\|null | |

```json
{ "ok": true, "data": {
  "aging_threshold_days": 60, "default_reorder_threshold": 3,
  "dup_similarity_threshold": 0.86, "dup_text_ratio": 0.85,
  "backup_frequency": "daily", "backup_time": "23:30",
  "backup_retention_days": 30, "backup_target": "s3://toyshop-backups/****",
  "last_backup_at": "2026-07-01T23:30:11+05:30" } }
```

### `PUT /settings`
- **Purpose** — upsert one or more settings (partial update).
- **Auth** — 🔒 owner. Body is a flat `{ key: value }` map; unknown keys → `422 BUSINESS_RULE`.
- **Request body**

| Field | Type | Required | Validation | Notes |
|---|---|---|---|---|
| `<setting_key>` | scalar | ≥1 key | key whitelisted; typed per key | thresholds ≥ 0; ratios 0–1; time `HH:mm` |

- **Response `200`** — the full settings object (as `GET`), reflecting the new values.
- **Errors** — `422 BUSINESS_RULE` (unknown/invalid key or out-of-range), `403 FORBIDDEN` (not owner).

```bash
curl -X PUT /v1/settings -H "Authorization: Bearer …" \
  -d '{"aging_threshold_days":90,"dup_similarity_threshold":0.9}'
```

### `POST /settings/backup`  *(Proposed — depends on backup infra)*
- **Purpose** — trigger an on-demand server snapshot now.
- **Auth** — 🔒 owner. **Idempotency** — `Idempotency-Key` to avoid duplicate runs.
- **Response `202`** — `{ "status": "queued", "job_id": "…" }`; updates `last_backup_at` on success.
- **Errors** — `409 CONFLICT` (backup already running), `503` (backup target unreachable).

## 5. Business logic & validation
- Values are stored as strings in `app_settings`; the API validates & coerces per-key types.
- Changing `aging_threshold_days`/`default_reorder_threshold` immediately affects
  [stock aging/low queries](../stock/stock-api.md) (no denormalized copy).
- Changing `dup_similarity_threshold`/`dup_text_ratio` affects the next
  [duplicate check](../duplicate-detection/duplicate-detection-api.md).
- Every write records `updated_by` and an `audit_log` row.

## 6. Sync & conflict handling
- N/A for the mobile offline path — settings are owner-only and edited online. Writes are
  blocked offline; last-write-wins by `updated_at` if two owner sessions race.

## 7. Edge cases & failure modes
1. Unknown key in `PUT` → reject the whole request (`422`), change nothing (atomic).
2. Out-of-range threshold (e.g. ratio > 1) → `422` with `field`.
3. Backup target credentials invalid → `POST /settings/backup` returns `503`; `last_backup_at` unchanged.
4. Accountant attempts a write → `403 FORBIDDEN`.

## 8. Performance & indexing
- Tiny table; cache the whole settings object in the API layer with a short TTL and bust
  on `PUT`. No pagination.

## 9. Related docs
- [web/settings](../../web/settings/settings.md) (primary consumer) ·
  [incentives-api](../incentives/incentives-api.md) · [gst-api](../gst/gst-api.md) ·
  [stock-api](../stock/stock-api.md) · [duplicate-detection-api](../duplicate-detection/duplicate-detection-api.md) ·
  [data-model §10.4](../../../foundation/data-model.md)
