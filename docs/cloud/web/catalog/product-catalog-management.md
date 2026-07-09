# Product Catalog Management — Owner / Accountant · Flutter Web

> Status: `✅ Specified` · The **bulk-friendly** web catalog: mass edit/upload (CSV + bulk
> photos) and the **duplicate-detection review queue** (Requirement 2). The web counterpart to
> the mobile owner catalog, built for volume.

---

## 1. Purpose & context
- **What this screen is for** — manage the whole product catalog at desktop scale: browse/search
  products in a dense table, **bulk edit** fields (price, category, thresholds, shelf), **bulk
  upload** new products via **CSV + a batch of photos**, and work the **duplicate review queue**
  — flagged similar items shown **side-by-side** with `similarity_score`, resolved as
  `confirmed_duplicate` (with **merge**) or `confirmed_unique`.
- **Who uses it** — `owner` (catalog owner) primarily; `accountant` typically read-only.
- **When** — onboarding a supplier's new shipment (bulk add), periodic price/category cleanups,
  and clearing the duplicate queue that accumulates from mobile/offline entries.
- **Why it exists** — the shop's #1 data risk: **no barcodes/SKUs**, so the same toy gets entered
  twice under near-identical names, splitting stock and confusing pricing (R2). Mobile catches
  duplicates at entry; ambiguous cases are queued here for a human decision on a big screen with
  side-by-side photos. Bulk tools make cataloguing a shipment feasible without per-item typing.
- **Frequency / criticality** — periodic bursts; **high** — a wrong merge destroys a distinct
  product's history; a missed duplicate splits stock. Merges must be reversible/auditable.

---

## 2. Entry points & navigation
- **Arrival** — sidebar **Catalog** (7th item); `g c`; from Stock Report product row; from a
  `duplicate_review` notification → Review Queue tab.
- **Exits**
  - **Product row** → product detail/edit drawer.
  - **Review Queue** resolve → stays; on merge → the surviving product.
  - **Bulk upload** → import wizard (modal/route) → back to table.
  - Deep-links from Sales/Stock (a product).
- **Back-button** — closes drawer/modal first; table filters + active tab in URL.
- Nav diagram: `Stock/notification → Catalog (Products | Review Queue) → {Edit drawer | Import wizard | Merge}`.

---

## 3. Roles & permissions
| Actor | Access | Notes |
|---|---|---|
| Owner | full: CRUD, bulk edit/upload, resolve queue, merge | duplicate resolution + merge are owner actions |
| Accountant | read-only browse/export | cannot edit/bulk/merge |
| Staff | ⛔ | staff manage catalog only via the mobile add-product flow |
- Product create/edit/deactivate and **duplicate resolution/merge** are owner writes (audited in
  `audit_log`). Deactivation is a **soft-delete** (`products.is_active=0`), never a hard delete
  (ledgers/history must stay intact). No `🔒 owner-PIN` gate specified for catalog edits.

---

## 4. Screen layout (wireframe)
Sidebar shell + two tabs: **Products** (dense table + bulk bar) and **Review Queue**
(side-by-side cards).

