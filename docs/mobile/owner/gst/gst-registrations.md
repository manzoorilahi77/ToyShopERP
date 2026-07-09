# GST Registrations — Owner · Mobile (Owner App)

> Manage the one-or-more **GSTINs** the shop operates under: add / edit each registration
> (GSTIN, legal name, trade name, address, state code) and mark it active / inactive.
> These records drive which registration a sale/purchase is filed under and the IGST vs
> CGST/SGST split at filing.

Status: `✅ Specified` · `🔒` on **deactivate** (filing-integrity action). GSTIN format +
checksum validated on save.

---

## 1. Purpose & context
- **What this screen is for:** keep the shop's tax identities correct so every sale and
  purchase can be attributed to the right registration and compiled at GST time.
- **Who & when:** the **owner** (accountant may edit if designated). Rare edits — at setup,
  when a new registration is obtained, or when one is surrendered.
- **Why it exists:** at filing time the owner "struggles to compile purchase/sales data
  across possibly multiple GST registrations (GSTIN) manually — this must become automatic"
  ([requirements](../../../requirements_and_prompt.md)). A correct, active GSTIN list is the
  prerequisite for that automation.
- **Frequency / criticality:** very low frequency, high criticality — a wrong GSTIN or
  state code corrupts every downstream filing figure and the tax split.

---

## 2. Entry points & navigation
- **More → GST** / **GST** quick-nav chip on
  [Dashboard Home](../dashboard/dashboard-home.md).
- Referenced from [New Purchase](../purchase/new-purchase.md) ("file under GSTIN") and the
  [GST snapshot in Reports](../reports/reports.md) when no active GSTIN exists.

```
Dashboard ─▶ GST Registrations (list) ─┬─▶ Add GSTIN
                                       └─▶ Edit GSTIN · Activate/Deactivate 🔒
```
- **Back:** list → Dashboard; form → list (unsaved-changes confirm).

---

## 3. Roles & permissions
| Actor | Access |
|---|---|
| Owner | ✅ add / edit / activate / deactivate |
| Accountant | ✅ edit if designated `🧩`; deactivate `🔒` still PIN-gated |
| Staff | ❌ |
- **`🔒`** Deactivate (`is_active=0`) requires an owner PIN — it removes a registration from
  selectability for new transactions and affects filing scope. Add/edit are
  owner-authenticated (edits to `gstin`/`state_code` on a registration with existing
  transactions are guarded — see §8).

---

## 4. Screen layout (wireframe)

```
LIST                                    ADD / EDIT GSTIN
┌──────────────────────────────┐        ┌────────────────────────────────────┐
│ ← GST Registrations   ✓sync   │        │ ← Add GSTIN                         │
│ ┌────────────────────────┐    │        │ GSTIN [ 27ABCDE1234F1Z5     ] ✓     │
│ │ 27ABCDE1234F1Z5   🟢   │ ▶ │        │        state 27 · Maharashtra       │
│ │ Sunrise Toys Pvt Ltd    │    │        │ Legal name [ Sunrise Toys Pvt Ltd ] │
│ │ (Sunrise Toys) · MH     │    │        │ Trade name [ Sunrise Toys       ]   │
│ ├────────────────────────┤    │        │ Address    [ 12 MG Road, Pune   ]   │
│ │ 29XYZAB5678K1Z0   🟢   │ ▶ │        │ State code [ 27 ] (auto from GSTIN)  │
│ │ Sunrise Toys (KA branch)│    │        │ Active  [ ● on ]                     │
│ ├────────────────────────┤    │        │ ─────────────────────────────────── │
│ │ 33LMNOP0000Q1Z9   ⚪   │ ▶ │        │ [ Save ]     [ 🔒 Deactivate ]      │
│ │ (inactive)              │    │        └────────────────────────────────────┘
│ └────────────────────────┘    │
│        [ ＋ Add GSTIN ]        │
└──────────────────────────────┘
```

- **Responsive:** phone = list → form (push). Tablet = master-detail split. Small list
  (typically 1–3 rows), so no pagination.

---

## 5. UI components & field-by-field spec

| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | GSTIN row | list row | `gst_registrations` (gstin, legal_name, trade_name, state_code) | — | — | tap → edit | active chip 🟢/⚪ (icon+label) |
| 2 | Add GSTIN | primary button | — | — | — | opens add form | |
| 3 | GSTIN | text (mono, 15) | user | **required**; `CHAR(15)`; format `^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$`; check-digit valid; `UNIQUE` | empty | auto-derives state code + name lookup | `gst_registrations.gstin` |
| 4 | Legal name | text | user | required; ≤150 | — | — | `gst_registrations.legal_name` |
| 5 | Trade name | text | user | optional; ≤150 | — | — | `gst_registrations.trade_name` (nullable) |
| 6 | Address | text | user | required; ≤255 | — | — | `gst_registrations.address` |
| 7 | State code | text (2) | **auto** from GSTIN first 2 digits | required; `CHAR(2)`; must equal GSTIN[0:2] | derived | shows state name hint | `gst_registrations.state_code`; drives IGST vs CGST/SGST |
| 8 | Active toggle | switch | `is_active` | — | on (new) | on = selectable for new txns | turning **off** is `🔒` (see #10) |
| 9 | Save | primary button | — | form valid | — | `POST`/`PATCH /gst/registrations` | idempotent create |
| 10 | Deactivate `🔒` | danger/toggle | owner PIN | PIN verified; no active txns block `🧩` | — | `PATCH …/{id}` `{ is_active:0, owner_pin }` | not selectable afterward; history intact |

**Prose notes**
- **GSTIN validation:** 15 chars = 2-digit **state code** + 10-char PAN + 1 entity digit +
  `Z` (default) + 1 check char. The screen validates the regex **and** the standard GSTIN
  check-digit; the first two digits populate `state_code` automatically and cannot be
  edited independently (they must match).
- **State code drives the tax split:** when a transaction's `gstin_id.state_code` equals the
  counterparty state → **CGST+SGST (intra-state)**; otherwise **IGST (inter-state)**
  ([data-model §2](../../../foundation/data-model.md)). This screen only captures the code;
  the [GST module](../../../cloud/api/gst/gst-api.md) applies the logic.
- **Active vs inactive:** only `is_active=1` registrations appear in the "file under GSTIN"
  picker on [New Purchase](../purchase/new-purchase.md) and in the sales GSTIN assignment.
  Inactive registrations remain on historical transactions and in past-period filings.

---

## 6. States
- **Default / populated:** list of registrations with active chips.
- **Empty:** `EmptyState` "No GST registrations yet — add your GSTIN to start filing"
  (blocks GSTIN-dependent flows until at least one active exists).
- **Loading:** skeleton rows / form.
- **Error:** inline field validation (bad GSTIN format/check-digit, duplicate GSTIN →
  `409`); save error preserves the form.
- **Offline:** browse cached list and add/edit **queued** (`sync_status`-style pending);
  **`🔒` deactivate requires online** (PIN verify) — disabled with a "connect" hint.
- **Success:** toast "GSTIN saved" / "Deactivated."
- **Permission-denied:** accountant without designation is read-only; deactivate blocked
  without owner PIN.

---

## 7. Interactions, gestures & hardware
- **Text entry** for GSTIN (mono, uppercased, 15-char mask); state code auto-fills as the
  first two digits are typed.
- **`PinDialog`** for the `🔒` deactivate action.
- **Tap** a row → edit; **pull-to-refresh** re-loads the small list.
- No camera/printer/scanner.
- **Latency:** list loads < 500 ms; validation is instant (client regex + check-digit).

---

## 8. Business rules & edge cases
1. **GSTIN is unique** (`UNIQUE` constraint); a duplicate returns `409 CONFLICT`.
2. **Format + check-digit** must pass before save; `state_code` must equal GSTIN[0:2].
3. **Deactivate is `🔒`** and reversible; it only stops **new** transactions from selecting
   the registration — history and past filings are unaffected.
4. **Editing `gstin` or `state_code` on a registration that already has transactions** is
   guarded: allowed only with a warning (or blocked, `🧩` confirm-with-owner) because it
   would retroactively change filing attribution; prefer deactivating and adding a new one.
5. **At least one active GSTIN** must exist for sales/purchases to be attributable; if none,
   dependent screens surface a "add a GSTIN first" prompt linking here.
6. **Trade name is optional**; legal name and address are required for filing headers.
7. **Idempotent create** via `client_uuid`; replays don't create duplicate rows.
8. **Audit:** add/edit/deactivate write `audit_log` (`gst.create`, `gst.update`,
   `gst.deactivate`) for traceability.

---

## 9. API interactions

| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| List | `GET /gst/registrations` | all registrations (active + inactive) | cached read |
| Active list (pickers) | `GET /gst/registrations?is_active=1` | selectable GSTINs for txns | cached |
| Create | `POST /gst/registrations` (`Idempotency-Key`=`client_uuid`) | add registration | queued |
| Edit | `PATCH /gst/registrations/{id}` | update names/address (guarded gstin/state) | queued (LWW by `updated_at`) |
| Deactivate `🔒` | `PATCH /gst/registrations/{id}` `{ is_active:0, owner_pin }` | soft state | **online** |

Key fields (see [gst-api](../../../cloud/api/gst/gst-api.md)):
- **create/edit body:** `{ gstin, legal_name, trade_name?, address, state_code }`
- **resp:** `{ id, gstin, legal_name, trade_name, address, state_code, is_active }`
- Errors: `VALIDATION_ERROR` (format/check-digit), `409 CONFLICT` (duplicate GSTIN),
  `403 FORBIDDEN` (deactivate PIN). Envelope per
  [api-conventions](../../../foundation/api-conventions.md).

---

## 10. Offline & sync behavior
- **Works offline:** view cached registrations; add/edit queue as pending and sync FIFO.
- **Blocked offline:** `🔒` deactivate (PIN verify must be live) — avoids stale filing-scope
  changes.
- **LWW:** concurrent edits reconcile last-write-wins by `updated_at`
  ([sync §5](../../../foundation/sync-and-conflict-resolution.md)). GSTINs are reference data;
  they are not part of the high-volume stock outbox.

---

## 11. Analytics & events
- `gst_registrations_viewed`
- `gstin_created` (state_code)
- `gstin_edited`
- `gstin_deactivated` / `gstin_reactivated`
- `gstin_validation_failed` (reason: format | checksum | duplicate)

---

## 12. Accessibility, localization & performance
- GSTIN field uses a monospace mask, auto-uppercase, and reads validity via **icon + text**
  (✓ valid / ! invalid), never color alone.
- Active/inactive shown by icon + label (🟢/⚪).
- State code shown with the resolved state name for confidence; dates **DD-MM-YYYY**.
- Small list loads fast; validation runs client-side (regex + check-digit) with no round-trip.

---

## 13. Acceptance criteria
- [ ] A GSTIN is accepted only if it passes the 15-char format regex and the standard GSTIN
      check-digit, and is unique.
- [ ] `state_code` auto-derives from the GSTIN's first two digits and cannot diverge.
- [ ] Only `is_active=1` registrations appear in the "file under GSTIN" pickers.
- [ ] Deactivating a GSTIN requires an owner PIN and does not alter historical transactions.
- [ ] Editing the GSTIN/state code of a registration with existing transactions is guarded
      with a warning (or blocked pending confirmation).
- [ ] Dependent screens prompt "add a GSTIN first" when no active registration exists.
- [ ] Add/edit work offline (queued); deactivate is blocked offline.
- [ ] Every add/edit/deactivate writes an `audit_log` entry.

---

## 14. Related docs
- Foundation: [data-model](../../../foundation/data-model.md) (`gst_registrations`) ·
  [api-conventions](../../../foundation/api-conventions.md) ·
  [sync](../../../foundation/sync-and-conflict-resolution.md) ·
  [design-system](../../../foundation/design-system.md)
- API: [gst-api](../../../cloud/api/gst/gst-api.md) · [auth-api](../../../cloud/api/auth/auth-api.md)
- Sibling screens: [New Purchase](../purchase/new-purchase.md) ·
  [Reports](../reports/reports.md) · [Dashboard Home](../dashboard/dashboard-home.md)
- Counterpart: [web GST filing](../../../cloud/web/gst/gst-filing.md) ·
  [web settings (GSTIN management)](../../../cloud/web/settings/settings.md)
