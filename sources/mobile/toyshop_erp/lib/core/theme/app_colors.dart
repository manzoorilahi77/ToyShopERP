import 'package:flutter/material.dart';

/// Color tokens — mirror `docs/foundation/design-system.md` §2.
///
/// Colors are placeholders; swap for the shop's brand before launch.
/// Every light/dark pair is chosen to pass WCAG AA (4.5:1) for text.
/// Meaning is never encoded by color alone — always pair with an icon + label.
class AppColors {
  const AppColors._();

  // --- Light ---
  static const primary = Color(0xFF2563EB);
  static const primaryInk = Color(0xFFFFFFFF);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF0891B2);
  static const bg = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0F172A);
  static const inkMuted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);

  // --- Dark ---
  static const primaryDark = Color(0xFF3B82F6);
  static const primaryInkDark = Color(0xFF0B1220);
  static const successDark = Color(0xFF22C55E);
  static const warningDark = Color(0xFFF59E0B);
  static const dangerDark = Color(0xFFEF4444);
  static const infoDark = Color(0xFF06B6D4);
  static const bgDark = Color(0xFF0B1220);
  static const surfaceDark = Color(0xFF111827);
  static const inkDark = Color(0xFFE5E7EB);
  static const inkMutedDark = Color(0xFF94A3B8);
  static const borderDark = Color(0xFF1F2937);
}

/// Semantic status colors resolved for the current brightness, plus the tokens
/// screens use directly. Access via `Theme.of(context).extension<AppPalette>()!`
/// or the `context.palette` helper below.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.primary,
    required this.primaryInk,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.bg,
    required this.surface,
    required this.ink,
    required this.inkMuted,
    required this.border,
  });

  final Color primary;
  final Color primaryInk;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color bg;
  final Color surface;
  final Color ink;
  final Color inkMuted;
  final Color border;

  static const light = AppPalette(
    primary: AppColors.primary,
    primaryInk: AppColors.primaryInk,
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.danger,
    info: AppColors.info,
    bg: AppColors.bg,
    surface: AppColors.surface,
    ink: AppColors.ink,
    inkMuted: AppColors.inkMuted,
    border: AppColors.border,
  );

  static const dark = AppPalette(
    primary: AppColors.primaryDark,
    primaryInk: AppColors.primaryInkDark,
    success: AppColors.successDark,
    warning: AppColors.warningDark,
    danger: AppColors.dangerDark,
    info: AppColors.infoDark,
    bg: AppColors.bgDark,
    surface: AppColors.surfaceDark,
    ink: AppColors.inkDark,
    inkMuted: AppColors.inkMutedDark,
    border: AppColors.borderDark,
  );

  /// Soft tinted background for a status color (chips, banners).
  Color tint(Color base) => Color.alphaBlend(base.withValues(alpha: 0.12), surface);

  @override
  AppPalette copyWith({
    Color? primary,
    Color? primaryInk,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? bg,
    Color? surface,
    Color? ink,
    Color? inkMuted,
    Color? border,
  }) {
    return AppPalette(
      primary: primary ?? this.primary,
      primaryInk: primaryInk ?? this.primaryInk,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      border: border ?? this.border,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryInk: Color.lerp(primaryInk, other.primaryInk, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

extension PaletteX on BuildContext {
  /// Shorthand: `context.palette.primary`.
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
