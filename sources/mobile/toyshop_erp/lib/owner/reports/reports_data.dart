// PROTOTYPE DUMMY DATA — replace ReportsRepository.<method>() with the matching
// HTTP endpoint below (see doc §9, docs/mobile/owner/reports/reports.md):
//   salesSummary(period)                    → GET /reports/sales-summary?period=today|week|month
//   topProducts()/topStaff()/categoryMix()  → prototype breakdowns of the same
//                                              sales-summary window (mobile-only extras)
//   agingStock(threshold)                   → GET /stock/aging?threshold_days=30|60|90
//   lowStock()                              → GET /stock/low
//   gstSnapshot()                           → GET /gst/summary?period=YYYY-MM
//
// Response shapes mirror the fields documented in §9 wherever the mobile doc
// defines them; the top-products/top-staff/category-mix breakdowns are a
// clickable-prototype extension (the doc keeps those on the web dashboard).

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/core.dart';
import '../../core/api_config.dart';
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

/// Sales report period — drives the segmented control at the top of Reports.
enum ReportPeriod {
  day('Day', 'today'),
  week('Week', 'week'),
  month('Month', 'month');

  const ReportPeriod(this.label, this.apiValue);

  /// Segmented-control label.
  final String label;

  /// `period=` query value used by `/reports/sales-summary`.
  final String apiValue;
}

/// Aging-stock threshold bucket (doc §5 row 5: 30 | 60 | 90 days).
enum AgingThreshold {
  d30(30),
  d60(60),
  d90(90);

  const AgingThreshold(this.days);
  final int days;

  String get label => '$days d';
}

/// One point on the sales-trend bar chart, e.g. a day-of-week or hour bucket.
class SalesPoint {
  const SalesPoint({required this.label, required this.value});
  final String label;
  final double value;
}

/// `GET /reports/sales-summary` response shape (doc §9) plus the chart series
/// used to draw the bars.
class SalesSummary {
  const SalesSummary({
    required this.salesTotal,
    required this.profitEstimate,
    required this.itemsSold,
    required this.salesCount,
    required this.trendPct,
    required this.series,
  });

  final double salesTotal;
  final double profitEstimate;
  final int itemsSold;
  final int salesCount;

  /// vs the previous equivalent period; +ve up, -ve down.
  final double trendPct;
  final List<SalesPoint> series;

  double get avgSale => salesCount == 0 ? 0 : salesTotal / salesCount;
  int get marginPct => salesTotal == 0 ? 0 : ((profitEstimate / salesTotal) * 100).round();
}

/// A best-seller row for the "Top products" list.
class TopProductStat {
  const TopProductStat({required this.product, required this.unitsSold, required this.revenue});
  final Product product;
  final int unitsSold;
  final double revenue;
}

/// A best-seller row for the "Top staff" leaderboard.
class TopStaffStat {
  const TopStaffStat({
    required this.name,
    required this.initials,
    required this.color,
    required this.revenue,
    required this.unitsSold,
    required this.salesCount,
  });
  final String name;
  final String initials;
  final Color color;
  final double revenue;
  final int unitsSold;
  final int salesCount;
}

/// One slice of the category-mix breakdown bar.
class CategoryShare {
  const CategoryShare({required this.category, required this.color, required this.value});
  final String category;
  final Color color;
  final double value;
}

/// `GET /stock/aging` row — product, days sitting, tied-up value.
class AgingStockItem {
  const AgingStockItem({
    required this.product,
    required this.daysInStock,
    required this.tiedValue,
  });
  final Product product;
  final int daysInStock;
  final double tiedValue;
}

/// `GET /stock/low` row — on-hand vs reorder threshold; [oversold] flags
/// on-hand < 0 after reconciliation (doc §5 note) distinctly.
class LowStockItem {
  const LowStockItem({
    required this.product,
    required this.onHand,
    required this.reorderThreshold,
    this.oversold = false,
  });
  final Product product;
  final int onHand;
  final int reorderThreshold;
  final bool oversold;
}

/// `GET /gst/summary` row — per active GSTIN, for the current period.
class GstSnapshotRow {
  const GstSnapshotRow({
    required this.gstin,
    required this.outputGst,
    required this.itc,
    required this.netPayable,
    required this.itcRiskCount,
  });
  final String gstin;
  final double outputGst;
  final double itc;
  final double netPayable;

