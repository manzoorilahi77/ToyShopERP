import 'package:flutter/material.dart';

import '../models/status.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A compact icon + label pill. Meaning is carried by icon **and** text, never
/// color alone (design-system.md §8).
class TonePill extends StatelessWidget {
  const TonePill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
    this.dense = false,
  });

  /// Convenience for a [Tone]-driven pill.
  factory TonePill.tone(
    Tone tone,
    String label, {
    IconData? icon,
    bool filled = false,
    bool dense = false,
  }) {
    return TonePill(
      label: label,
      color: _ToneColor(tone),
      icon: icon,
      filled: filled,
      dense: dense,
    );
  }

  final String label;

  /// Either a raw [Color] or a [_ToneColor] resolved against the palette.
  final Object color;
  final IconData? icon;
  final bool filled;
  final bool dense;

  Color _resolve(AppPalette p) =>
      color is _ToneColor ? (color as _ToneColor).tone.color(p) : color as Color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = _resolve(p);
    final fg = filled ? Colors.white : c;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: filled ? c : c.withValues(alpha: 0.12),
        borderRadius: AppRadii.chip,
        border: filled ? null : Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (dense ? AppType.caption : AppType.label).copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToneColor {
  const _ToneColor(this.tone);
  final Tone tone;
}

/// Stock status pill (🟢/🟠/🔴/⏳ + label).
class StockPill extends StatelessWidget {
  const StockPill(this.state, {super.key, this.dense = false, this.qty});
  final StockState state;
  final bool dense;
  final int? qty;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final label = (state == StockState.healthy && qty != null)
        ? '${state.label} · $qty'
        : state.label;
    return TonePill(label: label, color: state.color(p), icon: state.icon, dense: dense);
  }
}

/// Top-right sync indicator used in app bars (design-system.md §6, §8).
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip(this.state, {super.key, this.pendingCount = 0, this.onTap});
  final SyncState state;
  final int pendingCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = state.color(p);
    final showBadge = pendingCount > 0 &&
        (state == SyncState.pending || state == SyncState.offline);
    final label = showBadge ? '$pendingCount ${state.label.toLowerCase()}' : state.label;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.chip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(state.icon, size: 15, color: c),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppType.caption.copyWith(color: c, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Calm offline banner (never a red error) — design-system.md §7.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.message = 'Working offline — changes saved, will sync',
    this.queued = 0,
  });
  final String message;
  final int queued;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      color: p.warning.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: p.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppType.caption.copyWith(color: p.ink, fontWeight: FontWeight.w500),
            ),
          ),
          if (queued > 0)
            TonePill(label: '$queued queued', color: p.warning, dense: true),
        ],
      ),
    );
  }
}
