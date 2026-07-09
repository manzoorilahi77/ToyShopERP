# Suppliers API

> Base URL, envelope, headers, error codes and pagination live in
> [`api-conventions.md`](../../../foundation/api-conventions.md) — referenced, not repeated.
> Paths are relative to `…/v1`.

---

## 1. Overview

Suppliers are the party products are bought from. Because products arrive with **no
barcodes** and only a supplier name to go by, `supplier_id` is a **mandatory** scoping
field on every product ([`products-api`](../products/products-api.md), R2) and on every
purchase.

The one GST-critical attribute here is the supplier's **`gstin`**: it is *optional*, but a
**missing supplier GSTIN means an incomplete Input Tax Credit (ITC) claim** — the
reconciliation view flags it so the owner can chase the supplier before filing
([`requirements_and_prompt.md`](../../../requirements_and_prompt.md) R4 GST flow).

| Caller | Uses |
|---|---|
| **Owner App** | select/add supplier during [new purchase](../../../mobile/owner/purchase/new-purchase.md). |
| **Owner Web** | manage suppliers, view supplier-wise purchase ledger + ITC-risk flags. |
| **Catalog** | `supplier_id` lookups when creating products. |

This module is **not** sync-replayable in the offline outbox sense — suppliers are created
by the owner (usually online). It carries no `client_uuid`.

## 2. Data model touched

Source of truth: [`data-model.md`](../../../foundation/data-model.md).

| Table | R/W | Notes |
|---|---|---|
| `suppliers` | read/write | `name` NOT NULL, `gstin` **nullable** (missing → ITC-risk flag), `phone`, `address`, `is_active`. Index `idx_supplier_name`. |
| `products` | read | count/link products per supplier (referential integrity on deactivate). |
| `purchases` | read | supplier-wise rollups + missing-GSTIN reconciliation flag (`supplier_gstin`). |
| `audit_log` | write | `supplier.create`, `supplier.update`, `supplier.deactivate`. |

## 3. Auth & permissions

| Endpoint | Auth | Roles |
|---|---|---|
| `GET /suppliers` | Bearer | all |
| `GET /suppliers/{id}` | Bearer | all |
| `POST /suppliers` | Bearer | `owner`, `accountant` |
| `PATCH /suppliers/{id}` | Bearer | `owner`, `accountant` |
| `POST /suppliers/{id}/deactivate` | Bearer | `owner` |

---

## 4. Endpoints

### `GET /suppliers`
- **Purpose** — list/search suppliers for the purchase-entry picker and the supplier ledger.
- **Auth** — Bearer, all roles. **Idempotency** — N/A (read).
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `q` | query | string | no | — | search on `name` (prefix/`LIKE`, `idx_supplier_name`) and `phone` |
| `is_active` | query | boolean | no | `true` | `false`/`all` to include deactivated |
| `has_gstin` | query | boolean | no | — | `false` surfaces suppliers with missing GSTIN (ITC-risk) |
| `sort` | query | enum | no | `name` | `name\|created_at` |
| `order` | query | enum | no | `asc` | `asc\|desc` |
| `page` / `per_page` | query | integer | no | `1` / `50` | page-based |

- **Response `200`** — list envelope; each item:

| Field | Type | Notes |
|---|---|---|
| `id` | integer | |
| `name` | string | |
| `gstin` | string\|null | 15-char; **null → ITC-risk** |
| `phone` | string\|null | |
| `address` | string\|null | |
| `is_active` | boolean | |
| `product_count` | integer | products linked (advisory) |
| `itc_risk` | boolean | computed: `gstin IS NULL` |

