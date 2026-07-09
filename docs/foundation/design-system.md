# Foundation — Design System & UX Laws

The shared visual + interaction language for all three surfaces. Screen docs reference
these tokens and components instead of redefining them. The north star: a non-technical
19-year-old can bill correctly on day 3, fast, under pressure, without errors.

---

## 1. UX laws (non-negotiable, apply everywhere)

1. **Speed beats features on the sales floor.** Add-to-cart < 100 ms, screen transitions
   < 200 ms. Never show a spinner on the billing critical path (offline-first).
2. **Photo/QR/tap over typing.** Typing is the last resort. Every product action leads
   with an image and a big tap target.
3. **Confirm before commit.** A photo + name + price confirmation card precedes add-to-cart;
   a summary precedes every sale/purchase confirm.
4. **Forgiving, not punishing.** No blocking error dialogs mid-sale. Undo > confirm-dialogs
   where possible. Mistakes are reversible and traceable.
5. **Glanceable for the owner.** Big numbers, few per screen, high contrast, minimal chrome.
6. **Consistent across surfaces.** Same colors/icons/terms on staff, owner, web so muscle
   memory transfers.

---

## 2. Color tokens

| Token | Light | Dark | Use |
|---|---|---|---|
| `--primary` | `#2563EB` | `#3B82F6` | primary actions, active nav |
| `--primary-ink` | `#FFFFFF` | `#0B1220` | text on primary |
| `--success` | `#16A34A` | `#22C55E` | synced, sale confirmed, positive KPIs |
| `--warning` | `#D97706` | `#F59E0B` | pending sync, aging stock, low stock |
| `--danger` | `#DC2626` | `#EF4444` | errors, sync failed, oversold, reject |
| `--info` | `#0891B2` | `#06B6D4` | hints, discount pending |
| `--bg` | `#F8FAFC` | `#0B1220` | app background |
| `--surface` | `#FFFFFF` | `#111827` | cards |
| `--ink` | `#0F172A` | `#E5E7EB` | primary text |
| `--ink-muted` | `#64748B` | `#94A3B8` | secondary text |
| `--border` | `#E2E8F0` | `#1F2937` | dividers |

> Colors are **placeholders** — swap for the shop's brand before launch. Every pair must
> pass WCAG AA (4.5:1 text). Never encode meaning with color alone (add icon + label).

Category tiles use `categories.color_hex`; product chips use `products.color_tag` as a
searchable/visual cue, not as the only differentiator.

## 3. Typography
- Family: Inter / system default. Numerals **tabular** for money & counters.
- Scale: `Display 34/40 bold` (KPI numbers) · `H1 24` · `H2 20` · `Title 17` ·
  `Body 15` · `Label 13` · `Caption 12`.
- Money always shows `₹` + thousands separators (Indian grouping `1,23,456.00`).

## 4. Spacing, radius, elevation
- 4-pt grid: `4 / 8 / 12 / 16 / 24 / 32`. Screen padding 16 (mobile), 24–32 (web).
- Radius: `sm 8 · md 12 · lg 16 · pill 999`. Cards `md`, sheets `lg`.
- Elevation: flat surfaces + subtle shadow on cards; modals/sheets one step up.

## 5. Tap targets & ergonomics
- **Minimum 48×48 dp** for any tap target; primary sale actions 56 dp tall.
- Thumb-reachable primary actions at the **bottom** of mobile screens.
- Product grid tiles ≥ 96 dp with image + name + price; 2 cols phone, 3–4 tablet.

## 6. Core shared components

| Component | Where used | Key behavior |
|---|---|---|
| `AppScaffold` | all | title, sync indicator (top-right), role-based nav |
| `SyncStatusChip` | all | states from [sync doc](sync-and-conflict-resolution.md) §8 |
| `CategoryGrid` | staff sale/browse | tap category → product grid |
| `ProductTile` | catalog/sale | image + name + price; long-press = quick info |
| `ItemConfirmCard` | sale/purchase | photo + name + price + qty stepper → Add/Cancel |
| `QuickPickStrip` | staff home/sale | recent/frequent items, 1-tap add (80/20) |
| `CartSheet` | sale | running total always visible, swipe-to-remove line |
| `NumericPad` | PIN, qty, cash | large keys, no OS keyboard |
| `KpiCard` | dashboards | big tabular number + label + trend arrow |
| `AlertTile` | dashboards | low/aging stock, tap → drill-down |
| `DataTable` (web) | ledgers | sort, filter, sticky header, CSV/XLSX export |
| `PinDialog` | 🔒 actions | 4–6 digit, masked, owner approval |
| `EmptyState` | lists | friendly illustration + primary action |
| `ScannerOverlay` | QR/barcode | live camera, torch, manual entry fallback |
| `VoiceSearchButton` | search | on-device STT, shows partial transcript |

## 7. States (every screen must define all)
`default · empty · loading (skeletons, not blank) · populated · error (inline, retry) ·
offline (banner + queued badge) · success (toast/confirmation) · permission-denied`.

Loading uses **skeletons**; errors are **inline + retry**, never dead-ends. Offline shows
a calm banner ("Working offline — sales saved, will sync") not a red error.

## 8. Iconography & status language
- Sync: ✓ synced · ↻ syncing · • pending · ! failed (§ sync doc).
- Stock: 🟢 healthy · 🟠 low · 🔴 out/oversold · ⏳ aging.
- Never rely on color alone — pair with icon + text label (accessibility).

## 9. Motion
- 150–250 ms ease-out for transitions; add-to-cart uses a quick scale+fade so it feels
  instant. Respect "reduce motion" OS setting.

## 10. Accessibility & localization
- WCAG AA contrast; 48 dp targets; dynamic type support; screen-reader labels on icons.
- Localizable strings (English + regional as needed); ₹, Indian number grouping, GST
  terms, DD-MM-YYYY dates. Voice search language configurable.

## 11. Platform notes
- **Staff/Owner mobile:** bottom nav, one-hand use, hardware (camera/printer/mic).
- **Web:** left sidebar nav, dense tables, keyboard shortcuts, multi-column, export-first.

## 12. Related docs
- [overview.md](overview.md) · consumed by every screen doc in `mobile/` and `cloud/web/`.
