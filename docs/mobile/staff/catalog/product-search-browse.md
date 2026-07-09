# Product Search / Browse — Staff · Mobile (Flutter, offline-first)

> Follows [`_templates/screen-doc-template.md`](../../../_templates/screen-doc-template.md).
> Implements **exact-retrieval** (R2-B) and **easier-than-photo ID** (R3) from
> [`duplicate-detection.md`](../../../foundation/duplicate-detection.md) §5.
> Tokens/components from [`design-system.md`](../../../foundation/design-system.md); envelope
> & filters from [`api-conventions.md`](../../../foundation/api-conventions.md).
> Legend: `✅ Specified` · `🧩 Derived (confirm with owner)` · `⚠️ Risk` · `🔒 Owner PIN`.

---

## 1. Purpose & context
- **What it is** — a **read-only** catalog explorer: category filters, a fuzzy autocomplete
  search bar, a **voice-search** icon (on-device STT), a **QR-scan** icon
  (`internal_qr_code`), filters by **`color_tag`** and **`shelf_location`**, and a personal
  **favorites** row. It's the "where is that toy / what's its price" tool separate from the
  billing flow.
- **Who & when** — staff answering a customer ("do you have the red jeep? how much?"),
  locating stock on a shelf, or a new hire learning the catalog. Also reachable mid-sale, but
  the dedicated retrieval UX lives in [new-sale](../sales/new-sale.md).
- **Why it exists** — no barcodes/SKUs means fast, low-typing retrieval is the core UX bet
  (R2/R3). Multiple lightweight paths (QR, voice, color, shelf, favorites) let staff find an
  item the way they *remember* it ("the red car on rack 3").
- **Frequency / criticality** — frequent lookups; read-only so low risk, but speed and
  findability directly affect floor responsiveness.

## 2. Entry points & navigation
- **Arrive from:** the **Browse** bottom-nav tab; a "find a toy" affordance on
  [dashboard](../dashboard/dashboard-home.md).
- **Exit to:** product detail sheet → **Add to sale** hands off to
  [new-sale](../sales/new-sale.md) (pre-added item); back → dashboard.
- **Back button:** collapses an open product/detail sheet, then returns to dashboard.

```
Dashboard ─▶ Browse ─┬─ category → product grid → product detail ─▶ (Add to sale) New Sale
                     ├─ search / voice / QR → results/detail
                     └─ favorites row → product detail
```

## 3. Roles & permissions
- **Open to:** `staff` (read-only browsing — the R6 spec is explicit: "no edit").
- **No create/edit/deactivate** here — catalog management is owner/web
  ([owner catalog](../../owner/catalog/product-catalog-management.md)).
- **Favorites** are per-staff and editable by the owner of the list (self); toggling a
  favorite is the only write and is **not** `🔒` gated.

## 4. Screen layout (wireframe)

```
┌──────────────── Browse ─────────────────── ✓ synced ─┐
│  🔍 Search toys…               [ 🎤 ]   [ ▣ scan ]    │
│                                                       │
│  ⭐ Favorites  ┌────┐┌────┐┌────┐  → swipe            │
│               │📷 ₹││📷 ₹││📷 ₹│                       │
│               └────┘└────┘└────┘                       │
│                                                       │
│  Categories  ( All ) Battery Cars  Ride-on  Play …    │  ← filter chips
│  Color  ●red ●blue ●yellow   Shelf  A2 B1 C3          │  ← R3 filters
│                                                       │
│  ┌────┐ ┌────┐ ┌────┐                                 │
│  │📷  │ │📷  │ │📷  │  product tiles (image+name+₹)    │
│  │Red │ │Mini│ │Doll│  🟢/🟠/🔴 stock · ⭐ toggle      │
│  │Car │ │Jeep│ │Hse │                                 │
│  └────┘ └────┘ └────┘                                 │
│  ┌────┐ ┌────┐ ┌────┐                                 │
│  └────┘ └────┘ └────┘        ⟳ pull to refresh         │
└───────────────────────────────────────────────────────┘

  ── Product detail sheet (tap a tile) ──────────────────
  ┌───────────────────────────────────────────┐
  │  ┌──────┐  Red Racer Battery Car            │
  │  │  📷  │  ₹1,499 · GST 18% · HSN 9503      │
  │  └──────┘  🟢 in stock: 7 · Rack A2 · red   │
  │  QR: TSK-000123   ⭐ favorite                │
  │       [  Add to sale  ]                      │
  └───────────────────────────────────────────┘
```

Responsive: phone 2-col grid; tablet 3–4 cols with a persistent filter rail. Product tiles
≥96 dp (design-system §5). Read-only: no edit affordances.

## 5. UI components & field-by-field spec

| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Search bar | text + fuzzy autocomplete | `GET /products?q=` + local FULLTEXT/Levenshtein on `name` | — | empty | debounced results; suggests name/color/shelf | typing is last resort (R3) |
| 2 | Voice icon | `VoiceSearchButton` | on-device `speech_to_text` | mic permission | idle | partial transcript → fills query | language configurable (design-system §10) |
| 3 | QR scan icon | `ScannerOverlay` (`mobile_scanner`) | camera → `internal_qr_code` | camera permission | — | resolve → product detail | `GET /products/by-qr/{code}` |
| 4 | Category chips | filter chips | `categories` (cache) `is_active=1` | — | **All** | filter grid by `category_id` | single-select |
| 5 | Color filter | swatch chips | distinct `products.color_tag` | — | none | filter by `color_tag` | R3; icon+label, not color-only |
| 6 | Shelf filter | chips | distinct `products.shelf_location` | — | none | filter by `shelf_location` | R3 ("Rack A2") |
| 7 | Favorites row | strip | `staff_favorites` *(proposed, §10)* / else frequent | product `is_active=1` | staff's pins | tap → detail | R3 favorites-per-staff |
| 8 | Product tile | `ProductTile` | `products` (cache) `is_active=1` | — | — | tap → detail sheet; long-press → quick info | image + name + `selling_price` |
| 9 | Stock badge | status | local `v_current_stock` cache vs `reorder_threshold` | — | — | 🟢 healthy · 🟠 low · 🔴 out | hint only; server owns truth |
| 10 | ⭐ Favorite toggle | icon toggle | `staff_favorites` *(proposed)* | — | off | pin/unpin for this staff | only write on this screen |
| 11 | Detail: price/GST/HSN | static | `selling_price`, `gst_rate`, `hsn_code` | — | — | — | read-only |
| 12 | Detail: QR/shelf/color | static | `internal_qr_code`, `shelf_location`, `color_tag` | — | — | — | shows "no QR yet" if null (untagged legacy) |
| 13 | Add to sale | button | — | — | — | hands product to [new-sale](../sales/new-sale.md) | goes through `ItemConfirmCard` there |
| 14 | Pull-to-refresh | gesture | re-query + sync pull | — | — | refresh catalog/stock | offline → cache only |
| 15 | Empty/No-match | `EmptyState` | — | — | — | "no match — try photo browse / voice / scan" | graceful fallback (R3 edge) |

## 6. States

| State | What the user sees / can do |
|---|---|
| **default** | Favorites row + category chips + color/shelf filters + full product grid (cache). |
| **empty** | No products for the active filters → `EmptyState` suggesting alternate retrieval (photo browse / voice / scan / clear filters). |
| **loading** | Skeleton tiles (design-system §7); cached catalog shows instantly. |
| **error** | Search/scan network error → inline "couldn't refresh — showing cached catalog" + Retry; browsing continues from cache. |
| **offline** | Banner "Working offline — searching cached catalog"; all browsing/search/QR resolve against Drift; favorites toggle queued. |
| **success** | Favorite toggle confirmed (subtle); QR/voice resolves land on the detail sheet. |
| **permission-denied** | Camera/mic denied → scan/voice show a "grant permission" inline card and browsing/typed search still work. |

## 7. Interactions, gestures & hardware
- **Tap** chips/tiles/filters; **long-press** a tile for quick info; **swipe** favorites row;
  **pull-to-refresh**; **tap** ⭐ to pin/unpin.
- **Camera (QR)** via `mobile_scanner` with torch + manual-entry fallback for damaged
  stickers.
- **Mic (voice)** via on-device `speech_to_text`, showing the partial transcript.
- **No printer** on this screen.
- **Latency:** search suggestions debounce ~150–250 ms; grid paints from cache < 200 ms; QR
  resolve target < 500 ms.

## 8. Business rules & edge cases
1. **Read-only.** No product create/edit/deactivate; only favorite toggles write. Catalog
   integrity (dedup) stays with owner/web + [duplicate-detection](../../../foundation/duplicate-detection.md).
2. **Only active products** (`is_active=1`) are browsable/sellable; deactivated items are
   hidden (they remain in ledgers/history).
3. **QR resolves in one step** — a valid `internal_qr_code` jumps straight to the product
   detail (near-barcode speed, R3); an unknown code shows "not found — search instead".
4. **Untagged legacy stock** — products with a null `internal_qr_code` still appear via photo
   browse/search; the detail shows "no QR yet" and (🧩) may hint the owner to print one.
5. **Fuzzy search** tolerates plural/typo variants ("racer"/"racers") via FULLTEXT pre-filter
   + client Levenshtein (duplicate-detection §5.4); results rank exact-ish first.
6. **Color/shelf filters** combine with category and search (AND); clearing is one tap.
7. **Favorites are per-staff** — one staff's pins don't affect another's; the same product can
   be a favorite for several staff. Toggling offline queues and syncs later.
8. **Stock badge is a hint** — never authoritative; a 🔴 "out" item can still be sold if it
   physically exists (server reconciles, sync §5) — but browse only *shows* status; the sell
   decision happens in New Sale.
9. **Two look-alike products** — the detail's `shelf_location` + `color_tag` + `internal_qr_code`
   disambiguate; genuine duplicates route to the web review queue, not fixed here.
10. **New-hire fallback** — if grid scanning is slow, voice/search/QR give faster paths
    (R3 edge case: graceful fallback).

