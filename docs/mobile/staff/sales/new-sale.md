# New Sale — Staff · Mobile (Flutter, offline-first)

> Follows [`_templates/screen-doc-template.md`](../../../_templates/screen-doc-template.md).
> The **highest-criticality staff screen.** It implements the **Sales Flow** (R4) with
> **exact item retrieval** (R2-B, [`duplicate-detection.md`](../../../foundation/duplicate-detection.md))
> and **offline-first, never-block** billing ([`sync-and-conflict-resolution.md`](../../../foundation/sync-and-conflict-resolution.md)).
> Tokens/components from [`design-system.md`](../../../foundation/design-system.md); envelope,
> auth, errors, idempotency from [`api-conventions.md`](../../../foundation/api-conventions.md).
> Legend: `✅ Specified` · `🧩 Derived (confirm with owner)` · `⚠️ Risk` · `🔒 Owner PIN`.

---

## 1. Purpose & context
- **What it is** — the billing engine. A staff member finds items (five ways), confirms each
  visually, builds a cart with an always-visible running total, optionally requests an
  owner-approved discount, picks a payment mode, and confirms — producing a receipt. The sale
  is written to **local Drift first** and syncs in the background; the network is **never**
  on the critical path.
- **Who & when** — every staff member, all day, hardest during evening/weekend rush when a
  queue is forming and battery cars are being assembled on the counter.
- **Why it exists** — this is *the* revenue action and *the* risk surface: no barcodes/SKUs
  means wrong-item / wrong-price sales and double-counted stock are the top operational
  failure. The five retrieval methods + the mandatory **`ItemConfirmCard`** kill wrong-item
  sales; offline-first + `client_uuid` idempotency + event-sourced stock kill lost sales and
  negative-stock corruption.
- **Frequency / criticality** — the most-used screen in the app, dozens–hundreds of times a
  day. Every rule here is about **speed** (add-to-cart < 100 ms) **and** **correctness**
  (right item, right price, right stock, exactly-once).

## 2. Entry points & navigation
- **Arrive from:** the big **New Sale** button on [dashboard](../dashboard/dashboard-home.md);
  a **quick-pick** tile on the dashboard (opens with that item pre-added); the bottom-nav
  Sales tab; "New Sale" shortcut on [receipt](./receipt.md).
- **Internal steps** (a single screen with a sheet stack, not a wizard you can get lost in):
  `Find item → ItemConfirmCard → Cart → (Discount 🔒) → Payment → Confirm`.
- **Exit to:** [receipt](./receipt.md) on confirm; back/cancel → discard-guarded return to
  dashboard.
- **Back button:** collapses the current sheet (payment → cart → find); from the find step
  with a **non-empty cart** it prompts "Discard this sale?" (forgiving, not punishing).

```
Dashboard ─▶ New Sale
   ┌───────────────── find item ─────────────────┐
   │ quick-pick · QR scan · category grid ·        │
   │ fuzzy search · voice search                   │
   └───────┬───────────────────────────────────────┘
           ▼ ItemConfirmCard (photo+name+price+qty) ── Add ─▶ Cart (running total)
                                                              │
                        ┌── + Discount 🔒 (owner PIN / remote approval) ──┐
                        ▼                                                  │
                     Payment (cash / UPI / card) ─▶ Confirm ─▶ Receipt ◀──┘
```

## 3. Roles & permissions
- **Open to:** `staff` (and owner/accountant on a staff build). The sale is attributed to the
  logged-in `staff_id`.
- **`🔒 owner-PIN` gated:** applying any **cart-level discount** (`sales.discount_amount > 0`).
  Staff can *request* a discount; only an **owner PIN** (entered on-device) or a **remote owner
  approval** ([owner discount-approval](../../owner/approvals/discount-approval.md)) can apply
  it.
- **Per-line price override — not PIN-gated (rule 3a):** staff *may* override a single cart
  line's unit price, up or down, without an owner PIN (e.g. a floor-negotiated price, a
  chipped-box markdown). Unlike the discount, this is a staff self-serve action; it is instead
  **flagged** ("Custom price") on the cart line and the receipt, and carried onto the confirmed
  sale for the owner to review after the fact (a real backend records it to `audit_log`).
