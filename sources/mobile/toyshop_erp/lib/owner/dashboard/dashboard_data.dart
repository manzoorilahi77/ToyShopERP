import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/api_config.dart';
import '../../core/utils/storage_service.dart';

/// PROTOTYPE DUMMY DATA — Owner Dashboard Home.
///
/// To wire the backend, replace [OwnerDashboardRepository.load] with the single
/// aggregate `GET /reports/owner-dashboard` from
/// docs/mobile/owner/dashboard/dashboard-home.md §9. The [OwnerDashboardData]
/// fields map 1:1 to that JSON payload.

class TopPerformer {
  const TopPerformer({
    required this.name,
    required this.revenue,
    required this.units,
    required this.color,
    required this.initials,
  });
  final String name;
  final double revenue;
  final int units;
  final Color color;
  final String initials;
}

class OwnerDashboardData {
  const OwnerDashboardData({
    required this.date,
    required this.asOf,
    required this.salesTotal,
    required this.purchasesTotal,
    required this.salesTrendPct,
    required this.ordersTrendPct,
    required this.purchasesTrendPct,
    required this.alertsTrendPct,
    required this.profitEstimate,
    required this.marginPct,
    required this.onlineRevenue,
    required this.offlineRevenue,
    required this.salesCount,
    required this.gstLiability,
    required this.gstPeriod,
    required this.topPerformer,
    required this.lowStockCount,
    required this.agingStockCount,
    required this.unreadNotifications,
    required this.pendingApprovals,
  });

  final DateTime date;
  final DateTime asOf;
  final double salesTotal;
  final double purchasesTotal;
  final double salesTrendPct;
  final double ordersTrendPct;
  final double purchasesTrendPct;
  final double alertsTrendPct;
  final double profitEstimate;
  final int marginPct;
  final double onlineRevenue;
  final double offlineRevenue;
  final int salesCount;
  final double gstLiability;
  final String gstPeriod;
  final TopPerformer topPerformer;
  final int lowStockCount;
  final int agingStockCount;
  final int unreadNotifications;
  final int pendingApprovals;
}

class OwnerDashboardRepository {
  const OwnerDashboardRepository();

  Future<OwnerDashboardData> load({String? branchId, String? period}) async {
    // Generate some deterministic variation based on branchId
    final isFiltered = branchId != null;
    final factor = isFiltered ? (branchId.hashCode.abs() % 50 + 50) / 100.0 : 1.0;
    
    double backendSalesTotal = _demo.salesTotal * factor;
    int backendSalesCount = (_demo.salesCount * factor).round();
    double backendOnlineRevenue = 0.0;
    double backendOfflineRevenue = 0.0;
    int backendLowStockCount = isFiltered ? 2 : _demo.lowStockCount;
    int backendAgingStockCount = isFiltered ? 5 : _demo.agingStockCount;
    int backendUnreadNotifications = _demo.unreadNotifications;
    int backendPendingApprovals = _demo.pendingApprovals;
    double backendProfitEstimate = _demo.profitEstimate * factor;
    TopPerformer backendTopPerformer = _demo.topPerformer;

    double backendPurchasesTotal = 0.0;
    try {
      final token = await StorageService.getAccessToken();
      var uri = Uri.parse(ApiConfig.dashboardOwner);
      var queryParams = <String, String>{};
      if (branchId != null) queryParams['branchId'] = branchId;
      if (period != null) queryParams['period'] = period;

      if (queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final stats = data['data'];
          backendSalesTotal = double.tryParse(stats['todayRevenue']?.toString() ?? '0') ?? 0.0;
          backendSalesCount = int.tryParse(stats['todayOrders']?.toString() ?? '0') ?? 0;
          backendOnlineRevenue = double.tryParse(stats['onlineRevenue']?.toString() ?? '0') ?? 0.0;
          backendOfflineRevenue = double.tryParse(stats['offlineRevenue']?.toString() ?? '0') ?? 0.0;
          backendLowStockCount = int.tryParse(stats['lowStockProducts']?.toString() ?? '0') ?? 0;
          backendPurchasesTotal = double.tryParse(stats['todayPurchases']?.toString() ?? '0') ?? 0.0;
          backendProfitEstimate = double.tryParse(stats['profitEstimate']?.toString() ?? '0') ?? 0.0;
          
          backendAgingStockCount = int.tryParse(stats['agingStockCount']?.toString() ?? '0') ?? backendAgingStockCount;
          backendUnreadNotifications = int.tryParse(stats['unreadNotifications']?.toString() ?? '0') ?? backendUnreadNotifications;
          backendPendingApprovals = int.tryParse(stats['pendingApprovals']?.toString() ?? '0') ?? backendPendingApprovals;

          if (stats['topPerformer'] != null) {
            final tp = stats['topPerformer'];
            backendTopPerformer = TopPerformer(
              name: tp['name']?.toString() ?? 'Unknown',
              revenue: double.tryParse(tp['revenue']?.toString() ?? '0') ?? 0.0,
              units: int.tryParse(tp['units']?.toString() ?? '0') ?? 0,
              color: Color(int.tryParse(tp['color']?.replaceAll('#', '0xFF') ?? '0xFF2563EB') ?? 0xFF2563EB),
              initials: tp['initials']?.toString() ?? 'NA',
            );
          }
        }
      } else {
        debugPrint('Dashboard API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading owner dashboard from backend: $e');
    }

    return OwnerDashboardData(
      date: DateTime.now(), // Use current date for realism
      asOf: DateTime.now(),
      salesTotal: backendSalesTotal,
      purchasesTotal: backendPurchasesTotal,
      salesTrendPct: 12.5, // Mocked from UI design
      ordersTrendPct: 8.2, // Mocked from UI design
      purchasesTrendPct: -4.1, // Mocked from UI design
      alertsTrendPct: -2.0, // Mocked from UI design
      profitEstimate: backendProfitEstimate,
      marginPct: _demo.marginPct,
      onlineRevenue: backendOnlineRevenue,
      offlineRevenue: backendOfflineRevenue,
      salesCount: backendSalesCount,
      gstLiability: _demo.gstLiability * factor,
      gstPeriod: _demo.gstPeriod,
      topPerformer: backendTopPerformer,
      lowStockCount: backendLowStockCount,
      agingStockCount: backendAgingStockCount,
      unreadNotifications: backendUnreadNotifications,
      pendingApprovals: backendPendingApprovals,
    );
  }
}

final _demo = OwnerDashboardData(
  date: DateTime(2026, 7, 3),
  asOf: DateTime(2026, 7, 3, 19, 38),
  salesTotal: 6692.99,
  purchasesTotal: 0.0,
  salesTrendPct: 12.5,
  ordersTrendPct: 8.2,
  purchasesTrendPct: -4.1,
  alertsTrendPct: -2.0,
  profitEstimate: 31210,
  marginPct: 25,
  onlineRevenue: 1520.50,
  offlineRevenue: 5172.49,
  salesCount: 7,
  gstLiability: 18940,
  gstPeriod: '2026-07',
  topPerformer: const TopPerformer(
    name: 'Ravi Kumar',
    revenue: 42300,
    units: 23,
    color: Color(0xFF2563EB),
    initials: 'RK',
  ),
  lowStockCount: 0,
  agingStockCount: 12,
  unreadNotifications: 3,
  pendingApprovals: 2,
);
