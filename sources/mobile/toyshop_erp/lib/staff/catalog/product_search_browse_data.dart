// PROTOTYPE DUMMY DATA — replace ProductSearchBrowseRepository.search() with
// GET /products?category_id=&q=&color=&shelf= · .categories() with the cached
// `categories` list (`is_active=1`) · .resolveQr() with
// GET /products/by-qr/{internal_qr_code} · .toggleFavorite() with
// POST|DELETE /staff/{id}/favorites (see doc §9 — product-search-browse.md).
//
// Offline-first: docs §10 says browse/search/filters/QR all run against the
// Drift catalog cache. [_products] below stands in for that cache; filtering
// happens client-side via [filterProducts] exactly the way it would offline.

import 'package:flutter/material.dart';

import '../../core/core.dart';

/// A named color swatch for the R3 color filter. Carries a **label** so
/// meaning is never color-only (design-system.md §8).
class ColorTagOption {
  const ColorTagOption(this.label, this.color);
  final String label;
  final Color color;
}

/// Read-only catalog access for Browse (Requirement 3 — easier-than-photo
/// product ID: QR, color, shelf, voice, favorites).
class ProductSearchBrowseRepository {
  const ProductSearchBrowseRepository();

  /// `GET /products?category_id=&q=&color=&shelf=` (doc §9). Offline: served
  /// from the Drift catalog cache — mirrored here by [_products].
  Future<List<Product>> search({
    String? query,
    String? categoryId,
    Color? color,
    String? shelf,
    bool favoritesOnly = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final categoryName = categoryId == null
        ? null
        : _categories
            .firstWhere((c) => c.id == categoryId, orElse: () => _categories.first)
            .name;
    return filterProducts(
      _products,
      query: query,
      categoryName: categoryName,
      color: color,
      shelf: shelf,
      favoritesOnly: favoritesOnly,
    );
  }

  /// Cached `categories`, `is_active=1` only (doc §5 row 4).
  Future<List<ProductCategory>> categories() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _categories;
  }

  /// `GET /products/by-qr/{internal_qr_code}` (doc §9) — resolves a
  /// scanned/typed sticker straight to its product (near-barcode speed, R3
  /// rule 3); `null` when the code isn't recognised.
  Future<Product?> resolveQr(String code) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final norm = code.trim().toLowerCase();
    if (norm.isEmpty) return null;
    for (final p in _products) {
      if (p.qrCode != null && p.qrCode!.toLowerCase() == norm) return p;
    }
    return null;
  }

  /// `POST|DELETE /staff/{id}/favorites` (proposed, doc §10) — the only write
  /// on this screen; queued to `sync_outbox` when offline.
  Future<Product> toggleFavorite(String productId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final i = _products.indexWhere((p) => p.id == productId);
    final updated = _products[i].copyWith(isFavorite: !_products[i].isFavorite);
    _products[i] = updated;
    return updated;
  }

  /// Distinct `products.color_tag` values (doc §5 row 5).
  List<ColorTagOption> get colorOptions => _colorOptions;

  /// Distinct `products.shelf_location` values (doc §5 row 6).
  List<String> get shelfOptions => _shelfOptions;
}

/// Shared AND-combined filter (doc §8 rule 6) — used by
/// [ProductSearchBrowseRepository.search] and, client-side, by the screen for
/// instant re-filtering against the already-loaded cache (never a spinner on
/// a cached re-filter, design-system.md §1).
List<Product> filterProducts(
  List<Product> source, {
  String? query,
  String? categoryName,
  Color? color,
  String? shelf,
  bool favoritesOnly = false,
}) {
  return source.where((p) {
    if (categoryName != null && p.category != categoryName) return false;
    if (color != null && p.colorTag != color) return false;
    if (shelf != null && p.shelf != shelf) return false;
    if (favoritesOnly && !p.isFavorite) return false;
    if (query != null && query.trim().isNotEmpty && !_fuzzyMatch(p, query)) return false;
    return true;
  }).toList();
}

/// Human label for a [Product.colorTag] — used by filter chips and detail
/// views so color is never the only cue (design-system.md §8).
String colorLabel(Color c) {
  for (final o in _colorOptions) {
    if (o.color == c) return o.label;
  }
  return 'Other';
}

/// Fuzzy match tolerant of plural/typo variants (doc §8 rule 5 — FULLTEXT
/// pre-filter + client Levenshtein, duplicate-detection.md §5.4). Simplified
/// for the prototype: substring contains, then a one-edit token check.
bool _fuzzyMatch(Product p, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  final haystacks = <String>[
    p.name,
    p.category,
    if (p.shelf != null) p.shelf!,
    colorLabel(p.colorTag),
  ];
  for (final h in haystacks) {
    final hay = h.toLowerCase();
    if (hay.contains(needle)) return true;
    for (final word in hay.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      if (_stem(word) == _stem(needle)) return true;
      if (needle.length >= 3 && _levenshtein(word, needle) <= 1) return true;
    }
  }
  return false;
}

