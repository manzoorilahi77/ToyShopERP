import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'numeric_pad.dart';

/// Owner-PIN gate (🔒) for money-leaking actions — discount approval, price
/// override, product deactivate (overview.md §6.5, design-system.md §6 `PinDialog`).
///
/// PROTOTYPE: any 4-digit PIN is accepted. Returns `true` when approved,
/// `false`/`null` when cancelled.
Future<bool?> showOwnerPinSheet(
  BuildContext context, {
  String title = 'Owner approval',
  String? subtitle,
  String hint = 'Demo: enter any 4-digit PIN',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OwnerPinSheet(title: title, subtitle: subtitle, hint: hint),
  );
}

class _OwnerPinSheet extends StatefulWidget {
  const _OwnerPinSheet({required this.title, this.subtitle, required this.hint});
  final String title;
  final String? subtitle;
  final String hint;

  @override
  State<_OwnerPinSheet> createState() => _OwnerPinSheetState();
}

class _OwnerPinSheetState extends State<_OwnerPinSheet> {
  String _pin = '';
  bool _error = false;

  void _key(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _error = false;
      _pin += d;
    });
    if (_pin.length == 4) {
      // Prototype: accept any 4-digit PIN, brief confirm then pop true.
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    }
  }

  void _del() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            decoration: BoxDecoration(
              color: p.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Icon(Icons.lock_rounded, color: p.primary, size: 28),
          const SizedBox(height: 8),
          Text(widget.title, style: AppType.title.copyWith(color: p.ink)),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(color: p.inkMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          PinDots(length: 4, filled: _pin.length, error: _error),
          const SizedBox(height: 8),
          Text(widget.hint, style: AppType.caption.copyWith(color: p.inkMuted)),
          const SizedBox(height: AppSpacing.lg),
          NumericPad(onKey: _key, onDelete: _del, onLongDelete: () => setState(() => _pin = '')),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
