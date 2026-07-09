// PROTOTYPE DUMMY DATA — replace ProductCatalogRepository.all() with
// GET /products?q=&category_id=&is_active= (see doc §9).
//
// Other methods to wire similarly against
// docs/mobile/owner/catalog/product-catalog-management.md §9's API table:
//   ProductCatalogRepository.categories()      → GET  /categories
//   ProductCatalogRepository.checkDuplicate()  → POST /products/check-duplicate
//   ProductCatalogRepository.addProduct()      → POST /products (Idempotency-Key = client_uuid)
//   ProductCatalogRepository.addStockTo()      → POST /purchases (dup-check "Yes, same item")
//   ProductCatalogRepository.updateProduct()   → PATCH /products/{id}
//   ProductCatalogRepository.setActive()       → PATCH /products/{id} { is_active, owner_pin }

import 'package:flutter/material.dart';

import '../../core/models/product.dart';
import '../../core/models/status.dart';

/// Catalog-only attributes that aren't on the shared [Product] model (kept
/// lean for sale/search screens). Mirrors `products` / `duplicate_review_queue`
/// columns not otherwise represented — see doc §5b, §8. Keyed by [Product.id]
/// via [ProductCatalogRepository.metaFor].
@immutable
class CatalogMeta {
  const CatalogMeta({
    this.isActive = true,
    this.isDuplicateSuspect = false,
    this.duplicateOfName,
    this.costPrice,
    this.hsnCode,
    this.reorderThreshold = 3,
    this.agingThresholdDays,
    this.lastSoldAt,
  });

  final bool isActive;
  final bool isDuplicateSuspect;
  final String? duplicateOfName;
  final double? costPrice;
  final String? hsnCode;
  final int reorderThreshold;
  final int? agingThresholdDays;
  final DateTime? lastSoldAt;

  CatalogMeta copyWith({
    bool? isActive,
    bool? isDuplicateSuspect,
    String? duplicateOfName,
    double? costPrice,
    String? hsnCode,
    int? reorderThreshold,
    int? agingThresholdDays,
    DateTime? lastSoldAt,
  }) {
    return CatalogMeta(
      isActive: isActive ?? this.isActive,
      isDuplicateSuspect: isDuplicateSuspect ?? this.isDuplicateSuspect,
      duplicateOfName: duplicateOfName ?? this.duplicateOfName,
      costPrice: costPrice ?? this.costPrice,
      hsnCode: hsnCode ?? this.hsnCode,
      reorderThreshold: reorderThreshold ?? this.reorderThreshold,
      agingThresholdDays: agingThresholdDays ?? this.agingThresholdDays,
      lastSoldAt: lastSoldAt ?? this.lastSoldAt,
    );
  }
}

/// A ranked match from `POST /products/check-duplicate`
/// (foundation/duplicate-detection.md §2). Resolved against the loaded
/// catalog by [existingId] so the prompt can show the real photo/name/price.
@immutable
class DuplicateCandidate {
  const DuplicateCandidate({
    required this.existingId,
    required this.score,
    this.matchType = 'name + photo',
  });

  final String existingId;
  final double score;
  final String matchType;
}

/// Builds an edited copy of a [Product] for the fields the shared model
/// doesn't expose via `copyWith` (category / colorTag / shelf) — avoids
/// touching the read-only core model just for this prototype screen.
extension ProductCatalogEdit on Product {
  Product withCatalogEdits({
    double? price,
    String? category,
    Color? colorTag,
    String? shelf,
  }) {
    return Product(
      id: id,
      name: name,
      category: category ?? this.category,
      price: price ?? this.price,
      colorTag: colorTag ?? this.colorTag,
      mrp: mrp,
      stock: stock,
      stockQty: stockQty,
      supplier: supplier,
      shelf: shelf ?? this.shelf,
      qrCode: qrCode,
      icon: icon,
      isFavorite: isFavorite,
      gstRate: gstRate,
    );
  }
}

