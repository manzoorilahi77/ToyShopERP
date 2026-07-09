# Product Catalog Management — Owner · Mobile (Owner App)

> Where the owner curates the product catalog: add / edit / deactivate products with
> mandatory duplicate-check on add (image + fuzzy text), bulk photo upload, printing the
> **self-generated internal QR sticker** to a thermal label printer, and setting the
> retrieval/GST attributes (shelf location, color tag, reorder threshold, prices, GST rate,
> HSN code).

Status: `✅ Specified` · `🔒` on **deactivate** (money/inventory-integrity action). Every
add runs mandatory duplicate detection.

---

## 1. Purpose & context
- **What this screen is for:** keep the catalog clean, findable and correctly priced so the
  Staff App can retrieve the exact item fast while selling.
- **Who & when:** the **owner**, usually alongside a delivery (add/tag new items) or when
  correcting prices/thresholds; not on the sales critical path.
- **Why it exists:** products arrive with no barcodes/SKUs; duplicates and mis-tagging are
  the top data-quality risk (R2). The internal QR sticker is the "primary long-term"
  identifier (R3), and shelf/color tags make "the red car on rack 3" findable
  ([requirements R2, R3](../../../requirements_and_prompt.md)).
- **Frequency / criticality:** moderate frequency, high leverage — a duplicate or wrong
  price here degrades every future sale of that item.

---

## 2. Entry points & navigation
- **Catalog** quick-nav chip / **More → Catalog** from
  [Dashboard Home](../dashboard/dashboard-home.md).
- **From [New Purchase](../purchase/new-purchase.md):** a confirm-as-new product deep-links
  to the edit form to finish attributes.
- **From a duplicate/low-stock notification** → the specific product.

```
Dashboard ─▶ Catalog (list) ─┬─▶ Add Product (dup-check → save)
                             ├─▶ Edit Product (attributes / prices / QR / photos)
                             └─▶ Deactivate 🔒
```
- **Back:** list → Dashboard; edit → list (unsaved-changes confirm).

---

## 3. Roles & permissions
| Actor | Access |
|---|---|
| Owner | ✅ add / edit / deactivate / print QR / bulk upload |
| Accountant | 👁 view; edit prices/HSN if designated `🧩`; no deactivate |
| Staff | ❌ (staff browse a read-only [product search](../../staff/catalog/product-search-browse.md)) |
- **`🔒`** Deactivate (`is_active=0`) requires owner PIN — it hides a product from selling
  and is inventory-sensitive. Add/edit are owner-authenticated but not per-action PIN-gated.

---

## 4. Screen layout (wireframe)

```
LIST                                    EDIT / ADD PRODUCT
┌──────────────────────────────┐        ┌────────────────────────────────────┐
│ ← Catalog        🔍   ✓sync   │        │ ← Edit Product            ⋮         │
│ [All▾][Category▾][Active▾]    │        │ ┌────────┐  Name [ Red Racer Car ] │
│ ┌──────────┬──────────┐       │        │ │ (photo)│  Category [Battery Cars▾]│
│ │(img)     │(img)     │       │        │ │  +bulk │  Supplier [Sunrise Toys▾]│
│ │Red Racer │Blue Jet  │       │        │ └────────┘  (mandatory ✱)          │
│ │₹1,499 🟢 │₹4,299 🟠 │       │        │ Prices  Cost ₹[850] Sell ₹[1,499]  │
│ ├──────────┼──────────┤       │        │ GST [18%▾]   HSN [ 9503 ]           │
│ │Play Set  │Mini Bike │       │        │ Reorder threshold [ 3 ]            │
│ │₹899 🔴out│₹2,199 ⏳ │       │        │ Shelf [ Rack A2 ]  Color [ Red ▾ ] │
│ └──────────┴──────────┘       │        │ Internal QR: A2-0022  [🖨 Print]   │
│         [ ＋ Add Product ]     │        │ ─────────────────────────────────── │
└──────────────────────────────┘        │ [ Save ]      [ 🔒 Deactivate ]     │
                                          └────────────────────────────────────┘

ADD → DUPLICATE PROMPT
┌────────────────────────────────────────────┐
│  This looks similar to an existing item      │
│  ┌────────┐  vs  ┌────────┐   score 0.91     │
│  │ NEW    │      │ Red     │                  │
│  │ photo  │      │ Racer   │                  │
│  └────────┘      └────────┘                  │
│  [ Yes — same item (add stock) ]             │
│  [ No — it's a new product ]                 │
└────────────────────────────────────────────┘
```

