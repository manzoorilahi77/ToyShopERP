# Notifications — Owner · Mobile (Owner App)

> The owner's single inbox for everything that needs attention: **low stock**, **aging
> stock**, **sync failures**, **discount requests**, and **incentive milestones**. Filter
> by type, mark read, and tap to deep-link straight to the relevant screen.

Status: `✅ Specified` · read + mark-read; actions live on the deep-linked target screens.

---

## 1. Purpose & context
- **What this screen is for:** make sure nothing important slips past the owner while they
  float the floor — one place that aggregates alerts and routes to the fix.
- **Who & when:** the **owner** (`target_role='owner'` or `'all'`). Checked throughout the
  day; discount-request and sync-failure items are time-sensitive.
- **Why it exists:** the brief's Notifications screen must cover "low stock, aging stock,
  sync failures, discount requests" ([requirements R6](../../../requirements_and_prompt.md));
  incentive milestones (R5) are added so the owner can celebrate/act on staff progress.
  Undetected low/aging stock and silent sync failures are direct business risks.
- **Frequency / criticality:** high frequency during rushes (discount requests) and around
  restock/GST time (stock alerts); a missed sync-failure notification risks data loss
  visibility.

---

## 2. Entry points & navigation
- **Bell icon** (with unread badge) in the `AppScaffold` header on every Owner-App screen.
- **Push notification tap** opens the app directly on the relevant target (Login first if
  logged out), and this list reflects the same item.

```
Any screen (🔔 badge) ─▶ Notifications ─┬─ low_stock/aging_stock → Reports list / product
                                        ├─ sync_failure → Sync status sheet (retry)
                                        ├─ discount_request → Discount Approval
                                        └─ incentive → Staff performance snapshot
```
- **Back:** returns to the previous screen; unread items remain unread unless opened/marked.

---

## 3. Roles & permissions
| Actor | Access |
|---|---|
| Owner | ✅ all owner-targeted + `all` notifications; mark read; deep-link |
| Accountant | ✅ subset if targeted (`target_role` / `target_staff_id`) `🧩` |
| Staff | ❌ here (staff get their own incentive/sync notifications in the Staff App) |
- Read-only feed: the screen itself has no `🔒` actions. The deep-link **target** may be
  gated (e.g. [Discount Approval](../approvals/discount-approval.md) requires the owner PIN).

---

## 4. Screen layout (wireframe)

```
┌──────────────────────────────────────────────┐
│ ← Notifications          [ Mark all read ]     │
│ [All][Stock][Sync][Discounts][Incentive] ▾    │  ← type filter chips
├──────────────────────────────────────────────┤
│ ● 🟡 Discount request · Ravi K.      12s   ▶ │  ← unread (dot) → Discount Approval
│    "10% on Red Racer, cart ₹1,500"            │
├──────────────────────────────────────────────┤
│ ● 🔴 Sync failed · 2 sales queued     5m   ▶ │  → sync sheet (retry)
│    "Retries exhausted on device dev-abc123"   │
├──────────────────────────────────────────────┤
│   🟠 Low stock · Red Racer Car        1h   ▶ │  → Reports low-stock / product
│    "on-hand 2 / reorder 3"                     │
├──────────────────────────────────────────────┤
│   ⏳ Aging stock · Blue Jet Bike      3h   ▶ │  → Reports aging / product
│    "unsold 72 days"                            │
├──────────────────────────────────────────────┤
│   🏅 Incentive · Meena hit Tier 2     1d   ▶ │  → Staff performance
│    "₹5,00,000 monthly revenue"                │
├──────────────────────────────────────────────┤
│              (pull to refresh)                 │
└──────────────────────────────────────────────┘
```

- **Responsive:** phone = single scrolling list. Tablet = list + preview pane. Newest first;
  unread visually distinct (leading dot + weight), not by color alone.

---

## 5. UI components & field-by-field spec

| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Type filter chips | multi-chip | `notifications.type` enum: low_stock \| aging_stock \| sync_failure \| discount_request \| incentive \| system | — | All | filters list query | maps to `?type=` |
| 2 | Notification row | list row | `notifications` (type, title, body, created_at, is_read) | — | — | tap → mark read + deep-link | icon per type (§8 rule) |
| 3 | Unread indicator | leading dot + bold | `notifications.is_read=0` | — | unread | clears on open/mark | badge count = unread total |
| 4 | Type icon | icon | derived from `type` | — | — | — | 🟡 discount, 🔴 sync, 🟠 low, ⏳ aging, 🏅 incentive, ⓘ system |
| 5 | Timestamp | relative time | `notifications.created_at` | — | — | — | "12s / 5m / 1h / 1d"; absolute on long-press |
| 6 | Mark read (row) | swipe / tap | — | — | — | `POST /notifications/{id}/read` | optimistic; reverts on failure |
| 7 | Mark all read | button | — | — | — | bulk mark read | clears badge |
| 8 | Deep-link target | derived route | `ref_type` + `ref_id` | — | — | navigate | see routing table §8 |
| 9 | `SyncStatusChip` | status chip | [sync §8](../../../foundation/sync-and-conflict-resolution.md) | — | ✓ | tap → sync sheet | sync_failure rows also route here |
| 10 | Empty state | `EmptyState` | — | — | — | "You're all caught up" | friendly |

**Prose notes — deep-link routing (`ref_type` / `ref_id` → screen)**
| `type` | Icon | Deep-link target |
|---|---|---|
| `discount_request` | 🟡 | [Discount Approval](../approvals/discount-approval.md) (the request) |
| `sync_failure` | 🔴 | Sync status sheet (retry) — [sync §8](../../../foundation/sync-and-conflict-resolution.md) |
| `low_stock` | 🟠 | [Reports low-stock](../reports/reports.md) / the product |
| `aging_stock` | ⏳ | [Reports aging](../reports/reports.md) / the product |
| `incentive` | 🏅 | [Staff performance snapshot](../staff/staff-management.md) |
| `system` | ⓘ | in-app info (e.g. app update, settings) |

- Rows are generated server-side by the **notification generator** (cron/worker,
  [overview §3](../../../foundation/overview.md)); the owner also receives them as **push**
  via the `devices.push_token` registered at [login](../auth/login.md).
- The **`sync_failure`** type corresponds to the sync doc's retry-ceiling notification
  ([sync §8](../../../foundation/sync-and-conflict-resolution.md)) — the one alert that can
  indicate data at risk, so it is styled most prominently.

---

## 6. States
- **Default / populated:** reverse-chronological feed with unread items highlighted.
- **Empty:** `EmptyState` "You're all caught up — no notifications."
- **Loading:** skeleton rows.
- **Error:** inline retry on the list; a failed mark-read reverts the optimistic change.
- **Offline:** cached notifications render (marked stale); **mark-read queues** and syncs
  later; deep-links to cached screens work, live ones (discount approve) note "connect."
- **Success:** mark-read clears the dot instantly; "Mark all read" empties the badge.
- **Permission-denied:** items not targeted to this owner are not fetched.

---

## 7. Interactions, gestures & hardware
- **Tap** a row → optimistically mark read **and** deep-link to the target.
- **Swipe** a row → mark read (or mark unread to re-flag).
- **Pull-to-refresh** re-fetches; **push** inserts new rows live at the top with a subtle
  highlight.
- **Long-press** → show absolute timestamp + copy details.
- No camera/printer/scanner.
- **Latency:** list paint from cache < 200 ms; mark-read feels instant (optimistic).

---

## 8. Business rules & edge cases
1. Each row carries a `type` from the canonical enum; the **icon + text label** encode
   meaning (never color alone).
2. **Tap = mark read + navigate** in one gesture; unread badge decrements immediately.
3. **Idempotent mark-read:** repeat `POST …/read` is a no-op; offline marks queue and
   de-dupe on sync.
4. **Deep-link resolves via `ref_type` + `ref_id`;** if the target no longer exists (e.g.
   product deactivated), the row opens a graceful fallback ("item no longer available").
5. **Discount-request notifications** mirror the live [Discount Approval](../approvals/discount-approval.md)
   queue; deciding there resolves the notification's actionability (still shown in history).
6. **Sync-failure notifications** are raised only after the retry ceiling is exceeded
   ([sync §3/§8](../../../foundation/sync-and-conflict-resolution.md)); tapping opens the
   sync sheet with a **retry now** action.