String _stem(String w) => w.length > 3 && w.endsWith('s') ? w.substring(0, w.length - 1) : w;

/// Classic iterative Levenshtein edit distance (no new deps).
int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  var curr = List<int>.filled(b.length + 1, 0);
  for (var i = 0; i < a.length; i++) {
    curr[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a[i] == b[j] ? 0 : 1;
      final deletion = prev[j + 1] + 1;
      final insertion = curr[j] + 1;
      final substitution = prev[j] + cost;
      curr[j + 1] = [deletion, insertion, substitution].reduce((x, y) => x < y ? x : y);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[b.length];
}

// ---------------------------------------------------------------------------
// Demo dataset — categories, color/shelf filter options, and an 18-product
// spread across categories/colors/shelves/stock states so every browse path
// (category, color, shelf, voice, QR, favorites) has real results to show.
// ---------------------------------------------------------------------------

final List<ProductCategory> _categories = const [
  ProductCategory(
    id: 'cat-cars',
    name: 'Battery Cars',
    color: Color(0xFF2563EB),
    icon: Icons.directions_car_rounded,
    count: 4,
  ),
  ProductCategory(
    id: 'cat-rideon',
    name: 'Ride-ons',
    color: Color(0xFFDC2626),
    icon: Icons.directions_car_rounded,
    count: 3,
  ),
  ProductCategory(
    id: 'cat-soft',
    name: 'Soft Toys',
    color: Color(0xFFDB2777),
    icon: Icons.pets_rounded,
    count: 3,
  ),
  ProductCategory(
    id: 'cat-play',
    name: 'Play Sets',
    color: Color(0xFF16A34A),
    icon: Icons.kitchen_rounded,
    count: 3,
  ),
  ProductCategory(
    id: 'cat-edu',
    name: 'Educational',
    color: Color(0xFF7C3AED),
    icon: Icons.school_rounded,
    count: 3,
  ),
  ProductCategory(
    id: 'cat-outdoor',
    name: 'Outdoor',
    color: Color(0xFFD97706),
    icon: Icons.sports_baseball_rounded,
    count: 2,
  ),
];

const _red = Color(0xFFDC2626);
const _blue = Color(0xFF2563EB);
const _yellow = Color(0xFFEAB308);
const _green = Color(0xFF16A34A);
const _pink = Color(0xFFDB2777);
const _purple = Color(0xFF7C3AED);
const _brown = Color(0xFF92400E);

final List<ColorTagOption> _colorOptions = const [
  ColorTagOption('Red', _red),
  ColorTagOption('Blue', _blue),
  ColorTagOption('Yellow', _yellow),
  ColorTagOption('Green', _green),
  ColorTagOption('Pink', _pink),
  ColorTagOption('Purple', _purple),
  ColorTagOption('Brown', _brown),
];

final List<String> _shelfOptions = const [
  'A2', 'A3', 'B1', 'B2', 'C1', 'C2', 'C3', 'C4', 'D1', 'D2', 'E1',
];

final List<Product> _products = [
  // Battery Cars
  const Product(
    id: 'cb-001', name: 'Red Racer Battery Car', category: 'Battery Cars',
    price: 1499, mrp: 1699, colorTag: _red, stock: StockState.healthy, stockQty: 7,
    shelf: 'A2', qrCode: 'TSK-000123', icon: Icons.directions_car_rounded,
    isFavorite: true, gstRate: 18,
  ),
  const Product(
    id: 'cb-002', name: 'Blue Thunder RC Car', category: 'Battery Cars',
    price: 1899, colorTag: _blue, stock: StockState.low, stockQty: 3,
    shelf: 'A2', qrCode: 'TSK-000124', icon: Icons.directions_car_rounded, gstRate: 18,
  ),
  const Product(
    id: 'cb-003', name: 'Yellow Speedster Mini', category: 'Battery Cars',
    price: 899, colorTag: _yellow, stock: StockState.healthy, stockQty: 18,
    shelf: 'A3', icon: Icons.directions_car_rounded, gstRate: 18,
  ),
  const Product(
    id: 'cb-004', name: 'Green Buggy 4x4', category: 'Battery Cars',
    price: 2100, colorTag: _green, stock: StockState.aging, stockQty: 9,
    shelf: 'A3', qrCode: 'TSK-000125', icon: Icons.directions_car_rounded, gstRate: 18,
  ),
  // Ride-ons
  const Product(
    id: 'cb-005', name: 'Mini Jeep Red', category: 'Ride-ons',
    price: 4200, mrp: 4500, colorTag: _red, stock: StockState.healthy, stockQty: 5,
    shelf: 'B1', qrCode: 'TSK-000201', icon: Icons.directions_car_rounded,
    isFavorite: true, gstRate: 18,
  ),
  const Product(
    id: 'cb-006', name: 'Pink Princess Ride-on', category: 'Ride-ons',
    price: 4650, colorTag: _pink, stock: StockState.low, stockQty: 2,
    shelf: 'B1', qrCode: 'TSK-000202', icon: Icons.directions_car_rounded, gstRate: 18,
  ),
  const Product(
    id: 'cb-007', name: 'Baby Bike Blue', category: 'Ride-ons',
    price: 2100, colorTag: _blue, stock: StockState.out, stockQty: 0,
    shelf: 'B2', icon: Icons.pedal_bike_rounded, gstRate: 18,
  ),
  // Soft Toys
  const Product(
    id: 'cb-008', name: 'Teddy Bear XL Brown', category: 'Soft Toys',
    price: 799, colorTag: _brown, stock: StockState.healthy, stockQty: 25,
    shelf: 'C3', qrCode: 'TSK-000301', icon: Icons.pets_rounded,
    isFavorite: true, gstRate: 12,
  ),
  const Product(
    id: 'cb-009', name: 'Bunny Soft Toy Pink', category: 'Soft Toys',
    price: 549, colorTag: _pink, stock: StockState.healthy, stockQty: 30,
    shelf: 'C3', qrCode: 'TSK-000302', icon: Icons.pets_rounded, gstRate: 12,
  ),
  const Product(
    id: 'cb-010', name: 'Purple Unicorn Plush', category: 'Soft Toys',
    price: 699, colorTag: _purple, stock: StockState.aging, stockQty: 6,
    shelf: 'C4', icon: Icons.pets_rounded, gstRate: 12,
  ),
  // Play Sets
  const Product(
    id: 'cb-011', name: 'Kitchen Play Set Green', category: 'Play Sets',
    price: 1750, colorTag: _green, stock: StockState.healthy, stockQty: 22,
    shelf: 'D1', qrCode: 'TSK-000401', icon: Icons.kitchen_rounded, gstRate: 18,
  ),
  const Product(
    id: 'cb-012', name: 'Doll House Pink', category: 'Play Sets',
    price: 2350, colorTag: _pink, stock: StockState.low, stockQty: 4,
    shelf: 'D1', qrCode: 'TSK-000402', icon: Icons.house_rounded, gstRate: 18,
  ),
  const Product(
    id: 'cb-013', name: 'Tool Bench Set Yellow', category: 'Play Sets',
    price: 1450, colorTag: _yellow, stock: StockState.healthy, stockQty: 14,
    shelf: 'D2', icon: Icons.construction_rounded, gstRate: 18,
  ),
  // Educational
  const Product(
    id: 'cb-014', name: 'Alphabet Blocks Set', category: 'Educational',
    price: 599, colorTag: _blue, stock: StockState.healthy, stockQty: 40,
    shelf: 'C1', qrCode: 'TSK-000501', icon: Icons.school_rounded,
    isFavorite: true, gstRate: 12,
  ),
  const Product(
    id: 'cb-015', name: 'Number Puzzle Board', category: 'Educational',
    price: 449, colorTag: _green, stock: StockState.healthy, stockQty: 35,
    shelf: 'C1', qrCode: 'TSK-000502', icon: Icons.extension_rounded, gstRate: 12,
  ),
  const Product(
    id: 'cb-016', name: 'Science Kit Junior', category: 'Educational',
    price: 1299, colorTag: _purple, stock: StockState.low, stockQty: 3,
    shelf: 'C2', qrCode: 'TSK-000503', icon: Icons.science_rounded, gstRate: 12,
  ),
  // Outdoor
  const Product(
    id: 'cb-017', name: 'Soccer Set Kids', category: 'Outdoor',
    price: 899, colorTag: _yellow, stock: StockState.healthy, stockQty: 12,
    shelf: 'E1', qrCode: 'TSK-000601', icon: Icons.sports_soccer_rounded, gstRate: 18,
  ),
  const Product(
    id: 'cb-018', name: 'Badminton Combo', category: 'Outdoor',
    price: 649, colorTag: _blue, stock: StockState.out, stockQty: 0,
    shelf: 'E1', icon: Icons.sports_tennis_rounded, gstRate: 18,
  ),
];