- **Responsive:** list = 2-col grid on phone, 3–4 on tablet (`ProductTile` ≥ 96 dp with
  image + name + price + stock chip). Edit form single column on phone.

---

## 5. UI components & field-by-field spec

### 5a. List & filters
| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Search | search input | `GET /products?q=` (`FULLTEXT name`, `color_tag`, `shelf_location`) | — | empty | live filter | fuzzy |
| 2 | Category filter | dropdown | `categories` | — | All | filters list | |
| 3 | Active filter | dropdown | `is_active` | — | Active | show active/inactive/all | |
| 4 | `ProductTile` | grid tile | `products` + `v_current_stock` | — | — | tap → edit | stock chip 🟢/🟠/🔴/⏳ (icon+label) |
| 5 | Add Product | primary button | — | — | — | opens add form | |

### 5b. Add / Edit form — field by field
| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 6 | Primary photo | image + camera | `products.image_url`, `product_images` | required on add (drives embedding) | — | recompute `image_embedding`; re-run dup-check if changed | R2 image similarity |
| 7 | Bulk photo upload | multi-image picker | → `product_images` | ≤ N images, size/type-checked | — | first = `is_primary`; others gallery | |
| 8 | Name | text | user | required; fuzzy dup-checked | — | re-runs text dup-check | `products.name` |
| 9 | Category ✱ | dropdown | `categories` | **required (R2)** | — | narrows dup scope | `products.category_id` |
| 10 | Supplier ✱ | dropdown | `suppliers` | **required (R2)** | — | narrows dup scope | `products.supplier_id` |
| 11 | Cost price | money | user | `≥0`; `DECIMAL(12,2)` | last purchase cost | affects profit est. | `products.cost_price` |
| 12 | Selling price | money | user | **required**; `>0` | — | shown to staff at sale | `products.selling_price` |
| 13 | GST rate | dropdown | {0,5,12,18,28} | required | 18.00 | snapshots into future sales | `products.gst_rate` |
| 14 | HSN code | text | user | optional; ≤10 | — | used by GST module | `products.hsn_code` |
| 15 | Reorder threshold | integer | user | `≥0` | 3 | drives low-stock alert | `products.reorder_threshold` |
| 16 | Aging override | integer | user | optional; `≥0` days | null (use global) | per-product aging days | `products.aging_threshold_days` |
| 17 | Shelf location | text | user | optional; ≤20 | — | searchable retrieval tag (R3) | `products.shelf_location` (e.g. "Rack A2") |
| 18 | Color tag | dropdown/chip | user; `products.color_tag` | optional; ≤20 | — | searchable + visual cue (R3) | not sole differentiator |
| 19 | Internal QR code | read-only + Print | `products.internal_qr_code` (UNIQUE) | server-generated | null until printed | `POST /products/{id}/qr` mints + Print | see §7 printing |
| 20 | Save | primary button | — | form valid | — | `POST`/`PATCH /products` | idempotent on create (`client_uuid`) |
| 21 | Deactivate `🔒` | danger button | — | owner PIN | — | `PATCH /products/{id}` `is_active=0` | soft-delete; ledgers intact |
| 22 | Duplicate prompt | modal | `POST /products/check-duplicate` | — | — | Yes→add stock to existing / No→create | mandatory before create |

