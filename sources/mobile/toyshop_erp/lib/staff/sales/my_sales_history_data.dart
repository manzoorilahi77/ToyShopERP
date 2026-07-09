// PROTOTYPE DUMMY DATA — replace MySalesHistoryRepository.load() with
//   GET /sales?staff_id={me}&from=&to=&sort=sold_at&order=desc
// (see doc §9, docs/mobile/staff/sales/my-sales-history.md). Filtering here
// runs client-side over [_demo] exactly the way it would offline against the
// Drift `sales` cache (doc §10).

import '../../core/core.dart';
import 'receipt_data.dart';

/// Date-range chip options (my-sales-history doc §5 row 1).
enum DateRangeFilter {
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This week'),
  thisMonth('This month'),
  custom('Custom');

  const DateRangeFilter(this.label);
  final String label;
}

/// Aggregated totals for the current filtered range (doc §5 row 3) — count,
/// units, revenue and a payment-mode split, computed over the filtered set
/// including still-pending local sales (doc rule 5).
class SalesSummary {
  const SalesSummary({
    required this.saleCount,
    required this.units,
    required this.revenue,
    required this.byPayment,
  });

  final int saleCount;
  final int units;
  final double revenue;
  final Map<PaymentMode, double> byPayment;

  static const empty = SalesSummary(saleCount: 0, units: 0, revenue: 0, byPayment: {});
}

/// The staff member's own sales — scoped server-side to `staff_id={me}` (doc
/// rule 1) and, in this prototype, to the single demo dataset below.
class MySalesHistoryRepository {
  const MySalesHistoryRepository();

  /// `GET /sales?staff_id={me}&from=&to=` (doc §9). [query] is an extra
  /// client-side convenience (invoice ref / item name) layered on top of the
  /// doc's date-range filter.
  Future<List<ReceiptData>> load({
    DateRangeFilter filter = DateRangeFilter.today,
    DateTime? from,
    DateTime? to,
    String query = '',
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final range = _rangeFor(filter, from: from, to: to);
    var rows = _demo.where((r) {
      return !r.soldAt.isBefore(range.$1) && r.soldAt.isBefore(range.$2);
    }).toList();
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      rows = rows.where((r) {
        return r.displayRef.toLowerCase().contains(q) ||
            r.items.any((l) => l.name.toLowerCase().contains(q));
      }).toList();
    }
    rows.sort((a, b) => b.soldAt.compareTo(a.soldAt));
    return rows;
  }

  /// Totals over whatever range/query is currently showing (doc rule 5) —
  /// computed client-side; a very large server range would instead show a
  /// "computed on server" note (doc rule 9, 🧩).
  SalesSummary summarize(List<ReceiptData> rows) {
    if (rows.isEmpty) return SalesSummary.empty;
    final byPayment = <PaymentMode, double>{};
    var units = 0;
    var revenue = 0.0;
    for (final r in rows) {
      units += r.totalUnits;
      revenue += r.total;
      byPayment.update(r.paymentMode, (v) => v + r.total, ifAbsent: () => r.total);
    }
    return SalesSummary(saleCount: rows.length, units: units, revenue: revenue, byPayment: byPayment);
  }

  (DateTime, DateTime) _rangeFor(DateRangeFilter f, {DateTime? from, DateTime? to}) {
    final startOfToday = DateTime(_demoNow.year, _demoNow.month, _demoNow.day);
    final startOfTomorrow = startOfToday.add(const Duration(days: 1));
    switch (f) {
      case DateRangeFilter.today:
        return (startOfToday, startOfTomorrow);
      case DateRangeFilter.yesterday:
        return (startOfToday.subtract(const Duration(days: 1)), startOfToday);
      case DateRangeFilter.thisWeek:
        final weekStart = startOfToday.subtract(Duration(days: startOfToday.weekday - 1));
        return (weekStart, startOfTomorrow);
      case DateRangeFilter.thisMonth:
        final monthStart = DateTime(_demoNow.year, _demoNow.month, 1);
        return (monthStart, startOfTomorrow);
      case DateRangeFilter.custom:
        final start = from == null ? startOfToday : DateTime(from.year, from.month, from.day);
        final endExclusive =
            (to == null ? startOfToday : DateTime(to.year, to.month, to.day)).add(const Duration(days: 1));
        return (start, endExclusive);
    }
  }
}

