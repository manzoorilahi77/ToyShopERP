// PROTOTYPE DUMMY DATA — replace StaffRepository.staff() with
// GET /staff and StaffRepository.rules() with GET /incentive-rules (see doc §9).
//
// staff-management.md §9 key fields:
//   staff:      { id, name, photo_url, role, phone, join_date, is_active,
//                 current_month_points, total_lifetime_sales }
//   performance: GET /staff/{id}/performance?period=today|month|lifetime ->
//                 { revenue, units, points, lifetime_sales, badges:[…],
//                   incentive:{ rule_id, current_value, target_value, tier_reached } }
//   incentive_rules: { id, label, target_value (units), reward, is_active }
//
// Reset PIN -> PATCH /staff/{id} { pin, owner_pin } (🔒, bcrypt-hashed server-side,
// never returned). Activate/Deactivate -> PATCH /staff/{id} { is_active, owner_pin } (🔒).

import 'package:flutter/material.dart';

import '../../core/core.dart';

/// A single sales-staff / accountant / co-owner roster entry, plus the
/// denormalized performance snapshot shown on the detail sheet. Mutable so the
/// prototype can add/edit/toggle in place without a full state-management layer.
class StaffMember {
  StaffMember({
    required this.id,
    required this.name,
    required this.initials,
    required this.color,
    required this.role,
    required this.phone,
    required this.joinDate,
    this.isActive = true,
    this.monthUnits = 0,
    this.monthRevenue = 0,
    this.points = 0,
    this.rank = 0,
    this.todayRevenue = 0,
    this.todayUnits = 0,
    this.lifetimeSales = 0,
    this.badges = const [],
    this.incentiveProgressPct = 0,
    this.incentiveTierLabel = '',
  });

  final String id;
  String name;
  String initials;
  Color color;
  UserRole role;
  String phone;
  DateTime joinDate;
  bool isActive;

  // Performance snapshot — denormalized caches, reconciled nightly (§5c).
  int monthUnits;
  double monthRevenue;
  int points;
  int rank;
  double todayRevenue;
  int todayUnits;
  double lifetimeSales;
  List<String> badges;
  int incentiveProgressPct;
  String incentiveTierLabel;
}

/// A tier in the incentive scheme: hit [targetUnits] this month, earn [reward].
class IncentiveRule {
  IncentiveRule({
    required this.id,
    required this.label,
    required this.targetUnits,
    required this.reward,
    this.isActive = true,
  });

  final String id;
  String label;
  int targetUnits;
  String reward;
  bool isActive;
}

/// Decorative avatar colors cycled for newly-added staff (stands in for
/// `photo_url`, matching [AvatarBadge]'s design).
const List<Color> staffAvatarColors = [
  Color(0xFF2563EB),
  Color(0xFFDB2777),
  Color(0xFF7C3AED),
  Color(0xFFEA580C),
  Color(0xFF0891B2),
  Color(0xFF16A34A),
];

class StaffRepository {
  const StaffRepository();

  Future<List<StaffMember>> staff() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _demoStaff;
  }

  Future<List<IncentiveRule>> rules() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _demoRules;
  }
}

final List<StaffMember> _demoStaff = [
  StaffMember(
    id: 's1',
    name: 'Ravi Kumar',
    initials: 'RK',
    color: staffAvatarColors[0],
    role: UserRole.staff,
    phone: '+91 98765 43210',
    joinDate: DateTime(2025, 3, 12),
    isActive: true,
    monthUnits: 156,
    monthRevenue: 680400,
    points: 1240,
    rank: 1,
    todayRevenue: 42300,
    todayUnits: 23,
    lifetimeSales: 4120000,
    badges: const ['Top Week', '50 Toys'],
    incentiveProgressPct: 82,
    incentiveTierLabel: 'Tier 2',
  ),
  StaffMember(
    id: 's2',
    name: 'Meena S.',
    initials: 'MS',
    color: staffAvatarColors[1],
    role: UserRole.staff,
    phone: '+91 98450 11223',
    joinDate: DateTime(2025, 6, 3),
    isActive: true,
    monthUnits: 98,
    monthRevenue: 410200,
    points: 860,
    rank: 2,
    todayRevenue: 18500,
    todayUnits: 9,
    lifetimeSales: 2210000,
    badges: const ['Rising Star'],
    incentiveProgressPct: 55,
    incentiveTierLabel: 'Tier 1',
  ),
  StaffMember(
    id: 's3',
    name: 'Karthik Raj',
    initials: 'KR',
    color: staffAvatarColors[2],
    role: UserRole.staff,
    phone: '+91 90032 77641',
    joinDate: DateTime(2025, 8, 20),
    isActive: true,
    monthUnits: 61,
    monthRevenue: 265000,
    points: 540,
    rank: 3,
    todayRevenue: 5200,
    todayUnits: 3,
    lifetimeSales: 980000,
    badges: const [],
    incentiveProgressPct: 20,
    incentiveTierLabel: 'Tier 1',
  ),
  StaffMember(
    id: 's4',
    name: 'Arun Verma',
    initials: 'AV',
    color: staffAvatarColors[3],
    role: UserRole.staff,
    phone: '+91 88009 55210',
    joinDate: DateTime(2024, 11, 4),
    isActive: false,
    monthUnits: 0,
    monthRevenue: 0,
    points: 0,
    rank: 6,
    todayRevenue: 0,
    todayUnits: 0,
    lifetimeSales: 1540000,
    badges: const ['50 Toys'],
    incentiveProgressPct: 0,
    incentiveTierLabel: 'Tier 1',
  ),
  StaffMember(
    id: 's5',
    name: 'Priya Nair',
    initials: 'PN',
    color: staffAvatarColors[4],
    role: UserRole.accountant,
    phone: '+91 97400 66112',
    joinDate: DateTime(2025, 1, 15),
    isActive: true,
    monthUnits: 0,
    monthRevenue: 0,
    points: 0,
    rank: 0,
    todayRevenue: 0,
    todayUnits: 0,
    lifetimeSales: 0,
    badges: const [],
    incentiveProgressPct: 0,
    incentiveTierLabel: '',
  ),
  StaffMember(
    id: 's6',
    name: 'Suresh Iyer',
    initials: 'SI',
    color: staffAvatarColors[5],
    role: UserRole.owner,
    phone: '+91 99010 33445',
    joinDate: DateTime(2023, 4, 1),
    isActive: true,
    monthUnits: 0,
    monthRevenue: 0,
    points: 0,
    rank: 0,
    todayRevenue: 0,
    todayUnits: 0,
    lifetimeSales: 0,
    badges: const [],
    incentiveProgressPct: 0,
    incentiveTierLabel: '',
  ),
];

final List<IncentiveRule> _demoRules = [
  IncentiveRule(
    id: 'r1',
    label: 'Tier 1 — Starter',
    targetUnits: 50,
    reward: '₹500 bonus',
    isActive: true,
  ),
  IncentiveRule(
    id: 'r2',
    label: 'Tier 2 — Pro',
    targetUnits: 150,
    reward: '₹2,000 bonus',
    isActive: true,
  ),
  IncentiveRule(
    id: 'r3',
    label: 'Tier 3 — Elite',
    targetUnits: 300,
    reward: '₹5,000 + badge',
    isActive: true,
  ),
  IncentiveRule(
    id: 'r4',
    label: 'Festive Push (Diwali)',
    targetUnits: 80,
    reward: '₹1,000 gift voucher',
    isActive: false,
  ),
];