- **Read-only for staff:** `gst_rate` and `hsn_code` come from the catalog snapshot and are
  **not editable** on this screen. `selling_price` is editable only via the flagged per-line
  override above or the gated cart-level discount — never a silent edit.

## 4. Screen layout (wireframe)

```
┌───────────────────── New Sale ───────────────── • 3 pending ─┐
│  🔍 Search toys…                     [ 🎤 voice ] [ ▣ scan ] │  ← search + hardware
│                                                               │
│  Quick pick   ┌────┐┌────┐┌────┐┌────┐  → swipe               │
│               │📷 ₹││📷 ₹││📷 ₹││📷 ₹│  1-tap add             │
│               └────┘└────┘└────┘└────┘                        │
│                                                               │
│  Categories                                                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                       │
│  │Battery   │ │Ride-on   │ │Play      │  tap → product grid   │
│  │Cars      │ │Bikes     │ │Sets      │                       │
│  └──────────┘ └──────────┘ └──────────┘                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                       │
│  │Remote    │ │Dolls     │ │Outdoor   │                       │
│  └──────────┘ └──────────┘ └──────────┘                       │
│                                                               │
│ ┌──────── Cart (always visible, running total) ───────────┐   │
│ │ 🛒 3 items                              ₹ 6,497.00       │   │
│ │  ‹ swipe a line left to remove ›            View ▸       │   │
│ └──────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘

  ── ItemConfirmCard (bottom sheet on select) ──────────────────
  ┌───────────────────────────────────────────┐
  │  ┌──────┐  Red Racer Battery Car            │
  │  │  📷  │  ₹ 1,499.00   · GST 18% · Rack A2 │
  │  └──────┘  🟢 in stock: 7                   │
  │                                             │
  │        Qty   ［ − ］   2   ［ ＋ ］          │
  │                                             │
  │   [ Cancel ]              [  Add ₹2,998  ]  │
  └───────────────────────────────────────────┘

  ── CartSheet (expanded) ──────────────────────────────────────
  ┌───────────────────────────────────────────────────────────┐
  │  Red Racer Car     ₹1,499 ×2      ₹2,998   ‹swipe to remove›│
  │  Mini Jeep         ₹1,999 ×1      ₹1,999                    │
  │  Doll House        ₹  750 ×2      ₹1,500                    │
  │  ────────────────────────────────────────────────────────  │
  │  Subtotal                          ₹6,497.00               │
  │  Discount 🔒       [ + Add discount ]      − ₹0.00         │
  │  GST (incl.)                        (₹ …)                  │
  │  ─────────────────────────────────────────                │
  │  TOTAL                              ₹6,497.00  (Display)   │
  │                                                            │
  │  Payment:  ( ● Cash )  ( UPI )  ( Card )                   │
  │  ┌──────────────────────────────────────────────────────┐ │
  │  │            ✓  C O N F I R M   S A L E   (56dp)         │ │
  │  └──────────────────────────────────────────────────────┘ │
  └───────────────────────────────────────────────────────────┘
```

Responsive: phone = full-width sheets; tablet keeps the product grid on the left and a
persistent cart panel on the right (no sheet toggling). Running total is **always** on screen
(design-system §6 `CartSheet`).

Both the `ItemConfirmCard` price and each `CartSheet` line's "₹X each" are tappable (✎) — they
open a `NumericPad` price-override sheet (rule 3a) rather than being read-only, and an
overridden line grows a small "Custom price · was ₹Y" flag underneath.

## 5. UI components & field-by-field spec

| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Search bar | text + fuzzy autocomplete | `GET /products?q=` + local FULLTEXT/Levenshtein | — | empty | debounced suggestions (name, `color_tag`, `shelf_location`) | typing is last resort (R3) |
| 2 | Voice button | `VoiceSearchButton` | on-device `speech_to_text` | mic permission | idle | shows partial transcript → fills search | fast in a rush (R3) |
| 3 | Scan button | `ScannerOverlay` (`mobile_scanner`) | camera → `internal_qr_code` | camera permission | — | resolves QR → ItemConfirmCard directly | near-barcode speed (R3), primary long-term |
| 4 | Quick-pick strip | `QuickPickStrip` | favorites + frequent (local) | product `is_active=1` | top 8 | 1-tap → ItemConfirmCard (qty 1) | 80/20 (R2-B) |
| 5 | Category tile | `CategoryGrid` | `categories` (cache) `is_active=1` | — | — | tap → product grid for that `category_id` | mirrors mental model (R2-B) |
| 6 | Product tile | `ProductTile` | `products` in category (cache) | `is_active=1` | — | tap → ItemConfirmCard | image + name + price; long-press = quick info |
| 7 | ItemConfirmCard photo/name/price | card | selected product snapshot | — | — | visual double-check before add; tap price (✎) → override sheet | prevents wrong-item sale (R2-B); price edit is rule 3a |
| 8 | Stock hint | badge | local `v_current_stock`-equivalent cache | — | shows on_hand | 🟢/🟠/🔴 by `reorder_threshold` | UX hint only — server owns truth |
| 9 | **Qty stepper** | `−`/value/`+` (`NumericPad` on tap) | user | integer ≥1; > on_hand → warn, not block | 1 | recompute line + running total instantly | long-press +/- accelerates; tap number → pad |
| 10 | Add-to-cart | primary button | — | qty ≥1 | — | append/merge line; **< 100 ms**; scale+fade | merges same product into one line |
| 11 | Cart line | list row | Drift cart (in-progress) | — | — | tap qty number → bulk-edit pad; **swipe-left → remove** (with undo) | swipe-to-remove (design-system §6) |
| 11a | Line price override | tap "₹X each" → `NumericPad` sheet | user | > 0 | catalog `selling_price` | resets/sets `sale_items.unit_price` for that line only; shows delta vs catalog | **not** owner-gated (rule 3a); flags the line "Custom price" |
| 12 | Subtotal / GST / Total | computed | sum of `sale_items` | — | ₹0 | live recompute on any change | tax-inclusive or exclusive per config (see rule 6) |
| 13 | **Add discount** 🔒 | button → discount sheet | — | — | hidden until tapped | opens discount request (amount/percent + reason) | see fields 14–17 |
| 14 | Discount type | toggle Amount / Percent | user | one selected | Amount | switches input mode | percent resolves to ₹ (see proposed note) |
| 15 | Discount value | numeric (`NumericPad`) | user | > 0; ≤ subtotal (amount) or ≤ 100 (percent); not below cost 🧩 | empty | previews new total | over-limit → inline warn |
| 16 | Discount reason | text (optional) | user | ≤ 255 | empty | stored on `discount_approvals.reason` | free text |
| 17 | Owner PIN dialog | `PinDialog` 🔒 | owner PIN (on-device) | 4–6 digits, owner role | — | verify → apply discount, set `discount_approved_by` | or route to remote approval (rule 8) |
| 18 | Payment selector | segmented | `cash` / `upi` / `card` | required | **cash** | sets `sales.payment_mode` | matches `sales.payment_mode` enum |
| 19 | Confirm Sale | primary 56 dp | — | cart non-empty; payment chosen; discount (if any) approved | — | writes sale to Drift, shows receipt | **never blocks** on network |
| 20 | `SyncStatusChip` | status | sync worker | — | current | tap → sync sheet | shows N pending |
| 21 | Cancel/discard | icon/back | — | — | — | if cart non-empty → confirm discard | forgiving |

Prose on subtle fields:
- **Qty stepper** — `+`/`−` for fast small quantities; tapping the number opens the
  `NumericPad` for larger counts (e.g. a bulk buy). Qty above cached `on_hand` shows an amber
  "only 7 in stock — sell anyway?" and **still allows** the sale (goods may physically exist;
  server reconciles — sync doc §5). It never hard-blocks a real sale.
- **Discount** — entering percent computes the rupee `requested_amount` shown to the owner;
  the persisted value is the resolved **amount** (see proposed note in §10).
- **Payment** — a single required choice; UPI/card are recorded, not processed by this app
  (no PG integration in scope) — the staff confirms payment was received out-of-band.

## 6. States