/// `products.color_tag` swatches — searchable/visual cue, not the sole
/// differentiator (design-system.md §2).
const List<Color> kCatalogColorTags = [
  Color(0xFFDC2626), // red
  Color(0xFF2563EB), // blue
  Color(0xFF16A34A), // green
  Color(0xFFD97706), // orange
  Color(0xFF7C3AED), // purple
  Color(0xFF0891B2), // teal
  Color(0xFFDB2777), // pink
  Color(0xFF78350F), // brown
  Color(0xFF64748B), // grey
];

const Map<int, String> _colorTagNames = {
  0xFFDC2626: 'Red',
  0xFF2563EB: 'Blue',
  0xFF16A34A: 'Green',
  0xFFD97706: 'Orange',
  0xFF7C3AED: 'Purple',
  0xFF0891B2: 'Teal',
  0xFFDB2777: 'Pink',
  0xFF78350F: 'Brown',
  0xFF64748B: 'Grey',
};

/// Screen-reader / chip label for a [Product.colorTag] swatch — color is
/// never the sole differentiator (design-system.md §12).
String colorTagLabel(Color c) => _colorTagNames[c.toARGB32()] ?? 'Custom';

/// Allowed GST slabs (doc §5b field 13).
const List<int> kCatalogGstRates = [0, 5, 12, 18, 28];

final List<ProductCategory> _demoCategories = [
  const ProductCategory(
    id: 'vehicles',
    name: 'Vehicles',
    color: Color(0xFF2563EB),
    icon: Icons.directions_car_filled_rounded,
    count: 5,
  ),
  const ProductCategory(
    id: 'dolls',
    name: 'Dolls & Soft Toys',
    color: Color(0xFFDB2777),
    icon: Icons.child_friendly_rounded,
    count: 3,
  ),
  const ProductCategory(
    id: 'educational',
    name: 'Educational',
    color: Color(0xFF16A34A),
    icon: Icons.school_rounded,
    count: 3,
  ),
  const ProductCategory(
    id: 'puzzles',
    name: 'Puzzles & Games',
    color: Color(0xFF7C3AED),
    icon: Icons.extension_rounded,
    count: 3,
  ),
  const ProductCategory(
    id: 'electronic',
    name: 'Electronic Toys',
    color: Color(0xFF0891B2),
    icon: Icons.smart_toy_rounded,
    count: 3,
  ),
  const ProductCategory(
    id: 'outdoor',
    name: 'Outdoor & Sports',
    color: Color(0xFFD97706),
    icon: Icons.sports_baseball_rounded,
    count: 3,
  ),
];

