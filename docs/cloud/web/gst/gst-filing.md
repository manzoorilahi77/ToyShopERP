# GST Filing — Owner / Accountant · Flutter Web

> Status: `✅ Specified` · Implements **Requirement 4 — GST FILING FLOW**, the primary reason
> the web dashboard exists. **Headline screen.** GSTIN + period selector → auto-computed
> liability → one-click **GSTR-1 / GSTR-3B** export → **ITC reconciliation**.

---

## 1. Purpose & context
- **What this screen is for** — pick a **GSTIN** + a **reporting period** (month or quarter) and
  instantly see **total outward supply** (sales), **output GST liability**, **total input tax
  credit (ITC)** from purchases, and **net GST payable**; then **one-click export GSTR-1**
  (outward supplies) and **GSTR-3B** (summary) as CSV/Excel; plus a **reconciliation view** that
  flags purchases **missing `supplier_gstin`** (ITC-at-risk) to fix before filing.
- **Who uses it** — `owner` and especially the `accountant`. This is the screen a CA or the
  owner opens on a laptop at filing time.
- **When** — **monthly/quarterly at GST season** — the highest-stakes, most time-pressured web
  task in the whole system.
- **Why it exists** — the brief: today the owner "struggles to compile purchase/sales data
  across possibly multiple GSTIN manually … this must become automatic." Manual GST compilation
  is error-prone and stressful; a wrong return means penalties or lost ITC. This screen makes the
  numbers computed, exportable, and reconcilable.
- **Frequency / criticality** — low frequency, **maximum criticality** — the figures go to the
  government; correctness, auditability, and "what's excluded and why" transparency are paramount.

---

## 2. Entry points & navigation
- **Arrival** — sidebar **GST** (5th item); `g g`; Dashboard **"GST due"** KPI drill; a filing
  due-date notification.
- **Exits**
  - **Export GSTR-1 / GSTR-3B** → file download (no navigation).
  - **Outward supplies detail** → [../sales/sales-ledger.md](../sales/sales-ledger.md) filtered
    to the GSTIN + period.
  - **ITC / reconciliation detail** → [../purchases/purchase-ledger.md](../purchases/purchase-ledger.md)
    filtered to the GSTIN + period (ITC = missing when flagged).
  - **Fix supplier GSTIN** (from a reconciliation flag) → supplier edit (inline Proposed) /
    Purchase Ledger.
  - **Manage GSTINs** → [../settings/settings.md](../settings/settings.md) → owner mobile
    [../../../mobile/owner/gst/gst-registrations.md](../../../mobile/owner/gst/gst-registrations.md).
- **Back-button** — leaves the screen; GSTIN + period are in the URL query for a shareable,
  reproducible view.
- Nav diagram: `Dashboard GST KPI → GST Filing → {Sales Ledger | Purchase Ledger | Export}`.

---

## 3. Roles & permissions
| Actor | Access | Notes |
|---|---|---|
| Owner | full read + export | can act on reconciliation flags |
| Accountant | full read + export | the primary user; **read-only** on data (compute + export only) |
| Staff | ⛔ | not on web |
- The screen **computes and exports**; it does **not** file to the GST portal or mutate sales /
  purchases. No `🔒 owner-PIN` gate (viewing/exporting financial summaries is allowed to
  owner/accountant). Fixing a supplier GSTIN is a normal owner write.

---

## 4. Screen layout (wireframe)
Sidebar shell + selector bar + summary cards + a computed breakdown + reconciliation panel.

