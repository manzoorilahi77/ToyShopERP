import 'package:intl/intl.dart';

/// Formatting helpers — money uses `₹` with **Indian digit grouping**
/// (1,23,456.00) and dates use **DD-MM-YYYY**, per design-system.md §3/§10.
class Fmt {
  const Fmt._();

  static final NumberFormat _rupee = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _rupee0 = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final NumberFormat _compact = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
  );

  static final NumberFormat _plain = NumberFormat.decimalPattern('en_IN');

  /// `₹1,23,456.00`
  static String money(num value) => _rupee.format(value);

  /// `₹1,23,456` (no paise) — for big glanceable KPI numbers.
  static String money0(num value) => _rupee0.format(value);

  /// `₹1.2L` / `₹45.3K` — compact KPI shorthand.
  static String moneyCompact(num value) => _compact.format(value);

  /// `1,23,456` — counts with Indian grouping, no symbol.
  static String count(num value) => _plain.format(value);

  /// `03-07-2026`
  static String date(DateTime d) => DateFormat('dd-MM-yyyy').format(d);

  /// `03 Jul 2026`
  static String dateMed(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  /// `03 Jul, 7:42 PM`
  static String dateTime(DateTime d) => DateFormat('dd MMM, h:mm a').format(d);

  /// `7:42 PM`
  static String time(DateTime d) => DateFormat('h:mm a').format(d);

  /// Human "time ago" — `2m`, `3h`, `Yesterday`, `04 Jul`.
  static String ago(DateTime d, {DateTime? now}) {
    final ref = now ?? DateTime(2026, 7, 3, 19, 45);
    final diff = ref.difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return dateMed(d);
  }
}