| State | What the user sees / can do |
|---|---|
| **default** | Search + voice + scan, quick-pick, category grid, empty cart (total ₹0), Confirm disabled. |
| **empty (cart)** | Cart pill shows "0 items · ₹0"; Confirm disabled with hint "add an item to start". |
| **loading** | Catalog/search skeletons only; **never** a blocking spinner on add-to-cart or confirm (design-system §1, sync §1). |
| **populated (cart has items)** | Running total live; swipe-to-remove; discount + payment available; Confirm enabled. |
| **error** | Search/scan errors are **inline** ("no match — try photo browse", "QR not found — enter manually") with a retry/fallback; never a dead-end. A discount-approval network error offers "ask owner in person (PIN)" fallback. |
| **offline** | Calm banner "Working offline — sale will sync". Catalog/quick-pick from cache; sale still confirms and prints; discount uses **on-device owner PIN** (remote approval unavailable — rule 8). |
| **success** | On Confirm: quick success animation → route to receipt (provisional invoice ref); day counter increments optimistically. |
| **permission-denied** | Camera/mic denied → scan/voice show a "grant permission" inline card and fall back to search/browse; discount without approval → Confirm stays blocked for the discounted total (rule 7). |

## 7. Interactions, gestures & hardware
- **Tap** category/product/quick-pick; **tap** `+`/`−`, **long-press** to accelerate qty;
  **tap** the qty number → `NumericPad`.
- **Swipe-left** a cart line to remove (with an **Undo** snackbar — reversible, design-system
  §1/§6).
- **Camera (QR)** via `mobile_scanner` `ScannerOverlay`: live preview, torch toggle, and a
  **manual-entry** fallback if a sticker is torn/unreadable.
- **Mic (voice)** via on-device `speech_to_text`: shows partial transcript; language
  configurable (design-system §10).
- **Bluetooth printer** is not used here — it's on [receipt](./receipt.md).
- **Latency budgets:** add-to-cart **< 100 ms**; screen/sheet transitions **< 200 ms**;
  Confirm→receipt **< 200 ms** (all local, sync §1). QR resolve target < 500 ms including
  camera focus.

## 8. Business rules & edge cases
1. **Never block the sale.** Confirm writes to Drift and shows the receipt instantly; the API
   is fire-and-forget (sync §1–2). No spinner, no error dialog on the critical path.
2. **Confirm-before-commit item retrieval.** Every add-to-cart passes through the
   `ItemConfirmCard` (photo + name + price + qty) — even QR/quick-pick — so a wrong item is
   caught by eye before it enters the cart (R2-B, design-system §1.3).
3. **Right price snapshot.** Each `sale_items` row snapshots `unit_price` (= catalog
   `selling_price`, or a per-line override — rule 3a — at sale time), `gst_rate`, `gst_amount`,
   `line_total`; later catalog price edits do not retroactively change a completed sale.
3a. **Per-line price override.** From the `ItemConfirmCard` or a cart line, staff may retype the
    unit price up or down (§5 row 11a) — no owner PIN, unlike the cart-level discount (rule 7).
    The line is flagged "Custom price · was ₹Y" in the cart and on the receipt, and
    `sale_items.unit_price` simply *is* the overridden value; there is no separate approval
    record. A real backend should still write the override to `audit_log` so the owner can spot
    under/over-selling in review — this prototype has no backend to write it to.
4. **Merge same product.** Selecting an already-in-cart product **at the same unit price**
   increments its line qty rather than adding a duplicate line; a differently-priced add for the
   same product starts its own line so an override never blends into catalog-priced units
   (keeps the cart and stock decrement clean).
5. **Oversold / low stock.** Qty above cached `on_hand` warns but is **allowed**; on sync the
   server records the `sale_out` movement and, if reconciled on-hand `< 0`, still keeps the
   sale, raises an `oversold`/`low_stock` notification, and flags a physical count (sync §5).
   The staff is never stopped from ringing up a real sale.
6. **Tax handling.** GST is computed from each line's `gst_rate` (catalog snapshot);
   `sales.subtotal`, `tax_amount`, `total` follow the shop's inclusive/exclusive config in
   `app_settings` (server authoritative on rounding, api-conventions §1). Receipt shows the
   breakdown.
