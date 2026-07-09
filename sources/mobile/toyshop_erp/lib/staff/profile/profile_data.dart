// PROTOTYPE DUMMY DATA — replace StaffProfileRepository.load() with GET /staff/{id} (see doc §9).
//
// Backing calls per docs/mobile/staff/profile/profile.md §9:
//   GET /staff/{id}                 → identity + total_lifetime_sales + current_month_points
//   GET /staff/{id}/badges          → earned badges (+ earned_at, period)
//   GET /staff/leaderboard          → rank ("#2 of 6")
//   POST/DELETE /staff/{id}/favorites (proposed) → pin/unpin/reorder, queued in outbox offline
//   POST /auth/logout               → revoke refresh token, clear local session

import 'package:flutter/material.dart';

import '../../core/core.dart';

/// Lifetime + this-month performance snapshot (denormalized caches per §6.2).
class ProfileStats {
  const ProfileStats({
    required this.lifetimeUnits,
    required this.lifetimeSales,
    required this.monthPoints,
    required this.rank,
    required this.totalStaff,
    required this.asOf,
  });

  final int lifetimeUnits;
  final double lifetimeSales;
  final int monthPoints;
  final int rank;
  final int totalStaff;
  final DateTime asOf;

  String get rankLabel => '#$rank of $totalStaff';
}

/// A badge from the `badges` catalog, joined with `staff_badges` (earned or not).
class ProfileBadge {
  const ProfileBadge({
    required this.code,
    required this.label,
    required this.icon,
    required this.criteria,
    required this.earned,
    this.earnedOn,
  });

  final String code;
  final String label;
  final IconData icon;

  /// `criteria_json` rendered as a human hint — shown for both earned (as
  /// "how you earned it") and locked (as "how to earn it") badges.
  final String criteria;
  final bool earned;
  final DateTime? earnedOn;
}

/// Named incentive ladder (Bronze → Platinum) the staff climbs with points —
/// distinct from the dashboard's single-reward progress bar.
class IncentiveTierProgress {
  const IncentiveTierProgress({
    required this.tierNames,
    required this.tierThresholds,
    required this.tierRewards,
    required this.currentPoints,
    required this.periodLabel,
  });

  /// Ascending tier names, e.g. `[Bronze, Silver, Gold, Platinum]`.
  final List<String> tierNames;

  /// Points required to *enter* each tier (same length as [tierNames]; index 0 is 0).
  final List<int> tierThresholds;

  /// Reward label per tier.
  final List<String> tierRewards;
  final int currentPoints;
  final String periodLabel;

  int get currentIndex {
    var idx = 0;
    for (var i = 0; i < tierThresholds.length; i++) {
      if (currentPoints >= tierThresholds[i]) idx = i;
    }
    return idx;
  }

  String get currentTierName => tierNames[currentIndex];
  bool get isMaxTier => currentIndex >= tierNames.length - 1;
  String? get nextTierName => isMaxTier ? null : tierNames[currentIndex + 1];
  int? get nextThreshold => isMaxTier ? null : tierThresholds[currentIndex + 1];
  String get currentReward => tierRewards[currentIndex];

  int get toGo => nextThreshold == null ? 0 : (nextThreshold! - currentPoints).clamp(0, nextThreshold!);

  double get fraction {
    if (isMaxTier) return 1;
    final base = tierThresholds[currentIndex];
    final span = (nextThreshold! - base).clamp(1, 1 << 30);
    return ((currentPoints - base) / span).clamp(0, 1).toDouble();
  }
}

/// App-local (device) preferences — never synced to the server (§8 rule 8).
class ProfilePreferences {
  const ProfilePreferences({
    required this.biometricEnabled,
    required this.biometricEnrolled,
    required this.voiceLanguage,
  });

  final bool biometricEnabled;
  final bool biometricEnrolled;
  final String voiceLanguage;
}

/// Everything the Profile screen needs, mirroring `staff` + `staff_badges` +
/// the leaderboard snapshot + the (proposed) `staff_favorites` cache.
class StaffProfileData {
  const StaffProfileData({
    required this.stats,
    required this.badges,
    required this.favorites,
    required this.favoriteCatalog,
    required this.tier,
    required this.preferences,
  });

  final ProfileStats stats;
  final List<ProfileBadge> badges;

  /// Staff's pinned products (`staff_favorites`, R3).
  final List<Product> favorites;

