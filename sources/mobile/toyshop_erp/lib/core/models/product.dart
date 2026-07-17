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
}
