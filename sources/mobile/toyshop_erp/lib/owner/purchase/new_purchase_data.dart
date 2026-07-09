// PROTOTYPE DUMMY DATA — replace NewPurchaseRepository.checkDuplicate() with
// POST /products/check-duplicate (see doc §9).
//
// Other methods to wire similarly against
// docs/mobile/owner/purchase/new-purchase.md §9's API table:
//   NewPurchaseRepository.suppliers()        → GET  /suppliers?q=
//   NewPurchaseRepository.addSupplier()      → POST /suppliers
//   NewPurchaseRepository.existingProducts() → GET  /products
//   NewPurchaseRepository.ownerGstins()      → GET  /gst/registrations?is_active=1
//   NewPurchaseRepository.confirmPurchase()  → POST /purchases
//                                               (Idempotency-Key = client_uuid)

import 'package:flutter/material.dart';

import '../../core/models/product.dart';
import '../../core/models/status.dart';

/// A goods supplier (`suppliers.id/name/gstin`).
@immutable
class Supplier {
  const Supplier({required this.id, required this.name, this.gstin, this.phone});

  final String id;
  final String name;
  final String? gstin;
  final String? phone;
}

/// One line of a purchase (`purchase_items`). [productId] is set when the
/// line was routed to an existing product (dup-check "Use existing" or a
/// direct catalog pick); null means a brand-new product will be created on
/// confirm.
@immutable
class PurchaseLine {
  const PurchaseLine({
    required this.id,
    this.productId,
    required this.name,
    required this.category,
    required this.colorTag,
    required this.qty,
    required this.costPrice,
    required this.sellPrice,
    required this.gstRate,
    required this.isNew,
  });

  final String id;
  final String? productId;
  final String name;
  final String category;
  final Color colorTag;
  final int qty;
  final double costPrice;
  final double sellPrice;
  final int gstRate;
  final bool isNew;

  double get lineSubtotal => qty * costPrice;

  /// `round(qty × cost × rate/100)` — server is authoritative on final
  /// rounding (doc §8.8); this is the client-side preview.
  double get gstAmount => double.parse((lineSubtotal * gstRate / 100).toStringAsFixed(2));

  double get lineTotal => lineSubtotal + gstAmount;

  PurchaseLine copyWith({
    int? qty,
    double? costPrice,
    double? sellPrice,
    int? gstRate,
  }) {
    return PurchaseLine(
      id: id,
      productId: productId,
      name: name,
      category: category,
      colorTag: colorTag,
      qty: qty ?? this.qty,
      costPrice: costPrice ?? this.costPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      gstRate: gstRate ?? this.gstRate,
      isNew: isNew,
    );
  }
}

/// A ranked candidate returned by `POST /products/check-duplicate`
/// (foundation/duplicate-detection.md §2). "Yes, same item" routes the
/// purchase quantity to [productId] instead of creating a new product.
@immutable
class DuplicateMatch {
  const DuplicateMatch({
    required this.productId,
    required this.name,
    required this.category,
    required this.costPrice,
    required this.sellPrice,
    required this.colorTag,
    required this.gstRate,
    this.matchScore = 0.9,
  });

  final String productId;
  final String name;
  final String category;
  final double costPrice;
  final double sellPrice;
  final Color colorTag;
  final int gstRate;
  final double matchScore;
}

/// One of the shop's own GST registrations — "file under" GSTIN (`purchases.gstin_id`).
@immutable
class OwnerGstin {
  const OwnerGstin({
    required this.id,
    required this.gstin,
    required this.label,
    this.active = true,
  });

  final String id;
  final String gstin;
  final String label;
  final bool active;
}

/// Server response shape for a confirmed purchase (`POST /purchases`).
@immutable
class PurchaseReceipt {
  const PurchaseReceipt({
    required this.id,
    required this.totalUnits,
    required this.subtotal,
    required this.totalGst,
    required this.totalCost,
  });

  final String id;
  final int totalUnits;
  final double subtotal;
  final double totalGst;
  final double totalCost;
}

/// Categories offered when confirming a line as a brand-new product
/// (`categories`) — required scoping field for duplicate detection (R2).
const List<String> kPurchaseCategories = [
  'Vehicles',
  'Dolls & Soft Toys',
  'Educational',
  'Outdoor & Sports',
  'Puzzles & Games',
  'Electronic Toys',
];

/// `products.color_tag` swatches — a searchable/visual cue, not the sole
/// differentiator (design-system.md §2).
const List<Color> kPurchaseColorTags = [
  Color(0xFFDC2626), // red
  Color(0xFF2563EB), // blue
  Color(0xFF16A34A), // green
  Color(0xFFD97706), // orange
  Color(0xFF7C3AED), // purple
  Color(0xFF0891B2), // teal
  Color(0xFFDB2777), // pink
  Color(0xFF78350F), // brown
];

/// Allowed GST slabs (doc §5b field 9).
const List<int> kGstRates = [0, 5, 12, 18, 28];

final List<Supplier> _demoSuppliers = [
  const Supplier(id: 'SUP-1', name: 'Sunrise Toys', gstin: '27ABCDE1234F1Z5', phone: '+91 98765 43210'),
  const Supplier(id: 'SUP-2', name: 'Global Kids Traders', phone: '+91 90000 11122'),
  const Supplier(id: 'SUP-3', name: 'Playtime Distributors', gstin: '29PQRSX9876G1Z2', phone: '+91 91234 56789'),
  const Supplier(id: 'SUP-4', name: 'Happy Kids Wholesale'),
];

