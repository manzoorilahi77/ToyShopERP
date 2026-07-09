# GST API

> Base URL, auth, the response envelope, error codes, pagination and `?format=` export
> are defined once in [api-conventions.md](../../../foundation/api-conventions.md) — this
> doc references, does not repeat them.

---

## 1. Overview

The GST module turns the shop's raw `sales` and `purchases` into **filing-ready Indian GST
numbers** across possibly **multiple GST registrations (GSTIN)**. It replaces the owner's
manual month-end spreadsheet compilation (R4 GST Filing Flow) with:

- **Registrations CRUD** — manage the shop's GSTINs, mark active/inactive.
- **Period summary** — outward supply, output GST liability, input tax credit (ITC), net payable.
- **GSTR-1 export** — outward supplies (sales) as CSV/Excel, portal/CA-ready.
- **GSTR-3B export** — the consolidated monthly summary.
- **Reconciliation** — flags purchases **missing a supplier GSTIN** (ITC-claim risk) so the
  owner can chase the supplier before filing.

Callers: mostly **Owner Web** ([web/gst-filing](../../web/gst/gst-filing.md)) at filing
season; Owner App has a condensed snapshot ([owner/gst-registrations](../../../mobile/owner/gst/gst-registrations.md)).

**Indian GST context this module encodes:**
- Money in **₹**, `DECIMAL`. `gst_rate` ∈ {0, 5, 12, 18, 28} %.
- **CGST + SGST** for **intra-state** supply; **IGST** for **inter-state**. Split is driven
  by `state_code` (first 2 digits of the GSTIN).
- **HSN** summary rolls line items up by `products.hsn_code`.
- Period is `YYYY-MM` (monthly) or `YYYY-Qn` (quarterly, QRMP filers).

---

## 2. Data model touched

Canonical names from [data-model.md](../../../foundation/data-model.md):

| Table | Role | R/W |
|---|---|---|
| `gst_registrations` | the shop's GSTINs — `gstin`, `legal_name`, `trade_name`, `address`, `state_code`, `is_active` | read + write (CRUD) |
| `sales` + `sale_items` | **outward supplies** — `tax_amount`, `sale_items.gst_rate`, `gst_amount` | read |
| `purchases` + `purchase_items` | **inward supplies / ITC** — `total_gst`, `supplier_gstin`, `purchase_items.gst_rate`, `gst_amount` | read |
| `products` | `hsn_code`, `gst_rate` (for HSN summary) | read |
| `suppliers` | `name`, `gstin` (reconciliation follow-up) | read |
| `audit_log` | registration create/edit/deactivate | write |

**Sources of truth:** `sales`/`purchases` are authoritative for amounts. GST splits
(CGST/SGST/IGST) are **derived at query time** from `gst_amount` + `state_code`, not stored
per-line (see §5 and the Proposed schema addition).

> **Proposed schema addition (place of supply).** The canonical `sales` table has **no
> customer/place-of-supply state**. For correct inter-state (IGST) determination on the rare
> B2B / out-of-state sale, add `sales.place_of_supply_state_code CHAR(2) NULL`. Until then,
> retail B2C sales are treated as **intra-state** (place of supply = the registration's
> `state_code`) → CGST + SGST. This is called out wherever it affects a number below.

---

## 3. Auth & permissions

| Endpoint | staff | owner | accountant |
|---|---|---|---|
| `GET /gst/registrations` | ❌ | ✅ | ✅ |
| `POST /gst/registrations` | ❌ | ✅ | 🧩 |
| `PATCH /gst/registrations/{id}` | ❌ | ✅ | 🧩 |
| `GET /gst/summary` | ❌ | ✅ | ✅ |
| `GET /gst/gstr1` | ❌ | ✅ | ✅ |
| `GET /gst/gstr3b` | ❌ | ✅ | ✅ |
| `GET /gst/reconciliation` | ❌ | ✅ | ✅ |

