import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/api_config.dart';
import '../../core/utils/storage_service.dart';

class Sale {
  final int id;
  final String invoiceNumber;
  final double totalAmount;
  final double taxableAmount;
  final double cgst;
  final double sgst;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;
  final String? staffName;
  final List<SaleItem> items;

  Sale({
    required this.id,
    required this.invoiceNumber,
    required this.totalAmount,
    required this.taxableAmount,
    required this.cgst,
    required this.sgst,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.staffName,
    required this.items,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List? ?? [];
    List<SaleItem> parsedItems =
        itemsList.map((i) => SaleItem.fromJson(i)).toList();

    return Sale(
      id: json['id'],
      invoiceNumber: json['invoiceNumber'] ?? '',
      totalAmount: double.tryParse(json['totalAmount']?.toString() ?? '0') ?? 0.0,
      taxableAmount: double.tryParse(json['taxableAmount']?.toString() ?? '0') ?? 0.0,
      cgst: double.tryParse(json['cgst']?.toString() ?? '0') ?? 0.0,
      sgst: double.tryParse(json['sgst']?.toString() ?? '0') ?? 0.0,
      paymentMethod: json['paymentMethod'] ?? '',
      status: json['status'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      staffName: json['user']?['name'],
      items: parsedItems,
    );
  }
}

class SaleItem {
  final int quantity;
  final double unitPrice;
  final double subTotal;
  final String productName;

  SaleItem({
    required this.quantity,
    required this.unitPrice,
    required this.subTotal,
    required this.productName,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      quantity: json['quantity'] ?? 0,
      unitPrice: double.tryParse(json['unitPrice']?.toString() ?? '0') ?? 0.0,
      subTotal: double.tryParse(json['subTotal']?.toString() ?? '0') ?? 0.0,
      productName: json['product']?['name'] ?? 'Unknown Product',
    );
  }
}

class SalesService {
  Future<List<Sale>> fetchSales() async {
    final token = await StorageService.getAccessToken();
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.sales),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['data'] ?? [];
        return items.map((e) => Sale.fromJson(e)).toList();
      } else {
        throw Exception('API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e, stack) {
      throw Exception('Error details: $e');
    }
  }
}
