# Receipt — Staff · Mobile (Flutter, offline-first)

> Follows [`_templates/screen-doc-template.md`](../../../_templates/screen-doc-template.md).
> Tokens/components from [`design-system.md`](../../../foundation/design-system.md); envelope
> & errors from [`api-conventions.md`](../../../foundation/api-conventions.md); invoice
> numbering & provisional refs from [`sync-and-conflict-resolution.md`](../../../foundation/sync-and-conflict-resolution.md) §7.
> Legend: `✅ Specified` · `🧩 Derived (confirm with owner)` · `⚠️ Risk` · `🔒 Owner PIN`.

---

## 1. Purpose & context
- **What it is** — the post-sale screen: a clean **receipt preview** (shop header, GSTIN,
  invoice number, line items with GST breakdown, discount, total, payment mode, staff,
  timestamp) with three actions — **Share via WhatsApp**, **Print via Bluetooth thermal
  printer**, and **New Sale**.
- **Who & when** — staff, immediately after confirming a sale in [new-sale](./new-sale.md),
  or when re-opening a past sale from [my-sales-history](./my-sales-history.md).
- **Why it exists** — the customer expects a bill; the shop needs a GST-compliant record. It
  must produce a receipt **instantly and offline** (with a provisional invoice number) so the
  queue keeps moving, and print reliably on cheap Bluetooth thermal hardware.
- **Frequency / criticality** — once per sale (dozens–hundreds/day). Correctness matters
  (GST/amounts on a tax document) but the flow is already committed — this screen renders and
  outputs; it never changes the sale.

## 2. Entry points & navigation
- **Arrive from:** [new-sale](./new-sale.md) on Confirm (fresh receipt); a row tap in
  [my-sales-history](./my-sales-history.md) (historical receipt).
- **Exit to:** **New Sale** → [new-sale](./new-sale.md) (fresh empty cart, new `client_uuid`);
  back → returns to the origin (dashboard after a fresh sale, history if opened from there).
- **Back button:** from a fresh sale → [dashboard](../dashboard/dashboard-home.md) (the sale
  is already saved; back does not undo it).

```
New Sale ─confirm─▶ Receipt ─┬─ Share (WhatsApp)
                             ├─ Print (Bluetooth thermal)
                             └─ New Sale ─▶ (fresh sale)
My Sales History ─tap row──▶ Receipt (read-only reprint)
```

## 3. Roles & permissions
- **Open to:** the selling `staff` (own sale) and owner/accountant (any sale, e.g. from
  ledgers). Read-only rendering; no edits to `sales`/`sale_items` here.
- **No `🔒` gate** on this screen. A **void/refund** is out of scope for staff and lives in
  owner/web tooling; this screen only reprints/shares.

## 4. Screen layout (wireframe)

