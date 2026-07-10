import 'package:flutter/material.dart';
import '../../core/models/product.dart';

class StockAdditionRepository {
  const StockAdditionRepository();

  /// Simulates adding stock to the ERP
  Future<Product> addStock({
    required String name,
    required Color colorTag,
    required double price,
    required String sourceCompany,
    required int quantity,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 600));

    // In a real implementation, this would make an API call to save the product
    // and its initial stock/supplier details to the database.
    return Product(
      id: 'P-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      category: 'General', // A default category, since it wasn't requested
      price: price,
      colorTag: colorTag,
      stockQty: quantity,
      supplier: sourceCompany,
    );
  }
}
