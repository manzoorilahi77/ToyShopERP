import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../../core/models/product.dart';
import '../../core/models/status.dart';
import '../../core/utils/storage_service.dart';

String? _formatImageUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://localhost:5000')) {
    return url.replaceFirst('http://localhost:5000', 'https://toys.aspirasys.in');
  }
  if (url.startsWith('/')) {
    return 'https://toys.aspirasys.in$url';
  }
  return url;
}

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
    this.createdAt,
  });

  final bool isActive;
  final bool isDuplicateSuspect;
  final String? duplicateOfName;
  final double? costPrice;
  final String? hsnCode;
  final int reorderThreshold;
  final int? agingThresholdDays;
  final DateTime? lastSoldAt;
  final DateTime? createdAt;

  CatalogMeta copyWith({
    bool? isActive,
    bool? isDuplicateSuspect,
    String? duplicateOfName,
    double? costPrice,
    String? hsnCode,
    int? reorderThreshold,
    int? agingThresholdDays,
    DateTime? lastSoldAt,
    DateTime? createdAt,
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
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

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

extension ProductCatalogEdit on Product {
  Product withCatalogEdits({
    double? price,
    String? category,
    Color? colorTag,
    int? stockQty,
  }) {
    return Product(
      id: id,
      name: name,
      category: category ?? this.category,
      price: price ?? this.price,
      colorTag: colorTag ?? this.colorTag,
      mrp: mrp,
      stock: stock,
      stockQty: stockQty ?? this.stockQty,
      supplier: supplier,
      shelf: shelf,
      qrCode: qrCode,
      icon: icon,
      isFavorite: isFavorite,
      gstRate: gstRate,
    );
  }
}

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

String colorTagLabel(Color c) => _colorTagNames[c.value] ?? 'Custom';

const List<int> kCatalogGstRates = [0, 5, 12, 18, 28];

List<ProductCategory> _apiCategories = [];
List<Product> _apiProducts = [];
Map<String, CatalogMeta> _apiMeta = {};

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
    try {
      final token = await StorageService.getAccessToken();
      final response = await http.get(
        Uri.parse(ApiConfig.products),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> items = data['data'];
          _apiProducts.clear();
          _apiMeta.clear();
          for (var item in items) {
            final int stockQty = item['stock'] ?? 0;
            StockState state = StockState.healthy;
            if (stockQty <= 0) state = StockState.out;
            else if (stockQty <= 5) state = StockState.low;
            
            final catData = item['category'];
            final categoryName = catData != null ? catData['name'] : 'Uncategorized';
            
            final p = Product(
              id: item['id'].toString(),
              name: item['name'] ?? 'Unknown',
              category: categoryName,
              price: double.tryParse(item['price']?.toString() ?? '0') ?? 0.0,
              colorTag: const Color(0xFF2563EB),
              stock: state,
              stockQty: stockQty,
              supplier: item['supplier'] ?? 'Unknown',
              shelf: item['shelf'],
              gstRate: 18,
              image: _formatImageUrl(item['image']),
            );
            _apiProducts.add(p);
            _apiMeta[p.id] = CatalogMeta(
              isActive: item['isActive'] ?? true,
              createdAt: item['createdAt'] != null ? DateTime.tryParse(item['createdAt']) : DateTime.now(),
            );
          }
          return List.unmodifiable(_apiProducts);
        }
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');
    }
    return List.unmodifiable(_apiProducts);
  }

  Future<List<ProductCategory>> categories() async {
    try {
      final token = await StorageService.getAccessToken();
      final response = await http.get(
        Uri.parse(ApiConfig.categories),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> items = data['data'];
          _apiCategories.clear();
          for (var item in items) {
            _apiCategories.add(ProductCategory(
              id: item['id'].toString(),
              name: item['name'] ?? 'Unknown',
              color: const Color(0xFF2563EB),
              icon: Icons.category_rounded,
            ));
          }
          return List.unmodifiable(_apiCategories);
        }
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
    return List.unmodifiable(_apiCategories);
  }

  CatalogMeta metaFor(String productId) => _apiMeta[productId] ?? const CatalogMeta();

  Future<DuplicateCandidate?> checkDuplicate(String name) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final q = name.trim().toLowerCase();
    if (q.length < 3) return null;
    for (final entry in _duplicateIndex.entries) {
      if (q.contains(entry.key)) return entry.value;
    }
    return null;
  }

  Future<Product> addProduct({
    required String name,
    required String category,
    required String supplier,
    required double price,
    Color colorTag = const Color(0xFF2563EB),
    String? shelf,
    int gstRate = 18,
  }) async {
    final token = await StorageService.getAccessToken();
    final cat = _apiCategories.firstWhere((c) => c.name == category, orElse: () => const ProductCategory(id: '1', name: 'Misc', color: Colors.blue, icon: Icons.category));
    final response = await http.post(
      Uri.parse(ApiConfig.products),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'categoryId': int.tryParse(cat.id) ?? 1,
        'price': price,
        'stock': 0,
        'isActive': true,
      }),
    );
    if (response.statusCode == 201) {
      await all(); // Refresh list
    }
    return _apiProducts.lastWhere((p) => p.name == name, orElse: () => _apiProducts.first);
  }

  Future<Product> addStockTo(String productId, {int qty = 1}) async {
    return _apiProducts.firstWhere((p) => p.id == productId);
  }

  Future<Product> updateProduct(Product updated) async {
    final token = await StorageService.getAccessToken();
    final response = await http.put(
      Uri.parse("${ApiConfig.products}/${updated.id}"),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': updated.name,
        'price': updated.price,
        'stock': updated.stockQty,
      }),
    );
    if (response.statusCode == 200) {
      await all();
    }
    return updated;
  }

  Future<void> setActive(String productId, bool active) async {
    final token = await StorageService.getAccessToken();
    final response = await http.put(
      Uri.parse("${ApiConfig.products}/$productId"),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'isActive': active,
      }),
    );
    if (response.statusCode == 200) {
      _apiMeta[productId] = metaFor(productId).copyWith(isActive: active);
    }
  }
}
