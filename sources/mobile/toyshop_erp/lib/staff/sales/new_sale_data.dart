// PROTOTYPE DUMMY DATA — replace NewSaleRepository.loadCatalog() with
//   GET /products?category_id=&q=  ·  GET /products/by-qr/{internal_qr_code}
// and NewSaleRepository.confirmSale() with the sync-outbox push
//   POST /sync/push (entity_type=sale)  — or POST /sales when online —
// (see doc §9, docs/mobile/staff/sales/new-sale.md).
//
// Offline-first: doc §10 says find/browse/cart/confirm all run against the
// Drift catalog cache with zero connectivity. [_catalog] below stands in for
// that cache.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/core.dart';
import '../../core/api_config.dart';
import '../../core/utils/storage_service.dart';
import 'receipt_data.dart';

/// One priced row building up in the cart (new-sale doc §5 row 11). Mutable
/// [qty] so `+`/`-`/`NumericPad` edits update the running total in place
/// without rebuilding the whole list.
class CartLine {
  CartLine({required this.product, this.qty = 1, this.priceOverride});

  final Product product;
  int qty;

  /// A staff-entered unit price that replaces the catalog [Product.price] for
  /// this line — can be higher or lower. `null` means "use catalog price".
  /// Unlike the cart-level discount, this is **not owner-PIN gated**; it's
  /// flagged on the line (cart UI + receipt) and carried onto the confirmed
  /// sale via [ReceiptLine.priceOverridden] for the owner to review later
  /// (a real backend would write this to `audit_log`).
  double? priceOverride;

  double get unitPrice => priceOverride ?? product.price;
  bool get isPriceOverridden => priceOverride != null;

  double get lineTotal => (unitPrice * qty) + ((unitPrice * qty) * (product.gstRate / 100));

  /// Snapshots price/GST now — later catalog edits never touch this line
  /// once it's on a confirmed sale (new-sale doc rule 3).
  ReceiptLine toReceiptLine() => ReceiptLine(
        productId: product.id,
        name: product.name,
        qty: qty,
        unitPrice: unitPrice,
        gstRate: product.gstRate,
        priceOverridden: isPriceOverridden,
      );
}

/// The staff's catalog cache — categories, products and quick-picks — plus
/// the client-side lookups the doc runs against it (search, category, QR;
/// new-sale doc §5 rows 1–6, §9).
@immutable
class NewSaleCatalog {
  const NewSaleCatalog({
    required this.categories,
    required this.quickPicks,
    required this.products,
  });

  final List<ProductCategory> categories;

  /// Favorites + frequent (new-sale doc §5 row 4) — top 8, 1-tap add.
  final List<Product> quickPicks;
  final List<Product> products;

  List<Product> byCategory(String categoryName) =>
      products.where((p) => p.category == categoryName).toList();

  /// Simplified client fuzzy-find (new-sale doc §5 row 1) — name, category or
  /// shelf contains the query. Typing is the last resort (R3); QR/quick-pick/
  /// category are all faster paths to the same [ItemConfirmCard].
  List<Product> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return products.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          (p.shelf?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  /// `GET /products/by-qr/{internal_qr_code}` (doc §9) — resolves a
  /// scanned/typed sticker straight to a product, or `null` if unrecognised
  /// (doc §6 error state: "QR not found — enter manually").
  Product? byQr(String code) {
    final norm = code.trim().toLowerCase();
    if (norm.isEmpty) return null;
    for (final p in products) {
      if (p.qrCode != null && p.qrCode!.toLowerCase() == norm) return p;
    }
    return null;
  }
}

class NewSaleRepository {
  const NewSaleRepository();

  Future<NewSaleCatalog> loadCatalog() async {
    try {
      final token = await StorageService.getAccessToken();
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final catRes = await http.get(Uri.parse(ApiConfig.categories), headers: headers);
      final categories = <ProductCategory>[];
      if (catRes.statusCode == 200) {
        final data = jsonDecode(catRes.body);
        if (data['success'] == true && data['data'] != null) {
          final list = data['data'] as List;
          for (final c in list) {
            categories.add(ProductCategory.fromJson(c));
          }
        }
      }

      final prodRes = await http.get(Uri.parse(ApiConfig.products), headers: headers);
      final products = <Product>[];
      final quickPicks = <Product>[];
      if (prodRes.statusCode == 200) {
        final data = jsonDecode(prodRes.body);
        if (data['success'] == true && data['data'] != null) {
          final list = data['data'] as List;
          for (final p in list) {
            final prod = Product.fromJson(p);
            products.add(prod);
            if (prod.isFavorite) {
              quickPicks.add(prod);
            }
          }
        }
      }

      if (categories.isEmpty && products.isEmpty) {
        return _catalog;
      }

      return NewSaleCatalog(
        categories: categories.isEmpty ? _categories : categories,
        products: products,
        quickPicks: quickPicks,
      );
    } catch (e) {
      debugPrint('Error loading catalog: $e');
      return _catalog;
    }
  }

