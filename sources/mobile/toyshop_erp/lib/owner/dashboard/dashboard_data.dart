import 'package:flutter/material.dart';

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
    required this.salesTrendPct,
    required this.profitEstimate,
    required this.marginPct,
    required this.itemsSold,
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
  final double salesTrendPct;
  final double profitEstimate;
  final int marginPct;
  final int itemsSold;
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

  Future<OwnerDashboardData> load() async {
    return _demo;
  }
}

final _demo = OwnerDashboardData(
  date: DateTime(2026, 7, 3),
  asOf: DateTime(2026, 7, 3, 19, 38),
  salesTotal: 124850,
  salesTrendPct: 12,
  profitEstimate: 31210,
  marginPct: 25,
  itemsSold: 86,
  salesCount: 41,
  gstLiability: 18940,
  gstPeriod: '2026-07',
  topPerformer: const TopPerformer(
    name: 'Ravi Kumar',
    revenue: 42300,
    units: 23,
    color: Color(0xFF2563EB),
    initials: 'RK',
  ),
  lowStockCount: 7,
  agingStockCount: 12,
  unreadNotifications: 3,
  pendingApprovals: 2,
);
