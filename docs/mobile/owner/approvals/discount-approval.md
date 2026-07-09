# Discount Approval — Owner · Mobile (Owner App) `🔒`

> The owner's real-time inbox of discount requests raised by staff mid-sale. Each request
> shows the product(s), requested amount/percent, cart total, requester and reason; the
> owner approves or rejects **with their PIN**. The decision links back to the staff's
> **pending sale** via `discount_approvals.sale_client_uuid`.

Status: `✅ Specified` · every decision is `🔒 owner-PIN` gated · one `⚠️` schema gap (§5).

---

## 1. Purpose & context
- **What this screen is for:** let the owner approve/reject a discount in seconds while on
  the floor, without walking to the till, so the customer isn't kept waiting.
- **Who & when:** the **owner** (`role='owner'`). Peaks during evening/weekend rushes when
  staff negotiate with "demanding customers."
- **Why it exists:** "the owner … personally negotiates and approves discounts" and
  "discounts require owner PIN" ([requirements](../../../requirements_and_prompt.md), R4
  sales flow). Money leaks through unauthorized discounts are a core control this screen
  enforces (overview principle 5: *owner-PIN gates money leaks*).
- **Frequency / criticality:** several times an hour at peak; each decision directly moves
  margin, so the approve/reject action must be fast **and** deliberate (PIN-gated,
  auditable).

---

## 2. Entry points & navigation
- **Push notification** `discount_request` (primary) → deep-links straight here (via Login
  if logged out).
- **Approvals** bottom-nav tab (badge shows pending count).
- **Dashboard** pending-approvals badge.

```
Staff New-Sale (discount requested) ──push──▶ Owner: Discount Approval
        │                                            │ approve/reject + PIN
        └──────────── decision synced ◀──────────────┘
                        (staff cart unblocks)
```
- **Back button:** returns to the previous screen (Dashboard/Notifications); an undecided
  request stays `pending`.

---

## 3. Roles & permissions
| Actor | Access |
|---|---|
| Owner | ✅ view list; approve/reject **`🔒` PIN required per decision** |
| Accountant | 👁 view-only (no approve/reject) `🧩` |
| Staff | ❌ cannot open (they only *request* from the Staff App) |
- **`🔒`** Approve and Reject both require a fresh owner PIN via `POST /auth/verify-pin`
  (or inline PIN in the decide call). `discount_approvals.pin_verified` is set on approval.
- Approving sets `discount_approvals.approved_by` = owner `staff.id`; the linked sale's
  `sales.discount_approved_by` is stamped on the staff side at sale confirm.

---

## 4. Screen layout (wireframe)

```
┌──────────────────────────────────────────────┐
│  ← Discount Approvals            ✓sync   ⋮     │
│  Pending (2)   |   History                     │  ← tabs
├──────────────────────────────────────────────┤
│  ┌────────────────────────────────────────┐    │
│  │ (photo) Ravi K.        · 12s ago  🟡pend │   │  ← request card
│  │ Battery Car "Red Racer" ×1              │   │     product summary
│  │ Requested: 10%  (−₹150.00)              │   │     amount / percent
│  │ Cart total: ₹1,500.00 → ₹1,350.00       │   │     before → after
│  │ Reason: "Repeat customer, floor demo"   │   │
│  │ uuid: 0f8b… (pending sale)              │   │  ← sale_client_uuid
│  │  [  ✗ Reject  ]      [  ✓ Approve  ]     │   │  ← both PIN-gated
│  └────────────────────────────────────────┘    │
│  ┌────────────────────────────────────────┐    │
│  │ (photo) Meena     · 40s ago     🟡pend  │   │
│  │ Ride-on Bike "Blue Jet" ×1              │   │
│  │ Requested: ₹200.00 flat                 │   │
│  │ Cart total: ₹4,200.00 → ₹4,000.00       │   │
│  │  [  ✗ Reject  ]      [  ✓ Approve  ]     │   │
│  └────────────────────────────────────────┘    │
├──────────────────────────────────────────────┤
│  (tap Approve) ▶ PinDialog  ● ● ● ●            │  ← owner PIN, masked
└──────────────────────────────────────────────┘
```

- **Responsive:** phone = single column of cards; tablet = 2 columns. Newest pending on
  top. **History** tab lists decided requests (approved/rejected + timestamp + who).

---

## 5. UI components & field-by-field spec

| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Pending / History tabs | segmented | `status=pending` vs decided | — | Pending | switches list query | pending count badge |
| 2 | Requester | avatar + name | `discount_approvals.staff_id` → `staff.name/photo_url` | — | — | — | who asked |
| 3 | Age | relative time | `discount_approvals.created_at` | — | — | live-updates | "12s ago" |
| 4 | Product summary | text | line items of the pending cart (from push payload) | — | — | — | **not a column** — see note |
| 5 | Requested amount/percent | money or % | `discount_approvals.requested_amount` (+ type) | server: within staff/owner discount policy | — | drives before→after | **type (amount/percent) `⚠️` proposed** |
| 6 | Cart total (before→after) | money | push payload `cart_total`; after = total − discount | — | — | recompute on render | **`cart_total` not a column — `⚠️` proposed** |
| 7 | Reason | text | `discount_approvals.reason` | — | "(no reason)" | — | optional, staff-entered |
| 8 | `sale_client_uuid` chip | mono label | `discount_approvals.sale_client_uuid` | — | — | tap = copy | the link to the pending sale |
| 9 | Approve `🔒` | primary button | — | opens `PinDialog`; PIN must match owner | disabled while deciding | `POST /discount-approvals/{id}/decide {approve, owner_pin}` | success → card → History |
| 10 | Reject `🔒` | danger button | — | opens `PinDialog` | — | same endpoint, `decision=rejected` | staff notified, sale unblocks at full price |
| 11 | `PinDialog` | masked numeric 4–6 | owner PIN | required; matches `pin_hash` | empty | verifies → executes decision | shared design-system component |
| 12 | Amend & approve `🧩` | secondary action | owner overrides requested value | ≤ policy max | hidden by default | approves a *different* amount than requested | optional; audited |
| 13 | `SyncStatusChip` | status chip | [sync §8](../../../foundation/sync-and-conflict-resolution.md) | — | ✓ | — | shows if decisions are queued |

**Prose notes — how the link to the pending sale works**
- When staff request a discount, the Staff App generates the **sale's `client_uuid` first**
  (before the sale is saved) and sends it as `discount_approvals.sale_client_uuid`. The
  sale row itself may not exist server-side yet — the request references the *future* sale.
- The owner's approve/reject writes the **decision** onto that `discount_approvals` row
  (`status`, `approved_by`, `pin_verified`, `decided_at`).
- The Staff App, polling / pushed the decision, then finalizes the sale with the same
  `client_uuid`; on sale sync the server stamps `sales.discount_approved_by = approved_by`
  and `sales.discount_amount`. Because both sides key on `client_uuid`, the decision and
  the sale reconcile even if either arrives out of order (idempotent, see
  [sync §5](../../../foundation/sync-and-conflict-resolution.md)).
- **Product summary & cart total are carried in the request/push payload**, not stored as
  columns on `discount_approvals`.

> **⚠️ Proposed schema addition:** `discount_approvals.discount_type ENUM('amount','percent')
> DEFAULT 'amount'` and `discount_approvals.cart_total DECIMAL(12,2) NULL`. The canonical
> table ([data-model §5](../../../foundation/data-model.md)) stores `requested_amount`
> ("or percent — see api") and `reason` but has **no** explicit percent flag, no cart total,
> and no product reference. To render "10% (−₹150) · Cart ₹1,500 → ₹1,350 · Red Racer ×1"
> deterministically (rather than only from a volatile push payload), add `discount_type` +
> `cart_total`; the product summary can stay payload-only or be added as
> `discount_approvals.cart_summary_json JSON NULL`.

---

## 6. States
- **Default / populated:** list of pending request cards, newest first, live age counters.
- **Empty:** `EmptyState` "No pending discount requests — you're all caught up."
- **Loading:** skeleton cards while `GET /discount-approvals` resolves.
- **Error:** inline retry on the list; a failed **decide** call keeps the card pending and
  shows "Couldn't submit — retry."
- **Offline:** decisions **require the network** (PIN verify + immediate staff unblock).
  Offline shows a banner "Connect to approve discounts"; Approve/Reject are disabled, not
  hidden, so the owner knows why.
- **Success:** approved/rejected card animates out with a toast; History updates.
- **Permission-denied:** wrong PIN → inline "PIN incorrect" in the `PinDialog` (3 tries →
  30 s soft-lock + server `429`); accountant sees view-only cards without action buttons.

---

## 7. Interactions, gestures & hardware
- **Tap Approve/Reject** → `PinDialog` (`NumericPad`, masked).
- **Swipe** a card left = quick Reject, right = quick Approve (still routes through PIN).
- **Pull-to-refresh** re-fetches pending (push already keeps it live).
- **Real-time:** an incoming `discount_request` push inserts the card at top with a subtle
  highlight + optional sound/vibration so the owner notices during a rush.
- **Latency budget:** decision round-trip target < 1.5 s so the staff cart unblocks fast;
  the owner sees optimistic card removal immediately on server ack.

---

## 8. Business rules & edge cases
1. Every decision is `🔒`: no approval without a verified owner PIN (`pin_verified=1`).
2. A request is single-decision: once `status ∈ {approved, rejected}` it is immutable;
   re-taps are no-ops (idempotent by request `id`).
3. **Stale/expired request:** if the staff already cancelled or completed the sale at full
   price, the server returns `422 BUSINESS_RULE` ("request no longer active") and the card
   moves to History as "expired."
4. **Reject** → staff cart proceeds at full price; no discount is written; owner reason
   optional.
5. **Approve** → the linked sale (by `sale_client_uuid`) may carry the discount; the server
   enforces that `sales.discount_amount > 0` requires a matching approved request, else the
   sale sync is rejected `422` (prevents discount without approval).