  /// Browsable products a staff member can pin as a favorite (stand-in for
  /// the catalog picker the "Manage" sheet would otherwise deep-link to).
  final List<Product> favoriteCatalog;
  final IncentiveTierProgress tier;
  final ProfilePreferences preferences;
}

class StaffProfileRepository {
  const StaffProfileRepository();

  Future<StaffProfileData> load() async {
    return _demo;
  }
}

final _demo = StaffProfileData(
  stats: ProfileStats(
    lifetimeUnits: 3186,
    lifetimeSales: 842300,
    monthPoints: 812,
    rank: 2,
    totalStaff: 6,
    asOf: DateTime(2026, 7, 3, 19, 40),
  ),
  badges: const [
    ProfileBadge(
      code: 'top_week',
      label: 'Top Week',
      icon: Icons.emoji_events_rounded,
      criteria: 'Finish #1 on the weekly leaderboard.',
      earned: true,
      earnedOn: null,
    ),
    ProfileBadge(
      code: 'fifty_toys',
      label: '50 Toys',
      icon: Icons.toys_rounded,
      criteria: 'Sell 50 toys in a single month.',
      earned: true,
    ),
    ProfileBadge(
      code: 'fast_biller',
      label: 'Fast Biller',
      icon: Icons.bolt_rounded,
      criteria: 'Average under 90 seconds per sale for a week.',
      earned: true,
    ),
    ProfileBadge(
      code: 'first_sale',
      label: 'First Sale',
      icon: Icons.celebration_rounded,
      criteria: 'Complete your first sale.',
      earned: true,
    ),
    ProfileBadge(
      code: 'hundred_toys',
      label: '100 Toys',
      icon: Icons.lock_rounded,
      criteria: 'Sell 100 toys in a single month.',
      earned: false,
    ),
    ProfileBadge(
      code: 'weekend_king',
      label: 'Weekend King',
      icon: Icons.lock_rounded,
      criteria: 'Ring up ₹1,00,000 over a single weekend.',
      earned: false,
    ),
  ],
  favorites: const [
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
      id: 'p04', name: 'Kitchen Play Set', category: 'Play sets', price: 1750,
      colorTag: Color(0xFF16A34A), icon: Icons.kitchen_rounded,
      stock: StockState.healthy, stockQty: 22, isFavorite: true,
    ),
  ],
  favoriteCatalog: const [
    Product(
      id: 'p03', name: 'Baby Bike Pink', category: 'Bikes', price: 2100,
      colorTag: Color(0xFFDB2777), icon: Icons.pedal_bike_rounded,
      stock: StockState.low, stockQty: 4,
    ),
    Product(
      id: 'p05', name: 'Robot Walker', category: 'Cars', price: 999,
      colorTag: Color(0xFF7C3AED), icon: Icons.smart_toy_rounded,
      stock: StockState.healthy, stockQty: 31,
    ),
    Product(
      id: 'p06', name: 'Wooden Blocks Set', category: 'Play sets', price: 850,
      colorTag: Color(0xFFD97706), icon: Icons.category_rounded,
      stock: StockState.healthy, stockQty: 58,
    ),
    Product(
      id: 'p07', name: 'Plush Teddy XL', category: 'Soft toys', price: 1499,
      colorTag: Color(0xFFDB2777), icon: Icons.toys_rounded,
      stock: StockState.aging, stockQty: 9,
    ),
    Product(
      id: 'p08', name: 'Puzzle Cube 500pc', category: 'Puzzles', price: 620,
      colorTag: Color(0xFF0891B2), icon: Icons.extension_rounded,
      stock: StockState.healthy, stockQty: 26,
    ),
  ],
  tier: const IncentiveTierProgress(
    tierNames: ['Bronze', 'Silver', 'Gold', 'Platinum'],
    tierThresholds: [0, 300, 600, 1000],
    tierRewards: [
      '₹200 bonus',
      '₹500 bonus',
      '₹1,000 bonus + Gold badge',
      '₹2,500 bonus + trophy',
    ],
    currentPoints: 812,
    periodLabel: 'this month',
  ),
  preferences: const ProfilePreferences(
    biometricEnabled: false,
    biometricEnrolled: true,
    voiceLanguage: 'English',
  ),
);

/// Supported voice-search locales (design-system.md §10).
const List<String> kVoiceLanguages = ['English', 'Tamil', 'Hindi', 'Telugu'];