7. **Discount requires approval.** A sale with `discount_amount > 0` cannot be confirmed
   until an owner approval exists — either `pin_verified=1` on-device (`discount_approvals`)
   or an `approved` remote decision; otherwise Confirm stays blocked **for the discounted
   total** (a `422 BUSINESS_RULE` on the server if bypassed). `sales.discount_approved_by`
   records the approving owner.
8. **Two discount paths.**
   (a) **On-device owner PIN** — owner is on the floor: `PinDialog` → `POST /auth/verify-pin`
   (or local owner PIN check when offline) → apply. Works offline.
   (b) **Remote approval** — owner is away: create a `discount_approvals` row
   (`POST /discount-approvals`, `status=pending`) linked by `sale_client_uuid`; the owner
   approves/rejects from [owner discount-approval](../../owner/approvals/discount-approval.md);
   the sale stays in a "waiting for discount" state (staff may set it aside and bill the next
   customer). Remote path needs connectivity; offline → use path (a) or drop the discount.
9. **Discount floor 🧩.** A discount that drops the line below `cost_price` shows a warning
   ("below cost") — confirm with owner whether to hard-block or allow with a stronger prompt.
10. **Idempotency / exactly-once.** The sale gets a `client_uuid` at Confirm; the outbox
    push and any `POST /sales` carry it as `Idempotency-Key`. Retries/duplicate pushes return
    `DUPLICATE_IGNORED` — never a double sale or double stock decrement (sync §3, §5).
11. **Optimistic local stock decrement.** On Confirm the app inserts a **local**
    `stock_movements(sale_out, −qty)` row and decrements the cached `on_hand` for UX; this is
    a *hint only* — the server recomputes truth from the event log (sync §1.2).
12. **Mid-sale connectivity loss.** Losing the network while building the cart or at Confirm
    changes nothing on the critical path — the sale still writes locally and the chip flips to
    "pending". Only the **remote** discount path (8b) is unavailable; the on-device PIN path
    (8a) still works.
13. **App killed mid-sale.** An **in-progress cart** is persisted to Drift so a crash/kill
    before Confirm can be resumed (or safely discarded); a **confirmed** sale already survives
    in Drift and syncs on relaunch (sync §9 checklist).
14. **Duplicate-item catalog risk.** If two near-identical products exist (a duplicate that
    slipped past entry checks), the `ItemConfirmCard` (photo + `shelf_location` + `color_tag`)
    helps the staff pick the right one; genuine catalog duplicates are resolved upstream by
    [duplicate-detection](../../../foundation/duplicate-detection.md) / the web review queue.
15. **Product not yet synced.** If an offline-created product is sold before its `product`
    create syncs, outbox **FIFO** pushes the product first; a transient server `409 CONFLICT`
    (missing dependency) is retried after the next pull (sync §5 decision table).
16. **Empty / abandoned cart.** Leaving with a non-empty cart prompts a discard confirm;
    discarding writes nothing to `sales` (no orphan rows).
17. **Return to Home shortcut.** Confirm routes to receipt, whose "New Sale" returns here with
    a fresh empty cart and a **new** `client_uuid`.

## 9. API interactions

| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Search / autocomplete | `GET /products?q=&category_id=&color=&shelf=` | fuzzy find items | serve from Drift catalog cache |
| QR scan | `GET /products/by-qr/{internal_qr_code}` | resolve sticker → product | resolve against local cache |
| Open category | `GET /products?category_id=` | product grid | cache |
| Request remote discount 🔒 | `POST /discount-approvals` | owner-away approval flow (linked by `sale_client_uuid`) | **queued/blocked** — needs owner online; offline use on-device PIN |
| Verify owner PIN 🔒 | `POST /auth/verify-pin` | on-device owner approval → `X-Owner-Pin-Token` | offline → local owner PIN check |
| Confirm sale (primary) | outbox → `POST /sync/push` (`entity_type=sale`) | idempotent push of the sale batch | **always local-first**; queued when offline |
| Confirm sale (direct, online) | `POST /sales` | immediate create when connectivity is good | falls back to outbox if it fails |
| Pull back invoice/stock | `GET /sync/pull?since=` | receive server `invoice_no`, reconciled stock, approvals | runs when online |

