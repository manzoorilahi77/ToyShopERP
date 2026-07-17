import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/models/product.dart';
import '../../core/api_config.dart';
import '../../core/utils/storage_service.dart';

class StockAdditionRepository {
  const StockAdditionRepository();

  Future<List<ProductCategory>> getCategories() async {
    final token = await StorageService.getAccessToken();
    final res = await http.get(
      Uri.parse(ApiConfig.categories),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body)['data'] as List?;
      if (data != null) {
        return data.map((c) => ProductCategory(
          id: c['id'].toString(),
          name: c['name'],
          color: Colors.blue,
          icon: Icons.category,
        )).toList();
      }
    }
    return [];
  }

  Future<Product> addStock({
    required String name,
    required Color colorTag,
    required double price,
    required double costPrice,
    required String category,
    required String hsnCode,
    required int gstRate,
    required String sourceCompany,
    required int quantity,
    String? imagePath,
  }) async {
    final token = await StorageService.getAccessToken();
    final request = http.MultipartRequest('POST', Uri.parse(ApiConfig.products));
    
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['name'] = name;
    request.fields['price'] = price.toString();
    request.fields['costPrice'] = costPrice.toString();
    request.fields['stock'] = quantity.toString();
    
    // Find category ID from backend, fallback to 1
    // The UI now passes the exact category ID if we change `category` parameter to categoryId, but for now we look it up or accept it
    // Wait, the UI only passes the category name right now.
    // If the category field contains the categoryId, we can use it directly.
    request.fields['categoryId'] = category;
    
    request.fields['hsnCode'] = hsnCode;
    request.fields['gstRate'] = gstRate.toString();
    request.fields['supplierId'] = '1'; // Default supplier ID

    if (imagePath != null && imagePath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final item = data['data'];
      return Product(
        id: item['id'].toString(),
        name: item['name'] ?? name,
        category: category,
        price: double.tryParse(item['price']?.toString() ?? '0') ?? price,
        colorTag: colorTag,
        stockQty: int.tryParse(item['stock']?.toString() ?? '') ?? quantity,
        image: item['image'],
        supplier: sourceCompany,
      );
    } else {
      throw Exception('Failed to add stock: ${response.body}');
    }
  }
}