```
┌──────────────────── Receipt ─────────────── ✓ synced ─┐
│  ┌──────────────── preview (paper look) ─────────────┐ │
│  │            ToyShop Kids World                      │ │
│  │        12 Bazaar Road, Chennai 600001              │ │
│  │        GSTIN: 33AAAAA0000A1Z5                      │ │
│  │        ────────────────────────────               │ │
│  │  Invoice: GST1/26-27/000418   (or "Prov #A3F9")   │ │
│  │  Date: 02-07-2026  19:45      Staff: Ravi          │ │
│  │  ────────────────────────────────────             │ │
│  │  Item            Qty  Rate    GST%   Amount        │ │
│  │  Red Racer Car    2  1499.00   18%  2998.00        │ │
│  │  Mini Jeep        1  1999.00   18%  1999.00        │ │
│  │  Doll House       2   750.00   12%  1500.00        │ │
│  │  ────────────────────────────────────             │ │
│  │  Subtotal (taxable)               5,506.78         │ │
│  │  CGST                               492.61         │ │
│  │  SGST                               492.61         │ │
│  │  Discount                          − 0.00          │ │
│  │  ══════════════════════════════════               │ │
│  │  TOTAL                            ₹ 6,497.00        │ │
│  │  Paid: CASH                                        │ │
│  │        Thank you! Visit again 🧸                   │ │
│  └────────────────────────────────────────────────────┘│
│                                                         │
│  🖨 Printer: "RPP02" connected ✓        [ change ]      │
│  ┌───────────┐ ┌───────────┐ ┌───────────────────────┐ │
│  │  🖨 Print  │ │ 📤 Share  │ │    ＋ New Sale         │ │
│  └───────────┘ └───────────┘ └───────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

The preview mirrors the physical 58 mm / 80 mm thermal layout. Actions are bottom-anchored
(design-system §5). Provisional vs server invoice number is shown per rule 3/§10.

## 5. UI components & field-by-field spec

| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Shop header | static text | active `gst_registrations.legal_name`/`trade_name`, `address` (cache) | — | shop details | — | from the sale's `gstin_id` |
| 2 | GSTIN | text | `gst_registrations.gstin` for `sales.gstin_id` | valid 15-char | — | — | the registration the sale is under |
| 3 | Invoice no | text | `sales.invoice_no` (server) **or** provisional local ref | — | provisional until synced | swaps to real `invoice_no` after pull | labeled "Prov #…" while pending (rule 3) |
| 4 | Date/time | text | `sales.sold_at` | — | — | — | DD-MM-YYYY HH:mm |
| 5 | Staff | text | `staff.name` for `sales.staff_id` | — | — | — | attribution |
| 6 | Line items | table | `sale_items` (`quantity`, `unit_price`, `gst_rate`, `gst_amount`, `line_total`) | — | — | — | one row per product |
| 7 | GST breakdown | computed rows | per-line `gst_amount` split CGST/SGST or IGST by `state_code` | — | — | — | intra-state → CGST+SGST; inter-state → IGST |
| 8 | Discount | ₹ row | `sales.discount_amount` (+ `discount_approved_by`) | — | ₹0 | shown only if > 0 | approver traceable |
| 9 | Total | Display ₹ | `sales.total` | — | — | — | tabular, ₹ grouping |
| 10 | Payment mode | chip/text | `sales.payment_mode` | — | — | — | CASH / UPI / CARD |
| 11 | Printer status | chip | Bluetooth (`esc_pos_bluetooth`) | — | last-paired or "none" | pairing/connect states (§6) | tap → printer picker |
| 12 | **Print** | button | selected printer | printer connected | — | render → ESC/POS bytes → send | retry on failure (rule 6) |
| 13 | **Share** | button | native share → WhatsApp | — | — | build image/PDF → share sheet | works offline (local file) |
| 14 | **New Sale** | primary | — | — | — | → [new-sale](./new-sale.md) fresh cart | fastest path back to billing |
| 15 | `SyncStatusChip` | status | sync worker | — | current | tap → sync sheet | shows if this sale still pending |
| 16 | Change printer | link | paired devices | — | — | opens BT device list | pair/connect flow |

## 6. States

Screen-level plus **printer sub-states**.

| State | What the user sees / can do |
|---|---|
| **default / populated** | Full receipt preview + actions; printer chip shows last connection. |
| **empty** | N/A (a receipt always has a backing sale; a missing sale from a bad deep link shows an error state). |
| **loading** | Rendering the preview/print image → brief skeleton on the preview only; actions enable when ready. |
| **error** | Failed to load a historical sale → inline "couldn't load receipt — retry". Share/print errors are inline with retry (never lose the sale). |
| **offline** | Banner "Working offline"; invoice shows **provisional** ref; Share (local file) and Print (BT is local) both **fully work**; the real `invoice_no` fills in after sync. |
| **success** | Toast "Printed" / "Shared"; chip confirms sync when the sale is `synced`. |
| **permission-denied** | Bluetooth/nearby-devices permission denied → inline card "allow Bluetooth to print" with a settings shortcut; Share still available. |

**Printer sub-states** (Bluetooth thermal, `esc_pos_bluetooth`):

| Printer state | UI | Action |
|---|---|---|
| **no printer paired** | chip "No printer" | tap → OS/BT pair flow → device list |
| **paired, disconnected** | chip "RPP02 — tap to connect" | tap → connect |
| **connecting** | chip spinner "connecting…" | cancel |
| **connected** | chip "RPP02 ✓" | Print enabled |
| **printing** | button spinner "printing…" | — |
| **print failed** | inline "print failed — retry" (out of paper / out of range / connection lost) | Retry / reconnect / share instead |
| **paper likely out** 🧩 | hint after a failed feed | reload paper, retry |

## 7. Interactions, gestures & hardware
- **Tap** Print / Share / New Sale; **tap** the printer chip to pair/connect/change.
- **Bluetooth thermal printer** via `esc_pos_bluetooth` / `blue_thermal_printer`: the app
  builds an **ESC/POS** byte stream sized to the paper width (58 mm ≈ 32 chars, 80 mm ≈ 48
  chars), sends over the paired RFCOMM/BLE channel. Torn/receipt image for Share is rendered
  to PNG/PDF.
- **WhatsApp share** via the native share sheet (`share_plus`): passes a rendered
  image/PDF; no phone number required (customer picks the chat) — works offline (local file).
- **Latency budgets:** preview paints < 200 ms; print job dispatched < 1 s after tap on a
  connected printer; Share sheet opens < 500 ms.

## 8. Business rules & edge cases
1. **Read-only.** This screen never mutates `sales`/`sale_items`; it renders and outputs.
2. **Provisional vs server invoice.** Offline/pending sales show a **provisional local ref**
   (derived from `client_uuid`, e.g. "Prov #A3F9"); once `GET /sync/pull` returns the
   server-assigned `sales.invoice_no` (gapless per `gstin_id` sequence, sync §7) the preview
   and any reprint show the **real** number. A reprint after sync shows the real invoice.
3. **GST split.** CGST+SGST for intra-state (`gst_registrations.state_code` == customer/POS
   state) or IGST for inter-state; amounts derive from each line's `gst_amount`. Rounding is
   server-authoritative (api-conventions §1) — the offline preview may differ by ≤ paise until
   sync reconciles, so the printed total always equals `sales.total`.
4. **Discount line** appears only when `discount_amount > 0`, with the approving owner traceable
   via `discount_approved_by` (not printed to the customer, but in the record).
5. **Print failure is recoverable.** Out-of-paper / out-of-range / disconnected → inline retry;
   the sale is unaffected. Staff can **Share** instead and print later from history.
6. **Idempotent print.** Re-printing does not create a new sale or invoice; it re-renders the
   same record (safe to print twice for shop + customer copies).
7. **Reprint from history.** Opening a past sale from [my-sales-history](./my-sales-history.md)
   shows its final invoice number and allows re-print/re-share.
8. **Multiple GSTIN.** The header/GSTIN reflect the sale's `gstin_id`, not a global default, so
   receipts stay correct across registrations.
9. **Voided/oversold sale** (post-sync flags) — a receipt for a sale later flagged oversold
   still prints (the goods left); the flag is an inventory/notification concern, not a receipt
   block (sync §5).
10. **No printer available** — Share is always a fallback; the shop can also print later; the
    sale never depends on hardware being present.

## 9. API interactions

| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Render fresh receipt | (local) reads Drift `sales` + `sale_items` | build preview | fully local |
| Fill real invoice no | `GET /sync/pull?since=` | receive server `invoice_no`, `synced` status | runs when online; provisional until then |
| Load historical receipt | `GET /sales/{id}` *(or local cache)* | fetch a past sale for reprint | reads Drift cache when offline |

- No write endpoints originate here — the sale was already created by
  [new-sale](./new-sale.md) via the sync outbox (`POST /sync/push` / `POST /sales`). See
  [`sales-api`](../../../cloud/api/sales/sales-api.md) and
  [`sync-api`](../../../cloud/api/sync/sync-api.md). Envelope/errors per
  [`api-conventions.md`](../../../foundation/api-conventions.md).

## 10. Offline & sync behavior
- **Fully offline.** Preview, Print (Bluetooth is a local peripheral), and Share (local
  file) all work with no connectivity. Only the **real invoice number** waits on sync.
- The receipt reads the local Drift `sales`/`sale_items` written by New Sale; it does not set
  any `sync_status` itself. When the backing sale flips `pending → synced` (sync §8) and the
  pull returns `invoice_no`, this screen updates the displayed number live if open, and on any
  future reprint.
- Drift tables read: `sales`, `sale_items`, `gst_registrations` cache, `staff` cache. Printer
  pairing/last-device is a **local device preference** (no server schema).

### Proposed schema addition
None required. The provisional invoice ref is a **client-side display** derived from
`sales.client_uuid` (Drift only) — no server column is needed;
`sales.invoice_no` already carries the authoritative value once assigned.

## 11. Analytics & events
- `receipt_shown {client_uuid, provisional}`, `receipt_printed {client_uuid, printer_ok}`,
  `print_failed {reason: no_paper|out_of_range|disconnected|other}`,
  `receipt_shared {client_uuid, channel: whatsapp}`, `printer_paired {model}`,
  `printer_connect {result}`, `new_sale_from_receipt`.

## 12. Accessibility, localization & performance
- Buttons ≥48 dp; New Sale emphasized. Screen-reader reads the receipt as a structured list
  (item, qty, rate, amount, totals) and announces printer status changes.
- Contrast WCAG AA; printer state uses **icon + label**. Preview uses tabular numerals; ₹ with
  Indian grouping; date DD-MM-YYYY; GST terms (CGST/SGST/IGST, HSN) localizable.
- The ESC/POS render supports the configured paper width and an optional shop logo bitmap;
  keep the byte stream small for fast printing.
- Perf: preview < 200 ms; print dispatch < 1 s on a connected printer.

## 13. Acceptance criteria
- [ ] The preview shows shop name, address, correct GSTIN (from the sale's `gstin_id`),
      invoice number, date/time, staff, line items with per-line GST, discount (if any),
      total, and payment mode.
- [ ] Offline, the invoice shows a clearly-labeled provisional ref, and after sync it updates
      to the server `invoice_no` on the next view/reprint.
- [ ] GST is split CGST+SGST (intra-state) or IGST (inter-state) and the printed total equals
      `sales.total`.
- [ ] Print sends an ESC/POS job to a connected Bluetooth thermal printer; a print failure
      shows an inline retry and never alters the sale.
- [ ] Share opens the native sheet with a rendered receipt image/PDF and works offline.
- [ ] Re-printing/re-sharing does not create a new sale or invoice.
- [ ] New Sale returns to a fresh empty billing screen with a new `client_uuid`.
- [ ] Bluetooth/printer states (none/disconnected/connecting/connected/printing/failed) are
      each represented with icon + label.

## 14. Related docs
- **Foundation:** [sync-and-conflict-resolution](../../../foundation/sync-and-conflict-resolution.md)
  (invoice numbering §7) · [data-model](../../../foundation/data-model.md) ·
  [design-system](../../../foundation/design-system.md) ·
  [api-conventions](../../../foundation/api-conventions.md) ·
  [overview](../../../foundation/overview.md)
- **API:** [sales-api](../../../cloud/api/sales/sales-api.md) ·
  [sync-api](../../../cloud/api/sync/sync-api.md) ·
  [gst-api](../../../cloud/api/gst/gst-api.md)
- **Sibling staff screens:** [new-sale](./new-sale.md) ·
  [my-sales-history](./my-sales-history.md) · [dashboard-home](../dashboard/dashboard-home.md)
