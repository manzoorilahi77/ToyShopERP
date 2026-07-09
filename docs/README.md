# ToyShop ERP — Documentation Index

A retail ERP for a battery-operated toy shop (cars, bikes, ride-ons, play sets).
One Flutter codebase → three build targets, one Node.js/Express + MySQL backend.

> **Business one-liner:** the system must feel less like "software" and more like a
> fast, forgiving assistant that a non-technical 19-year-old shop boy can use
> correctly on his 3rd day of work. Every design decision in these docs is measured
> against that bar.

---

## 1. The three surfaces

| Surface | Target | Primary user | Character |
|---|---|---|---|
| **Staff App** | Flutter Android/iOS | 5–6 sales staff | Offline-first, hardware-heavy (camera, BT printer), speed-obsessed |
| **Owner App** | Flutter Android/iOS | Shop owner | Lightweight, on-the-go approvals & quick reports |
| **Owner Web Dashboard** | Flutter Web | Owner / Accountant | Desktop, GST season, full ledgers & exports |
| **Backend** | Node.js/Express + MySQL | All three | Single API, sync-conflict resolution, source of truth |

---

## 2. Folder map

```
docs/
├── README.md                      ← you are here
├── requirements_and_prompt.md     ← original business brief (source of truth for scope)
│
├── foundation/                    ← cross-cutting, read these FIRST
│   ├── overview.md                architecture, tech stack, module map
│   ├── data-model.md              canonical MySQL schema + migrations
│   ├── sync-and-conflict-resolution.md   offline sync, WorkManager, stock reconciliation
│   ├── api-conventions.md         REST style, auth, envelopes, errors, pagination
│   ├── design-system.md           colors, type, spacing, components, UX laws
│   └── duplicate-detection.md     image-embedding + fuzzy-text duplicate service
│
├── _templates/
│   ├── screen-doc-template.md     structure every mobile/web screen doc follows
│   └── api-doc-template.md        structure every backend API doc follows
│
├── mobile/
│   ├── staff/                     Staff App — 7 screens
│   │   ├── auth/login.md
│   │   ├── dashboard/dashboard-home.md
│   │   ├── sales/new-sale.md
│   │   ├── sales/receipt.md
│   │   ├── sales/my-sales-history.md
│   │   ├── catalog/product-search-browse.md
│   │   └── profile/profile.md
│   └── owner/                     Owner App — 9 screens
│       ├── auth/login.md
│       ├── dashboard/dashboard-home.md
│       ├── approvals/discount-approval.md
│       ├── purchase/new-purchase.md
│       ├── catalog/product-catalog-management.md
│       ├── staff/staff-management.md
│       ├── reports/reports.md
│       ├── gst/gst-registrations.md
│       └── notifications/notifications.md
│
└── cloud/
    ├── web/                       Owner/Accountant Web Dashboard — 9 screens
    │   ├── auth/login.md
    │   ├── dashboard/dashboard-home.md
    │   ├── sales/sales-ledger.md
    │   ├── purchases/purchase-ledger.md
    │   ├── stock/stock-report.md
    │   ├── gst/gst-filing.md
    │   ├── staff/staff-performance.md
    │   ├── catalog/product-catalog-management.md
    │   └── settings/settings.md
    └── api/                       Backend REST API — by module
        ├── auth/auth-api.md
        ├── products/products-api.md
        ├── suppliers/suppliers-api.md
        ├── purchases/purchases-api.md
        ├── sales/sales-api.md
        ├── sync/sync-api.md
        ├── stock/stock-api.md
        ├── gst/gst-api.md
        ├── staff/staff-api.md
        ├── incentives/incentives-api.md
        ├── duplicate-detection/duplicate-detection-api.md
        ├── reports-notifications/reports-notifications-api.md
        └── settings/settings-api.md
```

---

## 3. How to read these docs

1. **Everyone starts in `foundation/`.** The schema, sync rules, API conventions and
   design system are the shared vocabulary. Screen and API docs reference them instead
   of repeating them.
2. **Screen docs** (mobile + web) follow [`_templates/screen-doc-template.md`](_templates/screen-doc-template.md):
   purpose → navigation → wireframe → field-by-field spec → states → business rules →
   API calls → offline behavior → acceptance criteria.
3. **API docs** follow [`_templates/api-doc-template.md`](_templates/api-doc-template.md):
   overview → tables → auth → endpoint-by-endpoint (request/response/errors) → business
   logic → edge cases.

---

## 4. Requirement → doc traceability

| Requirement (brief) | Where it's specified |
|---|---|
| R1 Continuous sync + offline fallback | [foundation/sync-and-conflict-resolution.md](foundation/sync-and-conflict-resolution.md), [api/sync](cloud/api/sync/sync-api.md) |
| R2 Duplicate prevention + exact retrieval | [foundation/duplicate-detection.md](foundation/duplicate-detection.md), [staff/new-sale](mobile/staff/sales/new-sale.md), [owner/catalog](mobile/owner/catalog/product-catalog-management.md) |
| R3 Easier-than-photo ID (QR, color, shelf, voice, favorites) | [staff/product-search-browse](mobile/staff/catalog/product-search-browse.md), [products-api](cloud/api/products/products-api.md) |
| R4 Purchase / Sales / GST / Stock flows | [owner/new-purchase](mobile/owner/purchase/new-purchase.md), [staff/new-sale](mobile/staff/sales/new-sale.md), [web/gst-filing](cloud/web/gst/gst-filing.md), [web/stock-report](cloud/web/stock/stock-report.md) |
| R5 Dashboards + staff incentives | [owner/dashboard](mobile/owner/dashboard/dashboard-home.md), [staff/dashboard](mobile/staff/dashboard/dashboard-home.md), [web/staff-performance](cloud/web/staff/staff-performance.md), [incentives-api](cloud/api/incentives/incentives-api.md) |
| R6 Screen-by-screen WBS per role | all of `mobile/` and `cloud/web/` |

---

## 5. Build order (from the brief — highest risk first)

1. MySQL schema + migrations → [foundation/data-model.md](foundation/data-model.md)
2. Sync-conflict-resolution logic → [foundation/sync-and-conflict-resolution.md](foundation/sync-and-conflict-resolution.md)
3. Node/Express API → [cloud/api/](cloud/api/)
4. Flutter shared package (models, API client, sync manager, dup-detection)
5. Staff app → [mobile/staff/](mobile/staff/)
6. Owner mobile app → [mobile/owner/](mobile/owner/)
7. Owner web dashboard → [cloud/web/](cloud/web/)

---

## 6. Status legend used in docs

`✅ Specified` · `🧩 Derived (design decision, confirm with owner)` · `⚠️ Risk / open question` · `🔒 Requires owner PIN`