  Future<ReceiptData> confirmSale({
    required List<CartLine> lines,
    required PaymentMode paymentMode,
    required String staffName,
    required String branchName,
  }) async {
    try {
      final token = await StorageService.getAccessToken();
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = {
        'branchId': 1,
        'paymentMethod': paymentMode.name,
        'items': lines.map((l) => {
          'productId': l.product.id,
          'quantity': l.qty,
          'unitPrice': l.unitPrice,
        }).toList(),
      };

      final res = await http.post(
        Uri.parse(ApiConfig.sales),
        headers: headers,
        body: jsonEncode(body),
      );

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final sale = data['data']['sale'];
        
        return ReceiptData(
          clientUuid: sale['id'].toString(),
          invoiceNo: sale['invoiceNumber'],
          soldAt: DateTime.parse(sale['createdAt']).toLocal(),
          staffName: staffName,
          branchName: branchName,
          items: [for (final l in lines) l.toReceiptLine()],
          paymentMode: paymentMode,
          syncStatus: SyncState.synced,
        );
      }
    } catch (e) {
      debugPrint('Error confirming sale: $e');
    }

    return ReceiptData(
      clientUuid: _newClientUuid(),
      soldAt: DateTime.now(),
      staffName: staffName,
      branchName: branchName,
      items: [for (final l in lines) l.toReceiptLine()],
      paymentMode: paymentMode,
      syncStatus: SyncState.pending,
    );
  }

  String _newClientUuid() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36).toUpperCase();
}

// ---------------------------------------------------------------------------
// Demo dataset — the 6 categories from the new-sale wireframe (doc §4) and an
// 18-product spread across them with real stock/shelf/QR variety so every
// retrieval path (quick-pick, category, search, QR) has results to show.
// ---------------------------------------------------------------------------

const _blue = Color(0xFF2563EB);
const _red = Color(0xFFDC2626);
const _green = Color(0xFF16A34A);
const _purple = Color(0xFF7C3AED);
const _pink = Color(0xFFDB2777);
const _orange = Color(0xFFD97706);
const _yellow = Color(0xFFEAB308);

final List<ProductCategory> _categories = const [
  ProductCategory(id: 'battery-cars', name: 'Battery Cars', color: _blue, icon: Icons.directions_car_rounded),
  ProductCategory(id: 'rideon-bikes', name: 'Ride-on Bikes', color: _red, icon: Icons.pedal_bike_rounded),
  ProductCategory(id: 'play-sets', name: 'Play Sets', color: _green, icon: Icons.kitchen_rounded),
  ProductCategory(id: 'remote', name: 'Remote', color: _purple, icon: Icons.settings_remote_rounded),
  ProductCategory(id: 'dolls', name: 'Dolls', color: _pink, icon: Icons.child_care_rounded),
  ProductCategory(id: 'outdoor', name: 'Outdoor', color: _orange, icon: Icons.sports_baseball_rounded),
];