final List<Product> _demoProducts = [
  const Product(
    id: 'P-101',
    name: 'Red Racer Car',
    category: 'Vehicles',
    price: 1499,
    colorTag: Color(0xFFDC2626),
    stock: StockState.healthy,
    stockQty: 18,
    supplier: 'Sunrise Toys',
    shelf: 'Rack A2',
    qrCode: 'A2-0022',
    icon: Icons.directions_car_filled_rounded,
    gstRate: 18,
  ),
  const Product(
    id: 'P-102',
    name: 'Blue Jet Glider',
    category: 'Vehicles',
    price: 4299,
    colorTag: Color(0xFF2563EB),
    stock: StockState.low,
    stockQty: 3,
    supplier: 'Sunrise Toys',
    shelf: 'Rack A5',
    icon: Icons.flight_rounded,
    gstRate: 18,
  ),
  const Product(
    id: 'P-103',
    name: 'Mini Dirt Bike',
    category: 'Vehicles',
    price: 2199,
    colorTag: Color(0xFFD97706),
    stock: StockState.aging,
    stockQty: 9,
    supplier: 'Sunrise Toys',
    shelf: 'Rack A6',
    icon: Icons.two_wheeler_rounded,
    gstRate: 18,
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
    shelf: 'Rack A7',
    icon: Icons.directions_car_filled_rounded,
    gstRate: 18,
  ),
  const Product(
    id: 'P-105',
    name: 'RC Monster Truck — XL',
    category: 'Vehicles',
    price: 2999,
    colorTag: Color(0xFF2563EB),
    stock: StockState.healthy,
    stockQty: 4,
    supplier: 'Sunrise Toys',
    shelf: 'Rack A8',
    icon: Icons.directions_car_filled_rounded,
    gstRate: 18,
  ),
  const Product(
    id: 'P-106',
    name: 'Bella Baby Doll',
    category: 'Dolls & Soft Toys',
    price: 549,
    colorTag: Color(0xFFDB2777),
    stock: StockState.healthy,
    stockQty: 22,
    supplier: 'Global Kids Traders',
    shelf: 'Rack B2',
    qrCode: 'B2-0041',
    icon: Icons.child_friendly_rounded,
    gstRate: 12,
  ),
  const Product(
    id: 'P-107',
    name: 'Bella Baby Doll — Deluxe',
    category: 'Dolls & Soft Toys',
    price: 599,
    colorTag: Color(0xFFDB2777),
    stock: StockState.healthy,
    stockQty: 6,
    supplier: 'Global Kids Traders',
    shelf: 'Rack B2',
    icon: Icons.child_friendly_rounded,
    gstRate: 12,
  ),
  const Product(
    id: 'P-108',
    name: 'Play Kitchen Set',
    category: 'Dolls & Soft Toys',
    price: 899,
    colorTag: Color(0xFFDB2777),
    stock: StockState.out,
    stockQty: 0,
    supplier: 'Global Kids Traders',
    shelf: 'Rack B1',
    icon: Icons.child_friendly_rounded,
    gstRate: 12,
  ),
  const Product(
    id: 'P-109',
    name: 'Wooden Alphabet Train',
    category: 'Educational',
    price: 899,
    colorTag: Color(0xFF78350F),
    stock: StockState.healthy,
    stockQty: 14,
    supplier: 'Playtime Distributors',
    shelf: 'Rack C1',
    icon: Icons.school_rounded,
    gstRate: 12,
  ),
  const Product(
    id: 'P-110',
    name: 'Rainbow Stacking Rings',
    category: 'Educational',
    price: 349,
    colorTag: Color(0xFF7C3AED),
    stock: StockState.healthy,
    stockQty: 40,
    supplier: 'Happy Kids Wholesale',
    shelf: 'Rack C2',
    icon: Icons.school_rounded,
    gstRate: 5,
  ),
  const Product(
    id: 'P-111',
    name: 'Number Puzzle Board',
    category: 'Educational',
    price: 299,
    colorTag: Color(0xFF0891B2),
    stock: StockState.low,
    stockQty: 2,
    supplier: 'Happy Kids Wholesale',
    shelf: 'Rack C3',
    icon: Icons.school_rounded,
    gstRate: 12,
  ),
  const Product(
    id: 'P-112',
    name: '100-pc Jigsaw Puzzle — Farm',
    category: 'Puzzles & Games',
    price: 299,
    colorTag: Color(0xFF0891B2),
    stock: StockState.healthy,
    stockQty: 17,
    supplier: 'Global Kids Traders',
    shelf: 'Rack D1',
    icon: Icons.extension_rounded,
    gstRate: 12,
  ),
  const Product(
    id: 'P-113',
    name: '500-pc Jigsaw Puzzle — Space',
    category: 'Puzzles & Games',
    price: 499,
    colorTag: Color(0xFF7C3AED),
    stock: StockState.aging,
    stockQty: 25,
    supplier: 'Global Kids Traders',
    shelf: 'Rack D2',
    icon: Icons.extension_rounded,
    gstRate: 12,
  ),
  const Product(
    id: 'P-114',
    name: 'Classic Ludo & Snakes',
    category: 'Puzzles & Games',
    price: 199,
    colorTag: Color(0xFF16A34A),
    stock: StockState.out,
    stockQty: 0,
    supplier: 'Playtime Distributors',
    shelf: 'Rack D3',
    icon: Icons.extension_rounded,
    gstRate: 12,
  ),
  const Product(
    id: 'P-115',
    name: 'Remote Control Drone Mini',
    category: 'Electronic Toys',
    price: 2599,
    colorTag: Color(0xFF64748B),
    stock: StockState.low,
    stockQty: 5,
    supplier: 'Sunrise Toys',
    shelf: 'Rack E1',
    icon: Icons.smart_toy_rounded,
    gstRate: 18,
  ),
  const Product(
    id: 'P-116',
    name: 'Talking Robot Buddy',
    category: 'Electronic Toys',
    price: 3499,
    colorTag: Color(0xFF0891B2),
    stock: StockState.healthy,
    stockQty: 8,
    supplier: 'Sunrise Toys',
    shelf: 'Rack E2',
    qrCode: 'E2-0077',
    icon: Icons.smart_toy_rounded,
    gstRate: 18,
  ),
  const Product(
    id: 'P-117',
    name: 'New Arrival — Robot Kit',
    category: 'Electronic Toys',
    price: 0,
    colorTag: Color(0xFF64748B),
    supplier: 'Sunrise Toys',
    icon: Icons.smart_toy_rounded,
    gstRate: 18,
  ),
  const Product(
    id: 'P-118',
    name: 'Basketball Hoop Stand',
    category: 'Outdoor & Sports',
    price: 1799,
    colorTag: Color(0xFFD97706),
    stock: StockState.low,
    stockQty: 4,
    supplier: 'Playtime Distributors',
    shelf: 'Rack F1',
    icon: Icons.sports_baseball_rounded,
    gstRate: 18,
  ),
  const Product(
    id: 'P-119',
    name: 'Badminton Set of 2',
    category: 'Outdoor & Sports',
    price: 399,
    colorTag: Color(0xFF16A34A),
    stock: StockState.healthy,
    stockQty: 30,
    supplier: 'Playtime Distributors',
    shelf: 'Rack F2',
    icon: Icons.sports_baseball_rounded,
    gstRate: 12,
  ),
  const Product(
    id: 'P-120',
    name: 'Skipping Rope — Kids',
    category: 'Outdoor & Sports',
    price: 99,
    colorTag: Color(0xFFDC2626),
    stock: StockState.healthy,
    stockQty: 60,
    supplier: 'Happy Kids Wholesale',
    shelf: 'Rack F3',
    icon: Icons.sports_baseball_rounded,
    gstRate: 5,
  ),
];

