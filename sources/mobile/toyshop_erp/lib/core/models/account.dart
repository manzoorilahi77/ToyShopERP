import 'package:flutter/material.dart';

/// App roles. A single app serves all of them; the account's [role] chosen at
/// login decides which shell/dashboard the user lands on.
enum UserRole {
  staff('Staff'),
  owner('Owner'),
  accountant('Accountant');

  const UserRole(this.label);
  final String label;

  bool get isOwnerSide => this == owner || this == accountant;
}

/// A login-roster entry (staff picker tile). Mirrors the `staff` roster subset
/// (`id`, `name`, `photo_url`, `role`, `is_active`) from the auth docs.
///
/// PROTOTYPE: [photoColor] + [initials] stand in for `photo_url` so tiles render
/// offline without network images.
@immutable
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.role,
    required this.initials,
    required this.photoColor,
    this.email,
    this.joinDate,
    this.phone,
    this.isActive = true,
  });

  final String id;
  final String name;
  final UserRole role;
  final String initials;
  final Color photoColor;
  final String? email;
  final DateTime? joinDate;
  final String? phone;
  final bool isActive;

  String get roleLabel => role.label;

  factory Account.fromJson(Map<String, dynamic> json) {
    // Determine color from colorClass, default to blue
    Color parsedColor = const Color(0xFF2563EB); // bg-blue-600
    if (json['colorClass'] != null) {
      final colorStr = json['colorClass'].toString();
      if (colorStr.contains('green')) parsedColor = const Color(0xFF16A34A);
      if (colorStr.contains('pink')) parsedColor = const Color(0xFFDB2777);
      if (colorStr.contains('amber')) parsedColor = const Color(0xFFD97706);
      if (colorStr.contains('purple')) parsedColor = const Color(0xFF7C3AED);
      if (colorStr.contains('cyan')) parsedColor = const Color(0xFF0891B2);
    }

    // Determine role
    UserRole parsedRole = UserRole.staff;
    if (json['role'] == 'owner') parsedRole = UserRole.owner;
    if (json['role'] == 'accountant') parsedRole = UserRole.accountant;

    return Account(
      id: json['id'].toString(),
      name: json['name'] ?? 'Unknown',
      email: json['email'],
      role: parsedRole,
      initials: json['initials'] ?? '?',
      photoColor: parsedColor,
      isActive: json['isActive'] ?? true,
    );
  }
}
