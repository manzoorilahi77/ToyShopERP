# Duplicate Detection API

> Base URL, auth, the response envelope, error codes and pagination are defined once in
> [api-conventions.md](../../../foundation/api-conventions.md) — referenced, not repeated.
> The algorithm and thresholds are specified in
> [duplicate-detection.md](../../../foundation/duplicate-detection.md); this doc is the REST
> surface for it.

---

## 1. Overview

Because products arrive with **no barcodes / no SKUs**, the same toy is easily entered twice
under slightly different names — splitting stock counts and confusing pricing (R2, the top
data-quality risk). This module:

- **`POST /products/check-duplicate`** — run *before* saving a new product; returns ranked
  candidate matches (image + fuzzy text) so the app can prompt *"same item?"*.
- **`GET /duplicate-review-queue`** — the web review queue of ambiguous cases.
- **`POST /duplicate-review-queue/{id}/resolve`** — human decision; on `confirmed_duplicate`
  it **merges** — routing stock to the existing product.

Callers: Owner catalog add + purchase entry (check-duplicate), Owner Web catalog review
queue ([web/catalog](../../web/catalog/product-catalog-management.md)). Mirrors the layered
algorithm (cosine image similarity + Levenshtein/token-set text, scoped by category+supplier).

---

## 2. Data model touched

Canonical names from [data-model.md](../../../foundation/data-model.md):

| Table | Role | R/W |
|---|---|---|
| `products` | `image_embedding` (vector), `name`, `category_id`, `supplier_id`, `internal_qr_code` | read (match) + write (merge target) |
| `duplicate_review_queue` | `new_product_id`, `matched_existing_product_id`, `similarity_score`, `match_type`, `status`, `reviewed_by`, `reviewed_at` | read + write |
| `app_settings` | `dup_similarity_threshold` (default `0.86`), text ratio threshold | read |
| `stock_movements` | merge routes stock via new append-only movements (never edits) | write (merge) |
| `audit_log` | resolve/merge actions | write |

**Sources:** `products.image_embedding` + `products.name` are matched against; the
`duplicate_review_queue` is the authoritative record of ambiguous cases and their resolution.

---

## 3. Auth & permissions

| Endpoint | staff | owner | accountant | Notes |
|---|---|---|---|---|
| `POST /products/check-duplicate` | 🧩 | ✅ | ✅ | staff flavor uses on-device check first; server re-check on sync |
| `GET /duplicate-review-queue` | ❌ | ✅ | ✅ | web review queue |
| `POST /duplicate-review-queue/{id}/resolve` | ❌ | ✅ | 🧩 | merge routes stock — owner decision |

JWT + `X-Device-Id`. Resolve writes `audit_log`.

---

## 4. Endpoints

### `POST /products/check-duplicate`

- **Purpose** — given a candidate product (image **or** precomputed embedding + name +
  mandatory category/supplier), return ranked existing-product candidates with similarity
  scores and match type. Runs **before** the product is saved.
- **Auth** — owner/accountant (staff 🧩 via on-device + sync re-check).
- **Idempotency** — safe to repeat (read-only scoring; no row written). No `client_uuid`.
- **Path / query params** — none.
- **Request body**

| Field | Type | Required | Validation | Notes |
|---|---|---|---|---|
| `name` | string | yes | ≤ 150 | candidate name (drives fuzzy text layer) |
| `category_id` | int | yes | exists | **mandatory scoping** (R2) — narrows search |
| `supplier_id` | int | yes | exists | **mandatory scoping** (R2) |
| `image_embedding` | float[] | conditional | 256–512 dims | send this **or** `image_base64`/`image_url` |
| `image_base64` | string | conditional | ≤ size limit | server computes the embedding |
| `image_url` | string | conditional | reachable | already-uploaded image |
| `limit` | int | no | ≤ 20; default `5` | max candidates returned |
| `threshold` | decimal | no | 0–1; default `app_settings.dup_similarity_threshold` | override image cutoff |