  /// Purchases counted toward [itc] but missing a `supplier_gstin` (ITC-risk).
  final int itcRiskCount;
}

/// Freshness stamp shown in the app bar subtitle ("updated Xago").
final DateTime kReportsAsOf = DateTime(2026, 7, 3, 19, 44);

class ReportsRepository {
  const ReportsRepository();

  Future<Map<String, String>> _headers() async {
    final token = await StorageService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<SalesSummary> salesSummary(ReportPeriod period, {String? branchId}) async {
    final uri = Uri.parse('${ApiConfig.reportsSalesSummary}?period=${period.apiValue}');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) throw Exception('Failed to load sales summary');
    
    final data = jsonDecode(res.body)['data'];
    return SalesSummary(
      salesTotal: (data['salesTotal'] as num?)?.toDouble() ?? 0.0,
      profitEstimate: (data['profitEstimate'] as num?)?.toDouble() ?? 0.0,
      itemsSold: (data['itemsSold'] as num?)?.toInt() ?? 0,
      salesCount: (data['salesCount'] as num?)?.toInt() ?? 0,
      trendPct: (data['trendPct'] as num?)?.toDouble() ?? 0.0,
      series: (data['series'] as List? ?? []).map((s) => SalesPoint(
        label: s['label'],
        value: (s['value'] as num?)?.toDouble() ?? 0.0,
      )).toList(),
    );
  }

  Future<List<TopProductStat>> topProducts(ReportPeriod period) async {
    final uri = Uri.parse('${ApiConfig.reportsTopProducts}?period=${period.apiValue}');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) return _topProductsByPeriod[period] ?? [];
    
    final List data = jsonDecode(res.body)['data'] ?? [];
    return data.map((item) => TopProductStat(
      product: Product(
        id: item['id'].toString(),
        name: item['name'],
        category: item['category'],
        price: (item['price'] as num?)?.toDouble() ?? 0.0,
        stockQty: (item['stock'] as num?)?.toInt() ?? 0,
        image: _formatImageUrl(item['image']),
        colorTag: const Color(0xFF2563EB), // Default color
      ),
      unitsSold: (item['unitsSold'] as num?)?.toInt() ?? 0,
      revenue: (item['revenue'] as num?)?.toDouble() ?? 0.0,
    )).toList();
  }

  Future<List<TopStaffStat>> topStaff(ReportPeriod period) async {
    final uri = Uri.parse('${ApiConfig.reportsTopStaff}?period=${period.apiValue}');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) return _topStaffByPeriod[period] ?? [];
    
    final List data = jsonDecode(res.body)['data'] ?? [];
    return data.map((item) => TopStaffStat(
      name: item['name'],
      initials: item['initials'],
      color: Colors.blue,
      revenue: (item['revenue'] as num?)?.toDouble() ?? 0.0,
      unitsSold: (item['unitsSold'] as num?)?.toInt() ?? 0,
      salesCount: (item['salesCount'] as num?)?.toInt() ?? 0,
    )).toList();
  }

  Future<List<CategoryShare>> categoryMix(ReportPeriod period) async {
    final uri = Uri.parse('${ApiConfig.reportsCategoryMix}?period=${period.apiValue}');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) return _categoryByPeriod[period] ?? [];
    
    final List data = jsonDecode(res.body)['data'] ?? [];
    return data.map((item) => CategoryShare(
      category: item['category'],
      color: Colors.primaries[data.indexOf(item) % Colors.primaries.length],
      value: (item['value'] as num?)?.toDouble() ?? 0.0,
    )).toList();
  }

  Future<List<AgingStockItem>> agingStock(AgingThreshold threshold) async {
    final uri = Uri.parse('${ApiConfig.reportsAgingStock}?threshold_days=${threshold.days}');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) return [];
    
    final List data = jsonDecode(res.body)['data'] ?? [];
    return data.map((item) => AgingStockItem(
      product: Product(
        id: item['id'].toString(),
        name: item['name'],
        category: item['category'],
        price: (item['price'] as num?)?.toDouble() ?? 0.0,
        stockQty: (item['stock'] as num?)?.toInt() ?? 0,
        colorTag: const Color(0xFF2563EB),
      ),
      daysInStock: (item['daysInStock'] as num?)?.toInt() ?? 0,
      tiedValue: (item['tiedValue'] as num?)?.toDouble() ?? 0.0,
    )).toList();
  }

  Future<List<LowStockItem>> lowStock() async {
    final uri = Uri.parse(ApiConfig.reportsLowStock);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) return [];
    
    final List data = jsonDecode(res.body)['data'] ?? [];
    return data.map((item) => LowStockItem(
      product: Product(
        id: item['id'].toString(),
        name: item['name'],
        category: item['category'],
        price: (item['price'] as num?)?.toDouble() ?? 0.0,
        stockQty: (item['stock'] as num?)?.toInt() ?? 0,
        colorTag: const Color(0xFF2563EB),
      ),
      onHand: (item['onHand'] as num?)?.toInt() ?? 0,
      reorderThreshold: (item['reorderThreshold'] as num?)?.toInt() ?? 0,
      oversold: item['oversold'] ?? false,
    )).toList();
  }

  Future<List<GstSnapshotRow>> gstSnapshot() async {
    final uri = Uri.parse(ApiConfig.reportsGstSnapshot);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) return [];
    
    final List data = jsonDecode(res.body)['data'] ?? [];
    return data.map((item) => GstSnapshotRow(
      gstin: item['gstin'],
      outputGst: (item['outputGst'] as num?)?.toDouble() ?? 0.0,
      itc: (item['itc'] as num?)?.toDouble() ?? 0.0,
      netPayable: (item['netPayable'] as num?)?.toDouble() ?? 0.0,
      itcRiskCount: (item['itcRiskCount'] as num?)?.toInt() ?? 0,
    )).toList();
  }
}

