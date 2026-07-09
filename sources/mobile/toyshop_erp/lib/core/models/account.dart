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
    this.joinDate,
    this.phone,
    this.isActive = true,
  });

  final String id;
  final String name;
  final UserRole role;
  final String initials;
  final Color photoColor;
  final DateTime? joinDate;
  final String? phone;
  final bool isActive;

  String get roleLabel => role.label;
}