6. **Amend-and-approve** records the owner-set amount, not the requested one; the delta is
   captured in `audit_log` (`action='discount.approve'`).
7. **Percent vs flat:** percent requests resolve to a rupee amount against `cart_total` at
   decision time; the stored effect on the sale is the resolved `discount_amount`.
8. **Duplicate pushes** of the same request are de-duped by request `id`; the card never
   appears twice.
9. **Multiple owners/devices:** the first PIN-verified decision wins; a second device sees
   the card already resolved (server is source of truth).
10. All approvals/rejections write `audit_log` (actor, before/after, device) for traceability.

---

## 9. API interactions

| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Open / refresh / push | `GET /discount-approvals?status=pending` | list pending requests | cached list; decisions still blocked offline |
| History tab | `GET /discount-approvals?status=approved,rejected&sort=decided_at&order=desc` | decided log | cached |
| Approve/Reject `🔒` | `POST /discount-approvals/{id}/decide` | body `{ decision:'approved'\|'rejected', owner_pin \| X-Owner-Pin-Token, amount? }` → writes `status, approved_by, pin_verified, decided_at` | **blocked offline** |
| PIN token (optional) | `POST /auth/verify-pin` | obtain `X-Owner-Pin-Token` to batch several decisions | blocked offline |

Key fields (see [sales-api](../../../cloud/api/sales/sales-api.md) discount section &
[api-conventions](../../../foundation/api-conventions.md)):
- **list item:** `{ id, sale_client_uuid, staff:{id,name,photo_url}, requested_amount,
  discount_type⚠️, cart_total⚠️, reason, status, created_at }`
- **decide req:** `{ decision, owner_pin, amount? }` (with `Idempotency-Key = id`)
- **decide resp:** `{ id, status, approved_by, decided_at }`; errors: `403 FORBIDDEN`
  (PIN wrong/role), `422 BUSINESS_RULE` (expired/inactive), `429 RATE_LIMITED`.

---

## 10. Offline & sync behavior
- **Requires online:** approve/reject is a control action that must reach the server and
  unblock the staff cart promptly — it is intentionally **not** queued offline.
- **Cached read:** the pending list is viewable from cache offline, marked stale.
- **Cross-device truth:** decisions live server-side on `discount_approvals`; the Staff App
  reconciles via `GET /sync/pull` and the sale's `client_uuid` link, per
  [sync-and-conflict-resolution.md §4–5](../../../foundation/sync-and-conflict-resolution.md).
- No Drift outbox rows are written on the Owner App for this action.

---

## 11. Analytics & events
- `discount_request_received` (via push; id, staff_id)
- `discount_approval_viewed`
- `discount_decided` (decision, requested_amount, final_amount, latency_ms, amended: bool)
- `discount_pin_failed`
- `discount_request_expired`

---

## 12. Accessibility, localization & performance
- Approve (success) and Reject (danger) differ by **icon + label + position**, not color
  alone; buttons ≥ 48 dp.
- `PinDialog` announces masked entry to screen readers; amounts announced as "minus ₹150,
  ten percent."
- `₹` Indian grouping, **DD-MM-YYYY** in History; percent shown with the resolved rupee
  value alongside.
- New-request insert animation respects "reduce motion"; decision round-trip target < 1.5 s.

---

## 13. Acceptance criteria
- [ ] A staff discount request appears here in real time via push (and on pull refresh).
- [ ] Each card shows product summary, requested amount/percent, cart total before→after,
      requester, reason, and the `sale_client_uuid` link.
- [ ] Approve and Reject each require a valid owner PIN; wrong PIN blocks the decision.
- [ ] Approving stamps `status='approved'`, `approved_by`, `pin_verified=1`, `decided_at`.
- [ ] The decision reconciles to the correct pending sale by `sale_client_uuid` even if the
      sale syncs afterward.
- [ ] A sale carrying `discount_amount > 0` without a matching approved request is rejected
      server-side (`422`).
- [ ] Deciding an already-completed/cancelled request returns `422` and shows "expired."
- [ ] Offline disables (not hides) Approve/Reject with a "connect to approve" banner.
- [ ] Every decision writes an `audit_log` entry (actor, before/after, device).

---

## 14. Related docs
- Foundation: [data-model](../../../foundation/data-model.md) (`discount_approvals`, `sales`) ·
  [sync](../../../foundation/sync-and-conflict-resolution.md) ·
  [api-conventions](../../../foundation/api-conventions.md) ·
  [design-system](../../../foundation/design-system.md)
- API: [sales-api](../../../cloud/api/sales/sales-api.md) ·
  [auth-api](../../../cloud/api/auth/auth-api.md) ·
  [reports-notifications-api](../../../cloud/api/reports-notifications/reports-notifications-api.md)
- Sibling screens: [Dashboard Home](../dashboard/dashboard-home.md) ·
  [Notifications](../notifications/notifications.md)
- Counterpart: [staff new-sale](../../staff/sales/new-sale.md) (the requesting side)