// ---------------------------------------------------------------------------
// Demo datasets
// ---------------------------------------------------------------------------

const _salesByPeriod = {
  ReportPeriod.day: SalesSummary(
    salesTotal: 92400,
    profitEstimate: 23100,
    itemsSold: 58,
    salesCount: 27,
    trendPct: 9,
    series: [
      SalesPoint(label: '10a', value: 8200),
      SalesPoint(label: '12p', value: 14300),
      SalesPoint(label: '2p', value: 11800),
      SalesPoint(label: '4p', value: 19600),
      SalesPoint(label: '6p', value: 21500),
      SalesPoint(label: '8p', value: 17000),
    ],
  ),
  ReportPeriod.week: SalesSummary(
    salesTotal: 512300,
    profitEstimate: 128075,
    itemsSold: 392,
    salesCount: 168,
    trendPct: 6,
    series: [
      SalesPoint(label: 'Mon', value: 58200),
      SalesPoint(label: 'Tue', value: 61400),
      SalesPoint(label: 'Wed', value: 55700),
      SalesPoint(label: 'Thu', value: 68900),
      SalesPoint(label: 'Fri', value: 74300),
      SalesPoint(label: 'Sat', value: 98800),
      SalesPoint(label: 'Sun', value: 95000),
    ],
  ),
  ReportPeriod.month: SalesSummary(
    salesTotal: 2145600,
    profitEstimate: 536400,
    itemsSold: 1640,
    salesCount: 705,
    trendPct: -3,
    series: [
      SalesPoint(label: 'W1', value: 410000),
      SalesPoint(label: 'W2', value: 452000),
      SalesPoint(label: 'W3', value: 398600),
      SalesPoint(label: 'W4', value: 480000),
      SalesPoint(label: 'W5', value: 405000),
    ],
  ),
};