- The **sale is created through the sync path** (sync §2, §4): the app enqueues a
  `sync_outbox` item and *attempts* an immediate `POST /sync/push` (or `POST /sales`);
  success marks it `synced`, failure/offline leaves it `pending` for the WorkManager worker.
  Both carry the `client_uuid` as `Idempotency-Key` (api-conventions §6). See
  [`sales-api`](../../../cloud/api/sales/sales-api.md),
  [`sync-api`](../../../cloud/api/sync/sync-api.md),
  [`products-api`](../../../cloud/api/products/products-api.md),
  [`auth-api`](../../../cloud/api/auth/auth-api.md).
- **Key push payload fields** (per sync §4): `staff_id`, `gstin_id`, `payment_mode`,
  `items[]{ product_id, quantity, unit_price }`, `discount_amount`, `total`, `sold_at`,
  `client_uuid`, `device_id`. **Key ack fields:** `status (applied|duplicate_ignored|
  rejected)`, `server_id`, `invoice_no`, `reconciled_stock`.

## 10. Offline & sync behavior
- **Fully offline.** Finding items (cache), building the cart, on-device owner-PIN discount,
  Confirm, and printing/sharing the receipt all work with zero connectivity. Only the
  **remote** discount approval (8b) and live invoice-number assignment require the network.
- **Write path on Confirm** (sync §2):
  1. `INSERT` Drift `sales` (`client_uuid`, `sync_status='pending'`, `device_id`, `sold_at`)
     + `sale_items` + a local `stock_movements(sale_out, −qty)` per line.
  2. Optimistically decrement cached `on_hand` (UX hint).
  3. Show receipt (< 100 ms) — user is done.
  4. Fire-and-forget: enqueue `sync_outbox(entity_type='sale', client_uuid, payload_json)` and
     try an immediate push; on success mark `synced` + delete outbox row; on fail leave
     `pending` for WorkManager with exponential backoff.
- **`sync_status` transitions:** `pending → syncing → synced` (or `failed` after retries;
  tap the chip to retry). `DUPLICATE_IGNORED` acks are treated as **success** (sync §4).
- **Invoice number:** shown as a **provisional local ref** until `GET /sync/pull` returns the
  server-assigned `invoice_no` (per `gstin_id` sequence) which is written back onto the local
  sale and the [receipt](./receipt.md) (sync §7).
- **Drift tables:** read `products`, `categories`, `staff` caches, `v_current_stock`-cache;
  write `sales`, `sale_items`, `stock_movements`, `discount_approvals`, `sync_outbox`, and the
  in-progress cart.

### Proposed schema addition (flag for schema owner)
Not in [`data-model.md`](../../../foundation/data-model.md); minor, for the discount UX:

| Addition | Where | Why |
|---|---|---|
| `discount_type ENUM('amount','percent') DEFAULT 'amount'`, `requested_percent DECIMAL(5,2) NULL` | `discount_approvals` | The screen offers **amount or percent** entry. `discount_approvals` stores only `requested_amount`; the data-model note says "or percent — see api". Persisting the original type/percent makes the owner's approval screen show exactly what the staff asked. Until confirmed, the client resolves percent → `requested_amount` and this is `🧩 Derived`. |
| `sale_items.price_overridden BOOLEAN DEFAULT false` | `sale_items` | Rule 3a's per-line price override needs an `audit_log`-visible flag distinguishing "sold at catalog price" from "staff retyped the price" — otherwise the owner can't tell them apart when reviewing `sale_items.unit_price` alone. `🧩 Derived`. |

Favorites feeding the quick-pick reuse the `staff_favorites` addition proposed in
[dashboard](../dashboard/dashboard-home.md) §10.

## 11. Analytics & events
- `new_sale_opened {source}`, `item_retrieval_method {qr|quickpick|category|search|voice}`,
  `item_confirm_shown {product_id}`, `item_added {product_id, qty}`,
  `cart_line_removed {product_id}`, `discount_requested {type, value, path: pin|remote}`,
  `discount_approved {by, path}`, `discount_rejected`, `payment_selected {mode}`,
  `sale_confirmed {client_uuid, total, items, offline}`, `oversold_warning_shown {product_id}`,
  `qr_not_found {code}`, `sale_synced {client_uuid, status}`,
  `price_overridden {product_id, catalog_price, new_price, source: item_confirm|cart_line}`.