**Prose notes**
- **Duplicate-check is mandatory on add** (never on edit of an existing identity). Photo →
  embedding + name/category/supplier → `check-duplicate`. Strong single match → "Yes, same
  item" abandons the new draft and routes the owner to the existing product (add stock via
  purchase). Ambiguous → save + `duplicate_review_queue(status='pending')` for the
  [web review queue](../../../cloud/web/catalog/product-catalog-management.md).
- **Deactivate, never delete:** soft-delete via `is_active=0` keeps `sale_items`/`purchase_
  items`/`stock_movements` history intact ([data-model design rule](../../../foundation/data-model.md)).
- **Internal QR** (`internal_qr_code`) is `NULL` until the sticker is first printed; minting
  is idempotent (re-print reuses the same code — a product has exactly one QR).

---

## 6. States
- **Default / populated:** grid of products with stock chips; filters applied.
- **Empty:** `EmptyState` "No products yet — add your first" → Add form.
- **Loading:** skeleton tiles; edit form shows skeleton fields.
- **Error:** inline retry on list; save error keeps the form (values preserved) + inline
  message; duplicate-check failure degrades to "save + queue for review."
- **Offline:** add/edit work against the local cache; save queues (`sync_status='pending'`);
  duplicate-check runs on-device; QR **print** works offline (code is local/minted-ahead),
  but minting a *new* server code may defer until sync.
- **Success:** toast "Product saved"; QR print → "Sticker sent to printer."
- **Permission-denied:** deactivate without PIN → blocked; accountant sees no deactivate.

---

## 7. Interactions, gestures & hardware
- **Camera / multi-picker** for primary + bulk photos; images size/type/virus-checked on
  upload ([api-conventions §10](../../../foundation/api-conventions.md)).
- **Thermal label printer (Bluetooth):** `[🖨 Print]` sends the `internal_qr_code` as a QR
  label (via `esc_pos_bluetooth` / `blue_thermal_printer`) to stick on the toy/box at
  intake — near-barcode speed later on the sales floor. Printer pairing reused from the
  Staff App printing stack.
- **Long-press a tile** → quick info (stock, shelf, last sold).
- **Latency:** list scroll 60 fps; dup-check < 800 ms server / instant on-device.

---

## 8. Business rules & edge cases
1. **Mandatory duplicate-check on add**; category + supplier are required scoping fields (R2).
2. **"Yes, same item"** never creates a duplicate — quantity is added to the existing
   product instead (via purchase flow).
3. **Ambiguous match** → product saved provisionally + `duplicate_review_queue` row.
4. **Deactivate is `🔒`** and reversible (reactivate); it removes the product from staff
   sale retrieval but preserves all historical rows.
5. **One QR per product:** `internal_qr_code` is `UNIQUE`; reprinting uses the same code;
   the code never encodes price (price can change) — only product identity.
6. **Selling price is required** before a product is sellable; a product with null selling
   price is flagged and hidden from staff quick-pick.
7. **Editing the primary photo** recomputes `image_embedding` and may surface a new
   duplicate suspicion on next check.
8. **Changing GST rate / HSN** affects only future sales/purchases; past line snapshots are
   immutable.
9. **Idempotent create** via `client_uuid`; offline replay is safe.
10. **Category/supplier must be active**; deactivated category/supplier still shows on
    historical products but is not selectable for new ones.

---

## 9. API interactions

| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| List / search | `GET /products?q=&category_id=&is_active=` | catalog grid | cached read |
| Open product | `GET /products/{id}` | full detail + images | cached |
| Add (pre-save) | `POST /products/check-duplicate` | mandatory dup candidates (image+text) | on-device cache check |
| Create | `POST /products` (`Idempotency-Key`=`client_uuid`) | new product | queued `pending` |
| Edit | `PATCH /products/{id}` | update attributes/prices | queued (LWW by `updated_at`) |
| Deactivate `🔒` | `PATCH /products/{id}` `{ is_active:0, owner_pin }` | soft-delete | **online** (PIN verify) |
| Mint/print QR | `POST /products/{id}/qr` | assign/return `internal_qr_code` | print cached; mint may defer |
| Bulk photos | `POST /products/{id}/images` | add to `product_images` | queued uploads |