> Provide **exactly one** image input (`image_embedding` | `image_base64` | `image_url`), or
> none (text-only check). Missing all image inputs → text-only candidates.

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `has_strong_match` | bool | any candidate ≥ threshold on image, or ≥ text ratio |
| `decision_hint` | enum | `save_new \| prompt_same_item \| enqueue_review` (mirrors algorithm) |
| `candidates[].product_id` | int | existing product |
| `candidates[].name` | string | |
| `candidates[].image_url` | string | for side-by-side prompt |
| `candidates[].similarity_score` | decimal(0–1) | best of image/text for ranking |
| `candidates[].image_score` | decimal / null | cosine similarity |
| `candidates[].text_score` | decimal / null | Levenshtein/token-set ratio |
| `candidates[].match_type` | enum | `image \| text \| both` |
| `candidates[].on_hand` | int | current stock of the existing product (context for merge) |

```json
// Request
{ "name": "Red Racer Cars", "category_id": 3, "supplier_id": 8,
  "image_embedding": [0.012, -0.98, 0.33, "…512 dims…"] }
// Response 200
{ "ok": true, "data": {
  "has_strong_match": true, "decision_hint": "prompt_same_item",
  "candidates": [
    { "product_id": 141, "name": "Red Racer Car",
      "image_url": "https://cdn.toyshop.example/p/141.jpg",
      "similarity_score": 0.9123, "image_score": 0.9123, "text_score": 0.90,
      "match_type": "both", "on_hand": 4 }
  ]
}, "meta": { "request_id": "req_d10" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | scored (even with zero candidates) |
| 400 | `VALIDATION_ERROR` | missing `name`/`category_id`/`supplier_id`; >1 image input; bad embedding length |
| 403 | `FORBIDDEN` | role not allowed |
| 404 | `NOT_FOUND` | `category_id`/`supplier_id` does not exist |
| 413 | `VALIDATION_ERROR` | image exceeds size limit (mapped to 400 `VALIDATION_ERROR` per conventions) |

---

### `GET /duplicate-review-queue`

- **Purpose** — list ambiguous duplicate cases for human review (web catalog).
- **Auth** — owner/accountant.
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `status` | query | enum | no | `pending` | `pending \| confirmed_duplicate \| confirmed_unique` |
| `match_type` | query | enum | no | — | `image \| text \| both` |
| `min_score` | query | decimal | no | — | filter by `similarity_score` |
| `category_id` | query | int | no | — | scope |
| `sort` | query | enum | no | `similarity_score` | `similarity_score \| created_at` |
| `order` | query | enum | no | `desc` | highest-risk first |
| `page` / `per_page` | query | int | no | `1` / `50` | |

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `data[].id` | int | queue row id |
| `data[].similarity_score` | decimal(0–1) | |
| `data[].match_type` | enum | `image \| text \| both` |
| `data[].status` | enum | |
| `data[].new_product` | object | `{ product_id, name, image_url, on_hand, created_at }` (candidate) |
| `data[].matched_existing_product` | object | `{ product_id, name, image_url, on_hand }` (suspected original) |
| `data[].created_at` | datetime | |
| `data[].reviewed_by` | int / null | |
| `data[].reviewed_at` | datetime / null | |

```json
{ "ok": true, "data": [
  { "id": 33, "similarity_score": 0.8840, "match_type": "both", "status": "pending",
    "new_product": { "product_id": 220, "name": "Red Racer Cars",
      "image_url": "https://cdn.toyshop.example/p/220.jpg", "on_hand": 6,
      "created_at": "2026-07-02T18:00:00+05:30" },
    "matched_existing_product": { "product_id": 141, "name": "Red Racer Car",
      "image_url": "https://cdn.toyshop.example/p/141.jpg", "on_hand": 4 },
    "created_at": "2026-07-02T18:00:01+05:30", "reviewed_by": null, "reviewed_at": null }
], "meta": { "page": 1, "per_page": 50, "total": 3, "request_id": "req_d20" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | ok |
| 403 | `FORBIDDEN` | staff role |

---

### `POST /duplicate-review-queue/{id}/resolve`

- **Purpose** — record the human decision. `confirmed_unique` keeps both products (and stops
  future nagging for that pair). `confirmed_duplicate` **merges**: routes the new product's
  stock to the existing product and deactivates the duplicate.
- **Auth** — owner (accountant 🧩).
- **Idempotency** — resolving an already-resolved row with the **same** decision returns
  `200` no-op; a **conflicting** re-resolve → `409 CONFLICT`.
- **Path / query params** — `id` (path, int, required).
- **Request body**

| Field | Type | Required | Validation | Notes |
|---|---|---|---|---|
| `resolution` | enum | yes | `confirmed_duplicate \| confirmed_unique` | |
| `keep_product_id` | int | conditional | one of the pair | for `confirmed_duplicate`: the **survivor** (usually the existing original) |
| `merge_strategy` | enum | no | `move_stock \| move_stock_and_prices`; default `move_stock` | how to route data on duplicate |
| `note` | string | no | ≤ 255 | audit reason |

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `id` | int | queue row |
| `status` | enum | new status |
| `resolution` | enum | echoed |
| `merged` | object / null | present on duplicate: `{ kept_product_id, deactivated_product_id, moved_on_hand, movements_created }` |
| `reviewed_by` | int | staff id |
| `reviewed_at` | datetime | |

```json
// Request (merge the new dup into the existing original)
{ "resolution": "confirmed_duplicate", "keep_product_id": 141,
  "merge_strategy": "move_stock", "note": "Same toy, plural typo" }
// Response 200
{ "ok": true, "data": {
  "id": 33, "status": "confirmed_duplicate", "resolution": "confirmed_duplicate",
  "merged": { "kept_product_id": 141, "deactivated_product_id": 220,
              "moved_on_hand": 6, "movements_created": 2 },
  "reviewed_by": 1, "reviewed_at": "2026-07-02T20:30:00+05:30" },
  "meta": { "request_id": "req_d30" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | resolved (or idempotent no-op) |
| 400 | `VALIDATION_ERROR` | bad `resolution`; `keep_product_id` not in the pair on duplicate |
| 403 | `FORBIDDEN` | role not owner/accountant |
| 404 | `NOT_FOUND` | no such queue row |
| 409 | `CONFLICT` | already resolved with a different decision |
| 422 | `BUSINESS_RULE` | `confirmed_duplicate` without `keep_product_id`; survivor is inactive |

---

## 5. Business logic & validation

**Matching (mirrors [duplicate-detection.md](../../../foundation/duplicate-detection.md)).**
1. **Image layer** — cosine similarity between the candidate `image_embedding` and existing
   `products.image_embedding`, brute-force < 10k SKUs (ANN at scale). Threshold from
   `app_settings.dup_similarity_threshold` (default `0.86`).
2. **Text layer** — normalize name (lowercase, trim, singularize, strip punctuation),
   Levenshtein / token-set ratio **scoped to the same `category_id` + `supplier_id`**;
   candidate if ratio ≥ `0.85`.
3. **Combine** — union by `product_id`, keep best score, set `match_type ∈ image|text|both`.
4. **Decision hint:** none → `save_new`; one strong match → `prompt_same_item`; multiple /
   unsure → `enqueue_review` (creates a `duplicate_review_queue` row on save).

**Merge on `confirmed_duplicate` (transactional).**
```
BEGIN
  survivor  = keep_product_id           (existing original)
  duplicate = the other product in the pair
  moved = on_hand(duplicate)  = SUM(quantity_delta) over duplicate
  IF moved != 0:
     INSERT stock_movements(product=duplicate, adjustment, −moved, note='merge → survivor')
     INSERT stock_movements(product=survivor,  return_in,  +moved, note='merge ← duplicate')
  merge_strategy='move_stock_and_prices' → also copy latest cost/selling price if survivor stale
  UPDATE products SET is_active=0 WHERE id = duplicate     -- soft delete, ledgers intact
  UPDATE duplicate_review_queue SET status='confirmed_duplicate', reviewed_by, reviewed_at
  INSERT audit_log(action='duplicate.merge', before/after)
COMMIT
```
Stock is moved by **appending offsetting movements** (never editing history) — consistent
with the event-sourced model. Future scans of the duplicate's `internal_qr_code` are
redirected to the survivor 🧩.

**`confirmed_unique`** sets status and records the pair so the algorithm **suppresses future
prompts** for that specific (new, matched) pair — two genuinely different look-alikes stop
nagging.

**Validation.** `name` + `category_id` + `supplier_id` mandatory (scoping). On resolve,
`keep_product_id` must be one of the pair and active.

---

## 6. Sync & conflict handling

- **`check-duplicate` is stateless scoring** — safe to call repeatedly; no idempotency key.
- **Offline entry:** the staff/owner app runs the duplicate check **on-device** against the
  local catalog cache; on sync, the server **re-checks** against the full catalog and can
  still enqueue a `duplicate_review_queue` row (a product created offline may collide with one
  created on another device). See
  [duplicate-detection.md §6](../../../foundation/duplicate-detection.md) and
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md).
- **Merge uses append-only movements**, so it composes safely with concurrent offline sales of
  either product — all deltas still sum correctly after reconcile.

---

## 7. Edge cases & failure modes

1. **Two genuinely different look-alike toys.** Review queue → `confirmed_unique` stops
   future false prompts for that pair.
2. **Duplicate created on two devices offline.** Both sync; server re-check enqueues a review
   row; merge consolidates stock.
3. **Merge survivor has open offline sales for the duplicate.** Sales still apply (append
   `sale_out` on the duplicate); the merge's offsetting movements keep both products'
   reconciled stock correct; net stock lands on the survivor 🧩.
4. **Concurrent resolve of the same queue row.** First wins; second with a different decision
   → `409 CONFLICT`; same decision → idempotent `200`.
5. **Embedding missing (legacy product).** Falls back to text-only matching; a re-embed job
   backfills `image_embedding` when the primary image is (re)uploaded.
6. **Threshold tuned by owner.** `app_settings.dup_similarity_threshold` change takes effect
   immediately (no release) — higher = fewer prompts, more risk; lower = more prompts.

---

## 8. Performance & indexing

| Query | Approach / index |
|---|---|
| image similarity | in-memory brute-force cosine < 10k SKUs; ANN (FAISS-like sidecar) at scale |
| text pre-filter | `products.ft_name` FULLTEXT + app-side Levenshtein on the shortlist |
| scope narrowing | `products.idx_cat`, `idx_supplier` (mandatory category+supplier shrinks the set) |
| review queue | filter `status` (+ `created_at`), small table |

- Mandatory `category_id`+`supplier_id` scoping is the main performance lever — it turns a
  full-catalog scan into a small shortlist before scoring.
- `check-duplicate` latency budget is interactive (product-add flow); precompute embeddings
  on image upload so the check only compares vectors.

---

## 9. Related docs

- Foundation: [duplicate-detection.md](../../../foundation/duplicate-detection.md) (algorithm) ·
  [data-model.md](../../../foundation/data-model.md) ·
  [api-conventions.md](../../../foundation/api-conventions.md) ·
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md)
- Sibling APIs: [products-api](../products/products-api.md) (create/edit products) ·
  [stock-api](../stock/stock-api.md) (merge routes stock movements)
- Screens: [web/catalog](../../web/catalog/product-catalog-management.md) (review queue) ·
  [owner/catalog](../../../mobile/owner/catalog/product-catalog-management.md) ·
  [staff/product-search-browse](../../../mobile/staff/catalog/product-search-browse.md)
