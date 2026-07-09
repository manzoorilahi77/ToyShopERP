# ToyShop ERP — Mobile Clickable Prototype

A **single Flutter app** that serves **both roles** (Staff and Owner). The user logs
in once; the app routes to the correct role's dashboard and navigation. Auth is the
only shared surface — everything after login forks by role.

> This is a **clickable prototype**. All data is dummy data from per-screen Dart
> files, deliberately shaped like the eventual API request/response so each screen
> can be wired to the real backend by swapping one repository method.

---

## Running it

```bash
cd sources/mobile/toyshop_erp
flutter pub get
flutter run              # pick an Android/iOS emulator or device
```

**Demo login:** on the "Who's billing?" picker, tap any face → enter **any 4-digit
PIN**. Staff faces land on the gamified Staff app; the **Owner** tile (bottom-right,
outlined) lands on the Owner app. Sign out from Staff → Profile, or Owner → More.

Tap the **sync chip** (top-right of any screen) to toggle online/offline and see the
offline banner behavior.

---

## Single app, role-based routing

```
main.dart → ToyShopApp (owns AppSession) → _RootGate
                                              ├─ not signed in      → LoginScreen (shared auth)
                                              ├─ role = staff        → StaffShell  (bottom nav)
                                              └─ role = owner/acct.   → OwnerShell  (bottom nav)
```

`AppSession` (an `InheritedNotifier`, `lib/core/session/app_session.dart`) holds the
signed-in `Account`. Signing in/out just flips the gate — no manual navigation.

- **Staff shell** tabs: Home · Sell · History · Catalog · Profile
- **Owner shell** tabs: Home · Approvals · Purchase · Reports · More
  (More → Catalog, Staff, GST, Notifications, Settings, Sign out)

---

## Folder map

```
lib/
├── main.dart                      app entry
├── app.dart                       ToyShopApp + role-based _RootGate
│
├── core/                          SHARED FOUNDATION (design system + primitives)
│   ├── core.dart                  barrel — `import 'package:toyshop_erp/core/core.dart'`
│   ├── theme/                     colors, typography, spacing, ThemeData (design-system.md)
│   ├── models/                    Account, Product, status enums (SyncState, StockState, Tone)
│   ├── session/                   AppSession + SessionScope
│   ├── utils/formats.dart         Fmt — ₹ Indian grouping + DD-MM-YYYY
│   └── widgets/                   AppScaffold, AppCard, KpiCard, AlertTile, NumericPad,
│                                  ProductTile, ItemConfirmCard, TonePill, StockPill,
│                                  SyncStatusChip, EmptyState, SkeletonBox, PIN sheet, …
│
├── auth/                          SHARED login (face picker incl. owner → PIN → role route)
│   ├── login_screen.dart
│   └── auth_data.dart             ← dummy roster
│
├── staff/                         STAFF role
│   ├── staff_shell.dart
│   ├── dashboard/                 dashboard_home_screen.dart  + dashboard_data.dart
│   ├── sales/                     new_sale · receipt · my_sales_history  (+ *_data.dart)
│   ├── catalog/                   product_search_browse_screen.dart + _data.dart
│   └── profile/                   profile_screen.dart + profile_data.dart
│
└── owner/                         OWNER role
    ├── owner_shell.dart
    ├── dashboard/                 dashboard_home_screen.dart + dashboard_data.dart
    ├── approvals/                 discount_approval_screen.dart + _data.dart
    ├── purchase/                  new_purchase_screen.dart + _data.dart
    ├── catalog/                   product_catalog_management_screen.dart + _data.dart
    ├── staff/                     staff_management_screen.dart + _data.dart
    ├── reports/                   reports_screen.dart + _data.dart
    ├── gst/                       gst_registrations_screen.dart + _data.dart
    ├── notifications/             notifications_screen.dart + _data.dart
    └── more/                      more_menu_screen.dart
```

Every screen lives under `lib/<role>/<screen>/` with its **dummy-data file co-located**
in the same folder, exactly as requested: `lib/staff/<screen>/<file>.dart` and
`lib/owner/<screen>/<file>.dart`.

---

## The dummy-data → API pattern

Each screen's data file is written so wiring the backend is a one-method change. The
pattern (see any `*_data.dart`):

```dart
// PROTOTYPE DUMMY DATA — replace StaffDashboardRepository.load() with
// GET /staff/{id}/dashboard (see docs/mobile/staff/dashboard/dashboard-home.md §9).

class StaffDashboardRepository {
  Future<StaffDashboardData> load() async {
    return _demo;               // ← today: returns dummy data
    // return _mapResponse(await api.get('/staff/$id/dashboard'));  // ← later: real API
  }
}
```

- Repository methods are **already `async`** so screens use `FutureBuilder`/`initState`
  loading with `SkeletonBox` placeholders — no UI changes when the real API lands.
- The dummy model classes mirror the **response field names** from each screen doc's
  §9 API table, so mapping to JSON is mechanical.
- Screens never touch the network directly; they only call their repository.

---

## Design system

All screens consume shared tokens/components (no per-screen colors or ad-hoc widgets):

- **Colors** via `context.palette` (light/dark aware) — `docs/foundation/design-system.md` §2.
- **Type scale** `AppType.{display,h1,h2,title,body,label,caption,money}` (tabular money).
- **Money** always `Fmt.money(...)` → `₹1,23,456.00` (Indian grouping); **dates** DD-MM-YYYY.
- **Status** always icon **+** label (never color alone): `TonePill`, `StockPill`,
  `SyncStatusChip`.
- **Offline-first tone:** calm offline banner + queued badges; skeletons on load, never a
  blocking spinner on the sale path.

---

## Notes & scope

- Colors are the design-system placeholders — swap for the shop's brand before launch.
- Product/staff "photos" are rendered as tinted placeholders (`ProductThumb`,
  `AvatarBadge`) so the prototype runs fully offline with no network images.
- Owner-PIN (🔒) actions open a real PIN sheet (`showOwnerPinSheet`) — any 4-digit PIN
  approves in the prototype.
- No real backend, no extra pub packages beyond `intl` (for ₹/date formatting).