## 9. API interactions

| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Browse / filter / search | `GET /products?category_id=&q=&color=&shelf=` | list/filter catalog | serve Drift catalog cache |
| QR scan | `GET /products/by-qr/{internal_qr_code}` | resolve sticker → product | resolve against local cache |
| Toggle favorite | `POST /staff/{id}/favorites` / `DELETE …` *(proposed API)* | pin/unpin per staff | queue in outbox; sync later |
| Refresh | `GET /sync/pull?since=` | refresh catalog + stock hints | cache-only when offline |

- Filters per [`api-conventions.md`](../../../foundation/api-conventions.md) §7. See
  [`products-api`](../../../cloud/api/products/products-api.md) and
  [`staff-api`](../../../cloud/api/staff/staff-api.md). Key product fields shown: `id`, `name`,
  `selling_price`, `gst_rate`, `hsn_code`, `internal_qr_code`, `shelf_location`, `color_tag`,
  `image_url`, `is_active` + stock hint.

## 10. Offline & sync behavior
- **Fully offline browse.** Category grid, search (local FULLTEXT/Levenshtein), color/shelf
  filters, and QR resolution all run against the Drift **catalog cache**; refreshed by
  `GET /sync/pull`.
- Drift tables read: `products`, `categories`, `product_images`, `v_current_stock` cache.
  Writes: **favorites** only (queued to `sync_outbox`, idempotent by a client key).
- Stock badges reflect the **last-synced** on-hand; they are hints, never the sell-blocker.

### Proposed schema addition (flag for schema owner)
Not in [`data-model.md`](../../../foundation/data-model.md); required for **favorites per
staff** (R3), shared with [dashboard](../dashboard/dashboard-home.md) and
[profile](../profile/profile.md):

| Addition | Shape | Why |
|---|---|---|
| `staff_favorites` | `id BIGINT UN PK, staff_id BIGINT UN FK→staff, product_id BIGINT UN FK→products, sort_order INT DEFAULT 0, created_at TIMESTAMP, UNIQUE(staff_id, product_id)` | R3 "favorites per staff" — pin most-sold items to a personal row. No per-staff pin table exists; without it, favorites fall back to `🧩 Derived` frequency. Implies API `GET/POST/DELETE /staff/{id}/favorites`. Confirm with owner/schema owner. |

## 11. Analytics & events
- `browse_opened`, `search_performed {q, results}`, `voice_search_used {result}`,
  `qr_scan_used {result}`, `filter_applied {category|color|shelf}`,
  `favorite_toggled {product_id, on}`, `product_detail_viewed {product_id}`,
  `add_to_sale_from_browse {product_id}`, `no_match_shown {q}`.

## 12. Accessibility, localization & performance
- Tiles ≥96 dp; chips/toggles ≥48 dp. Color filter swatches carry a **text label** (never
  color-only). Stock badges use icon + label. WCAG AA contrast.
- Screen-reader: tile announces "name, price, stock status, favorite on/off"; QR/voice
  buttons labelled with purpose.
- i18n: ₹ Indian grouping, GST %, HSN; localizable names/labels; voice language configurable;
  DD-MM-YYYY where dates appear.
- Perf: cache paint < 200 ms; 60 fps grid scroll; search debounced to avoid jank.

## 13. Acceptance criteria
- [ ] Staff can browse by category and see image + name + price tiles from cache, offline.
- [ ] Fuzzy search returns tolerant matches (plural/typo) and suggests alternatives on no-match.
- [ ] Voice search fills the query from on-device STT; QR scan resolves a valid
      `internal_qr_code` straight to the product detail.
- [ ] Color and shelf filters narrow results and combine with category/search.
- [ ] A per-staff favorites row shows and toggles (pin/unpin), persisting across sessions and
      syncing when online.
- [ ] The screen is **read-only** — no create/edit/deactivate is offered.
- [ ] Only `is_active=1` products appear; stock badges are shown as hints, not sell-blockers.
- [ ] "Add to sale" hands the product to New Sale, entering the `ItemConfirmCard` flow.

## 14. Related docs
- **Foundation:** [duplicate-detection](../../../foundation/duplicate-detection.md) (retrieval
  §5) · [data-model](../../../foundation/data-model.md) ·
  [design-system](../../../foundation/design-system.md) ·
  [api-conventions](../../../foundation/api-conventions.md) ·
  [sync-and-conflict-resolution](../../../foundation/sync-and-conflict-resolution.md)
- **API:** [products-api](../../../cloud/api/products/products-api.md) ·
  [staff-api](../../../cloud/api/staff/staff-api.md) ·
  [duplicate-detection-api](../../../cloud/api/duplicate-detection/duplicate-detection-api.md) ·
  [sync-api](../../../cloud/api/sync/sync-api.md)
- **Sibling staff screens:** [new-sale](../sales/new-sale.md) ·
  [dashboard-home](../dashboard/dashboard-home.md) · [profile](../profile/profile.md)
- **Other surfaces:** [owner catalog](../../owner/catalog/product-catalog-management.md)
