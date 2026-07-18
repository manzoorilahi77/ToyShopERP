import 'package:flutter/material.dart';

import 'status.dart';

/// Shared product model used by catalog, search and sale screens.
///
/// Products arrive with **no barcodes/SKUs** — only a supplier name and a look
/// (overview.md §1), so the UI leans on image, [colorTag] and [shelf] cues.
/// PROTOTYPE: [icon] + [colorTag] render an offline placeholder image.
@immutable
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.colorTag,
    this.mrp,
    this.stock = StockState.healthy,
    this.stockQty,
    this.supplier,
    this.shelf,
    this.qrCode,
    this.icon = Icons.toys_rounded,
    this.isFavorite = false,
    this.gstRate = 18,
    this.image,
  });

  final String id;
  final String name;
  final String category;
  final double price;

  /// MRP before any line discount, when different from [price].
  final double? mrp;
  final Color colorTag;
  final StockState stock;
  final int? stockQty;
  final String? supplier;
  final String? shelf;
  final String? qrCode;
  final IconData icon;
  final bool isFavorite;
  final int gstRate;
  final String? image;

  Product copyWith({bool? isFavorite, StockState? stock, int? stockQty, double? price, String? image}) {
    return Product(
      id: id,
      name: name,
      category: category,
      price: price ?? this.price,
      colorTag: colorTag,
      mrp: mrp,
      stock: stock ?? this.stock,
      stockQty: stockQty ?? this.stockQty,
      supplier: supplier,
      shelf: shelf,
      qrCode: qrCode,
      icon: icon,
      isFavorite: isFavorite ?? this.isFavorite,
      gstRate: gstRate,
      image: image ?? this.image,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    Color parseColor(String? hex) {
      if (hex == null || hex.isEmpty) return const Color(0xFF2563EB); // Default blue
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      try {
        return Color(int.parse(buffer.toString(), radix: 16));
      } catch (e) {
        return const Color(0xFF2563EB);
      }
    }

    final stockQty = json['stock'] as int? ?? 0;
    StockState stockState = StockState.healthy;
    if (stockQty == 0) {
      stockState = StockState.out;
    } else if (stockQty < 10) {
      stockState = StockState.low;
    }

    return Product(
      id: (json['id'] ?? '').toString(),
      name: json['name'] ?? 'Unknown',
      category: json['category']?['name'] ?? 'Uncategorized',
      price: double.tryParse((json['price'] ?? '0').toString()) ?? 0,
      mrp: double.tryParse((json['mrp'] ?? '0').toString()),
      colorTag: parseColor(json['color']),
      stock: stockState,
      stockQty: stockQty,
      supplier: json['supplier'],
      shelf: json['shelfLocation'],
      qrCode: json['barcode'],
      isFavorite: json['isFavorite'] == true || json['isFavorite'] == 1,
      gstRate: int.tryParse((json['gstRate'] ?? '18').toString()) ?? 18,
      image: json['image'],
    );
  }
}

/// A product category tile (design-system.md §6 `CategoryGrid`).
@immutable
class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.count = 0,
  });

  final String id;
  final String name;
  final Color color;
  final IconData icon;
  final int count;

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: (json['id'] ?? '').toString(),
      name: json['name'] ?? 'Unknown',
      color: const Color(0xFF16A34A), // Default green, or parse if backend sends color
      icon: Icons.category_rounded,
    );
  }
}
