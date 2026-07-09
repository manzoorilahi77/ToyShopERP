import 'package:flutter/widgets.dart';

/// Spacing, radius & sizing tokens — `docs/foundation/design-system.md` §4–5.
/// 4-pt grid: 4 / 8 / 12 / 16 / 24 / 32. Screen padding 16 on mobile.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Default mobile screen edge padding.
  static const EdgeInsets screen = EdgeInsets.all(lg);
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: lg);

  // Tap targets & ergonomics (§5).
  static const double tapMin = 48; // minimum any tappable
  static const double primaryAction = 56; // sale / primary buttons
  static const double tileMin = 96; // product / photo tiles
}

/// Corner radii — sm 8 · md 12 · lg 16 · pill 999. Cards md, sheets lg.
class AppRadii {
  const AppRadii._();

  static const Radius sm = Radius.circular(8);
  static const Radius md = Radius.circular(12);
  static const Radius lg = Radius.circular(16);
  static const Radius pill = Radius.circular(999);

  static const BorderRadius card = BorderRadius.all(md);
  static const BorderRadius sheet = BorderRadius.vertical(top: lg);

  /// Badges, tags, filter chips and segmented-toggle pills all share this —
  /// the same lg radius as the primary CTA (New Sale) — so no screen mixes
  /// a fully-pill control next to the CTA's rounded-rect shape.
  static const BorderRadius chip = BorderRadius.all(lg);

  /// Every tappable CTA (filled/elevated/outlined/floating-action buttons)
  /// shares this radius, matching the primary "New Sale" action.
  static const BorderRadius button = BorderRadius.all(lg);
}
