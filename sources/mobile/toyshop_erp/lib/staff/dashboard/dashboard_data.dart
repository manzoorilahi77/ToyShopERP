import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/core.dart';
import '../../core/api_config.dart';
import '../../core/utils/storage_service.dart';

/// PROTOTYPE DUMMY DATA — Staff Home / Dashboard.
///
/// To wire the backend, replace [StaffDashboardRepository.load] with the three
/// GETs from docs/mobile/staff/dashboard/dashboard-home.md §9:
///   GET /staff/{id}/dashboard · GET /staff/leaderboard · GET /incentives/progress
/// The shapes below mirror those response fields.

enum DashPeriod { day, week, month }

class PeriodStat {
  const PeriodStat({required this.units, required this.revenue, required this.trendPct});
  final int units;
  final double revenue;
  final double trendPct; // +ve up, -ve down, vs previous period
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.points,
    required this.units,
    required this.movement,
    this.isMe = false,
    required this.color,
    required this.initials,
  });
  final int rank;
  final String name;
  final int points;
  final int units;
  final int movement; // +up / -down / 0 same
  final bool isMe;
  final Color color;
  final String initials;
}

class IncentiveProgress {
  const IncentiveProgress({
    required this.current,
    required this.target,
    required this.rewardLabel,
    required this.unitLabel,
  });
  final int current;
  final int target;
  final String rewardLabel;
  final String unitLabel;

  int get toGo => (target - current).clamp(0, target);
  double get fraction => target == 0 ? 0 : (current / target).clamp(0, 1);
}

class StaffBadge {
  const StaffBadge({required this.label, required this.icon, required this.earned, this.hint});
  final String label;
  final IconData icon;
  final bool earned;
  final String? hint;
}

class StaffDashboardData {
  const StaffDashboardData({
    required this.stats,
    required this.leaderboard,
    required this.incentive,
    required this.badges,
    required this.quickPicks,
    required this.asOf,
  });
  final Map<DashPeriod, PeriodStat> stats;
  final List<LeaderboardEntry> leaderboard;
  final IncentiveProgress incentive;
  final List<StaffBadge> badges;
  final List<Product> quickPicks;
  final DateTime asOf;
}

class StaffDashboardRepository {
  const StaffDashboardRepository();

  Future<StaffDashboardData> load() async {
    try {
      final token = await StorageService.getAccessToken();
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Fetch dashboard stats
      final dashRes = await http.get(Uri.parse(ApiConfig.dashboardStaff), headers: headers);
      var dayUnits = 0;
      var dayRev = 0.0;
      var lifetimeUnits = 0;
      var currentPoints = 0;
      if (dashRes.statusCode == 200) {
        final data = jsonDecode(dashRes.body);
        if (data['success'] == true && data['data'] != null) {
          final stats = data['data'];
          dayUnits = stats['salesToday'] ?? 0;
          dayRev = double.tryParse((stats['revenueToday'] ?? '0').toString()) ?? 0.0;
          lifetimeUnits = stats['lifetimeUnits'] ?? 0;
          currentPoints = stats['points'] ?? 0;
        }
      }

      // Fetch leaderboard
      final lbRes = await http.get(Uri.parse(ApiConfig.usersLeaderboard), headers: headers);
      final leaderboard = <LeaderboardEntry>[];
      if (lbRes.statusCode == 200) {
        final data = jsonDecode(lbRes.body);
        if (data['success'] == true && data['data'] != null) {
          final list = data['data'] as List;
          for (var i = 0; i < list.length; i++) {
            final u = list[i];
            final name = u['name'] ?? 'Unknown';
            leaderboard.add(LeaderboardEntry(
              rank: i + 1,
              name: name,
              points: u['points'] ?? 0,
              units: 0,
              movement: 0,
              isMe: false, // We'll rely on name matching for demo or skip
              color: i == 0 ? const Color(0xFFDB2777) : const Color(0xFF2563EB),
              initials: name.isNotEmpty ? name.substring(0, 2).toUpperCase() : 'NA',
            ));
          }
        }
      }

      // Fetch quick picks
      final prodRes = await http.get(Uri.parse(ApiConfig.products), headers: headers);
      final quickPicks = <Product>[];
      if (prodRes.statusCode == 200) {
        final data = jsonDecode(prodRes.body);
        if (data['success'] == true && data['data'] != null) {
          final list = data['data'] as List;
          for (final p in list) {
            if (p['isFavorite'] == true) {
              quickPicks.add(Product.fromJson(p));
            }
          }
        }
      }

      return StaffDashboardData(
        asOf: DateTime.now(),
        stats: {
          DashPeriod.day: PeriodStat(units: dayUnits, revenue: dayRev, trendPct: 0),
          DashPeriod.week: PeriodStat(units: _demo.stats[DashPeriod.week]!.units, revenue: _demo.stats[DashPeriod.week]!.revenue, trendPct: _demo.stats[DashPeriod.week]!.trendPct),
          DashPeriod.month: PeriodStat(units: lifetimeUnits, revenue: _demo.stats[DashPeriod.month]!.revenue, trendPct: _demo.stats[DashPeriod.month]!.trendPct),
        },
        leaderboard: leaderboard.isEmpty ? _demo.leaderboard : leaderboard,
        incentive: IncentiveProgress(
          current: lifetimeUnits, target: 500, unitLabel: 'units', rewardLabel: '₹1,000 bonus',
        ),
        badges: _demo.badges,
        quickPicks: quickPicks.isEmpty ? _demo.quickPicks : quickPicks,
      );
    } catch (e) {
      debugPrint('Error loading staff dashboard: $e');
      return _demo;
    }
  }
}