All GST endpoints are **owner/accountant only** — never exposed to the staff flavor. JWT +
`X-Device-Id` as usual.

---

## 4. Endpoints

### `GET /gst/registrations`

- **Purpose** — list the shop's GST registrations.
- **Auth** — owner/accountant.
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `is_active` | query | bool | no | — | filter active/inactive |

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `data[].id` | int | `gstin_id` used by other endpoints & `sales`/`purchases` |
| `data[].gstin` | string(15) | e.g. `29AABCT1234K1Z5` |
| `data[].legal_name` | string | |
| `data[].trade_name` | string / null | |
| `data[].address` | string | |
| `data[].state_code` | string(2) | first 2 digits of GSTIN |
| `data[].is_active` | bool | inactive = not selectable for new txns |

```json
{ "ok": true, "data": [
  { "id": 1, "gstin": "29AABCT1234K1Z5", "legal_name": "Little Wheels Traders",
    "trade_name": "ToyShop", "address": "12 MG Rd, Bengaluru",
    "state_code": "29", "is_active": true }
], "meta": { "request_id": "req_g10" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | ok |
| 403 | `FORBIDDEN` | staff role |

---

### `POST /gst/registrations`

- **Purpose** — add a new GSTIN.
- **Auth** — owner (accountant 🧩).
- **Idempotency** — N/A (small, rare write; `gstin` UNIQUE guards accidental double-add).
- **Request body**

| Field | Type | Required | Validation | Notes |
|---|---|---|---|---|
| `gstin` | string(15) | yes | format `^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$`, UNIQUE | 15-char GSTIN |
| `legal_name` | string | yes | ≤ 150 | |
| `trade_name` | string | no | ≤ 150 | |
| `address` | string | yes | ≤ 255 | |
| `state_code` | string(2) | no | must equal first 2 chars of `gstin` | auto-derived if omitted |
| `is_active` | bool | no | default `true` | |

- **Response `201`** — the created registration (same shape as list row).

```json
// Request
{ "gstin": "27AABCT1234K1Z2", "legal_name": "Little Wheels Traders",
  "trade_name": "ToyShop Pune", "address": "5 FC Rd, Pune" }