```
┌──────────┬──────────────────────────────────────────────────────────────────────┐
│ 🧸       │  GST Filing                                          ⟳   Manage GSTINs │
│ Dashboard│  GSTIN[ 33ABCDE1234F1Z5 — ToyShop (TN) ▾ ]  Period[ Month▾ ][Jun 2026▾]│
│ Sales    │ ┌────────────┐┌────────────┐┌────────────┐┌────────────┐               │
│ Purchases│ │Outward sup.││Output GST  ││Input credit││ NET PAYABLE│  ← summary     │
│ Stock    │ │₹ 4,82,300  ││₹  73,320   ││₹ 1,04,300  ││ ₹  0 (cr)  │               │
│ GST      │ │(sales)     ││CGST+SGST   ││(ITC)       ││ carry fwd  │               │
│ ▸(GST)   │ └────────────┘└────────────┘└────────────┘└────────────┘               │
│ Staff    │  ── Rate-wise breakdown (outward) ─────────────────────────────────    │
│ Catalog  │  Rate   Taxable₹    CGST     SGST     IGST    Total tax                 │
│ Settings │   5%     20,000      500      500       0        1,000                  │
│          │  18%    3,90,000   35,100   35,100      0       70,200                  │
│ ──────   │  28%     ...                                                            │
│ 👤 Acct  │  ── ITC reconciliation ───────────────────────────────────────────     │
│ ✓ synced │  ⚠ 5 purchases missing supplier GSTIN → ₹ 9,180 ITC at risk  [Review]  │
│          │  [  Export GSTR-1 ▾ ]   [  Export GSTR-3B ▾ ]        (CSV / XLSX)        │
└──────────┴──────────────────────────────────────────────────────────────────────┘
```

**Sidebar nav placement** — GST is the **5th** item, visually emphasized (the web dashboard's
headline task). **Selector bar** is sticky. **Summary cards** use big tabular `₹`; **Net payable**
is the hero number.

**Responsive breakpoints**

| Name | Width | Layout |
|---|---|---|
| Compact | < 768 px | selectors stack; 4 summary cards → 1 col; rate table horizontal scroll; export buttons full-width |
| Medium | 768–1199 px | selectors inline; summary 2×2; rate table scroll |
| Expanded | 1200–1599 px | selectors inline; summary in a row; full rate table + reconciliation |
| Wide | ≥ 1600 px | centred max 1440; reconciliation can sit beside the breakdown |

---

## 5. UI components & field-by-field spec
### Selectors & actions
| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | GSTIN | dropdown | `gst_registrations` where `is_active=1` | must be active | last used / first active | recompute all | shows `gstin — trade_name (state)`; `state_code` drives CGST/SGST vs IGST |
| 2 | Period type | segmented | Month · Quarter | — | Month | switches picker granularity | quarterly filers use Quarter |
| 3 | Period value | picker | months / `Qn FY26-27` | within FY; not future | current open period | recompute | `period=YYYY-MM` or `YYYY-Qn` (api-conventions §8) |
| 4 | Refresh ⟳ | button | — | — | — | recompute from live data | `r` |
| 5 | Manage GSTINs | link | — | — | — | → Settings / owner mobile | add/activate registrations |
| 6 | Review (reconciliation) | button | — | — | — | → Purchase Ledger (missing GSTIN, this period) | fix before filing |
| 7 | Export GSTR-1 ▾ | menu | CSV · XLSX | period+GSTIN required | — | build GSTR-1 outward file | see §export |
| 8 | Export GSTR-3B ▾ | menu | CSV · XLSX | period+GSTIN required | — | build GSTR-3B summary file | |

### Summary cards (computed)
| Card | Formula (canonical) | Notes |
|---|---|---|
| Outward supply | `Σ sales.subtotal` (taxable value) for GSTIN+period | pre-tax outward value |
| Output GST liability | `Σ sales.tax_amount` (= `Σ sale_items.gst_amount`) | split CGST/SGST/IGST (§8 R4) |
| Input tax credit (ITC) | `Σ purchases.total_gst` where `supplier_gstin IS NOT NULL`, GSTIN+period | **excludes** missing-GSTIN bills |
| Net GST payable | `Output GST − ITC` (floored at 0; surplus → credit carry-forward) | **hero** number |

### Rate-wise breakdown table (outward)
| Column | Source | Notes |
|---|---|---|
| Rate | `sale_items.gst_rate` (0/5/12/18/28) | grouped |
| Taxable ₹ | `Σ line taxable` at that rate | GSTR-1 needs rate-wise |
| CGST / SGST | intra-state: `gst_amount/2` each | when buyer state = registration `state_code` |
| IGST | inter-state: full `gst_amount` | when place of supply ≠ registration state (§8 R4) |
| Total tax | `Σ gst_amount` at rate | |