final _demo = StaffDashboardData(
  asOf: DateTime(2026, 7, 3, 19, 40),
  stats: const {
    DashPeriod.day: PeriodStat(units: 12, revenue: 48300, trendPct: 18),
    DashPeriod.week: PeriodStat(units: 74, revenue: 289400, trendPct: 9),
    DashPeriod.month: PeriodStat(units: 412, revenue: 1624800, trendPct: -4),
  },
  leaderboard: const [
    LeaderboardEntry(
      rank: 1, name: 'Meena', points: 840, units: 96, movement: 0,
      color: Color(0xFFDB2777), initials: 'MR',
    ),
    LeaderboardEntry(
      rank: 2, name: 'You', points: 812, units: 92, movement: 2, isMe: true,
      color: Color(0xFF2563EB), initials: 'RK',
    ),
    LeaderboardEntry(
      rank: 3, name: 'Karan', points: 790, units: 88, movement: -1,
      color: Color(0xFFD97706), initials: 'KD',
    ),
    LeaderboardEntry(
      rank: 4, name: 'Anbu', points: 705, units: 80, movement: 1,
      color: Color(0xFF16A34A), initials: 'AS',
    ),
    LeaderboardEntry(
      rank: 5, name: 'Suraj', points: 560, units: 63, movement: -2,
      color: Color(0xFF7C3AED), initials: 'SP',
    ),
  ],
  incentive: const IncentiveProgress(
    current: 412, target: 500, unitLabel: 'units', rewardLabel: '₹1,000 bonus',
  ),
  badges: const [
    StaffBadge(label: 'Top Week', icon: Icons.emoji_events_rounded, earned: true),
    StaffBadge(label: '50 Toys', icon: Icons.toys_rounded, earned: true),
    StaffBadge(label: 'Fast Biller', icon: Icons.bolt_rounded, earned: true),
    StaffBadge(label: '100 Toys', icon: Icons.lock_rounded, earned: false, hint: 'Sell 100 in a month'),
    StaffBadge(label: 'Weekend King', icon: Icons.lock_rounded, earned: false, hint: '₹1L in a weekend'),
  ],
  quickPicks: const [
    Product(
      id: 'p01', name: 'Rideon Jeep Red', category: 'Ride-ons', price: 4200,
      colorTag: Color(0xFFDC2626), icon: Icons.directions_car_rounded,
      stock: StockState.healthy, stockQty: 14, isFavorite: true,
    ),
    Product(
      id: 'p02', name: 'RC Racer Blue', category: 'Cars', price: 1350,
      colorTag: Color(0xFF2563EB), icon: Icons.toys_rounded,
      stock: StockState.healthy, stockQty: 40, isFavorite: true,
    ),
    Product(
      id: 'p03', name: 'Baby Bike Pink', category: 'Bikes', price: 2100,
      colorTag: Color(0xFFDB2777), icon: Icons.pedal_bike_rounded,
      stock: StockState.low, stockQty: 4,
    ),
    Product(
      id: 'p04', name: 'Kitchen Play Set', category: 'Play sets', price: 1750,
      colorTag: Color(0xFF16A34A), icon: Icons.kitchen_rounded,
      stock: StockState.healthy, stockQty: 22,
    ),
    Product(
      id: 'p05', name: 'Robot Walker', category: 'Cars', price: 999,
      colorTag: Color(0xFF7C3AED), icon: Icons.smart_toy_rounded,
      stock: StockState.healthy, stockQty: 31,
    ),
  ],
);