const _topProductsByPeriod = {
  ReportPeriod.day: [
    TopProductStat(
      product: Product(
        id: 'rp01', name: 'Rideon Jeep Red', category: 'Ride-ons', price: 4200,
        colorTag: Color(0xFFDC2626), icon: Icons.directions_car_rounded,
        stock: StockState.healthy, stockQty: 8,
      ),
      unitsSold: 6, revenue: 25200,
    ),
    TopProductStat(
      product: Product(
        id: 'rp03', name: 'Baby Bike Pink', category: 'Bikes', price: 2100,
        colorTag: Color(0xFFDB2777), icon: Icons.pedal_bike_rounded,
        stock: StockState.low, stockQty: 4,
      ),
      unitsSold: 8, revenue: 16800,
    ),
    TopProductStat(
      product: Product(
        id: 'rp02', name: 'RC Racer Blue', category: 'Cars', price: 1350,
        colorTag: Color(0xFF2563EB), icon: Icons.toys_rounded,
        stock: StockState.healthy, stockQty: 30,
      ),
      unitsSold: 10, revenue: 13500,
    ),
    TopProductStat(
      product: Product(
        id: 'rp04', name: 'Kitchen Play Set', category: 'Play sets', price: 1750,
        colorTag: Color(0xFF16A34A), icon: Icons.kitchen_rounded,
        stock: StockState.healthy, stockQty: 16,
      ),
      unitsSold: 6, revenue: 10500,
    ),
    TopProductStat(
      product: Product(
        id: 'rp05', name: 'Robot Walker', category: 'Cars', price: 999,
        colorTag: Color(0xFF7C3AED), icon: Icons.smart_toy_rounded,
        stock: StockState.healthy, stockQty: 22,
      ),
      unitsSold: 9, revenue: 8991,
    ),
  ],
  ReportPeriod.week: [
    TopProductStat(
      product: Product(
        id: 'rp01', name: 'Rideon Jeep Red', category: 'Ride-ons', price: 4200,
        colorTag: Color(0xFFDC2626), icon: Icons.directions_car_rounded,
        stock: StockState.healthy, stockQty: 8,
      ),
      unitsSold: 34, revenue: 142800,
    ),
    TopProductStat(
      product: Product(
        id: 'rp03', name: 'Baby Bike Pink', category: 'Bikes', price: 2100,
        colorTag: Color(0xFFDB2777), icon: Icons.pedal_bike_rounded,
        stock: StockState.low, stockQty: 4,
      ),
      unitsSold: 46, revenue: 96600,
    ),
    TopProductStat(
      product: Product(
        id: 'rp02', name: 'RC Racer Blue', category: 'Cars', price: 1350,
        colorTag: Color(0xFF2563EB), icon: Icons.toys_rounded,
        stock: StockState.healthy, stockQty: 30,
      ),
      unitsSold: 58, revenue: 78300,
    ),
    TopProductStat(
      product: Product(
        id: 'rp05', name: 'Robot Walker', category: 'Cars', price: 999,
        colorTag: Color(0xFF7C3AED), icon: Icons.smart_toy_rounded,
        stock: StockState.healthy, stockQty: 22,
      ),
      unitsSold: 51, revenue: 50949,
    ),
    TopProductStat(
      product: Product(
        id: 'rp04', name: 'Kitchen Play Set', category: 'Play sets', price: 1750,
        colorTag: Color(0xFF16A34A), icon: Icons.kitchen_rounded,
        stock: StockState.healthy, stockQty: 16,
      ),
      unitsSold: 30, revenue: 52500,
    ),
  ],
  ReportPeriod.month: [
    TopProductStat(
      product: Product(
        id: 'rp01', name: 'Rideon Jeep Red', category: 'Ride-ons', price: 4200,
        colorTag: Color(0xFFDC2626), icon: Icons.directions_car_rounded,
        stock: StockState.healthy, stockQty: 8,
      ),
      unitsSold: 140, revenue: 588000,
    ),
    TopProductStat(
      product: Product(
        id: 'rp03', name: 'Baby Bike Pink', category: 'Bikes', price: 2100,
        colorTag: Color(0xFFDB2777), icon: Icons.pedal_bike_rounded,
        stock: StockState.low, stockQty: 4,
      ),
      unitsSold: 190, revenue: 399000,
    ),
    TopProductStat(
      product: Product(
        id: 'rp02', name: 'RC Racer Blue', category: 'Cars', price: 1350,
        colorTag: Color(0xFF2563EB), icon: Icons.toys_rounded,
        stock: StockState.healthy, stockQty: 30,
      ),
      unitsSold: 240, revenue: 324000,
    ),
    TopProductStat(
      product: Product(
        id: 'rp05', name: 'Robot Walker', category: 'Cars', price: 999,
        colorTag: Color(0xFF7C3AED), icon: Icons.smart_toy_rounded,
        stock: StockState.healthy, stockQty: 22,
      ),
      unitsSold: 205, revenue: 204795,
    ),
    TopProductStat(
      product: Product(
        id: 'rp06', name: 'Wooden Puzzle Cube', category: 'Puzzles & Games', price: 449,
        colorTag: Color(0xFF0891B2), icon: Icons.extension_rounded,
        stock: StockState.healthy, stockQty: 64,
      ),
      unitsSold: 410, revenue: 184090,
    ),
  ],
};

