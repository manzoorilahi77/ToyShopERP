// PROTOTYPE DUMMY DATA — replace DiscountApprovalRepository.pending() with
// GET /discounts/requests?status=pending (see doc §9).
//
// Other methods to wire similarly against
// docs/mobile/owner/approvals/discount-approval.md §9's API table:
//   DiscountApprovalRepository.history()  → GET  /discounts/requests?status=approved,rejected
//   DiscountApprovalRepository.decide()   → POST /discounts/requests/{id}/decide
//                                            body: { action: approve|reject, pin }

import 'package:flutter/material.dart';

/// Money-leak guard threshold (overview.md §6.5): discounts at/above this rate
/// need extra owner scrutiny before the 🔒 PIN unlocks the approval — flagged,
/// never auto-blocked, because a well-justified high discount is still valid.
const double kHighRiskDiscountPct = 15;

enum DiscountRequestStatus { pending, approved, rejected }

/// A staff-raised request to sell a cart below its listed price
/// (`discount_requests` — staff, cart summary, original/requested price,
/// reason, status). Only the owner can move it out of `pending`; that PIN
/// gate is the anti money-leak control this whole screen exists to enforce.
@immutable
class DiscountRequest {
  const DiscountRequest({
    required this.id,
    required this.saleRef,
    required this.staffName,
    required this.staffInitials,
    required this.staffColor,
    required this.itemSummary,
    required this.itemCount,
    required this.originalPrice,
    required this.requestedPrice,
    required this.reason,
    required this.requestedAt,
    this.status = DiscountRequestStatus.pending,
    this.decidedAt,
    this.decidedBy,
  });

  final String id;
  final String saleRef;
  final String staffName;
  final String staffInitials;
  final Color staffColor;

  /// e.g. "RC Racer Blue ×2, Puzzle Set ×1" — the cart this discount applies to.
  final String itemSummary;
  final int itemCount;
  final double originalPrice;
  final double requestedPrice;
  final String reason;
  final DateTime requestedAt;
  final DiscountRequestStatus status;
  final DateTime? decidedAt;
  final String? decidedBy;

  double get discountAmount => originalPrice - requestedPrice;

  double get discountPct => originalPrice == 0 ? 0 : (discountAmount / originalPrice) * 100;

  /// True when this needs extra owner scrutiny before approval (§6.5 guard).
  bool get isHighRisk => discountPct >= kHighRiskDiscountPct;

  DiscountRequest copyWith({
    DiscountRequestStatus? status,
    DateTime? decidedAt,
    String? decidedBy,
  }) {
    return DiscountRequest(
      id: id,
      saleRef: saleRef,
      staffName: staffName,
      staffInitials: staffInitials,
      staffColor: staffColor,
      itemSummary: itemSummary,
      itemCount: itemCount,
      originalPrice: originalPrice,
      requestedPrice: requestedPrice,
      reason: reason,
      requestedAt: requestedAt,
      status: status ?? this.status,
      decidedAt: decidedAt ?? this.decidedAt,
      decidedBy: decidedBy ?? this.decidedBy,
    );
  }
}

/// Fixed "now" reference so seed timestamps line up with [Fmt.ago]'s default
/// clock in this prototype build.
final DateTime _kNow = DateTime(2026, 7, 3, 19, 45);

