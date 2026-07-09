import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Large on-screen number pad — no OS keyboard (design-system.md §6).
/// Used for PIN, quantity and cash entry. Keys are ≥56 dp tall (§5).
class NumericPad extends StatelessWidget {
  const NumericPad({
    super.key,
    required this.onKey,
    required this.onDelete,
    this.onBiometric,
    this.onLongDelete,
    this.confirmLabel,
    this.onConfirm,
  });

  /// Called with the tapped digit '0'..'9'.
  final ValueChanged<String> onKey;
  final VoidCallback onDelete;
  final VoidCallback? onLongDelete;

  /// If provided, a fingerprint key replaces the bottom-left slot.
  final VoidCallback? onBiometric;

  /// If provided, the bottom-left slot becomes a confirm (✓) action instead.
  final String? confirmLabel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final rows = <List<Widget>>[
      [_digit(context, '1'), _digit(context, '2'), _digit(context, '3')],
      [_digit(context, '4'), _digit(context, '5'), _digit(context, '6')],
      [_digit(context, '7'), _digit(context, '8'), _digit(context, '9')],
      [_leftSlot(context), _digit(context, '0'), _deleteKey(context)],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  Expanded(child: row[i]),
                  if (i < row.length - 1) const SizedBox(width: AppSpacing.md),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _digit(BuildContext context, String d) {
    return _PadKey(
      onTap: () {
        HapticFeedback.selectionClick();
        onKey(d);
      },
      child: Text(d, style: AppType.h1.copyWith(fontSize: 26)),
    );
  }

  Widget _deleteKey(BuildContext context) {
    return _PadKey(
      onTap: onDelete,
      onLongPress: onLongDelete,
      child: const Icon(Icons.backspace_outlined, size: 22),
    );
  }

  Widget _leftSlot(BuildContext context) {
    final p = context.palette;
    if (confirmLabel != null && onConfirm != null) {
      return _PadKey(
        onTap: onConfirm,
        color: p.primary,
        child: Icon(Icons.check_rounded, size: 24, color: p.primaryInk),
      );
    }
    if (onBiometric != null) {
      return _PadKey(
        onTap: onBiometric,
        child: Icon(Icons.fingerprint_rounded, size: 26, color: p.primary),
      );
    }
    return const SizedBox.shrink();
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({required this.child, this.onTap, this.onLongPress, this.color});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: color ?? p.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color == null ? p.border : Colors.transparent),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: p.ink),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Row of masked PIN dots that fills as digits are entered (§ auth docs).
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.length,
    required this.filled,
    this.error = false,
  });
  final int length;
  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled
                    ? (error ? p.danger : p.primary)
                    : Colors.transparent,
                border: Border.all(
                  color: error ? p.danger : (i < filled ? p.primary : p.border),
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
