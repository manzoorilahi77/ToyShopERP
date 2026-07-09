// PROTOTYPE DUMMY DATA — replace GstRegistrationsRepository.all() with
// GET /gst/registrations (see doc §9).
//
// Other methods to wire similarly against
// docs/mobile/owner/gst/gst-registrations.md §9's API table:
//   create      → POST  /gst/registrations   (Idempotency-Key = client_uuid)
//   edit        → PATCH /gst/registrations/{id}
//   deactivate  → PATCH /gst/registrations/{id}  { is_active:0, owner_pin }
//   mark filed  → GST filing module, see cloud/api/gst/gst-api.md

import 'package:flutter/material.dart';

/// Filing state of one GSTR period — icon + label per design-system.md §8
/// (never color alone).
enum GstFilingStatus {
  filed('Filed', Icons.check_circle_rounded),
  pending('Pending', Icons.schedule_rounded),
  overdue('Overdue', Icons.error_rounded);

  const GstFilingStatus(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// One return period in a registration's filing history.
@immutable
class GstFilingPeriod {
  const GstFilingPeriod({
    required this.label,
    required this.liability,
    required this.status,
    required this.dueDate,
  });

  /// e.g. "Jul 2026".
  final String label;
  final double liability;
  final GstFilingStatus status;
  final DateTime dueDate;

  GstFilingPeriod copyWith({GstFilingStatus? status}) => GstFilingPeriod(
        label: label,
        liability: liability,
        status: status ?? this.status,
        dueDate: dueDate,
      );
}

/// GST state codes (first 2 digits of a GSTIN) → state name. Drives the
/// IGST vs CGST/SGST split at filing (doc §5); the screen only captures it.
const Map<String, String> gstStateNames = {
  '01': 'Jammu & Kashmir',
  '02': 'Himachal Pradesh',
  '03': 'Punjab',
  '04': 'Chandigarh',
  '05': 'Uttarakhand',
  '06': 'Haryana',
  '07': 'Delhi',
  '08': 'Rajasthan',
  '09': 'Uttar Pradesh',
  '10': 'Bihar',
  '11': 'Sikkim',
  '12': 'Arunachal Pradesh',
  '13': 'Nagaland',
  '14': 'Manipur',
  '15': 'Mizoram',
  '16': 'Tripura',
  '17': 'Meghalaya',
  '18': 'Assam',
  '19': 'West Bengal',
  '20': 'Jharkhand',
  '21': 'Odisha',
  '22': 'Chhattisgarh',
  '23': 'Madhya Pradesh',
  '24': 'Gujarat',
  '26': 'Dadra & Nagar Haveli and Daman & Diu',
  '27': 'Maharashtra',
  '28': 'Andhra Pradesh (Old)',
  '29': 'Karnataka',
  '30': 'Goa',
  '31': 'Lakshadweep',
  '32': 'Kerala',
  '33': 'Tamil Nadu',
  '34': 'Puducherry',
  '35': 'Andaman & Nicobar Islands',
  '36': 'Telangana',
  '37': 'Andhra Pradesh',
  '38': 'Ladakh',
};

/// GSTIN format — 2-digit state + 10-char PAN + 1 entity code + default `Z`
/// + 1 check character (doc §5). The check-digit itself is authoritative
/// server-side; the client enforces format + the state-code prefix rule.
final RegExp gstinFormat = RegExp(
  r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
);

/// One tax registration the shop operates under (`gst_registrations`).
@immutable
class GstRegistration {
  const GstRegistration({
    required this.id,
    required this.gstin,
    required this.legalName,
    this.tradeName,
    required this.address,
    required this.state,
    required this.isActive,
    required this.currentPeriodLiability,
    required this.filingStatus,
    required this.lastFiledPeriod,
    required this.registeredOn,
    this.periods = const [],
  });

  final String id;
  final String gstin;
  final String legalName;
  final String? tradeName;
  final String address;
  final String state;
  final bool isActive;
  final double currentPeriodLiability;
  final GstFilingStatus filingStatus;
  final String lastFiledPeriod;
  final DateTime registeredOn;
  final List<GstFilingPeriod> periods;

  /// First 2 digits — drives CGST+SGST vs IGST at filing (doc §5).
  String get stateCode => gstin.substring(0, 2);

  /// Grouped for readability — `27 ABCDE1234F 1Z5` — never a bare 15-char
  /// blob (doc §12, mono display).
  String get formattedGstin =>
      '${gstin.substring(0, 2)} ${gstin.substring(2, 12)} ${gstin.substring(12)}';

  String get displayName => (tradeName?.isNotEmpty ?? false) ? tradeName! : legalName;

  GstRegistration copyWith({
    bool? isActive,
    double? currentPeriodLiability,
    GstFilingStatus? filingStatus,
    String? lastFiledPeriod,
    List<GstFilingPeriod>? periods,
  }) {
    return GstRegistration(
      id: id,
      gstin: gstin,
      legalName: legalName,
      tradeName: tradeName,
      address: address,
      state: state,
      isActive: isActive ?? this.isActive,
      currentPeriodLiability: currentPeriodLiability ?? this.currentPeriodLiability,
      filingStatus: filingStatus ?? this.filingStatus,
      lastFiledPeriod: lastFiledPeriod ?? this.lastFiledPeriod,
      registeredOn: registeredOn,
      periods: periods ?? this.periods,
    );
  }
}

class GstRegistrationsRepository {
  const GstRegistrationsRepository();

  Future<List<GstRegistration>> all() async {
    await Future.delayed(const Duration(milliseconds: 450));
    return List.unmodifiable(_demo);
  }
}

final List<GstRegistration> _demo = [
  GstRegistration(
    id: 'gst-1',
    gstin: '27AAAAA0000A1Z5',
    legalName: 'Sunrise Toys Private Limited',
    tradeName: 'Sunrise Toys',
    address: '12 MG Road, Pune, Maharashtra 411001',
    state: 'Maharashtra',
    isActive: true,
    currentPeriodLiability: 18940,
    filingStatus: GstFilingStatus.pending,
    lastFiledPeriod: 'Jun 2026',
    registeredOn: DateTime(2022, 4, 12),
    periods: [
      GstFilingPeriod(
        label: 'Jul 2026',
        liability: 18940,
        status: GstFilingStatus.pending,
        dueDate: DateTime(2026, 8, 20),
      ),
      GstFilingPeriod(
        label: 'Jun 2026',
        liability: 21150,
        status: GstFilingStatus.filed,
        dueDate: DateTime(2026, 7, 20),
      ),
      GstFilingPeriod(
        label: 'May 2026',
        liability: 17640,
        status: GstFilingStatus.filed,
        dueDate: DateTime(2026, 6, 20),
      ),
    ],
  ),
  GstRegistration(
    id: 'gst-2',
    gstin: '29BBBBB1111B1Z8',
    legalName: 'Sunrise Toys Private Limited',
    tradeName: 'Sunrise Toys (Bengaluru)',
    address: '48 Brigade Road, Bengaluru, Karnataka 560025',
    state: 'Karnataka',
    isActive: true,
    currentPeriodLiability: 6420,
    filingStatus: GstFilingStatus.overdue,
    lastFiledPeriod: 'May 2026',
    registeredOn: DateTime(2023, 9, 1),
    periods: [
      GstFilingPeriod(
        label: 'Jun 2026',
        liability: 6420,
        status: GstFilingStatus.overdue,
        dueDate: DateTime(2026, 7, 20),
      ),
      GstFilingPeriod(
        label: 'May 2026',
        liability: 5980,
        status: GstFilingStatus.filed,
        dueDate: DateTime(2026, 6, 20),
      ),
    ],
  ),
  GstRegistration(
    id: 'gst-3',
    gstin: '33ABCDE1234F1Z5',
    legalName: 'Sunrise Toys South Private Limited',
    tradeName: 'Sunrise Toys Chennai',
    address: '7 Anna Salai, Chennai, Tamil Nadu 600002',
    state: 'Tamil Nadu',
    isActive: false,
    currentPeriodLiability: 0,
    filingStatus: GstFilingStatus.filed,
    lastFiledPeriod: 'Feb 2026',
    registeredOn: DateTime(2021, 1, 20),
    periods: [
      GstFilingPeriod(
        label: 'Feb 2026',
        liability: 3120,
        status: GstFilingStatus.filed,
        dueDate: DateTime(2026, 3, 20),
      ),
      GstFilingPeriod(
        label: 'Jan 2026',
        liability: 2890,
        status: GstFilingStatus.filed,
        dueDate: DateTime(2026, 2, 20),
      ),
    ],
  ),
];
