import 'package:flutter/material.dart';

/// Type scale — `docs/foundation/design-system.md` §3.
/// Family: system default (Inter in production). Money & counters use
/// tabular figures so digits don't jitter as values change.
class AppType {
  const AppType._();

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // Display 34/40 bold — big KPI numbers.
  static const TextStyle display = TextStyle(
    fontSize: 34,
    height: 40 / 34,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
  );

  static const TextStyle h1 = TextStyle(fontSize: 24, fontWeight: FontWeight.w700);
  static const TextStyle h2 = TextStyle(fontSize: 20, fontWeight: FontWeight.w700);
  static const TextStyle title = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
  static const TextStyle body = TextStyle(fontSize: 15, fontWeight: FontWeight.w400);
  static const TextStyle label = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
  static const TextStyle caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w400);

  /// Money style — tabular numerals, semi-bold by default.
  static const TextStyle money = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFeatures: _tabular,
  );

  /// Build a Material [TextTheme] from the scale above.
  static TextTheme textTheme(Color ink) {
    TextStyle c(TextStyle s) => s.copyWith(color: ink);
    return TextTheme(
      displayLarge: c(display),
      displayMedium: c(display.copyWith(fontSize: 28, height: 34 / 28)),
      headlineMedium: c(h1),
      headlineSmall: c(h2),
      titleLarge: c(h2),
      titleMedium: c(title),
      titleSmall: c(label),
      bodyLarge: c(body.copyWith(fontSize: 16)),
      bodyMedium: c(body),
      bodySmall: c(caption),
      labelLarge: c(label.copyWith(fontSize: 14)),
      labelMedium: c(label),
      labelSmall: c(caption),
    );
  }
}
