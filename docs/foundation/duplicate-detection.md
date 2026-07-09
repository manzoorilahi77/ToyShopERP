# Foundation — Duplicate Detection & Exact Retrieval

Implements **Requirement 2** (and supports R3). Because products have **no barcodes/SKUs**,
duplicate catalog entries are the top data-quality risk: the same toy entered twice under
slightly different names splits stock counts and confuses pricing. This service adds
layered safeguards at entry, and fast unambiguous retrieval while selling.

---

## 1. Two problems, one service

| Problem | Where | Technique |
|---|---|---|
| **Prevent duplicates at entry** | add product (owner catalog, purchase entry) | image similarity + fuzzy text + mandatory category/supplier |
| **Retrieve the exact item fast while selling** | staff new-sale/browse | QR → quick-pick → category grid → fuzzy search → confirm card |

---

## 2. Duplicate prevention at entry (R2-A)

Runs **before** a new product is saved. Three layers, combined:

### Layer 1 — Image similarity
- On capture, compute an **image embedding** (vector) with a lightweight model
  (e.g. MobileNet/CLIP-mobile on-device, or server-side on upload).
- Compare against existing `products.image_embedding` via **cosine similarity**.
- If `max_similarity ≥ threshold` (default `0.86`, in `app_settings.dup_similarity_threshold`),
  prompt: *"This looks similar to **[existing product]** — is this the same item?"*
  with both photos side by side.

### Layer 2 — Fuzzy text match
- Normalize `name` (+ `supplier` name): lowercase, trim, singularize, strip punctuation.
- Compute **Levenshtein / token-set ratio** against existing products **scoped to the same
  category + supplier**. Catches "Red Racer Car" vs "Red Racer Cars".
- If ratio ≥ `0.85`, raise a text-match candidate.

### Layer 3 — Mandatory scoping fields
- `category_id` and `supplier_id` are **required** (see [data-model.md](data-model.md)) —
  they narrow the search space and sharply improve match precision.

### Combine & decide
```
candidates = image_matches ∪ text_matches   (dedupe by product_id, keep best score)
if none            → save as new product
if strong single   → inline prompt "same item? [Yes, add stock] [No, it's new]"
if multiple/unsure  → save + enqueue duplicate_review_queue(status='pending')
```
- **Yes, same item** → do NOT create a new product; route the quantity to the existing
  product (add stock / correct price) — this is the win.
- **No, it's new** → create; record `confirmed_unique` so we don't nag again.
- **Ambiguous** → create provisionally + `duplicate_review_queue` row for the web review
  queue ([web/catalog](../cloud/web/catalog/product-catalog-management.md)).

---

## 3. Storage & matching internals
- `products.image_embedding`: JSON array of floats (e.g. 256–512 dims), or MySQL 8
  `VECTOR` column if available; otherwise a sidecar vector store (FAISS/pgvector-like)
  keyed by product_id. Similarity search is ANN for scale, brute-force is fine < 10k SKUs.
- Recompute embeddings if the primary image changes.
- Text index: `products.name FULLTEXT` for pre-filtering + app-side Levenshtein for the
  final score.
- Thresholds live in `app_settings` so the owner can tune sensitivity without a release.

## 4. API surface
See [api/duplicate-detection](../cloud/api/duplicate-detection/duplicate-detection-api.md):
- `POST /products/check-duplicate` — body: candidate image (or embedding) + name +
  category_id + supplier_id → returns ranked candidates with scores + match_type.
- `GET /duplicate-review-queue?status=pending` — web review queue.
- `POST /duplicate-review-queue/{id}/resolve` — `confirmed_duplicate | confirmed_unique`
  (+ merge action when duplicate).

## 5. Exact retrieval while selling (R2-B, R3)
Ordered by speed; each is a fallback for the previous. Detailed UX in
[staff/new-sale](../mobile/staff/sales/new-sale.md) and
[staff/product-search-browse](../mobile/staff/catalog/product-search-browse.md).

1. **Internal QR scan** (R3, primary long-term) — scan the self-printed sticker →
   `internal_qr_code` → product resolved in one step, near-barcode speed.
2. **Quick-pick strip** — recent/frequent items (80/20 rule); most sales in one tap.
3. **Category grid** — tap category → photo grid; mirrors how staff mentally organize.
4. **Fuzzy text search** with autocomplete; also filter by `color_tag` + `shelf_location`.
5. **Voice search** — on-device STT for name/category.
6. **Favorites per staff** — personal pinned row.
7. Always end with the **`ItemConfirmCard`** (photo + name + price) before add-to-cart.

## 6. Edge cases
- New staff, unfamiliar stock → falls back gracefully to search/voice if grid is slow.
- Untagged legacy stock (no QR yet) → photo browsing still works; prompt to print a QR.
- Two genuinely different toys that look alike → review queue + `confirmed_unique` stops
  future false prompts for that pair.
- Offline entry → duplicate check runs on-device against the local catalog cache; a
  server-side re-check runs on sync and can still enqueue a review item.

## 7. Related docs
- [data-model.md](data-model.md) (`products.image_embedding`, `duplicate_review_queue`)
- [api/duplicate-detection](../cloud/api/duplicate-detection/duplicate-detection-api.md)
- [api/products](../cloud/api/products/products-api.md)