### ITC reconciliation panel
| Element | Source | Notes |
|---|---|---|
| Missing-GSTIN count + ₹ at risk | `purchases` in period where `supplier_gstin IS NULL` → `Σ total_gst` | amber `⚠` + label |
| Review list (inline preview) | those purchases (supplier, invoice, ITC amount) | rows → Purchase Ledger / Fix GSTIN |
| Reconciled ITC | ITC with GSTIN − at-risk | what's safely claimable |

---

## 6. States
- **default / populated** — GSTIN + current open period selected; four summary cards + rate
  breakdown + reconciliation computed and shown.
- **empty** — no sales/purchases in period → cards show `₹0`; "No outward supplies for this
  period" / "No ITC to claim"; export produces a valid **nil** return (headers + zero totals).
- **loading** — skeleton summary cards + shimmer tables; export buttons disabled until computed.
- **error (inline, retry)** — "Couldn't compute GST for this period — Retry"; export disabled.
- **offline** — banner "Offline — cannot compute/export GST"; everything disabled (GST must be
  computed from the live server truth, never stale cache — see §8 R7).
- **success** — export ready → toast + download; "Computed as of HH:MM" stamp shown for audit.
- **permission-denied** — `N/A` for allowed roles.

---

## 7. Interactions, gestures & hardware
- **Keyboard** — `g g` open; `/` focus GSTIN selector; `m`/`q` toggle Month/Quarter; `←/→` step
  period; `1` export GSTR-1, `3` export GSTR-3B (open format menu); `Enter` on reconciliation →
  Review; `r` recompute.