const _topStaffByPeriod = {
  ReportPeriod.day: [
    TopStaffStat(
      name: 'Ravi Kumar', initials: 'RK', color: Color(0xFF2563EB),
      revenue: 28300, unitsSold: 19, salesCount: 9,
    ),
    TopStaffStat(
      name: 'Meena Rani', initials: 'MR', color: Color(0xFFDB2777),
      revenue: 22100, unitsSold: 15, salesCount: 7,
    ),
    TopStaffStat(
      name: 'Anbu Selvan', initials: 'AS', color: Color(0xFF16A34A),
      revenue: 18900, unitsSold: 13, salesCount: 6,
    ),
    TopStaffStat(
      name: 'Karan Das', initials: 'KD', color: Color(0xFFD97706),
      revenue: 13800, unitsSold: 9, salesCount: 4,
    ),
    TopStaffStat(
      name: 'Suraj Pillai', initials: 'SP', color: Color(0xFF7C3AED),
      revenue: 9300, unitsSold: 6, salesCount: 3,
    ),
  ],
  ReportPeriod.week: [
    TopStaffStat(
      name: 'Meena Rani', initials: 'MR', color: Color(0xFFDB2777),
      revenue: 148700, unitsSold: 112, salesCount: 48,
    ),
    TopStaffStat(
      name: 'Ravi Kumar', initials: 'RK', color: Color(0xFF2563EB),
      revenue: 132400, unitsSold: 98, salesCount: 43,
    ),
    TopStaffStat(
      name: 'Anbu Selvan', initials: 'AS', color: Color(0xFF16A34A),
      revenue: 105600, unitsSold: 79, salesCount: 35,
    ),
    TopStaffStat(
      name: 'Karan Das', initials: 'KD', color: Color(0xFFD97706),
      revenue: 78900, unitsSold: 58, salesCount: 25,
    ),
    TopStaffStat(
      name: 'Suraj Pillai', initials: 'SP', color: Color(0xFF7C3AED),
      revenue: 46700, unitsSold: 45, salesCount: 17,
    ),
  ],
  ReportPeriod.month: [
    TopStaffStat(
      name: 'Ravi Kumar', initials: 'RK', color: Color(0xFF2563EB),
      revenue: 612000, unitsSold: 468, salesCount: 201,
    ),
    TopStaffStat(
      name: 'Meena Rani', initials: 'MR', color: Color(0xFFDB2777),
      revenue: 574400, unitsSold: 440, salesCount: 189,
    ),
    TopStaffStat(
      name: 'Anbu Selvan', initials: 'AS', color: Color(0xFF16A34A),
      revenue: 468200, unitsSold: 358, salesCount: 156,
    ),
    TopStaffStat(
      name: 'Karan Das', initials: 'KD', color: Color(0xFFD97706),
      revenue: 312600, unitsSold: 239, salesCount: 104,
    ),
    TopStaffStat(
      name: 'Suraj Pillai', initials: 'SP', color: Color(0xFF7C3AED),
      revenue: 178400, unitsSold: 135, salesCount: 55,
    ),
  ],
};