final List<Product> _demoProducts = [
  const Product(
    id: 'P-101',
    name: 'Red Jeep Off-Roader',
    category: 'Vehicles',
    price: 1299,
    colorTag: Color(0xFFDC2626),
    stock: StockState.healthy,
    stockQty: 14,
    supplier: 'Sunrise Toys',
    gstRate: 18,
  ),
  const Product(
    id: 'P-102',
    name: 'Bella Baby Doll',
    category: 'Dolls & Soft Toys',
    price: 549,
    colorTag: Color(0xFFDB2777),
    stock: StockState.low,
    stockQty: 4,
    supplier: 'Global Kids Traders',
    gstRate: 12,
  ),
  const Product(
    id: 'P-103',
    name: 'Wooden Alphabet Train',
    category: 'Educational',
    price: 899,
    colorTag: Color(0xFF78350F),
    stock: StockState.healthy,
    stockQty: 20,
    supplier: 'Playtime Distributors',
    gstRate: 12,
  ),
  const Product(
    id: 'P-104',
    name: 'RC Monster Truck',
    category: 'Vehicles',
    price: 1899,
    colorTag: Color(0xFF2563EB),
    stock: StockState.aging,
    stockQty: 6,
    supplier: 'Sunrise Toys',
    gstRate: 18,
  ),
  const Product(
    id: 'P-105',
    name: 'Rainbow Stacking Rings',
    category: 'Educational',
    price: 349,
    colorTag: Color(0xFF7C3AED),
    stock: StockState.healthy,
    stockQty: 30,
    supplier: 'Happy Kids Wholesale',
    gstRate: 5,
  ),
  const Product(
    id: 'P-106',
    name: '100-pc Jigsaw Puzzle',
    category: 'Puzzles & Games',
    price: 299,
    colorTag: Color(0xFF0891B2),
    stock: StockState.low,
    stockQty: 5,
    supplier: 'Global Kids Traders',
    gstRate: 12,
  ),
];

/// Keyword → canned candidate, standing in for the real image+text similarity
/// service (foundation/duplicate-detection.md §2 layers 1–2). Typing a name
/// that *contains* a key (e.g. "Blue **Jeep** Racer") surfaces the match.
final Map<String, DuplicateMatch> _duplicateIndex = {
  'jeep': const DuplicateMatch(
    productId: 'P-101',
    name: 'Red Jeep Off-Roader',
    category: 'Vehicles',
    costPrice: 780,
    sellPrice: 1299,
    colorTag: Color(0xFFDC2626),
    gstRate: 18,
    matchScore: 0.91,
  ),
  'doll': const DuplicateMatch(
    productId: 'P-102',
    name: 'Bella Baby Doll',
    category: 'Dolls & Soft Toys',
    costPrice: 300,
    sellPrice: 549,
    colorTag: Color(0xFFDB2777),
    gstRate: 12,
    matchScore: 0.87,
  ),
};

final List<OwnerGstin> _demoGstins = [
  const OwnerGstin(id: 'G1', gstin: '27ABCDE1234F1Z5', label: 'Mumbai HO', active: true),
  const OwnerGstin(id: 'G2', gstin: '29ZZZZZ0000A1Z1', label: 'Bengaluru Branch', active: false),
];

class NewPurchaseRepository {
  const NewPurchaseRepository();

  Future<List<Supplier>> suppliers() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return List.unmodifiable(_demoSuppliers);
  }

  Future<Supplier> addSupplier({required String name, String? gstin, String? phone}) async {
    await Future.delayed(const Duration(milliseconds: 220));
    final s = Supplier(
      id: 'SUP-local-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      gstin: (gstin == null || gstin.trim().isEmpty) ? null : gstin.trim(),
      phone: (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
    );
    _demoSuppliers.add(s);
    return s;
  }

  Future<List<Product>> existingProducts() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return List.unmodifiable(_demoProducts);
  }

  Future<List<OwnerGstin>> ownerGstins() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return List.unmodifiable(_demoGstins);
  }

  /// Ranked-candidate lookup used before any new product is saved
  /// (foundation/duplicate-detection.md §2). Returns `null` below 3 chars or
  /// when nothing matches — mirrors "if none → save as new product".
  Future<DuplicateMatch?> checkDuplicate(String name) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final q = name.trim().toLowerCase();
    if (q.length < 3) return null;
    for (final entry in _duplicateIndex.entries) {
      if (q.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Idempotent write — appends one `stock_movements(purchase_in)` per line
  /// and updates each product's latest `cost_price` (doc §5d field 26, §8).
  Future<PurchaseReceipt> confirmPurchase({
    required Supplier supplier,
    required List<PurchaseLine> lines,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final units = lines.fold<int>(0, (a, l) => a + l.qty);
    final subtotal = lines.fold<double>(0, (a, l) => a + l.lineSubtotal);
    final gst = lines.fold<double>(0, (a, l) => a + l.gstAmount);
    return PurchaseReceipt(
      id: 'PUR-${DateTime.now().millisecondsSinceEpoch}',
      totalUnits: units,
      subtotal: subtotal,
      totalGst: gst,
      totalCost: subtotal + gst,
    );
  }
}
