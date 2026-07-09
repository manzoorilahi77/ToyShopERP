# Settings — Owner / Accountant · Flutter Web

> Status: `✅ Specified` · Owner-configurable control panel: aging/low-stock thresholds,
> incentive rules, duplicate similarity threshold, GSTIN management link, and backup settings.
> The tuning surface behind the Stock Report, Catalog, and Staff Performance screens.

---

## 1. Purpose & context
- **What this screen is for** — one place for the owner to tune the system: **aging stock
  threshold** (`app_settings.aging_threshold_days`), **reorder / low-stock defaults**, **incentive
  rule** configuration (`incentive_rules` CRUD), a **GSTIN management** link, the **duplicate
  similarity threshold** (`app_settings.dup_similarity_threshold`), and **backup settings**.
- **Who uses it** — `owner` (all settings). `accountant` typically read-only, except possibly
  GSTIN/backup review.
- **When** — infrequently: at setup, at the start of an incentive month, when tuning aging/low
  thresholds after a stock review, or adjusting duplicate sensitivity if the queue is too
  noisy/quiet.
- **Why it exists** — the brief wants thresholds and incentive rules **owner-configurable without
  a release** ([data-model.md](../../../foundation/data-model.md) `app_settings`;
  [duplicate-detection.md](../../../foundation/duplicate-detection.md) §3 "Thresholds live in
  `app_settings` so the owner can tune sensitivity"). Changes here ripple across other screens.
- **Frequency / criticality** — low frequency, **high** blast radius — a wrong threshold changes
  what counts as aging/low across the whole shop; a wrong incentive rule affects payouts. All
  changes are audited.

---

## 2. Entry points & navigation
- **Arrival** — sidebar **Settings** (8th/last item); `g ,`; from Stock Report ("edit
  threshold"), Catalog ("similarity threshold"), Staff Performance ("incentive rules"), GST
  Filing ("Manage GSTINs").
- **Exits**
  - **Manage GSTINs** → owner mobile
    [../../../mobile/owner/gst/gst-registrations.md](../../../mobile/owner/gst/gst-registrations.md)
    (source of truth for `gst_registrations`), or an inline web editor (Proposed).
  - Section deep-links back to the screen the setting affects (Stock/Catalog/Staff).
- **Back-button** — if there are unsaved edits, prompt "Discard changes?"; otherwise leave.
  Active section is in the URL (`/settings#incentives`).
- Nav diagram: `Stock/Catalog/Staff/GST → Settings (section) → {affected screen | GSTIN mgmt}`.

---

## 3. Roles & permissions
| Actor | Access | Notes |
|---|---|---|
| Owner | full read/write on all sections | the only role that tunes the shop |
| Accountant | read-only (may view GSTIN/backup) | cannot change thresholds/rules |
| Staff | ⛔ | not on web |
- All writes are owner-only and **audited** in `audit_log` (`app_settings.updated_by` records who
  changed a setting). No separate `🔒 owner-PIN` gate specified beyond the owner web session, but
  destructive/backup actions **confirm** before applying. `accountant` sees values disabled.

---

## 4. Screen layout (wireframe)
Sidebar shell + a left settings sub-nav + a right settings pane (form sections).

```
┌──────────┬──────────────────────────────────────────────────────────────────────┐
│ 🧸       │  Settings                                              ⟳   [ Save ]    │
│ Dashboard│  ┌────────────────┬───────────────────────────────────────────────┐   │
│ Sales    │  │ • Stock         │  Stock thresholds                             │   │
│ Purchases│  │ • Incentives    │  Aging threshold (days)   [ 30 ]  🧩          │   │
│ Stock    │  │ • Duplicates    │  Low-stock default reorder[ 3  ]               │   │
│ GST      │  │ • GSTINs        │  Buckets: 30 / 60 / 90 (per-product override   │   │
│ Staff    │  │ • Backup        │           via product.aging_threshold_days)    │   │
│ Catalog  │  ├────────────────┼───────────────────────────────────────────────┤   │
│ Settings▸│  │                 │  Incentive rules                    [+ New]   │   │
│          │  │                 │  ┌───────────────────────────────────────────┐│   │
│ ──────   │  │                 │  │ Monthly target · 150 units · ₹500 · active││   │
│ 👤 Owner │  │                 │  │ Revenue tier   · ₹30,000    · ₹1k  · active││   │
│ ✓ synced │  │                 │  └───────────────────────────────────────────┘│   │
│          │  │                 │  Duplicate similarity threshold [ 0.86 ] 🎚    │   │
│          │  └────────────────┴───────────────────────────────────────────────┘   │
└──────────┴──────────────────────────────────────────────────────────────────────┘
```

**Sidebar nav placement** — Settings is the **last** shell item; within it, a **left sub-nav**
(Stock · Incentives · Duplicates · GSTINs · Backup). A single sticky **Save** applies the dirty
section(s); an unsaved-changes guard protects navigation.

**Responsive breakpoints**

| Name | Width | Layout |
|---|---|---|
| Compact | < 768 px | sub-nav → top tabs/accordion; single-column forms; Save sticky bottom |
| Medium | 768–1199 px | sub-nav as a compact rail; forms single column |
| Expanded | 1200–1599 px | sub-nav + form pane side-by-side |
| Wide | ≥ 1600 px | centred, generous field spacing |

---

## 5. UI components & field-by-field spec
### Section: Stock thresholds → `app_settings`
| # | Element | Type | Source / key | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Aging threshold (days) | number | `app_settings.aging_threshold_days` | int 1–365 | 30 🧩 | on Save → recompute Stock Report aging | per-product override via `products.aging_threshold_days` |
| 2 | Aging buckets | read-only hint | derived 30/60/90 | — | — | reflects threshold | icon legend |
| 3 | Default reorder threshold | number | `app_settings.default_reorder_threshold` *(Proposed)* | int 0–999 | 3 | applies to **new** products lacking one | per-product `products.reorder_threshold` still wins |

### Section: Incentive rules → `incentive_rules` (CRUD)
| # | Element | Type | Source (canonical) | Validation | Notes |
|---|---|---|---|---|---|
| 4 | Rules list | table | `incentive_rules` | — | active + expired |
| 5 | Rule type | select | `incentive_rules.rule_type` (`per_unit_bonus`/`monthly_target`/`revenue_tier`) | required | drives target meaning |
| 6 | Target value | number | `incentive_rules.target_value` | > 0 | units or ₹ |
| 7 | Reward description | text | `incentive_rules.reward_description` | required | shown to staff |
| 8 | Reward value | number (₹) | `incentive_rules.reward_value` | ≥ 0, nullable | optional cash |
| 9 | Active from / to | date range | `incentive_rules.active_from` / `active_to` | `from ≤ to`, to nullable | scheduling |
| 10 | Active | toggle | `incentive_rules.is_active` | — | enable/disable |
| 11 | + New / Edit / Deactivate | buttons | — | — | soft-disable, not delete (keeps `staff_incentive_progress` valid) |

### Section: Duplicates → `app_settings`
| # | Element | Type | Source / key | Validation | Default | Notes |
|---|---|---|---|---|---|---|
| 12 | Similarity threshold | slider + number | `app_settings.dup_similarity_threshold` | 0.50–0.99 | **0.86** | higher = fewer prompts (stricter match); affects Catalog review queue volume |
| 13 | Text-match ratio | number | `app_settings.dup_text_ratio` *(Proposed)* | 0.50–0.99 | 0.85 | Levenshtein/token-set floor (dup-detection §2) |

### Section: GSTINs → `gst_registrations`
| # | Element | Type | Source | Notes |
|---|---|---|---|---|
| 14 | GSTIN list | read-only table | `gst_registrations` (gstin, legal_name, state_code, is_active) | validation format `22AAAAA0000A1Z5` |
| 15 | Manage GSTINs | link/button | — | → owner mobile GST registrations (or inline editor, Proposed) |

### Section: Backup → *(Proposed)*
| # | Element | Type | Source / key *(Proposed)* | Validation | Default | Notes |
|---|---|---|---|---|---|---|
| 16 | Backup frequency | select | `app_settings.backup_frequency` | daily/weekly | daily | when the server backup job runs |
| 17 | Backup time | time | `app_settings.backup_time` | HH:MM | 02:00 IST | off-peak |
| 18 | Retention (days) | number | `app_settings.backup_retention_days` | 7–365 | 30 | |
| 19 | Last backup | read-only | `app_settings.last_backup_at` | — | — | status + ✓/! |
| 20 | Backup now / Download | button | — | — | — | on-demand export/snapshot (confirm) |

### Global
| # | Element | Type | Notes |
|---|---|---|---|
| 21 | Save | button | applies dirty section(s); disabled until a change; per-setting optimistic + confirm |
| 22 | Unsaved-changes guard | dialog | on navigation away with dirty fields |

---

## 6. States
- **default / populated** — current values loaded from `app_settings` / `incentive_rules` /
  `gst_registrations`; Save disabled until a field is dirty.
- **empty** — no incentive rules yet → "No incentive rules — add one to motivate staff"
  (`EmptyState` + New).
- **loading** — skeleton form fields; Save disabled.
- **error (inline, retry)** — load error → retry; a rejected save shows the field-level
  `VALIDATION_ERROR` inline and keeps edits.
- **offline** — banner "Offline — settings are read-only"; all writes disabled (no web outbox).
- **success** — "Settings saved" toast; affected screens pick up new values on their next load;
  an "affects Stock Report / Catalog queue" hint clarifies downstream impact.
- **permission-denied** — accountant sees values but all inputs disabled with a "read-only" note.

---

## 7. Interactions, gestures & hardware
- **Keyboard** — `g ,` open; `↑/↓` or `1–5` move sub-nav sections; `Ctrl/Cmd+S` Save; `Esc`
  cancel an inline rule edit; `Enter` confirm a rule; slider adjustable by arrow keys.
- **Mouse** — drag the similarity slider (live numeric readout); inline-edit a rule row; toggle
  active switches.
- **No hardware** — desktop.
- **Latency** — Save round-trip < 1 s; downstream screens recompute on their next fetch (Settings
  doesn't force a global refresh).

---

## 8. Business rules & edge cases
1. **R1 — Settings are typed strings.** `app_settings.value` is stored as a string and typed in
   the app ([data-model.md](../../../foundation/data-model.md) §2); the UI validates types/ranges
   before Save; `updated_by` + `updated_at` record who/when (audit).
2. **R2 — Per-product overrides win.** Global `aging_threshold_days` / default reorder are
   **fallbacks**; a product's own `products.aging_threshold_days` / `reorder_threshold` override
   them. Changing the global does **not** overwrite per-product values.
3. **R3 — Threshold changes are retroactive to reports, not to history.** Lowering the aging
   threshold immediately re-buckets the Stock Report ([../stock/stock-report.md](../stock/stock-report.md))
   on next load; it does not rewrite past movements.
4. **R4 — Similarity threshold trades noise vs misses.** Raising
   `dup_similarity_threshold` → fewer prompts and a smaller review queue but more missed
   duplicates; lowering → more prompts/queue items. The help text states this; changes affect
   **future** checks only (existing `confirmed_unique` pairs stay resolved) — see
   [duplicate-detection.md](../../../foundation/duplicate-detection.md) §3.
5. **R5 — Incentive rules: soft-disable, never delete.** Deactivating a rule keeps its
   `staff_incentive_progress` history intact for audits/payouts; deleting is disallowed. Editing
   `target_value` mid-period is allowed but flagged ("affects current progress") since staff see a
   live bar ([../staff/staff-performance.md](../staff/staff-performance.md)).
6. **R6 — Rule scheduling.** `active_from`/`active_to` schedule rules; overlapping rules of the
   same type are allowed but warned (staff could progress on two).
7. **R7 — GSTIN is managed elsewhere.** `gst_registrations` is the source of truth edited in owner
   mobile ([../../../mobile/owner/gst/gst-registrations.md](../../../mobile/owner/gst/gst-registrations.md));
   Settings **links** to it (or an inline editor, Proposed) and validates the GSTIN format
   `22AAAAA0000A1Z5`; a GSTIN can be marked inactive but not deleted (past returns reference it).
8. **R8 — Backup is server-side.** Backup settings configure a **server** job (DB dump / object
   storage); "Backup now" triggers an on-demand snapshot with confirmation; the client never
   holds the backup. **⚠ Proposed schema addition:** no backup config exists — add `app_settings`
   keys (`backup_frequency`, `backup_time`, `backup_retention_days`, `backup_target`,
   `last_backup_at`) or a dedicated `backups` table (`id, started_at, finished_at, status,
   size_bytes, location`).
9. **R9 — Save scope.** Save applies only **dirty** sections; a failed section doesn't roll back a
   successful one; each setting write is independent + audited.
10. **R10 — Offline = read-only.** No web outbox, so Settings cannot be changed offline; the guard
    prevents accidental edits that can't persist.

---

## 9. API interactions
| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Load | `GET /settings` | all `app_settings` (aging, reorder default, similarity, text ratio, backup) | last cache; read-only |
| Save thresholds/duplicates/backup | `PUT /settings` `{ key: value, … }` | upsert `app_settings` (audited via `updated_by`) | blocked offline |
| Load incentive rules | `GET /incentives/rules` | list `incentive_rules` | cache |
| Create rule | `POST /incentives/rules` | new rule | blocked offline |
| Edit / activate | `PATCH /incentives/rules/{id}` | update / toggle `is_active` | blocked offline |
| Deactivate | `PATCH /incentives/rules/{id}` `{is_active:0}` | soft-disable | blocked offline |
| GSTIN list | `GET /gst/registrations` | read GSTINs | cache |
| Backup now | `POST /settings/backup` *(Proposed)* | trigger server snapshot | blocked offline |

- Writes are owner-only; validation errors return `400 VALIDATION_ERROR` with `field`
  ([api-conventions.md](../../../foundation/api-conventions.md) §5).
- API docs: [../../api/incentives/incentives-api.md](../../api/incentives/incentives-api.md)
  (rules CRUD) · GSTIN read via [../../api/gst/gst-api.md](../../api/gst/gst-api.md). **⚠ Proposed
  API module** `api/settings/settings-api.md` for `GET/PUT /settings` + `POST /settings/backup`
  (no settings module exists in the current API map).

**`GET /settings` — key response fields**
`{ aging_threshold_days, default_reorder_threshold, dup_similarity_threshold, dup_text_ratio,
backup:{ frequency, time, retention_days, target, last_backup_at, last_status }, updated_by,
updated_at }`.

---

## 10. Offline & sync behavior
- **Read-cache + online writes only.** No Drift/outbox on web; Settings are read from a session
  cache offline and **cannot** be edited until back online (§8 R10).
- Setting changes are **server-authoritative**; other web screens read the new values on their
  next fetch — Settings does not push to clients. Mobile apps pull updated thresholds via the
  normal `GET /sync/pull` path
  ([sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md) §3), so a
  threshold change reaches staff/owner devices on their next sync.
- No `sync_status` is written here.

---

## 11. Analytics & events
| Event | When | Properties |
|---|---|---|
| `web_settings_viewed` | load | `section` |
| `web_setting_changed` | Save | `key`, `old`, `new` |
| `web_incentive_rule_created` | new rule | `rule_type`, `target_value`, `reward_value` |
| `web_incentive_rule_updated` | edit/toggle | `rule_id`, `is_active`, `changed_fields` |
| `web_similarity_threshold_changed` | Save | `old`, `new` |
| `web_backup_config_changed` / `web_backup_now` | backup | `frequency`, `retention_days` / `triggered` |

---

## 12. Accessibility, localization & performance
- **A11y** — labeled inputs; the similarity slider has a numeric readout + keyboard control +
  `aria-valuenow`; toggles are real switches with state text; help text explains each threshold's
  effect (not tooltip-only). WCAG AA light/dark; unsaved-changes guard is keyboard-dismissible.
- **Localization** — `₹` for reward values (Indian grouping); DD-MM-YYYY for rule dates; GSTIN
  format shown; strings localizable.
- **Performance** — tiny payloads; Save is per-section; downstream recompute is lazy (next load),
  keeping Settings snappy.

---

## 13. Acceptance criteria
- [ ] Aging threshold (`app_settings.aging_threshold_days`) is editable, validated (1–365), and on
      Save re-buckets the Stock Report aging tab on next load; per-product overrides are preserved.
- [ ] Default reorder / low-stock value is configurable and applies to new products without a
      per-product `reorder_threshold`.
- [ ] Incentive rules support full CRUD (`incentive_rules`): type, target, reward description/value,
      active dates, active toggle; rules are **soft-disabled**, never deleted (progress history kept).
- [ ] Duplicate similarity threshold (`app_settings.dup_similarity_threshold`) is adjustable
      (0.50–0.99) with clear "fewer prompts vs more misses" guidance; affects future checks only.
- [ ] GSTIN section lists registrations and links to GSTIN management; GSTIN format validated;
      inactive-not-deleted enforced.
- [ ] Backup section configures frequency/time/retention and shows last backup status; "Backup
      now" confirms before triggering a server snapshot.
- [ ] All settings writes are owner-only, audited (`updated_by`/`updated_at`), and blocked offline
      (read-only), with an unsaved-changes guard.
- [ ] Accountant sees values read-only.
- [ ] Fully keyboard-operable; every threshold explains its downstream effect.

---

## 14. Related docs
- Foundation: [data-model.md](../../../foundation/data-model.md) (`app_settings`,
  `incentive_rules`, `gst_registrations`) ·
  [duplicate-detection.md](../../../foundation/duplicate-detection.md) (similarity/text thresholds) ·
  [sync-and-conflict-resolution.md](../../../foundation/sync-and-conflict-resolution.md) (threshold pull to devices) ·
  [api-conventions.md](../../../foundation/api-conventions.md) ·
  [design-system.md](../../../foundation/design-system.md)
- API: [../../api/incentives/incentives-api.md](../../api/incentives/incentives-api.md) ·
  [../../api/gst/gst-api.md](../../api/gst/gst-api.md) · *(Proposed)* `../../api/settings/settings-api.md`
- Sibling web screens: [../stock/stock-report.md](../stock/stock-report.md) (thresholds) ·
  [../catalog/product-catalog-management.md](../catalog/product-catalog-management.md) (similarity) ·
  [../staff/staff-performance.md](../staff/staff-performance.md) (incentive rules) ·
  [../gst/gst-filing.md](../gst/gst-filing.md) (GSTINs)
- Mobile: [../../../mobile/owner/gst/gst-registrations.md](../../../mobile/owner/gst/gst-registrations.md)
