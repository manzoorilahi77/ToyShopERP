import 'package:flutter/material.dart';

import '../core/core.dart';

/// PROTOTYPE DUMMY DATA — the login roster (staff picker + owner).
///
/// Mirrors the `staff` roster subset the auth docs read for the picker:
/// `id`, `name`, `photo_url`, `role`, `is_active`. To wire the backend, replace
/// [AuthRepository.fetchRoster] with `GET /staff` (roster subset) / the cached
/// `GET /sync/pull` roster — see docs/mobile/staff/auth/login.md §9.
class AuthRepository {
  const AuthRepository();

  Future<List<Account>> fetchRoster() async {
    // Simulates the async shape of the future API call.
    return demoRoster;
  }
}

/// Any 4-digit PIN unlocks in the prototype.
const String kDemoPinHint = 'Demo: any 4-digit PIN works';

final List<Account> demoRoster = [
  Account(
    id: 'stf_01',
    name: 'Ravi Kumar',
    role: UserRole.staff,
    initials: 'RK',
    photoColor: const Color(0xFF2563EB),
    joinDate: DateTime(2024, 8, 12),
    phone: '+91 98840 11223',
  ),
  Account(
    id: 'stf_02',
    name: 'Anbu Selvan',
    role: UserRole.staff,
    initials: 'AS',
    photoColor: const Color(0xFF16A34A),
    joinDate: DateTime(2023, 11, 3),
    phone: '+91 90031 55420',
  ),
  Account(
    id: 'stf_03',
    name: 'Meena Rani',
    role: UserRole.staff,
    initials: 'MR',
    photoColor: const Color(0xFFDB2777),
    joinDate: DateTime(2025, 1, 20),
    phone: '+91 99400 88771',
  ),
  Account(
    id: 'stf_04',
    name: 'Karan Das',
    role: UserRole.staff,
    initials: 'KD',
    photoColor: const Color(0xFFD97706),
    joinDate: DateTime(2024, 3, 9),
    phone: '+91 89395 22019',
  ),
  Account(
    id: 'stf_05',
    name: 'Suraj Pillai',
    role: UserRole.staff,
    initials: 'SP',
    photoColor: const Color(0xFF7C3AED),
    joinDate: DateTime(2025, 5, 2),
    phone: '+91 70108 34567',
  ),
  Account(
    id: 'own_01',
    name: 'Priya Nair',
    role: UserRole.owner,
    initials: 'PN',
    photoColor: const Color(0xFF0891B2),
    joinDate: DateTime(2019, 6, 1),
    phone: '+91 98410 00001',
  ),
];

/// The default owner account (used by the owner-side profile/menus).
final Account demoOwner = demoRoster.firstWhere((a) => a.role == UserRole.owner);