```
┌──────────┬──────────────────────────────────────────────────────────────────────┐
│ 🧸       │  Catalog   [ Products 312 ] [ Review Queue ⚠7 ]   ⟳  Import ▾  Export▾ │
│ Dashboard│  Category[All▾] Supplier[All▾] Status[Active▾]  🔍 name / QR / color…  │
│ Sales    │ ── PRODUCTS tab ────────────────────────────────────────────────────  │
│ Purchases│ │☑ 3 selected → [Bulk edit ▾] [Deactivate] [Print QR]                 ││ ← bulk bar
│ Stock    │ ┌────────────────────────────────────────────────────────────────────┐│
│ GST      │ │☑ Photo Name         Cat        Supplier  Sell₹  GST%  Shelf  QR  ● ││
│ Staff    │ │☑ 🧸   Red Racer     Battery… SunToys   1,499  18   A2   ✓QR  🟢 ││
│ Catalog ▸│ │☑ 🧸   Blue Jeep     Battery… SunToys   2,499  18   A3   —    🔴 ││
│ Settings │ │☐ 🧸   Farm Playset  Play Sets Playmax    799  12   B1   ✓QR  🟠 ││
│          │ └────────────────────────────────────────────────────────────────────┘│
│ ── REVIEW QUEUE tab ───────────────────────────────────────────────────────────  │
│ │  Similarity 0.91 · image+text                                                 │ │
│ │  ┌── NEW (candidate) ──┐        ┌── EXISTING (matched) ──┐                     │ │
│ │  │  🧸 photo           │  ⇔     │  🧸 photo               │                     │ │
│ │  │  "Red Racer Cars"   │        │  "Red Racer Car"        │                     │ │
│ │  │  SunToys · Battery  │        │  SunToys · Battery      │  on-hand 7          │ │
│ │  └─────────────────────┘        └─────────────────────────┘                     │ │
│ │  [ Same item → Merge into existing ]   [ Different → Keep both (unique) ]       │ │
│ └───────────────────────────────────────────────────────────────────────────────┘ │
└──────────┴──────────────────────────────────────────────────────────────────────┘
```

**Sidebar nav placement** — Catalog is the **7th** item. **Review Queue** tab shows a live
`⚠N` pending badge. **Dense-table behavior** — shared web `DataTable` (sticky header, sticky
photo+name column, 40/32 px rows, header sort + multi-sort, per-column filters, column
show/hide/resize, cursor pagination, selection checkboxes) **plus a bulk-action bar** that
appears when rows are selected.

**Responsive breakpoints**

| Name | Width | Layout |
|---|---|---|
| Compact | < 768 px | table → photo cards; bulk bar sticky bottom; review queue cards stack vertically (⇕) |
| Medium | 768–1199 px | table w/ horizontal scroll (Shelf/QR collapse); review pair stacks |
| Expanded | 1200–1599 px | full table; review pair **side-by-side** |
| Wide | ≥ 1600 px | full table + wide side-by-side review with zoomable photos |

---

## 5. UI components & field-by-field spec
### Products tab — table columns
| # | Column | Source (canonical) | Sort | Filter | Editable (bulk/inline) | Notes |
|---|---|---|---|---|---|---|
| C1 | ☑ select | — | no | — | — | drives bulk bar |
| C2 | Photo | `products.image_url` / `product_images` | no | — | upload | thumbnail |
| C3 | Name | `products.name` | ✅ | contains (FULLTEXT) | inline | fuzzy-search source (R2) |
| C4 | Category | `products.category_id`→`categories.name` | ✅ | multi-select | bulk | **mandatory** (R2) |
| C5 | Supplier | `products.supplier_id`→`suppliers.name` | ✅ | multi-select | bulk | **mandatory** (R2) |
| C6 | Cost | `products.cost_price` | ✅ | range | inline | latest cost |
| C7 | Selling | `products.selling_price` | ✅ | range | inline/bulk | required |
| C8 | GST% | `products.gst_rate` | ✅ | multi-select | bulk | 0/5/12/18/28 |
| C9 | HSN | `products.hsn_code` | ✅ | contains | bulk | GST |
| C10 | Shelf | `products.shelf_location` | ✅ | multi-select | inline/bulk | "Rack A2" (R3) |
| C11 | Color | `products.color_tag` | — | multi-select | inline | color chip + label |
| C12 | QR | `products.internal_qr_code` | — | has/none | print | ✓/— ; print sticker (R3) |
| C13 | Reorder | `products.reorder_threshold` | ✅ | range | bulk | low-stock trigger |
| C14 | On-hand | `v_current_stock.on_hand` | ✅ | range | read-only | 🟢/🟠/🔴 status |
| C15 | Status | `products.is_active` | ✅ | Active/Inactive | bulk toggle | soft-delete |

