// PROTOTYPE DUMMY DATA — replace OwnerNotificationsRepository.all() with
// GET /notifications?target=owner&type=&is_read= (see doc §9).
//
// Mark-read maps to `POST /notifications/{id}/read`; mark-all-read maps to
// `POST /notifications/read-all` — see
// docs/mobile/owner/notifications/notifications.md §9.

import 'package:flutter/material.dart';

import '../../core/core.dart';

/// Canonical notification categories (design-system.md §8 — meaning is
/// carried by **icon + label**, never color alone). Each type carries the
/// icon/tone used for its tinted circle + filter chip, and a human label for
/// the deep-link target it opens (§8 routing table).
enum NotifType {
  lowStock(
    label: 'Low stock',
    icon: Icons.warning_amber_rounded,
    tone: Tone.warning,
    target: 'Low-stock report',
  ),
  agingStock(
    label: 'Aging stock',
    icon: Icons.hourglass_bottom_rounded,
    tone: Tone.info,
    target: 'Aging-stock report',
  ),
  sync(
    label: 'Sync',
    icon: Icons.sync_problem_rounded,
    tone: Tone.danger,
    target: 'Sync status',
  ),
  gst(
    label: 'GST',
    icon: Icons.receipt_long_rounded,
    tone: Tone.warning,
    target: 'GST filing',
  ),
  milestone(
    label: 'Milestone',
    icon: Icons.emoji_events_rounded,
    tone: Tone.success,
    target: 'Staff performance',
  ),
  sale(
    label: 'Sale',
    icon: Icons.point_of_sale_rounded,
    tone: Tone.info,
    target: 'Sales report',
  );

  const NotifType({
    required this.label,
    required this.icon,
    required this.tone,
    required this.target,
  });

  final String label;
  final IconData icon;
  final Tone tone;

  /// Human label for the deep-link target, used in the "Opening …" snackbar
  /// that simulates navigation (§2 routing diagram).
  final String target;
}

/// A single alert row in the owner's inbox (mirrors the `notifications`
/// table's `{ id, type, title, body, created_at, is_read }` — doc §9).
class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final NotifType type;
  final String title;
  final String body;
  final DateTime createdAt;

  /// Mutable so the screen can flip it optimistically on tap/swipe/mark-all
  /// (mirrors the optimistic-update behavior in doc §6/§7).
  bool isRead;
}

/// Loads the owner's notification feed.
class OwnerNotificationsRepository {
  const OwnerNotificationsRepository();

  Future<List<AppNotification>> all() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _demo;
  }
}

/// Spans every type plus today / yesterday / older so the grouped list and
/// filter chips all have something to show. Anchored around "now" =
/// 2026-07-03 19:45 to line up with [Fmt.ago]'s default reference clock.
final List<AppNotification> _demo = [
  AppNotification(
    id: 'n2',
    type: NotifType.sync,
    title: 'Sync failed · 2 sales queued',
    body: 'Retries exhausted on device dev-abc123',
    createdAt: DateTime(2026, 7, 3, 19, 40),
  ),
  AppNotification(
    id: 'n3',
    type: NotifType.lowStock,
    title: 'Low stock · Red Racer Car',
    body: 'On-hand 2 / reorder level 3',
    createdAt: DateTime(2026, 7, 3, 18, 45),
  ),
  AppNotification(
    id: 'n4',
    type: NotifType.agingStock,
    title: 'Aging stock · Blue Jet Bike',
    body: 'Unsold 72 days · consider a markdown',
    createdAt: DateTime(2026, 7, 3, 16, 45),
    isRead: true,
  ),
  AppNotification(
    id: 'n5',
    type: NotifType.gst,
    title: 'GST filing due in 5 days',
    body: 'GSTR-3B for 2026-06 · liability ₹18,940',
    createdAt: DateTime(2026, 7, 3, 9, 0),
  ),
  AppNotification(
    id: 'n6',
    type: NotifType.milestone,
    title: 'Incentive · Meena hit Tier 2',
    body: '₹5,00,000 monthly revenue crossed',
    createdAt: DateTime(2026, 7, 2, 20, 0),
    isRead: true,
  ),
  AppNotification(
    id: 'n7',
    type: NotifType.sale,
    title: 'Big sale recorded · ₹12,400',
    body: 'Ravi Kumar closed a 6-item cart',
    createdAt: DateTime(2026, 7, 2, 14, 30),
    isRead: true,
  ),
  AppNotification(
    id: 'n8',
    type: NotifType.lowStock,
    title: 'Low stock · Wooden Puzzle Set',
    body: 'On-hand 1 / reorder level 5',
    createdAt: DateTime(2026, 6, 28, 10, 0),
    isRead: true,
  ),
  AppNotification(
    id: 'n9',
    type: NotifType.sync,
    title: 'Sync failed · 1 purchase queued',
    body: 'Retries exhausted on device dev-def456',
    createdAt: DateTime(2026, 6, 25, 11, 0),
    isRead: true,
  ),
];