// Response 201
{ "ok": true, "data": {
  "id": 2, "gstin": "27AABCT1234K1Z2", "legal_name": "Little Wheels Traders",
  "trade_name": "ToyShop Pune", "address": "5 FC Rd, Pune",
  "state_code": "27", "is_active": true },
  "meta": { "request_id": "req_g11" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 201 | — | created |
| 400 | `VALIDATION_ERROR` | bad GSTIN format / `state_code` mismatch |
| 403 | `FORBIDDEN` | role not owner/accountant |
| 409 | `CONFLICT` | `gstin` already registered |

---

### `PATCH /gst/registrations/{id}`

- **Purpose** — edit registration details or toggle active/inactive.
- **Auth** — owner (accountant 🧩).
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Notes |
|---|---|---|---|---|
| `id` | path | int | yes | registration id |

- **Request body** — any subset of: `legal_name`, `trade_name`, `address`, `is_active`.
  `gstin` and `state_code` are **immutable** (a new GSTIN = a new registration row) →
  `422 BUSINESS_RULE` if sent.

- **Response `200`** — updated registration.

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | updated |
| 403 | `FORBIDDEN` | role |
| 404 | `NOT_FOUND` | no such registration |
| 422 | `BUSINESS_RULE` | attempt to change `gstin`/`state_code`; or deactivate a GSTIN with open (unfiled) draft txns 🧩 |

---

### `GET /gst/summary`

- **Purpose** — the **filing dashboard numbers** for one GSTIN + period: outward supply
  total, output GST liability, input tax credit, net GST payable, with CGST/SGST/IGST split
  and an HSN roll-up (R4 step 2).
- **Auth** — owner/accountant.
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `gstin_id` | query | int | yes | — | which registration |
| `period` | query | string | yes | — | `YYYY-MM` **or** `YYYY-Qn` (e.g. `2026-06`, `2026-Q1`) |
| `include_hsn` | query | bool | no | `true` | include HSN summary block |

> Period resolves to an inclusive business-date range on `sales.sold_at` (outward) and
> `purchases.invoice_date` (inward). `YYYY-Qn` uses the **GST financial-year quarter**
> (Q1 = Apr–Jun).

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `gstin_id` | int | |
| `gstin` | string | |
| `period` | string | echoed |
| `outward.taxable_value` | decimal | Σ sale taxable value (pre-tax) |
| `outward.cgst` | decimal | intra-state half of output tax |
| `outward.sgst` | decimal | intra-state half |
| `outward.igst` | decimal | inter-state output tax (0 for pure B2C intra-state) |
| `outward.total_tax` | decimal | = `Σ sales.tax_amount` = cgst+sgst+igst |
| `outward.invoice_count` | int | number of sales |
| `inward.taxable_value` | decimal | Σ purchase subtotal |
| `inward.cgst` / `inward.sgst` / `inward.igst` | decimal | ITC split |
| `inward.total_itc` | decimal | = `Σ purchases.total_gst` (eligible ITC) |
| `inward.itc_at_risk` | decimal | ITC on purchases with **missing supplier_gstin** (not yet claimable) |
| `net_payable.cgst` / `sgst` / `igst` | decimal | `max(output − itc, 0)` per head |
| `net_payable.total` | decimal | net GST cash payable |
| `rate_breakup[]` | array | per `gst_rate`: `{ rate, taxable_value, tax }` |
| `hsn_summary[]` | array | per HSN: `{ hsn_code, description, quantity, taxable_value, cgst, sgst, igst }` |

```json
{ "ok": true, "data": {
  "gstin_id": 1, "gstin": "29AABCT1234K1Z5", "period": "2026-06",
  "outward": { "taxable_value": 812500.00, "cgst": 73125.00, "sgst": 73125.00,
               "igst": 0.00, "total_tax": 146250.00, "invoice_count": 418 },
  "inward":  { "taxable_value": 401000.00, "cgst": 36090.00, "sgst": 36090.00,
               "igst": 0.00, "total_itc": 72180.00, "itc_at_risk": 5400.00 },
  "net_payable": { "cgst": 37035.00, "sgst": 37035.00, "igst": 0.00, "total": 74070.00 },
  "rate_breakup": [
    { "rate": 18.00, "taxable_value": 700000.00, "tax": 126000.00 },
    { "rate": 12.00, "taxable_value": 112500.00, "tax": 13500.00 }
  ],
  "hsn_summary": [
    { "hsn_code": "9503", "description": "Toys, ride-on", "quantity": 512,
      "taxable_value": 812500.00, "cgst": 73125.00, "sgst": 73125.00, "igst": 0.00 }
  ]
}, "meta": { "request_id": "req_g20" } }
```

- **Status codes & errors**

| HTTP | `error.code` | When |
|---|---|---|
| 200 | — | ok |
| 400 | `VALIDATION_ERROR` | missing/badly-formatted `period`; missing `gstin_id` |
| 403 | `FORBIDDEN` | staff role |
| 404 | `NOT_FOUND` | no such `gstin_id` |
| 422 | `BUSINESS_RULE` | period in the future / registration inactive for whole period 🧩 |

---

### `GET /gst/gstr1`

- **Purpose** — **GSTR-1 outward-supplies** export: the detailed sales dataset for a GSTIN +
  period, formatted for the GST portal or CA hand-off (R4 step 3).
- **Auth** — owner/accountant.
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `gstin_id` | query | int | yes | — | |
| `period` | query | string | yes | — | `YYYY-MM` / `YYYY-Qn` |
| `format` | query | enum | no | `xlsx` | `json \| csv \| xlsx` (default export = Excel) |
| `section` | query | enum | no | `all` | `b2c \| hsn \| docs \| all` — GSTR-1 tables |

- **Response `200`** — JSON preview (when `format=json`) or a streamed file (`csv`/`xlsx`)
  with `Content-Disposition`. JSON shape mirrors GSTR-1 tables:

| Field | Type | Notes |
|---|---|---|
| `b2c_summary[]` | array | rate-wise B2C(S): `{ place_of_supply, rate, taxable_value, cgst, sgst, igst }` |
| `hsn_summary[]` | array | `{ hsn_code, description, uqc, quantity, taxable_value, rate, cgst, sgst, igst }` |
| `docs_issued` | object | invoice number range issued this period: `{ from_no, to_no, count, cancelled }` |
| `totals` | object | `{ taxable_value, cgst, sgst, igst, total_tax }` |

```json
{ "ok": true, "data": {
  "b2c_summary": [
    { "place_of_supply": "29", "rate": 18.00, "taxable_value": 700000.00,
      "cgst": 63000.00, "sgst": 63000.00, "igst": 0.00 }
  ],
  "hsn_summary": [
    { "hsn_code": "9503", "description": "Toys, ride-on", "uqc": "PCS",
      "quantity": 512, "taxable_value": 812500.00, "rate": 18.00,
      "cgst": 73125.00, "sgst": 73125.00, "igst": 0.00 }
  ],
  "docs_issued": { "from_no": "GST1/26-27/000001", "to_no": "GST1/26-27/000418",
                   "count": 418, "cancelled": 0 },
  "totals": { "taxable_value": 812500.00, "cgst": 73125.00, "sgst": 73125.00,
              "igst": 0.00, "total_tax": 146250.00 }
}, "meta": { "request_id": "req_g30" } }
```

- **Status codes & errors** — same table as `/gst/summary`.

---

### `GET /gst/gstr3b`

- **Purpose** — **GSTR-3B summary** export: the consolidated liability/ITC return for a
  GSTIN + period (R4 step 3).
- **Auth** — owner/accountant.
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `gstin_id` | query | int | yes | — | |
| `period` | query | string | yes | — | `YYYY-MM` / `YYYY-Qn` |
| `format` | query | enum | no | `xlsx` | `json \| csv \| xlsx` |

- **Response `200`** — GSTR-3B table structure:

| Field | Type | Notes |
|---|---|---|
| `table_3_1.outward_taxable` | object | 3.1(a): `{ taxable_value, igst, cgst, sgst }` |
| `table_3_1.nil_exempt` | decimal | 3.1(c) if any 0% lines |
| `table_4.itc_available` | object | 4(A)(5): `{ igst, cgst, sgst }` all-other-ITC |
| `table_4.itc_ineligible` | object | ITC at risk (missing supplier GSTIN) surfaced here 🧩 |
| `table_6_1.net_payable` | object | `{ igst, cgst, sgst, total }` cash payable |

```json
{ "ok": true, "data": {
  "table_3_1": { "outward_taxable": { "taxable_value": 812500.00, "igst": 0.00,
                 "cgst": 73125.00, "sgst": 73125.00 }, "nil_exempt": 0.00 },
  "table_4": { "itc_available": { "igst": 0.00, "cgst": 36090.00, "sgst": 36090.00 },
               "itc_ineligible": { "igst": 0.00, "cgst": 2700.00, "sgst": 2700.00 } },
  "table_6_1": { "net_payable": { "igst": 0.00, "cgst": 37035.00,
                 "sgst": 37035.00, "total": 74070.00 } }
}, "meta": { "request_id": "req_g40" } }
```

- **Status codes & errors** — same table as `/gst/summary`.

---

### `GET /gst/reconciliation`

- **Purpose** — **ITC-risk view**: list purchases in the period **missing a supplier GSTIN**
  (or with a malformed one), so the owner can follow up before filing (R4 step 4).
- **Auth** — owner/accountant.
- **Idempotency** — N/A.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|
| `gstin_id` | query | int | yes | — | |
| `period` | query | string | yes | — | `YYYY-MM` / `YYYY-Qn` |
| `flag` | query | enum | no | `all` | `missing_gstin \| invalid_gstin \| state_mismatch \| all` |
| `page` / `per_page` | query | int | no | `1` / `50` | |
| `format` | query | enum | no | `json` | export |

- **Response `200`**

| Field | Type | Notes |
|---|---|---|
| `summary.total_purchases` | int | in period |
| `summary.flagged_count` | int | purchases with any risk flag |
| `summary.itc_at_risk` | decimal | Σ `total_gst` of flagged purchases (₹ ITC that can't be claimed yet) |
| `data[].purchase_id` | int | |
| `data[].invoice_no` | string | supplier invoice number |
| `data[].invoice_date` | date | |
| `data[].supplier_id` | int | |
| `data[].supplier_name` | string | |
| `data[].supplier_phone` | string | to chase the supplier |
| `data[].supplier_gstin` | string / null | null = **missing** |
| `data[].flag` | enum | `missing_gstin \| invalid_gstin \| state_mismatch` |
| `data[].itc_amount` | decimal | ITC at stake for this purchase |

```json
{ "ok": true, "data": [
  { "purchase_id": 771, "invoice_no": "SUN/1123", "invoice_date": "2026-06-14",
    "supplier_id": 8, "supplier_name": "Sunshine Toys", "supplier_phone": "+91 90000 11111",
    "supplier_gstin": null, "flag": "missing_gstin", "itc_amount": 5400.00 }
], "meta": { "summary": { "total_purchases": 96, "flagged_count": 3,
             "itc_at_risk": 5400.00 }, "page": 1, "per_page": 50,
             "total": 3, "request_id": "req_g50" } }
```

- **Status codes & errors** — same table as `/gst/summary`.

---

## 5. Business logic & validation

**GSTIN format.** Validated on write with the standard 15-char pattern
`22AAAAA0000A1Z5`: 2-digit state code + 10-char PAN + entity digit + `Z` + checksum char.
`state_code` must equal the first two digits; it is auto-derived and immutable.

**CGST/SGST vs IGST split (derived).** The schema stores only `gst_amount` / `tax_amount` /
`total_gst`, **not** a per-head split, so the split is computed at query time:

- **Outward (sales).** Determine intra vs inter-state by comparing the **place of supply**
  to the registration's `state_code`. For B2C retail the place of supply = registration
  state (see Proposed schema addition), so **intra-state → `cgst = sgst = tax_amount / 2`,
  `igst = 0`**. If an inter-state sale is recorded (place of supply ≠ registration state),
  the whole `tax_amount` goes to **`igst`**.
- **Inward (purchases).** Compare the **supplier GSTIN state** (first 2 digits of
  `purchases.supplier_gstin`) to the registration's `state_code`: same → CGST+SGST split of
  `total_gst`; different → IGST. Missing `supplier_gstin` → cannot classify → counted as
  **ITC at risk** (not in claimable CGST/SGST/IGST).

**Rounding.** Half-splits are rounded half-up to paise; the two halves are reconciled so
`cgst + sgst = tax_amount` exactly (any 1-paise residue lands on CGST). Server is
authoritative on rounding (api-conventions §1).

**Net payable.** Per head: `net = max(output_tax − eligible_itc, 0)`. Excess ITC does not
create a negative liability in this summary (carry-forward is a portal concern, not modelled
here) 🧩.

**Period math.** `YYYY-MM` → first..last day of month. `YYYY-Qn` → GST FY quarter (Q1
Apr–Jun, Q2 Jul–Sep, Q3 Oct–Dec, Q4 Jan–Mar). Range is inclusive on business dates
(`sales.sold_at`, `purchases.invoice_date`).

**HSN summary.** Group `sale_items` by `products.hsn_code`; sum quantity, taxable value and
tax. Missing `hsn_code` rolls into an `UNCLASSIFIED` bucket and is flagged 🧩 (a product
should have an HSN before filing).

**Invoice range (GSTR-1 docs issued).** Derived from the gapless per-GSTIN invoice sequence
(`GST{gstin}/{fy}/{seq}` — see [sync §7](../../../foundation/sync-and-conflict-resolution.md)).

---

## 6. Sync & conflict handling

- GST endpoints are **read/report only** (except registration CRUD, which is a rare,
  online-only owner action) — **not** part of the offline outbox. `N/A` for `client_uuid`
  dedupe.
- They read committed `sales`/`purchases` only. A sale still `pending`/`syncing` in a staff
  device's outbox is **not** counted until it is `synced` and has a server-assigned
  `invoice_no`. This means a period summary can shift slightly until all devices flush their
  outboxes — the web filing screen shows an **"unsynced sales: N"** banner sourced from
  [sync-api](../sync/sync-api.md) so the owner does not file on incomplete data.
- Exports reflect a **snapshot at request time**; regenerate after all devices sync.

---

## 7. Edge cases & failure modes

1. **Multiple GSTINs.** Every summary/export is strictly scoped to one `gstin_id`; a sale's
   `sales.gstin_id` decides which registration it belongs to. Cross-GSTIN totals are never
   mixed.
2. **Missing supplier GSTIN.** Purchase still recorded; ITC is quarantined into
   `itc_at_risk` and surfaced by `/gst/reconciliation` + GSTR-3B table 4 ineligible.
3. **Inter-state sale without place-of-supply field.** Defaults to intra-state (CGST/SGST).
   Flagged as a Proposed schema addition; if inter-state B2B selling becomes real, add
   `sales.place_of_supply_state_code` before relying on IGST numbers.
4. **Inactive GSTIN mid-period.** Historical txns under it still report; it just cannot be
   selected for **new** txns.
5. **Product with no HSN.** Rolls into `UNCLASSIFIED` and is flagged; fix before filing.
6. **Quarterly filer (QRMP).** `YYYY-Qn` aggregates three months; GSTR-3B still monthly on
   the portal — the export notes the constituent months.
7. **Rounding drift across many invoices.** Each invoice's tax is stored at line level;
   summaries sum stored values (not re-derived from taxable × rate) to avoid compounding
   rounding error.

---

## 8. Performance & indexing

| Query | Index relied on |
|---|---|
| outward totals by period | `sales.idx_gstin_date (gstin_id, sold_at)` |
| inward totals by period | `purchases` (gstin_id, invoice_date) — add `KEY idx_pur_gstin_date` 🧩 |
| reconciliation (missing gstin) | filter `purchases.supplier_gstin IS NULL` within period |
| HSN rollup | join `sale_items → products.hsn_code` |

- **Volume:** a month = hundreds–low-thousands of sales; summaries are heavy aggregate
  queries → **cache the computed summary per `(gstin_id, period)`** and invalidate when a
  sale/purchase in that window changes.
- **Exports** stream CSV/XLSX; large GSTR-1 datasets should page internally.
- Filing season is bursty (month-start) — precompute the prior period nightly.

---

## 9. Related docs

- Foundation: [data-model.md](../../../foundation/data-model.md) ·
  [api-conventions.md](../../../foundation/api-conventions.md) ·
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md) (invoice numbering)
- Sibling APIs: [sales-api](../sales/sales-api.md) (output tax source) ·
  [purchases-api](../purchases/purchases-api.md) (ITC source) ·
  [suppliers-api](../suppliers/suppliers-api.md) (supplier GSTIN)
- Screens: [web/gst-filing](../../web/gst/gst-filing.md) ·
  [owner/gst-registrations](../../../mobile/owner/gst/gst-registrations.md)
