// PROTOTYPE DUMMY DATA — replace ReceiptRepository.awaitInvoiceNumber() with
// GET /sync/pull?since= (server-assigned invoice_no) — a historical open
// would use GET /sales/{id} (see doc §9, docs/mobile/staff/sales/receipt.md).
//
// [ReceiptData] is the shared, self-contained receipt model both
// NewSaleScreen (fresh confirm) and MySalesHistoryScreen (reprint) build or
// look up and pass directly into ReceiptScreen — mirrors `sales` +
// `sale_items` (receipt doc §5 / §9).

import 'package:flutter/material.dart';

import '../../core/core.dart';

/// How the customer paid — mirrors `sales.payment_mode` (new-sale doc §5 row 18).
enum PaymentMode {
  cash('Cash', Icons.payments_rounded),
  upi('UPI', Icons.qr_code_rounded),
  card('Card', Icons.credit_card_rounded);

  const PaymentMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// One priced line, snapshotted at sale time (new-sale doc rule 3) so later
/// catalog price edits never change a completed sale.
@immutable
class ReceiptLine {
  const ReceiptLine({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.gstRate,
    this.priceOverridden = false,
  });

  final String productId;
  final String name;
  final int qty;

  /// Tax-inclusive price at the moment of sale — the catalog `selling_price`,
  /// or a staff-entered override (see [priceOverridden]).
  final double unitPrice;
  final int gstRate;

  /// True when [unitPrice] was manually set by staff rather than taken from
  /// the catalog (new-sale doc rule 3a) — surfaced on the receipt so the
  /// owner can spot it during review.
  final bool priceOverridden;

  /// Tax-inclusive line amount (`sale_items.line_total`).
  double get lineTotal => unitPrice * qty;

  /// The GST portion already folded into [lineTotal] (receipt doc §5 row 7).
  double get gstAmount => lineTotal - lineTotal / (1 + gstRate / 100);
}

/// Shop / GST registration header printed on every receipt (receipt doc §5
/// rows 1–2). A single shop + GSTIN in this prototype (rule 8 — a real build
/// keys this off the sale's `gstin_id`).
@immutable
class ShopHeader {
  const ShopHeader({required this.name, required this.address, required this.gstin});
  final String name;
  final String address;
  final String gstin;
}

const kShopHeader = ShopHeader(
  name: 'ToyShop Kids World',
  address: '12 Bazaar Road, Chennai 600001',
  gstin: '33AAAAA0000A1Z5',
);

/// A complete, self-contained receipt — everything the receipt screen needs
/// to render. Both a fresh confirm and a history reprint build one of these and
/// pass it straight in, so the receipt never blocks on a network call
/// (new-sale doc rule 1 / receipt doc §10).
@immutable
class ReceiptData {
  const ReceiptData({
    required this.clientUuid,
    this.invoiceNo,
    required this.soldAt,
    required this.staffName,
    required this.items,
    this.discountAmount = 0,
    this.discountApprovedBy,
    required this.paymentMode,
    required this.syncStatus,
  });

  /// Idempotency key (new-sale doc rule 10); also seeds [provisionalRef].
  final String clientUuid;

  /// Server-assigned invoice number — `null` while the sale is still pending
  /// sync, in which case the UI shows [provisionalRef] (receipt doc rule 2).
  final String? invoiceNo;
  final DateTime soldAt;
  final String staffName;
  final List<ReceiptLine> items;
  final double discountAmount;
  final String? discountApprovedBy;
  final PaymentMode paymentMode;
  final SyncState syncStatus;

  bool get isProvisional => invoiceNo == null;

  /// e.g. `Prov #A1B2` — derived client-side from [clientUuid] (receipt doc
  /// "Proposed schema addition": no server column needed).
  String get provisionalRef =>
      'Prov #${clientUuid.substring(0, clientUuid.length < 4 ? clientUuid.length : 4).toUpperCase()}';

  String get displayRef => invoiceNo ?? provisionalRef;

  int get totalUnits => items.fold(0, (a, l) => a + l.qty);

  /// Any line rung up at a staff-entered price rather than the catalog one —
  /// drives the "price adjusted" footnote (new-sale doc rule 3a).
  bool get hasPriceOverrides => items.any((l) => l.priceOverridden);

  /// Gross, tax-inclusive sum of every line — before [discountAmount].
  double get grossTotal => items.fold(0.0, (a, l) => a + l.lineTotal);
  double get gstTotal => items.fold(0.0, (a, l) => a + l.gstAmount);
  double get taxableTotal => grossTotal - gstTotal;

  /// Intra-state split (receipt doc rule 3). This prototype has a single
  /// registration, so it's always CGST+SGST, never IGST.
  double get cgst => gstTotal / 2;
  double get sgst => gstTotal / 2;

  double get total => grossTotal - discountAmount;

  ReceiptData copyWith({String? invoiceNo, SyncState? syncStatus}) {
    return ReceiptData(
      clientUuid: clientUuid,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      soldAt: soldAt,
      staffName: staffName,
      items: items,
      discountAmount: discountAmount,
      discountApprovedBy: discountApprovedBy,
      paymentMode: paymentMode,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

/// Handles the one thing a receipt still needs from the network: filling in
/// the server-assigned invoice number once the backing sale syncs.
class ReceiptRepository {
  const ReceiptRepository();

  /// `GET /sync/pull?since=` (receipt doc §9). A fresh/pending sale renders
  /// instantly from the [ReceiptData] the caller already built — this only
  /// simulates the later pull that resolves the provisional ref to a real,
  /// gapless `invoice_no` (receipt doc rule 2, §10) or a failed retry
  /// (my-sales-history doc rule 3).
  Future<ReceiptData> awaitInvoiceNumber(ReceiptData data) async {
    await Future.delayed(const Duration(milliseconds: 1400));
    // 6-digit gapless-looking sequence, e.g. "000742" — kept clear of the
    // 000399–000420 range already used by the my-sales-history demo rows.
    final seq = 700 + (data.clientUuid.hashCode.abs() % 90);
    return data.copyWith(invoiceNo: 'GST1/26-27/000$seq', syncStatus: SyncState.synced);
  }
}