/// Fixed "now" for the whole prototype (matches dashboard_data.dart's `asOf`
/// and Fmt.ago's reference clock) so "Today" always has rich demo data
/// regardless of the device's real date.
final DateTime _demoNow = DateTime(2026, 7, 3, 19, 45);

ReceiptLine _li(String id, String name, int qty, double price, {int gst = 18}) =>
    ReceiptLine(productId: id, name: name, qty: qty, unitPrice: price, gstRate: gst);

ReceiptData _sale({
  required String id,
  String? inv,
  required DateTime at,
  required List<ReceiptLine> items,
  double discount = 0,
  String? discountBy,
  required PaymentMode pay,
  required SyncState sync,
  String staff = 'You',
}) {
  return ReceiptData(
    clientUuid: id,
    invoiceNo: inv,
    soldAt: at,
    staffName: staff,
    items: items,
    discountAmount: discount,
    discountApprovedBy: discountBy,
    paymentMode: pay,
    syncStatus: sync,
  );
}

final List<ReceiptData> _demo = [
  // --- Today (2026-07-03) — newest first, 14 sales ---
  _sale(
    id: 'a1b2c301', inv: 'GST1/26-27/000420', at: DateTime(2026, 7, 3, 19, 45),
    items: [_li('ns-01', 'Red Racer Battery Car', 2, 1499), _li('ns-13', 'Doll House', 1, 750, gst: 12)],
    pay: PaymentMode.cash, sync: SyncState.synced,
  ),
  _sale(
    id: 'a1b2c302', inv: 'GST1/26-27/000419', at: DateTime(2026, 7, 3, 19, 32),
    items: [_li('ns-12', 'Robot Walker', 3, 999)],
    pay: PaymentMode.upi, sync: SyncState.synced,
  ),
  _sale(
    id: 'a1b2c303', at: DateTime(2026, 7, 3, 19, 20),
    items: [_li('ns-10', 'RC Racer Blue', 2, 1350)],
    pay: PaymentMode.cash, sync: SyncState.pending,
  ),
  _sale(
    id: 'a1b2c304', at: DateTime(2026, 7, 3, 19, 5),
    items: [_li('ns-15', 'Baby Doll Pram', 1, 1120, gst: 12)],
    pay: PaymentMode.card, sync: SyncState.syncing,
  ),
  _sale(
    id: 'a1b2c305', at: DateTime(2026, 7, 3, 18, 58),
    items: [_li('ns-18', 'Trampoline Small', 1, 3499)],
    pay: PaymentMode.upi, sync: SyncState.failed,
  ),
  _sale(
    id: 'a1b2c306', inv: 'GST1/26-27/000413', at: DateTime(2026, 7, 3, 18, 40),
    items: [_li('ns-07', 'Kitchen Play Set', 1, 1750), _li('ns-08', 'Tool Bench Set', 1, 1290)],
    pay: PaymentMode.cash, sync: SyncState.synced,
  ),
  _sale(
    id: 'a1b2c307', inv: 'GST1/26-27/000412', at: DateTime(2026, 7, 3, 18, 15),
    items: [_li('ns-14', 'Fashion Doll Set', 2, 620, gst: 12)],
    pay: PaymentMode.cash, sync: SyncState.synced,
  ),
  _sale(
    id: 'a1b2c308', inv: 'GST1/26-27/000411', at: DateTime(2026, 7, 3, 17, 50),
    items: [_li('ns-04', 'Mini Jeep', 1, 4200)],
    pay: PaymentMode.upi, sync: SyncState.synced,
  ),
  _sale(
    id: 'a1b2c309', inv: 'GST1/26-27/000410', at: DateTime(2026, 7, 3, 17, 22),
    items: [_li('ns-16', 'Cricket Set Junior', 2, 549, gst: 12), _li('ns-17', 'Badminton Combo', 1, 399, gst: 12)],
    pay: PaymentMode.cash, sync: SyncState.synced,
  ),
  _sale(
    id: 'a1b2c310', inv: 'GST1/26-27/000409', at: DateTime(2026, 7, 3, 16, 45),
    items: [_li('ns-02', 'Blue Thunder Racer', 1, 1899)],
    pay: PaymentMode.card, sync: SyncState.synced,
  ),
  _sale(
    id: 'a1b2c311', inv: 'GST1/26-27/000408', at: DateTime(2026, 7, 3, 15, 30),
    items: [_li('ns-06', 'Trike Trooper', 2, 1350)],
    pay: PaymentMode.cash, sync: SyncState.synced,
  ),
  _sale(
    id: 'a1b2c312', inv: 'GST1/26-27/000407', at: DateTime(2026, 7, 3, 14, 10),
    items: [_li('ns-11', 'RC Helicopter', 1, 2450)],
    pay: PaymentMode.upi, sync: SyncState.synced,
  ),
  _sale(
    id: 'a1b2c313', inv: 'GST1/26-27/000406', at: DateTime(2026, 7, 3, 11, 5),
    items: [_li('ns-03', 'Yellow Jeep Battery Car', 1, 2599)],
    discount: 200, discountBy: 'Owner (PIN)',
    pay: PaymentMode.cash, sync: SyncState.synced,
  ),
  _sale(
    id: 'a1b2c314', inv: 'GST1/26-27/000405', at: DateTime(2026, 7, 3, 10, 20),
    items: [_li('ns-13', 'Doll House', 2, 750, gst: 12)],
    pay: PaymentMode.cash, sync: SyncState.synced,
  ),

  // --- Yesterday (2026-07-02) ---
  _sale(
    id: 'b2c40301', inv: 'GST1/26-27/000404', at: DateTime(2026, 7, 2, 20, 10),
    items: [_li('ns-04', 'Mini Jeep', 1, 4200)],
    pay: PaymentMode.cash, sync: SyncState.synced,
  ),
  _sale(
    id: 'b2c40302', inv: 'GST1/26-27/000403', at: DateTime(2026, 7, 2, 18, 30),
    items: [_li('ns-01', 'Red Racer Battery Car', 1, 1499)],
    pay: PaymentMode.upi, sync: SyncState.synced,
  ),
  _sale(
    id: 'b2c40303', inv: 'GST1/26-27/000402', at: DateTime(2026, 7, 2, 12, 15),
    items: [_li('ns-16', 'Cricket Set Junior', 3, 549, gst: 12)],
    pay: PaymentMode.cash, sync: SyncState.synced,
  ),

  // --- Earlier this week (Mon–Wed) ---
  _sale(
    id: 'c3040001', inv: 'GST1/26-27/000399', at: DateTime(2026, 6, 30, 16, 0),
    items: [_li('ns-07', 'Kitchen Play Set', 1, 1750)],
    pay: PaymentMode.cash, sync: SyncState.synced,
  ),
  _sale(
    id: 'c3040002', inv: 'GST1/26-27/000401', at: DateTime(2026, 7, 1, 11, 20),
    items: [_li('ns-05', 'Baby Bike Pink', 1, 2100)],
    pay: PaymentMode.upi, sync: SyncState.synced,
  ),

  // --- Further back in June — outside Today/Yesterday/This week/This month
  // (the fixed "now" is 3 July, so "This month" only reaches back to 1 July);
  // these two only surface via the Custom range picker, which demonstrates
  // it actually re-scopes the list rather than just decorating a chip. ---
  _sale(
    id: 'd4050001', inv: 'GST1/26-27/000350', at: DateTime(2026, 6, 15, 14, 0),
    items: [_li('ns-18', 'Trampoline Small', 1, 3499)],
    pay: PaymentMode.cash, sync: SyncState.synced,
  ),
  _sale(
    id: 'd4050002', inv: 'GST1/26-27/000320', at: DateTime(2026, 6, 5, 10, 0),
    items: [_li('ns-11', 'RC Helicopter', 1, 2450)],
    pay: PaymentMode.upi, sync: SyncState.synced,
  ),
];