const _categoryByPeriod = {
  ReportPeriod.day: [
    CategoryShare(category: 'Ride-ons', color: Color(0xFFDC2626), value: 25200),
    CategoryShare(category: 'Cars', color: Color(0xFF2563EB), value: 22491),
    CategoryShare(category: 'Bikes', color: Color(0xFFDB2777), value: 16800),
    CategoryShare(category: 'Play sets', color: Color(0xFF16A34A), value: 10500),
    CategoryShare(category: 'Puzzles & Games', color: Color(0xFF0891B2), value: 17409),
  ],
  ReportPeriod.week: [
    CategoryShare(category: 'Ride-ons', color: Color(0xFFDC2626), value: 142800),
    CategoryShare(category: 'Cars', color: Color(0xFF2563EB), value: 129249),
    CategoryShare(category: 'Bikes', color: Color(0xFFDB2777), value: 96600),
    CategoryShare(category: 'Play sets', color: Color(0xFF16A34A), value: 52500),
    CategoryShare(category: 'Puzzles & Games', color: Color(0xFF0891B2), value: 91151),
  ],
  ReportPeriod.month: [
    CategoryShare(category: 'Ride-ons', color: Color(0xFFDC2626), value: 588000),
    CategoryShare(category: 'Cars', color: Color(0xFF2563EB), value: 528795),
    CategoryShare(category: 'Bikes', color: Color(0xFFDB2777), value: 399000),
    CategoryShare(category: 'Play sets', color: Color(0xFF16A34A), value: 445715),
    CategoryShare(category: 'Puzzles & Games', color: Color(0xFF0891B2), value: 184090),
  ],
};

/// 12 items so 30/60/90-day thresholds each reslice to a different count
/// (12 / 7 / 2) — matches the owner dashboard's aging-stock tile (12).
const _agingDemo = [
  AgingStockItem(
    product: Product(
      id: 'ag01', name: 'Rainbow Stacking Rings', category: 'Educational', price: 349,
      colorTag: Color(0xFF7C3AED), icon: Icons.category_rounded,
      stock: StockState.aging, stockQty: 1,
    ),
    daysInStock: 30, tiedValue: 349,
  ),
  AgingStockItem(
    product: Product(
      id: 'ag02', name: 'Wooden Alphabet Train', category: 'Educational', price: 899,
      colorTag: Color(0xFF78350F), icon: Icons.school_rounded,
      stock: StockState.aging, stockQty: 2,
    ),
    daysInStock: 36, tiedValue: 1798,
  ),
  AgingStockItem(
    product: Product(
      id: 'ag03', name: '100-pc Jigsaw Puzzle', category: 'Puzzles & Games', price: 299,
      colorTag: Color(0xFFD97706), icon: Icons.extension_rounded,
      stock: StockState.aging, stockQty: 3,
    ),
    daysInStock: 42, tiedValue: 897,
  ),
  AgingStockItem(
    product: Product(
      id: 'ag04', name: 'RC Speed Buggy', category: 'Vehicles', price: 1599,
      colorTag: Color(0xFF0891B2), icon: Icons.directions_car_rounded,
      stock: StockState.aging, stockQty: 2,
    ),
    daysInStock: 48, tiedValue: 3198,
  ),
  AgingStockItem(
    product: Product(
      id: 'ag05', name: 'Bella Baby Doll', category: 'Dolls & Soft Toys', price: 549,
      colorTag: Color(0xFFDB2777), icon: Icons.toys_rounded,
      stock: StockState.aging, stockQty: 3,
    ),
    daysInStock: 55, tiedValue: 1647,
  ),
  AgingStockItem(
    product: Product(
      id: 'ag06', name: 'Soft Plush Bear', category: 'Dolls & Soft Toys', price: 449,
      colorTag: Color(0xFFD97706), icon: Icons.pets_rounded,
      stock: StockState.aging, stockQty: 4,
    ),
    daysInStock: 60, tiedValue: 1796,
  ),
  AgingStockItem(
    product: Product(
      id: 'ag07', name: 'RC Monster Truck', category: 'Vehicles', price: 1899,
      colorTag: Color(0xFF2563EB), icon: Icons.directions_car_rounded,
      stock: StockState.aging, stockQty: 2,
    ),
    daysInStock: 66, tiedValue: 3798,
  ),
  AgingStockItem(
    product: Product(
      id: 'ag08', name: 'Blue Jet Bike', category: 'Bikes', price: 4299,
      colorTag: Color(0xFF2563EB), icon: Icons.pedal_bike_rounded,
      stock: StockState.aging, stockQty: 1,
    ),
    daysInStock: 72, tiedValue: 4299,
  ),
  AgingStockItem(
    product: Product(
      id: 'ag09', name: 'Wooden Doctor Play Set', category: 'Play sets', price: 1299,
      colorTag: Color(0xFF16A34A), icon: Icons.category_rounded,
      stock: StockState.aging, stockQty: 2,
    ),
    daysInStock: 81, tiedValue: 2598,
  ),
  AgingStockItem(
    product: Product(
      id: 'ag10', name: 'Twin-Seat Pedal Car', category: 'Ride-ons', price: 1499,
      colorTag: Color(0xFFDC2626), icon: Icons.directions_car_rounded,
      stock: StockState.aging, stockQty: 2,
    ),
    daysInStock: 88, tiedValue: 2998,
  ),
  AgingStockItem(
    product: Product(
      id: 'ag11', name: 'Play Set A', category: 'Play sets', price: 899,
      colorTag: Color(0xFF16A34A), icon: Icons.category_rounded,
      stock: StockState.aging, stockQty: 1,
    ),
    daysInStock: 95, tiedValue: 899,
  ),
  AgingStockItem(
    product: Product(
      id: 'ag12', name: 'Vintage Rocking Horse', category: 'Ride-ons', price: 2400,
      colorTag: Color(0xFFD97706), icon: Icons.pets_rounded,
      stock: StockState.aging, stockQty: 1,
    ),
    daysInStock: 118, tiedValue: 2400,
  ),
];

