import 'package:flutter/material.dart';

import '../models/account.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Circular initials avatar — stands in for `photo_url` throughout the
/// prototype so nothing depends on network images.
class AvatarBadge extends StatelessWidget {
  const AvatarBadge({
    super.key,
    required this.initials,
    required this.color,
    this.size = 44,
    this.icon,
  });

  AvatarBadge.account(Account a, {super.key, this.size = 44})
      : initials = a.initials,
        color = a.photoColor,
        icon = null;

  final String initials;
  final Color color;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.alphaBlend(Colors.black12, color)],
        ),
        shape: BoxShape.circle,
      ),
      child: icon != null
          ? Icon(icon, color: Colors.white, size: size * 0.5)
          : Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.36,
              ),
            ),
    );
  }
}

/// Money text with tabular figures. Use for any ₹ amount.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.text, {
    super.key,
    this.style,
    this.color,
    this.strikethrough = false,
  });

  final String text;
  final TextStyle? style;
  final Color? color;
  final bool strikethrough;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Text(
      text,
      style: (style ?? AppType.money).copyWith(
        color: color ?? p.ink,
        decoration: strikethrough ? TextDecoration.lineThrough : null,
        decorationColor: p.inkMuted,
      ),
    );
  }
}

/// Friendly empty state — illustration + message + optional primary action
/// (design-system.md §6 `EmptyState`).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: p.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppType.title.copyWith(color: p.ink),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: p.inkMuted),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton placeholder block for loading states (design-system.md §7 — use
/// skeletons, not blank screens or spinners).
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 8,
  });
  final double width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(p.border, p.bg, _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A pinned bottom action bar (thumb-reachable primary actions, §5).
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: padding ??
          EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md + MediaQuery.of(context).padding.bottom,
          ),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: child,
    );
  }
}

/// Small labelled key/value row used in summaries and detail sheets.
class LabeledRow extends StatelessWidget {
  const LabeledRow(
    this.label,
    this.value, {
    super.key,
    this.emphasize = false,
    this.valueColor,
  });
  final String label;
  final Widget value;
  final bool emphasize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: (emphasize ? AppType.title : AppType.body).copyWith(
                color: emphasize ? p.ink : p.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          DefaultTextStyle.merge(
            style: (emphasize ? AppType.title : AppType.money).copyWith(
              color: valueColor ?? p.ink,
            ),
            child: value,
          ),
        ],
      ),
    );
  }
}