- **Mouse** — hover a summary card → formula tooltip ("Output GST = Σ sale tax for Jun 2026,
  GSTIN 33…F"); click a rate row → Sales Ledger filtered to that rate/period; click reconciliation
  → Purchase Ledger.
- **No hardware** — desktop; export is a file download.
- **Latency** — compute target < 2 s for a month; heavy periods computed server-side and cached
  for the (GSTIN, period) pair.

---

## 8. Business rules & edge cases
1. **R1 — Multi-GSTIN isolation.** All figures are scoped to **one** `gstin_id`; sales
   (`sales.gstin_id`) and purchases (`purchases.gstin_id`) are partitioned per registration —
   never mixed across GSTINs in a single return.
2. **R2 — Period basis.** Outward = sales by **business date** (`sold_at`) in the period; ITC =
   purchases by **`invoice_date`** in the period; inclusive ranges (api-conventions §8). Quarter
   = the 3 constituent months.
3. **R3 — Net payable & carry-forward.** `Net = Output GST − ITC`; if ITC > output, net is `0`
   and the surplus is an **ITC credit carried forward** (shown, not negative-payable).
4. **R4 — CGST/SGST vs IGST by `state_code`.** For **intra-state** supply (place of supply state
   = registration `gst_registrations.state_code`), tax splits **CGST = SGST = tax/2**; for
   **inter-state**, it's **IGST** (full). Toy retail is B2C intra-state by default →
   CGST+SGST. **⚠ Proposed schema addition:** `sales` has no `place_of_supply_state_code` and no
   customer GSTIN; add `sales.place_of_supply_state_code CHAR(2)` (and optional customer GSTIN)
   if inter-state / B2B outward supplies must be represented in GSTR-1. Until then, all outward
   supply is treated intra-state to the registration's state.
5. **R5 — ITC excludes missing supplier GSTIN.** A purchase with `supplier_gstin IS NULL` is
   **not** counted in claimable ITC (its tax is shown as "at risk"), because ITC needs a valid
   vendor GSTIN. This is the reconciliation flag's whole purpose.
6. **R6 — Rounding.** Money is `DECIMAL(12,2)`; server rounds **half-up to paise** and totals are
   summed from rounded line values so the return foots exactly (api-conventions §1). GSTR files
   present values per portal rounding rules.
7. **R7 — Compute from live server truth only.** GST figures are **never** computed from stale
   web cache — the screen is disabled offline and shows a "Computed as of HH:MM" audit stamp;
   only `synced` sales/purchases count (pending/failed/draft/void are excluded).
8. **R8 — Voids/returns net out.** `void` sales/purchases and `return_in` movements reduce the
   respective totals so the return isn't overstated.
9. **R9 — GSTR-1 structure.** Outward file is **rate-wise**, split B2C (summary) vs B2B (with
   customer GSTIN) — but with no customer GSTIN captured today, all outward is **B2C** (rate-wise
   summary). Nil period → a valid nil GSTR-1.
10. **R10 — GSTR-3B structure.** Summary of outward taxable + output tax (3.1) and eligible ITC
    (4) → net payable (5.1), matching the summary cards.
11. **R11 — Inactive GSTIN.** Not selectable for a new computation; historical periods for a
    now-inactive GSTIN remain viewable (read-only) for audits.
12. **R12 — Audit stamp.** Each computed view records who computed it, when, and the input row
    counts, so an exported return can be reproduced/defended (`audit_log`).

### Export flow (GSTR-1 / GSTR-3B)
Export ▾ → **CSV or XLSX** → client calls `GET /gst/gstr1` / `GET /gst/gstr3b`
`?gstin_id=&period=&format=` → server builds the **portal-ready** file (rate-wise, correct
column headers, rounded per portal rules) → download. Filename
`GSTR1_<gstin>_<period>.xlsx` / `GSTR3B_<gstin>_<period>.xlsx`. Large periods may return `202`
async with a ready link. Reference [api-conventions.md](../../../foundation/api-conventions.md) §7.

---

## 9. API interactions
| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| GSTIN/period change, load, ⟳ | `GET /gst/summary?gstin_id=&period=` | outward, output GST, ITC, net payable + rate-wise breakdown | **disabled** offline (no stale GST) |
| Review reconciliation | `GET /gst/reconciliation?gstin_id=&period=` | purchases missing `supplier_gstin` + ITC at risk | disabled offline |
| Export GSTR-1 | `GET /gst/gstr1?gstin_id=&period=&format=csv\|xlsx` | outward-supplies file | disabled offline |
| Export GSTR-3B | `GET /gst/gstr3b?gstin_id=&period=&format=csv\|xlsx` | summary file | disabled offline |
| Fix supplier GSTIN | `PATCH /suppliers/{id}` *(Proposed inline)* | backfill vendor GSTIN → moves ITC from at-risk to claimable | blocked offline |

- All reads **GET, read-only, no idempotency key**; period param `YYYY-MM` or `YYYY-Qn`
  (api-conventions §8).
- API doc: [../../api/gst/gst-api.md](../../api/gst/gst-api.md). Underlying data: sales
  ([../../api/sales/sales-api.md](../../api/sales/sales-api.md)) + purchases
  ([../../api/purchases/purchases-api.md](../../api/purchases/purchases-api.md)).

**`GET /gst/summary` — key response fields**
`{ gstin, period, outward_taxable, output_gst:{cgst,sgst,igst,total}, itc_claimable,
itc_at_risk, net_payable, credit_carry_forward, rate_wise:[{rate,taxable,cgst,sgst,igst,tax}],
reconciliation:{missing_gstin_count, itc_at_risk_amount}, computed_at, counts:{sales,purchases} }`.

---

## 10. Offline & sync behavior
- **Online-only, read-only.** GST computation is **never** served from stale web cache — the
  screen disables itself offline (§8 R7). There is no Drift/outbox on web.
- It reads the **server-reconciled** sales/purchases (only `synced` rows), so it inherits correct,
  conflict-resolved figures ([sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md)).
  Pending mobile transactions that haven't synced are **not** in the return — a "pending items
  may affect this period" note warns the accountant to sync before filing.
- The one write (fix supplier GSTIN) is online-only.

---

## 11. Analytics & events
| Event | When | Properties |
|---|---|---|
| `web_gst_viewed` | load | `gstin_id`, `period` |
| `web_gst_period_changed` | selector change | `period_type`, `period` |
| `web_gst_summary_computed` | compute done | `net_payable`, `itc_at_risk`, `counts`, `duration_ms` |
| `web_gst_reconciliation_reviewed` | Review click | `missing_gstin_count`, `itc_at_risk` |
| `web_gstr1_exported` | GSTR-1 export | `format`, `period`, `row_count`, `is_nil` |
| `web_gstr3b_exported` | GSTR-3B export | `format`, `period`, `net_payable` |
| `web_gst_supplier_gstin_fixed` | fix flag | `supplier_id`, `itc_recovered` |

---

## 12. Accessibility, localization & performance
- **A11y** — summary cards are large tabular numbers (Display 34/40); the ⚠ at-risk flag pairs an
  icon + text; rate-table has proper headers + `aria`; export buttons state what they produce;
  formula tooltips are keyboard-reachable. WCAG AA light/dark.
- **Localization** — `₹` Indian grouping `1,23,456.00`; DD-MM-YYYY; GST terminology
  (GSTIN/GSTR-1/GSTR-3B/CGST/SGST/IGST/ITC); FY as `26-27`; period labels localized; **export
  files keep GST-portal-standard column headers** regardless of UI locale.
- **Performance** — compute cached per (GSTIN, period); heavy aggregation server-side; export
  streamed/async for large periods; a period recompute after new sales invalidates the cache.

---

## 13. Acceptance criteria
- [ ] Selecting a GSTIN + month/quarter auto-computes Outward supply, Output GST liability,
      ITC, and Net payable, scoped strictly to that registration.
- [ ] Output GST splits **CGST/SGST** for intra-state (state_code) and **IGST** for inter-state;
      rate-wise breakdown foots to the totals.
- [ ] ITC counts only purchases **with** a `supplier_gstin`; purchases missing it are shown as
      **ITC at risk** and excluded from claimable ITC.
- [ ] Reconciliation panel lists missing-GSTIN purchases with the ₹ at risk and a Review link to
      the filtered Purchase Ledger; fixing a supplier GSTIN moves ITC from at-risk to claimable.
- [ ] Net payable never goes negative — surplus ITC shows as credit carry-forward.
- [ ] One-click export produces portal-ready **GSTR-1** (outward, rate-wise/B2C) and **GSTR-3B**
      (summary) CSV/XLSX with standard headers; a nil period yields a valid nil return.
- [ ] Only `synced` sales/purchases are included; pending items trigger a "sync before filing" note.
- [ ] Screen is disabled offline (no stale GST) and shows a "Computed as of HH:MM" audit stamp.
- [ ] Money rounds half-up to paise and returns foot exactly.
- [ ] Fully keyboard-operable; at-risk flag never color-alone.

---

## 14. Related docs
- Foundation: [data-model.md](../../../foundation/data-model.md) (`gst_registrations`, `sales`,
  `purchases`, `state_code`, `supplier_gstin`) ·
  [api-conventions.md](../../../foundation/api-conventions.md) (period params, export) ·
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md) ·
  [design-system.md](../../../foundation/design-system.md)
- API: [../../api/gst/gst-api.md](../../api/gst/gst-api.md) ·
  [../../api/sales/sales-api.md](../../api/sales/sales-api.md) ·
  [../../api/purchases/purchases-api.md](../../api/purchases/purchases-api.md)
- Sibling web screens: [../sales/sales-ledger.md](../sales/sales-ledger.md) ·
  [../purchases/purchase-ledger.md](../purchases/purchase-ledger.md) ·
  [../dashboard/dashboard-home.md](../dashboard/dashboard-home.md) ·
  [../settings/settings.md](../settings/settings.md)
- Mobile: [../../../mobile/owner/gst/gst-registrations.md](../../../mobile/owner/gst/gst-registrations.md)
