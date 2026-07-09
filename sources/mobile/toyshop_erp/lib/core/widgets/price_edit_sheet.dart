import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/formats.dart';
import 'numeric_pad.dart';

/// Bottom sheet for setting a per-line unit price — used from both the
/// add-to-cart card and the cart line tile so staff can price an item above
/// or below the catalog rate (e.g. a floor-negotiated price, a chipped-box
/// markdown) without leaving the sale. Not owner-PIN gated (unlike the
/// cart-level discount) — the caller flags the resulting line instead.
/// Returns the resolved rupee amount, or `null` if the staff cancelled.
Future<double?> showPriceEditSheet(
  BuildContext context, {
  required String productName,
  required double catalogPrice,
  required double currentPrice,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PriceEditSheet(
      productName: productName,
      catalogPrice: catalogPrice,
      currentPrice: currentPrice,
    ),
  );
}

class _PriceEditSheet extends StatefulWidget {
  const _PriceEditSheet({
    required this.productName,
    required this.catalogPrice,
    required this.currentPrice,
  });
  final String productName;
  final double catalogPrice;
  final double currentPrice;

  @override
  State<_PriceEditSheet> createState() => _PriceEditSheetState();
}

class _PriceEditSheetState extends State<_PriceEditSheet> {
  String _buffer = '';

  double get _value => _buffer.isEmpty ? widget.currentPrice : double.parse(_buffer);
  bool get _hasEdit => _buffer.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final catalog = widget.catalogPrice;
    final delta = _value - catalog;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_rounded, color: p.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Set price', style: AppType.title.copyWith(color: p.ink)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(widget.productName, style: AppType.caption.copyWith(color: p.inkMuted)),
          const SizedBox(height: 14),
          Center(
            child: Text(Fmt.money0(_value), style: AppType.display.copyWith(color: p.ink)),
          ),
          const SizedBox(height: 4),
          Center(
            child: delta == 0
                ? Text('Catalog price', style: AppType.caption.copyWith(color: p.inkMuted))
                : Text(
                    '${delta > 0 ? '+' : '−'} ${Fmt.money0(delta.abs())} vs catalog ${Fmt.money0(catalog)}',
                    style: AppType.caption.copyWith(
                      color: delta > 0 ? p.warning : p.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          NumericPad(
            onKey: (d) => setState(() {
              if (_buffer.length < 6) _buffer += d;
            }),
            onDelete: () => setState(
              () => _buffer = _buffer.isEmpty ? '' : _buffer.substring(0, _buffer.length - 1),
            ),
            confirmLabel: 'Set',
            onConfirm: () {
              if (_value > 0) Navigator.of(context).pop(_value);
            },
          ),
          if (_hasEdit || widget.currentPrice != catalog) ...[
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(catalog),
                child: Text('Reset to catalog price ${Fmt.money0(catalog)}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
