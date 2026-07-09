import 'package:flutter/material.dart';

import '../../core/core.dart';
import 'new_sale_screen.dart';
import 'receipt_data.dart';

/// Staff Receipt — the post-sale screen: a paper-look preview (shop header,
/// GSTIN, invoice number, line items with GST breakdown, discount, total,
/// payment mode) plus Print / Share / New Sale. Read-only — it never mutates
/// the sale (receipt doc rule 1). Doc: docs/mobile/staff/sales/receipt.md.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.data});

  /// The sale to render — built fresh by [NewSaleScreen] on confirm, or
  /// looked up by the sales-history screen for a reprint. Both hand the same
  /// [ReceiptData] model straight in, so this screen never blocks on a
  /// network call, online or offline (receipt doc §10).
  final ReceiptData data;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _receiptRepo = const ReceiptRepository();
  late ReceiptData _data = widget.data;
  bool _invoiceSyncKickedOff = false;

  // Bluetooth printer sub-state (receipt doc §6 "Printer sub-states"). This
  // prototype has no `esc_pos_bluetooth` plugin, so pairing/printing are
  // simulated but every state the doc lists is reachable and reversible.
  String? _pairedDevice = 'RPP02';
  bool _connected = true;
  bool _connecting = false;
  bool _printing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Simulate `GET /sync/pull` resolving the provisional ref to the real,
    // server-assigned invoice number (receipt doc rule 2, §10) — only when
    // there's something to resolve and the device is online. A `failed` sale
    // needs an explicit retry (my-sales-history doc rule 3) rather than
    // resolving just by being viewed.
    if (_invoiceSyncKickedOff || !_data.isProvisional || _data.syncStatus == SyncState.failed) {
      return;
    }
    // Only latch the flag once we actually kick off the simulated pull — if
    // we're offline, leave it false so toggling online while this receipt is
    // still open (via the sync chip) retries on the next dependency change.
    if (!SessionScope.of(context).isOnline) return;
    _invoiceSyncKickedOff = true;
    _receiptRepo.awaitInvoiceNumber(_data).then((updated) {
      if (mounted) setState(() => _data = updated);
    });
  }

  String _printerLabel() {
    if (_printing) return 'Printing…';
    if (_connecting) return 'Connecting…';
    final device = _pairedDevice;
    if (device == null) return 'No printer paired';
    return _connected ? '$device ✓ connected' : '$device — tap to connect';
  }

  Future<void> _changePrinter() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        final p = context.palette;
        Widget tile(String label, IconData icon) => ListTile(
              leading: Icon(icon, color: p.primary),
              title: Text(label),
              onTap: () => Navigator.of(ctx).pop(label),
            );
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.bluetooth_rounded, color: p.primary),
                    const SizedBox(width: 8),
                    Text('Bluetooth printers', style: AppType.title.copyWith(color: p.ink)),
                  ],
                ),
              ),
              tile('RPP02 (58mm)', Icons.bluetooth_connected_rounded),
              tile('Epson TM-P20 (80mm)', Icons.bluetooth_rounded),
              tile('None', Icons.bluetooth_disabled_rounded),
            ],
          ),
        );
      },
    );
    if (choice == null || !mounted) return;
    if (choice == 'None') {
      setState(() {
        _pairedDevice = null;
        _connected = false;
      });
      return;
    }
    setState(() {
      _connecting = true;
      _connected = false;
      _pairedDevice = choice;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _connected = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$choice connected')));
  }

  /// Out-of-paper / disconnected failures are recoverable and never touch the
  /// sale (receipt doc rule 5) — here, printing without a connected device
  /// simply reopens the picker instead of failing into a dead end.
  Future<void> _onPrint() async {
    if (!_connected) {
      _changePrinter();
      return;
    }
    setState(() => _printing = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _printing = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Printed')));
  }

  /// Share always works, printer or not (receipt doc rule 10) — no
  /// `share_plus` plugin in this prototype, so it's simulated.
  void _onShare() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt shared via WhatsApp')));
  }

  /// Fastest path back to billing (receipt doc row 14) — clears every route
  /// above the shell so New Sale always opens fresh, regardless of whether
  /// this receipt came from a confirm or a history reprint.
  void _onNewSale() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const NewSaleScreen()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Receipt',
      pendingCount: _data.syncStatus == SyncState.synced ? 0 : 1,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [_preview()],
      ),
      bottomBar: AppBottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _printerRow(),
            const SizedBox(height: 10),
            _actionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    final p = context.palette;
    final d = _data;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(kShopHeader.name, style: AppType.h2.copyWith(color: p.ink), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            kShopHeader.address,
            style: AppType.caption.copyWith(color: p.inkMuted),
            textAlign: TextAlign.center,
          ),
          Text('GSTIN: ${kShopHeader.gstin}', style: AppType.caption.copyWith(color: p.inkMuted)),
          const SizedBox(height: 14),
          Divider(color: p.border),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Invoice: ${d.displayRef}',
                  style: AppType.label.copyWith(color: p.ink, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (d.isProvisional) ...[
                const SizedBox(width: 8),
                TonePill(
                  label: d.syncStatus.label,
                  color: d.syncStatus.color(p),
                  icon: d.syncStatus.icon,
                  dense: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${Fmt.date(d.soldAt)}  ${Fmt.time(d.soldAt)}',
                style: AppType.caption.copyWith(color: p.inkMuted),
              ),
              Text('Staff: ${d.staffName}', style: AppType.caption.copyWith(color: p.inkMuted)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Branch: ${d.branchName}', style: AppType.caption.copyWith(color: p.inkMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: p.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  flex: _kItemFlex,
                  child: Text(
                    'Item',
                    style: AppType.caption.copyWith(color: p.inkMuted, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  flex: _kQtyFlex,
                  child: _tableCell('Qty', AppType.caption.copyWith(color: p.inkMuted, fontWeight: FontWeight.w700),
                      align: TextAlign.center),
                ),
                Expanded(
                  flex: _kRateFlex,
                  child: _tableCell('Rate', AppType.caption.copyWith(color: p.inkMuted, fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  flex: _kGstFlex,
                  child: _tableCell('GST%', AppType.caption.copyWith(color: p.inkMuted, fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  flex: _kAmountFlex,
                  child:
                      _tableCell('Amount', AppType.caption.copyWith(color: p.inkMuted, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          for (final line in d.items) _itemRow(line),
          Divider(color: p.border),
          const SizedBox(height: 4),
          LabeledRow('Subtotal (taxable)', MoneyText(Fmt.money(d.taxableTotal))),
          LabeledRow('CGST', MoneyText(Fmt.money(d.cgst))),
          LabeledRow('SGST', MoneyText(Fmt.money(d.sgst))),
          Divider(color: p.ink, thickness: 1.2),
          LabeledRow('TOTAL', MoneyText(Fmt.money(d.total), style: AppType.h2), emphasize: true),
          if (d.hasPriceOverrides) ...[
            const SizedBox(height: 4),
            Text(
              '* price adjusted by staff from catalog rate',
              style: AppType.caption.copyWith(color: p.info),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(d.paymentMode.icon, size: 16, color: p.inkMuted),
              const SizedBox(width: 6),
              Text(
                'Paid: ${d.paymentMode.label.toUpperCase()}',
                style: AppType.label.copyWith(color: p.inkMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Thank you! Visit again 🧸',
            style: AppType.caption.copyWith(color: p.inkMuted, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Column widths for the item table (header + rows must match). Qty/GST%
  // hold short digits so they stay narrow; Rate/Amount hold money strings —
  // the widest content in the table (and Amount uses the larger `money`
  // style) — so they get more room, or "Amount"/"₹4,200" wrap mid-word.
  static const _kItemFlex = 3;
  static const _kQtyFlex = 1;
  static const _kRateFlex = 2;
  static const _kGstFlex = 1;
  static const _kAmountFlex = 2;

  Widget _tableCell(String text, TextStyle style, {TextAlign align = TextAlign.right}) {
    return Text(text, textAlign: align, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: style);
  }

  Widget _itemRow(ReceiptLine l) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: _kItemFlex,
            child: Text(
              l.name,
              style: AppType.body.copyWith(color: p.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: _kQtyFlex,
            child: _tableCell('${l.qty}', AppType.body.copyWith(color: p.inkMuted), align: TextAlign.center),
          ),
          Expanded(
            flex: _kRateFlex,
            child: _tableCell(
              '${Fmt.money0(l.unitPrice)}${l.priceOverridden ? '*' : ''}',
              AppType.caption.copyWith(
                color: l.priceOverridden ? p.info : p.inkMuted,
                fontWeight: l.priceOverridden ? FontWeight.w700 : null,
              ),
            ),
          ),
          Expanded(
            flex: _kGstFlex,
            child: _tableCell('${l.gstRate}%', AppType.caption.copyWith(color: p.inkMuted)),
          ),
          Expanded(
            flex: _kAmountFlex,
            child: _tableCell(Fmt.money0(l.lineTotal), AppType.money.copyWith(color: p.ink)),
          ),
        ],
      ),
    );
  }

  Widget _printerRow() {
    final p = context.palette;
    return InkWell(
      onTap: _changePrinter,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.print_rounded, size: 16, color: _connected ? p.success : p.inkMuted),
            const SizedBox(width: 8),
            Expanded(child: Text(_printerLabel(), style: AppType.caption.copyWith(color: p.inkMuted))),
            Text('change', style: AppType.caption.copyWith(color: p.primary, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _actionButtons() {
    // Print/Share sit in a narrow Expanded(flex: 1) slot — the pill shape's
    // default M3 icon-button padding leaves too little room for "Print"/
    // "Share" next to their icon, so the label wraps mid-word and the
    // button grows taller than New Sale. Tighter padding + a forced single
    // line (ellipsis as a safety net, never a second line) fixes both.
    ButtonStyle compactOutlined() => OutlinedButton.styleFrom(
          minimumSize: const Size(0, 56),
          maximumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        );
    Widget oneLine(String text) => Text(text, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: compactOutlined(),
            onPressed: _printing ? null : _onPrint,
            icon: _printing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_rounded, size: 18),
            label: oneLine(_printing ? 'Printing…' : 'Print'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            style: compactOutlined(),
            onPressed: _onShare,
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: oneLine('Share'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
            onPressed: _onNewSale,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Sale'),
          ),
        ),
      ],
    );
  }
}
