import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles [ThemeData] for light & dark from the design-system tokens.
/// Screens should read semantic colors via `context.palette`, and text via
/// `Theme.of(context).textTheme` / the [AppType] constants.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light, AppPalette.light);
  static ThemeData dark() => _build(Brightness.dark, AppPalette.dark);

  static ThemeData _build(Brightness brightness, AppPalette p) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.primaryInk,
      secondary: p.info,
      onSecondary: Colors.white,
      error: p.danger,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.ink,
    );

    final base = brightness == Brightness.light
        ? ThemeData.light(useMaterial3: true)
        : ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      extensions: [p],
      textTheme: AppType.textTheme(p.ink),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: AppType.title.copyWith(color: p.ink, fontSize: 18),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(color: p.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        side: BorderSide(color: p.border),
        labelStyle: AppType.label.copyWith(color: p.ink),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.chip),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.primaryAction),
          textStyle: AppType.title,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.button),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.primaryAction),
          backgroundColor: p.primary,
          foregroundColor: p.primaryInk,
          elevation: 0,
          textStyle: AppType.title,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.button),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.primaryInk,
        elevation: 3,
        extendedTextStyle: AppType.title.copyWith(color: p.primaryInk),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.button),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.tapMin),
          foregroundColor: p.ink,
          side: BorderSide(color: p.border),
          textStyle: AppType.label.copyWith(fontSize: 14),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.button),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: const Size(0, AppSpacing.tapMin),
          textStyle: AppType.label.copyWith(fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: AppType.body.copyWith(color: p.inkMuted),
        border: OutlineInputBorder(
          borderRadius: AppRadii.card,
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.card,
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.card,
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.primary.withValues(alpha: 0.14),
        indicatorShape: const RoundedRectangleBorder(borderRadius: AppRadii.chip),
        elevation: 0,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? p.primary : p.inkMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) {
            final selected = states.contains(WidgetState.selected);
            return AppType.caption.copyWith(
              color: selected ? p.primary : p.inkMuted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            );
          },
        ),
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        contentTextStyle: AppType.body.copyWith(color: p.bg),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.card),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.inkMuted,
        titleTextStyle: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w600),
        subtitleTextStyle: AppType.caption.copyWith(color: p.inkMuted),
      ),
    );
  }
}