7. **Low/aging-stock notifications** are generated against `app_settings` thresholds (and
   per-product overrides); tapping lands on the matching Reports drill-down.
8. **Incentive milestones** fire when a staff member crosses a tier in
   `staff_incentive_progress`; the owner may act (adjust reward) from the linked snapshot.
9. **Targeting:** only `target_role IN ('owner','all')` (or `target_staff_id` = owner) rows
   appear here; staff-targeted rows are for the Staff App.

---

## 9. API interactions

| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|
| Open / refresh | `GET /notifications?target=owner&type=&is_read=` | list feed (filterable) | cached read |
| Unread badge | `GET /notifications?is_read=false&per_page=1` | unread count | cached count |
| Mark read | `POST /notifications/{id}/read` | set `is_read=1` | **queued**, optimistic UI |
| Mark all read | `POST /notifications/read-all` `🧩` | bulk mark | queued |
| Push receive | (FCM/APNs) | live insert via `devices.push_token` | delivered when online |

Key fields (see
[reports-notifications-api](../../../cloud/api/reports-notifications/reports-notifications-api.md)):
- **list item:** `{ id, type, title, body, ref_type, ref_id, is_read, created_at }`
- **filters:** `?type=low_stock,aging_stock,sync_failure,discount_request,incentive` +
  `?is_read=false` + cursor pagination
- Envelope/pagination/errors per [api-conventions §4,§7](../../../foundation/api-conventions.md).

---

## 10. Offline & sync behavior
- **Works offline:** browse the cached feed; **mark-read queues** and applies on sync
  (idempotent, de-duped).
- **Queued:** mark-read / mark-all-read actions.
- **Blocked offline:** receiving **new** push notifications (needs connectivity) and
  deep-links into live actions (e.g. approving a discount).
- **Source of truth:** `notifications` rows are generated server-side; the sync worker's
  `GET /sync/pull` also brings new notifications alongside other server changes
  ([sync §3](../../../foundation/sync-and-conflict-resolution.md)).

---

## 11. Analytics & events
- `notifications_viewed`
- `notification_filter_changed` (type)
- `notification_opened` (type, ref_type)
- `notification_marked_read` (type) / `notifications_mark_all_read`
- `notification_deeplink_failed` (target missing)
- `push_notification_received` (type)

---

## 12. Accessibility, localization & performance
- Each row's meaning is icon + label + text, never color alone; unread state also uses a dot
  + bold weight (not color).
- Screen-reader announces "unread, <type>, <title>, <relative time>, tap to open."
- `₹` Indian grouping in stock/discount bodies; dates **DD-MM-YYYY** (absolute on
  long-press); GST/stock terms localized.
- List virtualized for long histories; cached paint < 200 ms; mark-read optimistic.

---

## 13. Acceptance criteria
- [ ] The feed shows the five required categories: low stock, aging stock, sync failures,
      discount requests, and incentive milestones (+ system).
- [ ] Type filter chips narrow the list; "All" is the default.
- [ ] Tapping a row marks it read and deep-links to the correct screen via `ref_type`/`ref_id`.
- [ ] Unread count/badge reflects `is_read=0` and clears on open / mark-all-read.
- [ ] A `sync_failure` notification appears only after the retry ceiling and routes to the
      sync sheet with a retry action.
- [ ] A `discount_request` notification mirrors the live approval queue and opens it.
- [ ] Mark-read works offline (queued, optimistic) and is idempotent on sync.
- [ ] A deep-link to a removed target degrades gracefully instead of erroring.

---

## 14. Related docs
- Foundation: [data-model](../../../foundation/data-model.md) (`notifications`, `devices`) ·
  [sync](../../../foundation/sync-and-conflict-resolution.md) (`sync_failure`) ·
  [api-conventions](../../../foundation/api-conventions.md) ·
  [design-system](../../../foundation/design-system.md)
- API: [reports-notifications-api](../../../cloud/api/reports-notifications/reports-notifications-api.md)
- Sibling screens: [Discount Approval](../approvals/discount-approval.md) ·
  [Reports](../reports/reports.md) · [Staff Management](../staff/staff-management.md) ·
  [Dashboard Home](../dashboard/dashboard-home.md) · [Login](../auth/login.md)
- Counterpart: [web dashboard](../../../cloud/web/dashboard/dashboard-home.md)