### Bulk actions bar (on selection)
| Action | Effect | API |
|---|---|---|
| Bulk edit ▾ | set category/supplier/price/gst/shelf/reorder for N products | `PATCH /products/bulk` *(Proposed)* |
| Deactivate | `is_active=0` for N (soft) | `PATCH /products/bulk` |
| Print QR | generate/print `internal_qr_code` stickers for N | client → label sheet |
| Export | selected rows CSV/XLSX | `GET /products?...&format=` |

### Import wizard (CSV + bulk photos)
| Step | Element | Notes |
|---|---|---|
| 1 Upload | CSV file + photo batch (drag-drop) | CSV columns map to `products` fields; photos matched by filename ↔ a CSV key |
| 2 Map & validate | column mapping + row validation | required category/supplier; price numeric; **runs duplicate check per row** |
| 3 Preview | table of new / matched / error rows | matched rows → route to Review Queue |
| 4 Commit | create products + upload images + embeddings | server-side re-check may enqueue `duplicate_review_queue` |

### Review Queue tab — per item
| Field | Source (canonical) | Notes |
|---|---|---|
| Similarity | `duplicate_review_queue.similarity_score` (0–1) | e.g. 0.91 |
| Match type | `duplicate_review_queue.match_type` (`image`/`text`/`both`) | why flagged |
| New (candidate) | `new_product_id`→`products` (+ photos) | left card |
| Existing (matched) | `matched_existing_product_id`→`products` (+ photos, on-hand) | right card |
| Resolve: Same → Merge | sets `status='confirmed_duplicate'` + merge | routes stock/history to survivor |
| Resolve: Different → Unique | sets `status='confirmed_unique'` | won't nag again for this pair |
| Reviewer / time | `reviewed_by`, `reviewed_at` | audit |

---

## 6. States
- **default / populated** — Products table (active by default); Review Queue with pending cards.
- **empty** — no products → `EmptyState` ("Add your first products" → Import); empty queue →
  "No duplicates to review 🎉".
- **loading** — skeleton table rows / shimmer review cards; import shows per-step progress.
- **error (inline, retry)** — table load error → retry; import row errors listed with reasons;
  a failed merge rolls back and explains.
- **offline** — banner "Offline — browsing last loaded catalog"; **all writes** (edit, bulk,
  import, resolve, merge) disabled (web has no outbox).
- **success** — "3 products updated", "Import: 40 created, 3 queued for review", "Merged into
  Red Racer Car", toasts.
- **permission-denied** — accountant sees read-only table (no bulk bar / no resolve buttons).

---

## 7. Interactions, gestures & hardware
- **Keyboard** — `g c` open; `1/2` switch tabs; `/` focus search; `↑/↓` row focus, `Space`
  select, `Enter` open edit drawer, `Ctrl/Cmd+A` select page; in Review Queue: `j/k` next/prev
  item, `m` merge (same), `u` keep unique (different), `Esc` cancel; `Ctrl/Cmd+E` export.
- **Mouse** — inline-edit a cell (double-click); drag-drop CSV + photos into the import wizard;
  hover similarity → score breakdown; zoom review photos on click.
- **Hardware** — **thermal label printer** is a mobile concern; on web, **Print QR** generates a
  printable label **sheet (PDF)** for an office printer (no BT). Camera/scan is mobile-only.
- **Latency** — inline edit optimistic with confirm; import commit is async with progress; merge
  confirmed before applying.

---

## 8. Business rules & edge cases
1. **R1 — Mandatory scope fields.** `category_id` and `supplier_id` are **required** on every
   product (R2, [data-model.md](../../../foundation/data-model.md)) — enforced in inline edit,
   bulk edit, and CSV import (rows missing them are import errors).
2. **R2 — Duplicate check runs on create/import.** Each new product (single or CSV row) runs the
   layered check (image embedding + fuzzy text, scoped to category+supplier) from
   [duplicate-detection.md](../../../foundation/duplicate-detection.md): none → create; strong
   single → inline "same item?"; ambiguous/multiple → create provisionally + enqueue
   `duplicate_review_queue(status='pending')`.