final List<DiscountRequest> _demo = [
  DiscountRequest(
    id: 'DR-1042',
    saleRef: 'Sale #S-2291',
    staffName: 'Ravi Kumar',
    staffInitials: 'RK',
    staffColor: const Color(0xFF2563EB),
    itemSummary: 'RC Racer Blue ×2, Puzzle Set ×1',
    itemCount: 3,
    originalPrice: 3000,
    requestedPrice: 2700,
    reason: "Regular customer buying for both kids — asked to match last visit's price.",
    requestedAt: _kNow.subtract(const Duration(minutes: 6)),
  ),
  DiscountRequest(
    id: 'DR-1041',
    saleRef: 'Sale #S-2288',
    staffName: 'Meena Rani',
    staffInitials: 'MR',
    staffColor: const Color(0xFFDB2777),
    itemSummary: 'Baby Bike Pink ×1',
    itemCount: 1,
    originalPrice: 2100,
    requestedPrice: 1550,
    reason: 'Cosmetic scratch on the frame, customer noticed it at the counter.',
    requestedAt: _kNow.subtract(const Duration(minutes: 32)),
  ),
  DiscountRequest(
    id: 'DR-1040',
    saleRef: 'Sale #S-2280',
    staffName: 'Karan Das',
    staffInitials: 'KD',
    staffColor: const Color(0xFFD97706),
    itemSummary: 'Rideon Jeep Red ×1, RC Racer Blue ×1',
    itemCount: 2,
    originalPrice: 5550,
    requestedPrice: 4600,
    reason: 'Bulk buy for a birthday party return-gift order — wants a "package rate".',
    requestedAt: _kNow.subtract(const Duration(hours: 2, minutes: 10)),
  ),
  DiscountRequest(
    id: 'DR-1035',
    saleRef: 'Sale #S-2201',
    staffName: 'Anbu Selvan',
    staffInitials: 'AS',
    staffColor: const Color(0xFF16A34A),
    itemSummary: 'Kitchen Play Set ×1',
    itemCount: 1,
    originalPrice: 1750,
    requestedPrice: 1610,
    reason: 'Festival week promo price shown on the shelf card.',
    requestedAt: _kNow.subtract(const Duration(days: 1, hours: 3)),
    status: DiscountRequestStatus.approved,
    decidedAt: _kNow.subtract(const Duration(days: 1, hours: 2, minutes: 40)),
    decidedBy: 'Priya Nair',
  ),
  DiscountRequest(
    id: 'DR-1031',
    saleRef: 'Sale #S-2166',
    staffName: 'Suraj Pillai',
    staffInitials: 'SP',
    staffColor: const Color(0xFF7C3AED),
    itemSummary: 'Robot Walker ×3',
    itemCount: 3,
    originalPrice: 2997,
    requestedPrice: 2000,
    reason: 'Wanted a "wholesale" rate for reselling — no proof of business shown.',
    requestedAt: _kNow.subtract(const Duration(days: 2, hours: 5)),
    status: DiscountRequestStatus.rejected,
    decidedAt: _kNow.subtract(const Duration(days: 2, hours: 4, minutes: 50)),
    decidedBy: 'Priya Nair',
  ),
  DiscountRequest(
    id: 'DR-1028',
    saleRef: 'Sale #S-2140',
    staffName: 'Ravi Kumar',
    staffInitials: 'RK',
    staffColor: const Color(0xFF2563EB),
    itemSummary: 'Wooden Alphabet Train ×1',
    itemCount: 1,
    originalPrice: 899,
    requestedPrice: 820,
    reason: 'Display piece with minor box damage.',
    requestedAt: _kNow.subtract(const Duration(days: 3, hours: 1)),
    status: DiscountRequestStatus.approved,
    decidedAt: _kNow.subtract(const Duration(days: 3)),
    decidedBy: 'Priya Nair',
  ),
];

class DiscountApprovalRepository {
  const DiscountApprovalRepository();

  /// Oldest-first — the request that's kept a customer waiting longest
  /// surfaces at the top of the queue.
  Future<List<DiscountRequest>> pending() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final list = _demo.where((r) => r.status == DiscountRequestStatus.pending).toList()
      ..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
    return list;
  }

  /// Most-recently-decided first.
  Future<List<DiscountRequest>> history() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final list = _demo.where((r) => r.status != DiscountRequestStatus.pending).toList()
      ..sort((a, b) => (b.decidedAt ?? b.requestedAt).compareTo(a.decidedAt ?? a.requestedAt));
    return list;
  }

  /// Records the owner's PIN-gated decision against the backing store so the
  /// queue stays consistent if the screen is ever reloaded.
  Future<void> decide(String id, DiscountRequestStatus status, {String? decidedBy}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final i = _demo.indexWhere((r) => r.id == id);
    if (i == -1) return;
    _demo[i] = _demo[i].copyWith(status: status, decidedAt: DateTime.now(), decidedBy: decidedBy);
  }
}