```json
{ "ok": true,
  "data": [
    { "id": 3, "name": "Sunrise Toys Distributors", "gstin": "33ABCDE1234F1Z5",
      "phone": "+91 98765 43210", "address": "Chennai", "is_active": true,
      "product_count": 42, "itc_risk": false },
    { "id": 7, "name": "Local Cash Vendor", "gstin": null, "phone": null,
      "address": null, "is_active": true, "product_count": 3, "itc_risk": true }
  ],
  "meta": { "page": 1, "per_page": 50, "total": 18 } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | bad `sort`/`order` |
| 401 | `UNAUTHENTICATED` | no token |

---

### `GET /suppliers/{id}`
- **Purpose** — supplier detail + quick purchase summary.
- **Auth** — Bearer, all roles. **Idempotency** — N/A.
- **Path params** — `id` (integer, required).
- **Response `200`** — all `suppliers` columns + `itc_risk`, `product_count`, and:

| Field | Type | Notes |
|---|---|---|
| `purchase_summary` | object | `{ total_purchases, total_value, last_invoice_date }` (from `purchases`) |
| `created_at` / `updated_at` | string(ISO) | |

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 404 | `NOT_FOUND` | no such supplier |

---

### `POST /suppliers`
- **Purpose** — add a new supplier (often inline during purchase entry).
- **Auth** — Bearer; `owner`/`accountant`.
- **Idempotency** — N/A (owner-created online). Server dedupes on near-duplicate `name`
  (advisory warning, not a hard block).
- **Request body**

| Field | Type | Required | Validation | Notes |
|---|---|---|---|---|
| `name` | string | **yes** | 1–150 | |
| `gstin` | string | no | 15-char format `22AAAAA0000A1Z5` if present | **null allowed** → ITC-risk flag downstream |
| `phone` | string | no | ≤ 20 | |
| `address` | string | no | ≤ 255 | |

- **Response `201`** — created supplier object (as `GET /suppliers/{id}`), plus
  `warnings` array (e.g. `["gstin_missing"]`, `["similar_name:Sunrise Toys"]`).

```json
{ "ok": true,
  "data": { "id": 19, "name": "Bright Wheels Pvt Ltd", "gstin": "29AABCB1234C1Z2",
            "phone": "+91 90000 11111", "address": "Bengaluru", "is_active": true,
            "warnings": [] },
  "meta": { "request_id": "req_…" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | missing `name`; malformed `gstin` |
| 401 | `UNAUTHENTICATED` | no token |
| 403 | `FORBIDDEN` | role not allowed |
| 409 | `CONFLICT` | `gstin` already belongs to another supplier (UNIQUE if enforced) |

---

### `PATCH /suppliers/{id}`
- **Purpose** — edit supplier fields; the common case is **adding a GSTIN later** to clear
  an ITC-risk flag.
- **Auth** — Bearer; `owner`/`accountant`. **Idempotency** — natural (partial update).
- **Path params** — `id` (integer, required).
- **Request body** — any subset of `name`, `gstin`, `phone`, `address`. Same validation as
  create; setting `gstin` clears `itc_risk` on future reconciliations.
- **Response `200`** — updated supplier object. Writes `audit_log` (`supplier.update`,
  before/after).

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | malformed `gstin` |
| 404 | `NOT_FOUND` | no such supplier |
| 409 | `CONFLICT` | `gstin` collides with another supplier |

> **Note:** editing a supplier's `gstin` does **not** rewrite historical
> `purchases.supplier_gstin` (those are snapshots for ITC on the invoice they were entered
> against). New purchases pick up the corrected GSTIN.

---

### `POST /suppliers/{id}/deactivate`
- **Purpose** — soft-delete (`is_active=0`); supplier stays for historical purchase ledgers.
- **Auth** — Bearer; `owner` only.
- **Idempotency** — safe to repeat.
- **Request body** — `{ "reason": string? }`.
- **Response `200`** — `{ "id": 7, "is_active": false, "warnings": [] }`.

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 404 | `NOT_FOUND` | no such supplier |
| 422 | `BUSINESS_RULE` | (advisory) supplier still has **active products** → response includes `warnings:["has_active_products"]`; deactivation proceeds but those products can no longer be re-purchased under this supplier until reactivated |

---

## 5. Business logic & validation
- **GSTIN format** — when present, validate the 15-char pattern (`state_code`(2) + PAN(10) +
  entity/checksum(3)); `state_code` matters for CGST/SGST vs IGST downstream in
  [purchases](../purchases/purchases-api.md) and GST filing.
- **GSTIN optional by design** — many small local vendors have none; the system must not
  block purchases from them. Missing `gstin` sets `itc_risk=true` (computed) and drives the
  reconciliation flag, **not** a validation error.
- **Name near-duplicate guard** — on create, fuzzy-match `name` (`idx_supplier_name` +
  Levenshtein) and return an advisory `warnings:["similar_name:…"]`; never a hard block
  (unlike products, supplier dedupe is soft).
- **Referential integrity** — deactivation is soft; `products.supplier_id` and
  `purchases.supplier_id` FKs remain valid so ledgers/audit stay intact.
- **Audit** — create/update/deactivate write `audit_log` with before/after JSON.

## 6. Sync & conflict handling
Suppliers are **not** part of the offline sale/purchase outbox and carry no `client_uuid`;
they are created online by the owner. If a supplier is added inline during **offline**
purchase entry, the client generates it in the local cache and pushes it ahead of the
purchase in FIFO order (like products) — but the canonical `suppliers` table has no
`client_uuid`, so:

> **Proposed schema addition:** add `client_uuid CHAR(36) UNIQUE NULL` to `suppliers` **if**
> offline supplier creation is required. Until then, treat inline offline supplier creation
> as `⚠️ Risk`: the client must create the supplier server-side first (online) before the
> offline purchase can reference it, or the purchase push returns `409 CONFLICT` (missing
> dependency) and retries after the supplier syncs.

Attribute edits resolve **last-write-wins** by `updated_at` (sync doc §5).

## 7. Edge cases & failure modes
1. **Missing GSTIN at filing time** → surfaced in the GST reconciliation view
   ([web/gst-filing](../../web/gst/gst-filing.md)); owner `PATCH`es the GSTIN, then
   re-exports. Historical `purchases.supplier_gstin` snapshots are unchanged.
2. **GSTIN typo/collision** → `409 CONFLICT`; owner corrects. State code drives tax split,
   so a wrong `state_code` would misclassify IGST vs CGST/SGST — validated on entry.
3. **Deactivating a supplier with active products** → allowed with warning; products remain
   in catalog and sellable, just not re-purchasable under that supplier until reactivated.
4. **Two suppliers, same physical vendor, different names** → advisory near-duplicate
   warning on create; merge is a manual owner action (not auto).
5. **Reactivation** → `PATCH is_active=true` (or a dedicated reactivate) restores
   selectability without touching history.

## 8. Performance & indexing
- Tiny table (tens of rows). `idx_supplier_name` covers search; PK covers detail.
- `product_count` / `purchase_summary` are computed via indexed joins
  (`products.idx_supplier`, `purchases` supplier FK) — cheap at this volume; cache if the
  supplier ledger grows large.
- No pagination pressure; page-based default (50) is ample.

## 9. Related docs
- Screens: [owner/new-purchase](../../../mobile/owner/purchase/new-purchase.md) ·
  [web/purchase-ledger](../../web/purchases/purchase-ledger.md) ·
  [web/gst-filing](../../web/gst/gst-filing.md)
- Sibling APIs: [products-api](../products/products-api.md) ·
  [purchases-api](../purchases/purchases-api.md) · [gst-api](../gst/gst-api.md)
- Foundation: [data-model](../../../foundation/data-model.md) ·
  [api-conventions](../../../foundation/api-conventions.md)