3. **R3 — Review resolution.**
   - **Same → Merge** (`confirmed_duplicate`): the candidate merges **into** the existing
     survivor — its `stock_movements`, `sale_items`, `purchase_items` re-point to the survivor;
     the candidate is soft-deactivated; a single stock total results (the R2 "win"). Merge is
     **audited** and should be **reversible** within a window.
   - **Different → Unique** (`confirmed_unique`): both kept; the pair is remembered so the same
     lookalike never re-triggers a prompt.
4. **R4 — Merge safety.** Merge picks the **survivor** (default: the existing/older product with
   history) and validates prices/GST rates; conflicting attributes surface for the owner to
   choose. Never merge across different suppliers/categories without an explicit override.
5. **R5 — Soft-delete only.** Deactivate sets `is_active=0`; the product disappears from sale
   pickers but stays in ledgers/history and remains searchable via a Status filter.
6. **R6 — Bulk edit is transactional per field-set** and audited; a partial failure reports which
   rows failed and why (no silent partial writes).
7. **R7 — CSV import mapping** tolerates supplier/category by **name** (resolved to ids, creating
   is disallowed unless a "create missing supplier/category" toggle is on) and matches **photos
   by filename** to a CSV key column; unmatched photos/rows are flagged, not dropped.
8. **R8 — QR generation.** `internal_qr_code` is **self-generated** (R3), UNIQUE; Print QR mints
   codes for products missing one and lays out a printable sheet; re-printing keeps the same code.
9. **R9 — Embedding recompute.** Changing a product's **primary image** recomputes its
   `image_embedding` so future duplicate checks stay accurate (dup-detection §3).
10. **R10 — Offline entries reconcile.** A product created offline on mobile gets a **server-side
    re-check** on sync and may land in this queue later — the web queue is the catch-all for
    anything mobile couldn't auto-resolve (dup-detection §6).
11. **R11 — Concurrent edits** use last-write-wins on attributes by `updated_at`
    ([sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md) §5);
    the table warns if a row changed under you before you save.

---

## 9. API interactions
| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Load / filter / sort / page | `GET /products?category_id=&supplier_id=&status=&q=&sort=&cursor=` | product table | last cache; read-only |
| Inline / single edit | `PATCH /products/{id}` | update fields | blocked offline |
| Create | `POST /products` (Idempotency-Key = `client_uuid`) | new product (+ dup check) | blocked offline |
| Bulk edit / deactivate | `PATCH /products/bulk` *(Proposed)* | mass update N | blocked offline |
| CSV + photos import | `POST /products/import` *(Proposed, multipart, async)* | bulk create + embeddings | blocked offline |
| Review queue | `GET /duplicate-review-queue?status=pending` | pending flagged pairs | cache |
| Resolve / merge | `POST /duplicate-review-queue/{id}/resolve` `{resolution: confirmed_duplicate\|confirmed_unique, merge_into?}` | resolve + optional merge | blocked offline |
| Duplicate check (import/create) | `POST /products/check-duplicate` | ranked candidates + scores | server-side |
| Export | `GET /products?...&format=csv\|xlsx` | download | disabled offline |

- Creates/imports carry an `Idempotency-Key` (= `client_uuid`) so retried commits don't double-
  create ([api-conventions.md](../../../foundation/api-conventions.md) §6).
- API docs: [../../api/products/products-api.md](../../api/products/products-api.md) ·
  [../../api/duplicate-detection/duplicate-detection-api.md](../../api/duplicate-detection/duplicate-detection-api.md).

**`GET /duplicate-review-queue` — key response fields**
`data[]`: `{ id, similarity_score, match_type, new_product:{id,name,image_url,supplier,category},
matched_existing:{id,name,image_url,supplier,category,on_hand}, status, created_at }`.

---

## 10. Offline & sync behavior
- **Browse-cache + online writes.** Web keeps a session cache for browsing; **every write**
  (create/edit/bulk/import/resolve/merge) is **online-only** (no Drift/outbox on web) and blocked
  with a toast when offline.