final Map<String, CatalogMeta> _demoMeta = {
  'P-101': CatalogMeta(costPrice: 850, hsnCode: '9503', lastSoldAt: DateTime(2026, 7, 3)),
  'P-102': CatalogMeta(costPrice: 2600, hsnCode: '9503', reorderThreshold: 5, lastSoldAt: DateTime(2026, 6, 20)),
  'P-103': CatalogMeta(
    costPrice: 1400,
    hsnCode: '9503',
    agingThresholdDays: 45,
    lastSoldAt: DateTime(2026, 4, 10),
  ),
  'P-104': CatalogMeta(costPrice: 1200, hsnCode: '9503', lastSoldAt: DateTime(2026, 4, 25)),
  'P-105': CatalogMeta(
    costPrice: 2000,
    isDuplicateSuspect: true,
    duplicateOfName: 'RC Monster Truck',
    lastSoldAt: DateTime(2026, 6, 29),
  ),
  'P-106': CatalogMeta(costPrice: 300, hsnCode: '9503', lastSoldAt: DateTime(2026, 7, 2)),
  'P-107': CatalogMeta(
    costPrice: 340,
    isDuplicateSuspect: true,
    duplicateOfName: 'Bella Baby Doll',
    lastSoldAt: DateTime(2026, 6, 15),
  ),
  'P-108': CatalogMeta(costPrice: 520, lastSoldAt: DateTime(2026, 5, 1)),
  'P-109': CatalogMeta(costPrice: 520, hsnCode: '9503', lastSoldAt: DateTime(2026, 7, 1)),
  'P-110': CatalogMeta(costPrice: 180, reorderThreshold: 10, lastSoldAt: DateTime(2026, 7, 3)),
  'P-111': CatalogMeta(
    costPrice: 160,
    reorderThreshold: 2,
    isActive: false,
    lastSoldAt: DateTime(2026, 3, 10),
  ),
  'P-112': CatalogMeta(costPrice: 150, lastSoldAt: DateTime(2026, 6, 30)),
  'P-113': CatalogMeta(costPrice: 260, lastSoldAt: DateTime(2026, 3, 1)),
  'P-114': CatalogMeta(costPrice: 90, isActive: false, lastSoldAt: DateTime(2026, 2, 14)),
  'P-115': CatalogMeta(costPrice: 1700, hsnCode: '8517', lastSoldAt: DateTime(2026, 6, 18)),
  'P-116': CatalogMeta(costPrice: 2200, lastSoldAt: DateTime(2026, 7, 2)),
  'P-117': const CatalogMeta(),
  'P-118': CatalogMeta(costPrice: 1100, lastSoldAt: DateTime(2026, 6, 25)),
  'P-119': CatalogMeta(costPrice: 220, reorderThreshold: 15, lastSoldAt: DateTime(2026, 7, 3)),
  'P-120': CatalogMeta(costPrice: 45, reorderThreshold: 20, lastSoldAt: DateTime(2026, 7, 3)),
};

