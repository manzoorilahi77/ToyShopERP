import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// Big glanceable KPI — tabular number + label + optional trend arrow.
/// design-system.md §6 (`KpiCard`), §5 ("Glanceable for the owner").
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.trend,
    this.trendUp,
    this.accent,
    this.onTap,
    this.footnote,
  });

  final String label;
  final String value;
  final IconData? icon;

  /// e.g. "+12%". Rendered with an up/down arrow driven by [trendUp].
  final String? trend;
  final bool? trendUp;
  final Color? accent;
  final VoidCallback? onTap;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final a = accent ?? p.primary;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: a.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: a),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: AppType.caption.copyWith(color: p.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppType.display.copyWith(color: p.ink, fontSize: 26, height: 1.1),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (trend != null || footnote != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (trend != null) ...[
                  Icon(
                    trendUp == true
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 13,
                    color: trendUp == true ? p.success : p.danger,
                  ),
                  Text(
                    trend!,
                    style: AppType.caption.copyWith(
                      color: trendUp == true ? p.success : p.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (footnote != null)
                  Flexible(
                    child: Text(
                      footnote!,
                      style: AppType.caption.copyWith(color: p.inkMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Alert row — low/aging/out stock etc; tap drills down (design-system.md §6).
class AlertTile extends StatelessWidget {
  const AlertTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = color ?? p.warning;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: c),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppType.body.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppType.caption.copyWith(color: p.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          if (trailing == null && onTap != null)
            Icon(Icons.chevron_right_rounded, color: p.inkMuted),
        ],
      ),
    );
  }
}