- Creates use idempotency keys so a retried commit after a flaky connection doesn't duplicate.
- The Review Queue itself is fed by mobile/offline entries reconciled server-side on sync
  ([sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md) §5–6,
  [duplicate-detection.md](../../../foundation/duplicate-detection.md) §6) — the web is where
  humans clear what automation couldn't.

---

## 11. Analytics & events
| Event | When | Properties |
|---|---|---|
| `web_catalog_viewed` | load | `tab`, filters |
| `web_product_edited` | inline/single edit | `product_id`, `fields` |
| `web_bulk_edit` | bulk apply | `count`, `fields` |
| `web_import_started` / `_committed` | import | `row_count`, `created`, `queued`, `errors` |
| `web_dup_queue_viewed` | queue tab | `pending_count` |
| `web_dup_resolved` | resolve | `queue_id`, `resolution`, `similarity_score`, `merged_into` |
| `web_qr_printed` | print QR | `count` |

---

## 12. Accessibility, localization & performance
- **A11y** — side-by-side review cards are keyboard-navigable with clear "Same/Different"
  buttons (text, not color-only); similarity shown as a number + label; status uses icon + text;
  photos have alt text (product name). WCAG AA light/dark; zoomable photos for close comparison.
- **Localization** — `₹` Indian grouping; product/category names localizable; CSV template
  headers documented; DD-MM-YYYY on audit fields.
- **Performance** — cursor pagination + virtualization for large catalogs; import runs async with
  progress; embeddings computed server-side on upload; thumbnails lazy-loaded.

---

## 13. Acceptance criteria
- [ ] Products table lists catalog with sort/filter/search (name FULLTEXT, QR, color, shelf) and
      shows on-hand status; category and supplier are enforced as mandatory on every write.
- [ ] Selecting rows reveals a bulk bar; bulk edit/deactivate/print-QR/export apply to N products
      transactionally and are audited.
- [ ] CSV + bulk-photo import maps columns, validates rows, runs the duplicate check per row, and
      previews created vs queued vs error rows before commit.
- [ ] Review Queue shows each pending pair **side-by-side** with photos, `similarity_score`, and
      `match_type`.
- [ ] Resolving **confirmed_duplicate** merges the candidate into the survivor (re-pointing
      stock/sales/purchase history, soft-deactivating the candidate) — auditable and reversible.
- [ ] Resolving **confirmed_unique** keeps both and suppresses future prompts for that pair.
- [ ] Deactivation is soft (`is_active=0`); no hard deletes; history preserved.
- [ ] Changing a primary image recomputes the product's embedding.
- [ ] All writes are online-only and blocked (not silently queued) offline; creates are
      idempotent on retry.
- [ ] Accountant gets a read-only view (no bulk bar / resolve buttons); fully keyboard-operable.

---

## 14. Related docs
- Foundation: [duplicate-detection.md](../../../foundation/duplicate-detection.md)
  (`image_embedding`, `duplicate_review_queue`, layered checks) ·
  [data-model.md](../../../foundation/data-model.md) (`products`, `product_images`) ·
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md) (LWW attributes) ·
  [api-conventions.md](../../../foundation/api-conventions.md) (idempotency, export) ·
  [design-system.md](../../../foundation/design-system.md) (`DataTable`, `ProductTile`)
- API: [../../api/products/products-api.md](../../api/products/products-api.md) ·
  [../../api/duplicate-detection/duplicate-detection-api.md](../../api/duplicate-detection/duplicate-detection-api.md)
- Sibling web screens: [../stock/stock-report.md](../stock/stock-report.md) ·
  [../settings/settings.md](../settings/settings.md) (similarity threshold, reorder defaults)
- Mobile counterpart: [../../../mobile/owner/catalog/product-catalog-management.md](../../../mobile/owner/catalog/product-catalog-management.md) ·
  [../../../mobile/staff/catalog/product-search-browse.md](../../../mobile/staff/catalog/product-search-browse.md)