final List<Product> _products = const [
  // Battery Cars
  Product(
    id: 'ns-01', name: 'Red Racer Battery Car', category: 'Battery Cars',
    price: 1499, mrp: 1699, colorTag: _red, stock: StockState.healthy, stockQty: 7,
    shelf: 'A2', qrCode: 'NS-001', icon: Icons.directions_car_rounded,
    isFavorite: true, gstRate: 18,
  ),
  Product(
    id: 'ns-02', name: 'Blue Thunder Racer', category: 'Battery Cars',
    price: 1899, colorTag: _blue, stock: StockState.low, stockQty: 3,
    shelf: 'A2', icon: Icons.directions_car_rounded, gstRate: 18,
  ),
  Product(
    id: 'ns-03', name: 'Yellow Jeep Battery Car', category: 'Battery Cars',
    price: 2599, colorTag: _yellow, stock: StockState.healthy, stockQty: 9,
    shelf: 'A1', icon: Icons.directions_car_rounded, gstRate: 18,
  ),
  // Ride-on Bikes
  Product(
    id: 'ns-04', name: 'Mini Jeep', category: 'Ride-on Bikes',
    price: 4200, mrp: 4500, colorTag: _red, stock: StockState.healthy, stockQty: 5,
    shelf: 'B1', qrCode: 'NS-002', icon: Icons.directions_car_rounded,
    isFavorite: true, gstRate: 18,
  ),
  Product(
    id: 'ns-05', name: 'Baby Bike Pink', category: 'Ride-on Bikes',
    price: 2100, colorTag: _pink, stock: StockState.low, stockQty: 4,
    shelf: 'B2', icon: Icons.pedal_bike_rounded, gstRate: 18,
  ),
  Product(
    id: 'ns-06', name: 'Trike Trooper', category: 'Ride-on Bikes',
    price: 1350, colorTag: _green, stock: StockState.healthy, stockQty: 18,
    shelf: 'B3', icon: Icons.pedal_bike_rounded, gstRate: 18,
  ),
  // Play Sets
  Product(
    id: 'ns-07', name: 'Kitchen Play Set', category: 'Play Sets',
    price: 1750, colorTag: _green, stock: StockState.healthy, stockQty: 22,
    shelf: 'C1', icon: Icons.kitchen_rounded, gstRate: 18,
  ),
  Product(
    id: 'ns-08', name: 'Tool Bench Set', category: 'Play Sets',
    price: 1290, colorTag: _yellow, stock: StockState.healthy, stockQty: 15,
    shelf: 'C2', icon: Icons.construction_rounded, gstRate: 18,
  ),
  Product(
    id: 'ns-09', name: 'Doctor Play Kit', category: 'Play Sets',
    price: 899, colorTag: _blue, stock: StockState.aging, stockQty: 6,
    shelf: 'C3', icon: Icons.medical_services_rounded, gstRate: 12,
  ),
  // Remote
  Product(
    id: 'ns-10', name: 'RC Racer Blue', category: 'Remote',
    price: 1350, colorTag: _blue, stock: StockState.healthy, stockQty: 40,
    shelf: 'D1', qrCode: 'NS-003', icon: Icons.sports_esports_rounded,
    isFavorite: true, gstRate: 18,
  ),
  Product(
    id: 'ns-11', name: 'RC Helicopter', category: 'Remote',
    price: 2450, colorTag: _purple, stock: StockState.healthy, stockQty: 10,
    shelf: 'D2', icon: Icons.flight_rounded, gstRate: 18,
  ),
  Product(
    id: 'ns-12', name: 'Robot Walker', category: 'Remote',
    price: 999, colorTag: _purple, stock: StockState.healthy, stockQty: 31,
    shelf: 'D3', icon: Icons.smart_toy_rounded, isFavorite: true, gstRate: 18,
  ),
  // Dolls
  Product(
    id: 'ns-13', name: 'Doll House', category: 'Dolls',
    price: 750, colorTag: _pink, stock: StockState.healthy, stockQty: 17,
    shelf: 'E1', icon: Icons.cottage_rounded, isFavorite: true, gstRate: 12,
  ),
  Product(
    id: 'ns-14', name: 'Fashion Doll Set', category: 'Dolls',
    price: 620, colorTag: _pink, stock: StockState.healthy, stockQty: 25,
    shelf: 'E2', icon: Icons.toys_rounded, gstRate: 12,
  ),
  Product(
    id: 'ns-15', name: 'Baby Doll Pram', category: 'Dolls',
    price: 1120, colorTag: _blue, stock: StockState.out, stockQty: 0,
    shelf: 'E3', icon: Icons.stroller_rounded, gstRate: 12,
  ),
  // Outdoor
  Product(
    id: 'ns-16', name: 'Cricket Set Junior', category: 'Outdoor',
    price: 549, colorTag: _green, stock: StockState.healthy, stockQty: 28,
    shelf: 'F1', icon: Icons.sports_cricket_rounded, gstRate: 12,
  ),
  Product(
    id: 'ns-17', name: 'Badminton Combo', category: 'Outdoor',
    price: 399, colorTag: _blue, stock: StockState.healthy, stockQty: 33,
    shelf: 'F2', icon: Icons.sports_tennis_rounded, gstRate: 12,
  ),
  Product(
    id: 'ns-18', name: 'Trampoline Small', category: 'Outdoor',
    price: 3499, colorTag: _yellow, stock: StockState.low, stockQty: 2,
    shelf: 'F3', icon: Icons.park_rounded, gstRate: 18,
  ),
];

final NewSaleCatalog _catalog = NewSaleCatalog(
  categories: _categories,
  products: _products,
  quickPicks: _products.where((p) => p.isFavorite).toList(),
);
