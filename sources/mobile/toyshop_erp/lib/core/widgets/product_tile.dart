import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/formats.dart';
import 'pills.dart';
import 'price_edit_sheet.dart';

/// Offline placeholder "photo" for a product — a tinted panel with the toy icon
/// and a color-tag dot. Replaces network `photo_url` for the prototype.
class ProductThumb extends StatelessWidget {
  const ProductThumb({
    super.key,
    required this.product,
    this.size,
    this.radius = 12,
  });
  final Product product;
  final double? size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = product.colorTag;
    final thumb = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.withValues(alpha: 0.22), c.withValues(alpha: 0.40)],
        ),
      ),
      child: Stack(
        children: [
          Center(child: Icon(product.icon, size: 34, color: c)),
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
    if (size != null) return SizedBox(width: size, height: size, child: thumb);
    return AspectRatio(aspectRatio: 1, child: thumb);
  }
}

/// Product grid tile — image + name + price, ≥96 dp (design-system.md §5, §6).
/// Long-press surfaces quick info via [onLongPress].
class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.showStock = true,
  });

  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool showStock;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final out = product.stockQty == 0;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: out ? null : onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: ProductThumb(product: product)),
                    if (product.isFavorite)
                      const Positioned(
                        top: 4,
                        left: 4,
                        child: Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                      ),
                    if (out)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Out of stock',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.label.copyWith(color: p.ink, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      Fmt.money0(product.price),
                      style: AppType.money.copyWith(color: p.ink),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              if (showStock && product.stockQty != null) ...[
                const SizedBox(height: 6),
                StockPill(product.stock, qty: product.stockQty, dense: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// +/- quantity stepper (design-system.md `ItemConfirmCard` qty control).
/// Long-press either button to auto-repeat (new-sale doc §7: "long-press to
/// accelerate qty") — fast bulk changes without a dozen individual taps.
/// Tapping the value itself is optional (via [onTapValue]) for jumping
/// straight to the `NumericPad` bulk-entry sheet.
class QtyStepper extends StatefulWidget {
  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 999,
    this.size = 40,
    this.onTapValue,
  });
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final double size;
  final VoidCallback? onTapValue;

  @override
  State<QtyStepper> createState() => _QtyStepperState();
}

class _QtyStepperState extends State<QtyStepper> {
  Timer? _repeatTimer;

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  void _step(int delta) {
    final next = (widget.value + delta).clamp(widget.min, widget.max);
    if (next != widget.value) {
      HapticFeedback.selectionClick();
      widget.onChanged(next);
    }
  }

  void _startRepeating(int delta) {
    _step(delta);
    _repeatTimer?.cancel();
    _repeatTimer = Timer(const Duration(milliseconds: 450), () {
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 90), (_) => _step(delta));
    });
  }

  void _stopRepeating() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // GestureDetector (not InkWell) so `onLongPressUp` can stop the repeat
    // timer the instant the finger lifts — InkWell has no such callback.
    Widget btn(IconData icon, bool enabled, int delta) => GestureDetector(
          onTap: enabled ? () => _step(delta) : null,
          onLongPress: enabled ? () => _startRepeating(delta) : null,
          onLongPressUp: _stopRepeating,
          child: Material(
            color: enabled ? p.surface : p.bg,
            shape: CircleBorder(side: BorderSide(color: p.border)),
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Icon(icon, size: 18, color: enabled ? p.ink : p.inkMuted),
            ),
          ),
        );
    final value = Container(
      width: 40,
      alignment: Alignment.center,
      child: Text('${widget.value}', style: AppType.title.copyWith(color: p.ink)),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.remove_rounded, widget.value > widget.min, -1),
        widget.onTapValue == null
            ? value
            : InkWell(borderRadius: BorderRadius.circular(8), onTap: widget.onTapValue, child: value),
        btn(Icons.add_rounded, widget.value < widget.max, 1),
      ],
    );
  }
}

/// "Confirm before commit" card — photo + name + price + qty stepper →
/// Add / Cancel. Precedes every add-to-cart (design-system.md §1.3, §6).
/// The price is tappable to override it (up or down) before the item ever
/// reaches the cart — handy for a floor-negotiated price on the spot.
class ItemConfirmCard extends StatefulWidget {
  const ItemConfirmCard({
    super.key,
    required this.product,
    required this.onAdd,
    this.initialQty = 1,
  });
  final Product product;

  /// `unitPrice` is `null` unless the staff overrode the catalog price.
  final void Function(int qty, double? unitPrice) onAdd;
  final int initialQty;

  @override
  State<ItemConfirmCard> createState() => _ItemConfirmCardState();
}

class _ItemConfirmCardState extends State<ItemConfirmCard> {
  late int _qty = widget.initialQty;
  double? _priceOverride;

  double get _unitPrice => _priceOverride ?? widget.product.price;

  Future<void> _editPrice() async {
    final prod = widget.product;
    final result = await showPriceEditSheet(
      context,
      productName: prod.name,
      catalogPrice: prod.price,
      currentPrice: _unitPrice,
    );
    if (result == null || !mounted) return;
    setState(() => _priceOverride = result == prod.price ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final prod = widget.product;
    final overridden = _priceOverride != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProductThumb(product: prod, size: 72),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prod.name, style: AppType.title.copyWith(color: p.ink)),
                    const SizedBox(height: 2),
                    Text(
                      prod.category,
                      style: AppType.caption.copyWith(color: p.inkMuted),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _editPrice,
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        children: [
                          Text(
                            Fmt.money(_unitPrice),
                            style: AppType.h2.copyWith(color: overridden ? p.info : p.ink),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.edit_rounded, size: 15, color: p.inkMuted),
                        ],
                      ),
                    ),
                    if (overridden) ...[
                      const SizedBox(height: 3),
                      TonePill(
                        label: 'Custom price · was ${Fmt.money0(prod.price)}',
                        color: p.info,
                        icon: Icons.flag_rounded,
                        dense: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text('Quantity', style: AppType.body.copyWith(color: p.inkMuted)),
              const Spacer(),
              QtyStepper(value: _qty, onChanged: (v) => setState(() => _qty = v)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => widget.onAdd(_qty, _priceOverride),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: Text('Add · ${Fmt.money0(_unitPrice * _qty)}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