/// 7 items — matches the owner dashboard's low-stock tile (7); one oversold
/// (on-hand < 0) so it can be flagged distinctly per doc §5/§8.
const _lowStockDemo = [
  LowStockItem(
    product: Product(
      id: 'ls01', name: 'Red Racer Car', category: 'Cars', price: 799,
      colorTag: Color(0xFFDC2626), icon: Icons.directions_car_rounded,
      stock: StockState.low, stockQty: 2,
    ),
    onHand: 2, reorderThreshold: 3,
  ),
  LowStockItem(
    product: Product(
      id: 'ls02', name: 'Mini Bike', category: 'Bikes', price: 1699,
      colorTag: Color(0xFF2563EB), icon: Icons.pedal_bike_rounded,
      stock: StockState.low, stockQty: 1,
    ),
    onHand: 1, reorderThreshold: 3,
  ),
  LowStockItem(
    product: Product(
      id: 'ls03', name: 'Building Blocks Set', category: 'Educational', price: 649,
      colorTag: Color(0xFFD97706), icon: Icons.construction_rounded,
      stock: StockState.low, stockQty: 3,
    ),
    onHand: 3, reorderThreshold: 5,
  ),
  LowStockItem(
    product: Product(
      id: 'ls04', name: 'Princess Castle Playhouse', category: 'Play sets', price: 2499,
      colorTag: Color(0xFFDB2777), icon: Icons.house_rounded,
      stock: StockState.low, stockQty: 1,
    ),
    onHand: 1, reorderThreshold: 4,
  ),
  LowStockItem(
    product: Product(
      id: 'ls05', name: 'Toy Xylophone', category: 'Educational', price: 399,
      colorTag: Color(0xFF16A34A), icon: Icons.toys_rounded,
      stock: StockState.low, stockQty: 2,
    ),
    onHand: 2, reorderThreshold: 4,
  ),
  LowStockItem(
    product: Product(
      id: 'ls06', name: 'Superhero Action Figure Set', category: 'Action Figures', price: 599,
      colorTag: Color(0xFF2563EB), icon: Icons.shield_rounded,
      // stockQty deliberately non-zero (-1, matching onHand) so ProductTile's
      // built-in "out of stock ⇒ tile disabled" rule doesn't block the tap —
      // the owner still needs to reach this row to raise a purchase order.
      stock: StockState.out, stockQty: -1,
    ),
    onHand: -1, reorderThreshold: 3, oversold: true,
  ),
  LowStockItem(
    product: Product(
      id: 'ls07', name: 'Mini Soccer Goal Set', category: 'Sports & Outdoor', price: 899,
      colorTag: Color(0xFF0891B2), icon: Icons.sports_soccer_rounded,
      stock: StockState.low, stockQty: 1,
    ),
    onHand: 1, reorderThreshold: 2,
  ),
];

const _gstDemo = [
  GstSnapshotRow(
    gstin: '27ABCDE1234F1Z5',
    outputGst: 18940,
    itc: 3888,
    netPayable: 15052,
    itcRiskCount: 1,
  ),
  GstSnapshotRow(
    gstin: '29XYZAB5678K1Z0',
    outputGst: 4120,
    itc: 600,
    netPayable: 3520,
    itcRiskCount: 0,
  ),
];