Key fields (see [products-api](../../../cloud/api/products/products-api.md),
[duplicate-detection-api](../../../cloud/api/duplicate-detection/duplicate-detection-api.md)):
- **check-duplicate req:** `{ image|embedding, name, category_id, supplier_id }` →
  `{ candidates:[{product_id, score, match_type}] }`
- **create/edit body:** `name, category_id, supplier_id, cost_price, selling_price,
  gst_rate, hsn_code, reorder_threshold, aging_threshold_days, shelf_location, color_tag`
- Envelope/errors per [api-conventions](../../../foundation/api-conventions.md).

---

## 10. Offline & sync behavior
- **Works offline:** browse/search cached catalog, add/edit (queued), on-device dup-check,
  QR print of already-minted codes.
- **Queued:** `product` creates/edits + `product_images` uploads → `sync_status='pending'`;
  edits reconcile last-write-wins by `updated_at`
  ([sync §5](../../../foundation/sync-and-conflict-resolution.md)).
- **Blocked offline:** `🔒` deactivate (needs PIN verify) and minting a brand-new server QR
  code.
- **Server re-check:** on sync, the server re-runs duplicate detection and may enqueue a
  `duplicate_review_queue` row even if the on-device check passed.

---

## 11. Analytics & events
- `catalog_viewed` · `product_created` · `product_edited` · `product_deactivated`
- `duplicate_prompt_shown` / `duplicate_resolved` (add_stock | new | review_queued)
- `qr_sticker_printed` (product_id)
- `bulk_photos_uploaded` (count)

---

## 12. Accessibility, localization & performance
- Tiles ≥ 96 dp with image + name + price + **stock chip (icon+label, not color alone)**.
- Money `₹` + Indian grouping + tabular; GST rate labelled `%`; dates **DD-MM-YYYY**.
- Duplicate prompt shows both photos side-by-side ≥ 96 dp for confident comparison.
- Screen-reader labels on filter chips, stock chips, and the Print/Deactivate actions.
- Image uploads compressed client-side; list virtualized for smooth scroll on large catalogs.

---

## 13. Acceptance criteria
- [ ] Adding a product always runs `check-duplicate` before it can be saved.
- [ ] Category and supplier are required; a product cannot be created without both.
- [ ] "Yes, same item" adds stock to the existing product instead of creating a new one.
- [ ] An ambiguous match saves the product and enqueues a `duplicate_review_queue` row.
- [ ] Deactivate requires an owner PIN, sets `is_active=0`, and keeps history intact.
- [ ] Printing a QR mints/returns a single `internal_qr_code` and sends it to the thermal
      printer; reprint reuses the same code.
- [ ] Shelf location, color tag, reorder threshold, prices, GST rate and HSN persist and
      map to the canonical `products` columns.
- [ ] Editing the primary photo recomputes the embedding for duplicate detection.
- [ ] Offline add/edit queues with `sync_status='pending'` and re-checks on sync.

---

## 14. Related docs
- Foundation: [duplicate-detection](../../../foundation/duplicate-detection.md) ·
  [data-model](../../../foundation/data-model.md) (`products`, `product_images`) ·
  [design-system](../../../foundation/design-system.md) ·
  [sync](../../../foundation/sync-and-conflict-resolution.md) ·
  [api-conventions](../../../foundation/api-conventions.md)
- API: [products-api](../../../cloud/api/products/products-api.md) ·
  [duplicate-detection-api](../../../cloud/api/duplicate-detection/duplicate-detection-api.md)
- Sibling screens: [New Purchase](../purchase/new-purchase.md) ·
  [Reports](../reports/reports.md) · [Notifications](../notifications/notifications.md)
- Counterparts: [web catalog / review queue](../../../cloud/web/catalog/product-catalog-management.md) ·
  [staff product search](../../staff/catalog/product-search-browse.md)