- Emit `duplicate_prompt_shown` only if a catalog dup surfaces during retrieval (rare here;
  mostly an entry-time concern).

## 12. Accessibility, localization & performance
- Tap targets: product tiles ≥96 dp; `+`/`−` and payment chips ≥48 dp; Confirm 56 dp,
  bottom-anchored for one-hand use.
- Screen-reader: ItemConfirmCard announces "name, price, GST rate, in stock N"; cart total
  announces on every change; swipe-remove exposes an accessible "remove" action + undo.
- Contrast WCAG AA; stock and sync states use **icon + label**, never color alone
  (design-system §8). Reduce-motion keeps add-to-cart instant but drops the scale animation.
- i18n: ₹ Indian grouping, GST %, DD-MM-YYYY on the receipt handoff; voice-search language
  configurable. Tabular numerals for money.
- Perf budgets: add-to-cart < 100 ms, transitions < 200 ms, Confirm→receipt < 200 ms; catalog
  grid scrolls at 60 fps from cache.

## 13. Acceptance criteria
- [ ] An item can be found and added by **each** of: QR scan, quick-pick, category grid,
      fuzzy search, and voice search — every path ends in the `ItemConfirmCard`.
- [ ] Add-to-cart completes in < 100 ms and the running total updates immediately.
- [ ] Selecting the same product twice **at the same price** merges into one cart line with
      summed qty; at a different overridden price it starts a separate line.
- [ ] Swipe-left removes a cart line and offers Undo.
- [ ] Staff can override a line's unit price, higher or lower than catalog, from either the
      `ItemConfirmCard` or the cart line, with no owner PIN — the line and the receipt flag it
      "Custom price"; resetting it restores the catalog price and clears the flag.
- [ ] A discount cannot be applied without an owner approval (on-device PIN **or** remote
      `approved`); Confirm stays blocked for the discounted total otherwise.
- [ ] Confirming a sale writes to Drift and shows the receipt with **no** network call on the
      critical path, online or offline.
- [ ] The sale carries a `client_uuid`; pushing it 2–3× yields exactly one sale
      (`DUPLICATE_IGNORED` on replays) and one net stock decrement.
- [ ] Selling above cached `on_hand` warns but still completes; after sync an oversold case
      records the sale and raises the oversold flag/notification.
- [ ] Killing the app before Confirm preserves (or safely discards) the in-progress cart;
      killing after Confirm preserves the sale which syncs on relaunch.
- [ ] Losing connectivity mid-sale does not interrupt billing; the sync chip flips to pending.
- [ ] After sync, the server `invoice_no` and reconciled stock are pulled back onto the local
      sale/receipt.

## 14. Related docs
- **Foundation:** [sync-and-conflict-resolution](../../../foundation/sync-and-conflict-resolution.md)
  (critical) · [duplicate-detection](../../../foundation/duplicate-detection.md) ·
  [data-model](../../../foundation/data-model.md) ·
  [design-system](../../../foundation/design-system.md) ·
  [api-conventions](../../../foundation/api-conventions.md) ·
  [overview](../../../foundation/overview.md) ·
  [requirements](../../../requirements_and_prompt.md)
- **API:** [sales-api](../../../cloud/api/sales/sales-api.md) ·
  [sync-api](../../../cloud/api/sync/sync-api.md) ·
  [products-api](../../../cloud/api/products/products-api.md) ·
  [auth-api](../../../cloud/api/auth/auth-api.md) ·
  [duplicate-detection-api](../../../cloud/api/duplicate-detection/duplicate-detection-api.md)
- **Sibling staff screens:** [dashboard-home](../dashboard/dashboard-home.md) ·
  [receipt](./receipt.md) · [my-sales-history](./my-sales-history.md) ·
  [product-search-browse](../catalog/product-search-browse.md)
- **Other surfaces:** [owner discount-approval](../../owner/approvals/discount-approval.md)