/// Keyword → canned candidate, standing in for the real image+text similarity
/// service (foundation/duplicate-detection.md §2 layers 1–2), used by the
/// **Add product** flow. Typing a name that *contains* a key (e.g. "Blue
/// **Racer** Car") surfaces the match.
final Map<String, DuplicateCandidate> _duplicateIndex = {
  'racer': const DuplicateCandidate(existingId: 'P-101', score: 0.88, matchType: 'name + category'),
  'doll': const DuplicateCandidate(existingId: 'P-106', score: 0.83, matchType: 'name + photo'),
  'robot': const DuplicateCandidate(existingId: 'P-116', score: 0.90, matchType: 'name + photo'),
  'truck': const DuplicateCandidate(existingId: 'P-104', score: 0.86, matchType: 'name + category'),
  'puzzle': const DuplicateCandidate(existingId: 'P-112', score: 0.79, matchType: 'name + category'),
};

class ProductCatalogRepository {
  const ProductCatalogRepository();

  Future<List<Product>> all() async {
    await Future.delayed(const Duration(milliseconds: 320));
    return List.unmodifiable(_demoProducts);
  }

  Future<List<ProductCategory>> categories() async {
    await Future.delayed(const Duration(milliseconds: 160));
    return List.unmodifiable(_demoCategories);
  }

  /// Prototype-only catalog attributes not on [Product] — see [CatalogMeta].
  CatalogMeta metaFor(String productId) => _demoMeta[productId] ?? const CatalogMeta();

  /// Mandatory dup-check before any add can be saved (doc §8.1).
  Future<DuplicateCandidate?> checkDuplicate(String name) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final q = name.trim().toLowerCase();
    if (q.length < 3) return null;
    for (final entry in _duplicateIndex.entries) {
      if (q.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// `POST /products` — category & supplier are required scoping fields (R2).
  Future<Product> addProduct({
    required String name,
    required String category,
    required String supplier,
    required double price,
    Color colorTag = const Color(0xFF2563EB),
    String? shelf,
    int gstRate = 18,
  }) async {
    await Future.delayed(const Duration(milliseconds: 420));
    final product = Product(
      id: 'P-${200 + _demoProducts.length}',
      name: name,
      category: category,
      price: price,
      colorTag: colorTag,
      supplier: supplier,
      shelf: shelf,
      gstRate: gstRate,
    );
    _demoProducts.add(product);
    return product;
  }

  /// "Yes, same item" never creates a duplicate — the purchase quantity is
  /// added to the existing product instead (doc §8.2).
  Future<Product> addStockTo(String productId, {int qty = 1}) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final idx = _demoProducts.indexWhere((p) => p.id == productId);
    if (idx == -1) throw StateError('Unknown product $productId');
    final current = _demoProducts[idx];
    final newQty = (current.stockQty ?? 0) + qty;
    final updated = current.copyWith(
      stockQty: newQty,
      stock: newQty <= 0 ? StockState.out : (newQty <= 5 ? StockState.low : StockState.healthy),
    );
    _demoProducts[idx] = updated;
    return updated;
  }

  Future<Product> updateProduct(Product updated) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final idx = _demoProducts.indexWhere((p) => p.id == updated.id);
    if (idx != -1) _demoProducts[idx] = updated;
    return updated;
  }

  /// `PATCH /products/{id} { is_active, owner_pin }` — 🔒 gated on deactivate
  /// (doc §5b field 21); reactivate is the same endpoint, reversible.
  Future<void> setActive(String productId, bool active) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final current = _demoMeta[productId] ?? const CatalogMeta();
    _demoMeta[productId] = current.copyWith(isActive: active);
  }
}
