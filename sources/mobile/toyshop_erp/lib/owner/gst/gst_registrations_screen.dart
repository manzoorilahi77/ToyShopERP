import 'package:flutter/material.dart';

import '../../core/core.dart';
import 'gst_registrations_data.dart';

/// Owner "GST Registrations" — manage the shop's GSTIN(s): add/edit, see
/// per-GSTIN liability & filing status, activate/deactivate (🔒 PIN-gated).
/// Doc: docs/mobile/owner/gst/gst-registrations.md
class GstRegistrationsScreen extends StatefulWidget {
  const GstRegistrationsScreen({super.key});

  @override
  State<GstRegistrationsScreen> createState() => _GstRegistrationsScreenState();
}

class _GstRegistrationsScreenState extends State<GstRegistrationsScreen> {
  final _repo = const GstRegistrationsRepository();
  List<GstRegistration>? _regs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _repo.all();
    if (mounted) setState(() => _regs = r);
  }

  @override
  Widget build(BuildContext context) {
    final regs = _regs;
    return AppScaffold(
      title: 'GST Registrations',
      subtitle: regs == null
          ? null
          : '${regs.length} registration${regs.length == 1 ? '' : 's'} · '
                '${regs.where((r) => r.isActive).length} active',
      actions: [
        IconButton(
          onPressed: regs == null ? null : _openAddSheet,
          icon: const Icon(Icons.add_circle_rounded),
          tooltip: 'Add GSTIN',
        ),
      ],
      body: regs == null
          ? _loading()
          : regs.isEmpty
          ? EmptyState(
              icon: Icons.description_rounded,
              title: 'No GST registrations yet',
              message: 'Add your GSTIN to start filing sales & purchases correctly.',
              actionLabel: 'Add GSTIN',
              onAction: _openAddSheet,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _summaryCard(regs),
                  const SizedBox(height: 18),
                  const SectionHeader(
                    title: 'Registrations',
                    subtitle: 'Tap a GSTIN for filing periods',
                  ),
                  for (final r in regs) ...[
                    _GstCard(
                      registration: r,
                      onTap: () => _openDetailSheet(r),
                      onActiveChanged: (v) => _setActive(r, v),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _loading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SkeletonBox(height: 96, radius: 12),
        SizedBox(height: 18),
        SkeletonBox(height: 18, width: 160),
        SizedBox(height: 12),
        SkeletonBox(height: 132, radius: 12),
        SizedBox(height: 10),
        SkeletonBox(height: 132, radius: 12),
        SizedBox(height: 10),
        SkeletonBox(height: 132, radius: 12),
      ],
    );
  }

  Widget _summaryCard(List<GstRegistration> regs) {
    final p = context.palette;
    final active = regs.where((r) => r.isActive).toList();
    final total = active.fold<double>(0, (sum, r) => sum + r.currentPeriodLiability);
    final overdue = active.where((r) => r.filingStatus == GstFilingStatus.overdue).length;
    return KpiCard(
      label: 'TOTAL LIABILITY · ACTIVE GSTINs',
      value: Fmt.money(total),
      icon: Icons.receipt_long_rounded,
      accent: overdue > 0 ? p.danger : p.warning,
      footnote: overdue > 0
          ? '${active.length} active · $overdue overdue filing${overdue == 1 ? '' : 's'}'
          : '${active.length} active GSTIN${active.length == 1 ? '' : 's'} this period',
    );
  }

  Future<void> _openAddSheet() async {
    final result = await showModalBottomSheet<GstRegistration>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GstFormSheet(
        existingGstins: (_regs ?? const []).map((r) => r.gstin).toList(),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _regs = [...(_regs ?? const []), result]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result.gstin} saved')),
    );
  }

  Future<void> _openEditSheet(GstRegistration r) async {
    final result = await showModalBottomSheet<GstRegistration>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GstFormSheet(
        existing: r,
        existingGstins: (_regs ?? const [])
            .where((x) => x.id != r.id)
            .map((x) => x.gstin)
            .toList(),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _regs = [for (final reg in _regs!) reg.id == r.id ? result : reg]);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('GSTIN updated')),
    );
  }

  void _openDetailSheet(GstRegistration r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GstDetailSheet(
        registration: r,
        onEdit: () => _openEditSheet(r),
        onMarkFiled: (period) => _markFiled(r, period),
        onPrepareFiling: (period) => _prepareFiling(r, period),
      ),
    );
  }

  Future<void> _setActive(GstRegistration r, bool value) async {
    if (!value) {
      final ok = await showOwnerPinSheet(
        context,
        title: 'Deactivate GSTIN',
        subtitle:
            '${r.formattedGstin} · ${r.displayName}\n'
            'It will no longer be selectable for new sales/purchases. History stays intact.',
      );
      if (ok != true) return;
    }
    if (!mounted) return;
    setState(() {
      _regs = [
        for (final reg in _regs!) reg.id == r.id ? reg.copyWith(isActive: value) : reg,
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? 'GSTIN activated' : 'GSTIN deactivated')),
    );
  }

  void _markFiled(GstRegistration r, GstFilingPeriod period) {
    setState(() {
      _regs = [
        for (final reg in _regs!)
          if (reg.id == r.id)
            reg.copyWith(
              filingStatus: GstFilingStatus.filed,
              lastFiledPeriod: period.label,
              periods: [
                for (final pr in reg.periods)
                  pr.label == period.label ? pr.copyWith(status: GstFilingStatus.filed) : pr,
              ],
            )
          else
            reg,
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Marked ${period.label} as filed for ${r.gstin}')),
    );
  }

  void _prepareFiling(GstRegistration r, GstFilingPeriod period) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Compiling ${period.label} sales & purchases for ${r.gstin}…',
        ),
      ),
    );
  }
}

/// One GSTIN row on the list — masked/formatted GSTIN, trade name, state,
/// this-period liability, filing-status pill and an active toggle.
class _GstCard extends StatelessWidget {
  const _GstCard({
    required this.registration,
    required this.onTap,
    required this.onActiveChanged,
  });

  final GstRegistration registration;
  final VoidCallback onTap;
  final ValueChanged<bool> onActiveChanged;

  Tone _statusTone(GstFilingStatus s) => switch (s) {
    GstFilingStatus.filed => Tone.success,
    GstFilingStatus.pending => Tone.warning,
    GstFilingStatus.overdue => Tone.danger,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = registration;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.confirmation_number_rounded, size: 16, color: p.inkMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  r.formattedGstin,
                  style: AppType.label.copyWith(color: p.ink, fontWeight: FontWeight.w700),
                ),
              ),
              Switch(value: r.isActive, onChanged: onActiveChanged),
            ],
          ),
          const SizedBox(height: 2),
          Text(r.displayName, style: AppType.title.copyWith(color: p.ink)),
          const SizedBox(height: 2),
          Text(
            '${r.state} · ${r.legalName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption.copyWith(color: p.inkMuted),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TonePill.tone(
                r.isActive ? Tone.success : Tone.neutral,
                r.isActive ? 'Active' : 'Inactive',
                icon: r.isActive ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                dense: true,
              ),
              const SizedBox(width: 8),
              TonePill.tone(
                _statusTone(r.filingStatus),
                r.filingStatus.label,
                icon: r.filingStatus.icon,
                dense: true,
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('this period', style: AppType.caption.copyWith(color: p.inkMuted)),
                  MoneyText(Fmt.money(r.currentPeriodLiability)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Last filed: ${r.lastFiledPeriod}',
            style: AppType.caption.copyWith(color: p.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet shown on tap — registration details, filing-period history
/// and the "Prepare filing" / "Mark as filed" actions for the current period.
class _GstDetailSheet extends StatelessWidget {
  const _GstDetailSheet({
    required this.registration,
    required this.onEdit,
    required this.onMarkFiled,
    required this.onPrepareFiling,
  });

  final GstRegistration registration;
  final VoidCallback onEdit;
  final ValueChanged<GstFilingPeriod> onMarkFiled;
  final ValueChanged<GstFilingPeriod> onPrepareFiling;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = registration;
    final current = r.periods.isNotEmpty ? r.periods.first : null;
    final pendingAction = current != null && current.status != GstFilingStatus.filed;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.formattedGstin, style: AppType.h2.copyWith(color: p.ink)),
                    const SizedBox(height: 2),
                    Text(r.displayName, style: AppType.body.copyWith(color: p.inkMuted)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onEdit();
                },
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TonePill.tone(
                r.isActive ? Tone.success : Tone.neutral,
                r.isActive ? 'Active' : 'Inactive',
                icon: r.isActive ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                dense: true,
              ),
              TonePill.tone(
                Tone.info,
                '${r.state} (${r.stateCode})',
                icon: Icons.map_rounded,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          LabeledRow('This period', MoneyText(Fmt.money(r.currentPeriodLiability))),
          LabeledRow(
            'Registered',
            Text(Fmt.date(r.registeredOn), style: AppType.body.copyWith(color: p.ink)),
          ),
          const SizedBox(height: 10),
          Text(
            'LEGAL NAME',
            style: AppType.caption.copyWith(color: p.inkMuted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(r.legalName, style: AppType.body.copyWith(color: p.ink)),
          const SizedBox(height: 10),
          Text(
            'ADDRESS',
            style: AppType.caption.copyWith(color: p.inkMuted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(r.address, style: AppType.body.copyWith(color: p.ink)),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Filing periods', padding: EdgeInsets.zero),
          const SizedBox(height: 4),
          if (r.periods.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No filing history yet.', style: AppType.body.copyWith(color: p.inkMuted)),
            )
          else
            for (final period in r.periods) _periodRow(context, period),
          const SizedBox(height: 16),
          if (pendingAction)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onPrepareFiling(current);
                    },
                    child: const Text('Prepare filing'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onMarkFiled(current);
                    },
                    child: const Text('Mark as filed'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(Icons.verified_rounded, size: 16, color: p.success),
                const SizedBox(width: 6),
                Text(
                  'All caught up — nothing pending',
                  style: AppType.caption.copyWith(color: p.success, fontWeight: FontWeight.w600),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _periodRow(BuildContext context, GstFilingPeriod period) {
    final p = context.palette;
    final tone = switch (period.status) {
      GstFilingStatus.filed => Tone.success,
      GstFilingStatus.pending => Tone.warning,
      GstFilingStatus.overdue => Tone.danger,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              period.label,
              style: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              period.status == GstFilingStatus.filed ? 'Filed' : 'Due ${Fmt.date(period.dueDate)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.caption.copyWith(color: p.inkMuted),
            ),
          ),
          TonePill.tone(tone, period.status.label, icon: period.status.icon, dense: true),
          const SizedBox(width: 10),
          MoneyText(Fmt.money(period.liability)),
        ],
      ),
    );
  }
}

/// Add/Edit GSTIN form sheet. GSTIN format is validated live (doc §5/§7); the
/// state is auto-derived from the first 2 digits and cannot diverge.
class _GstFormSheet extends StatefulWidget {
  const _GstFormSheet({this.existing, required this.existingGstins});

  /// Non-null when editing; null when adding a new registration.
  final GstRegistration? existing;

  /// Other GSTINs already on file (excluding [existing]) — mirrors the
  /// server's `409 CONFLICT` on a duplicate GSTIN (doc §8.1).
  final List<String> existingGstins;

  @override
  State<_GstFormSheet> createState() => _GstFormSheetState();
}

class _GstFormSheetState extends State<_GstFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _gstinCtrl = TextEditingController(text: widget.existing?.gstin ?? '');
  late final _legalCtrl = TextEditingController(text: widget.existing?.legalName ?? '');
  late final _tradeCtrl = TextEditingController(text: widget.existing?.tradeName ?? '');
  late final _addressCtrl = TextEditingController(text: widget.existing?.address ?? '');
  late bool _active = widget.existing?.isActive ?? true;
  String? _gstinError;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _gstinCtrl.dispose();
    _legalCtrl.dispose();
    _tradeCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final gstin = _gstinCtrl.text.trim().toUpperCase();
    if (widget.existingGstins.contains(gstin)) {
      setState(() => _gstinError = 'This GSTIN is already registered');
      return;
    }
    final stateName = gstStateNames[gstin.substring(0, 2)] ?? 'Unknown';
    final trade = _tradeCtrl.text.trim();
    final result = GstRegistration(
      id: widget.existing?.id ?? 'gst-${DateTime.now().microsecondsSinceEpoch}',
      gstin: gstin,
      legalName: _legalCtrl.text.trim(),
      tradeName: trade.isEmpty ? null : trade,
      address: _addressCtrl.text.trim(),
      state: stateName,
      isActive: _active,
      currentPeriodLiability: widget.existing?.currentPeriodLiability ?? 0,
      filingStatus: widget.existing?.filingStatus ?? GstFilingStatus.pending,
      lastFiledPeriod: widget.existing?.lastFiledPeriod ?? '—',
      registeredOn: widget.existing?.registeredOn ?? DateTime(2026, 7, 3),
      periods: widget.existing?.periods ?? const [],
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final rawGstin = _gstinCtrl.text.trim().toUpperCase();
    final validFormat = gstinFormat.hasMatch(rawGstin);
    final code = rawGstin.length >= 2 ? rawGstin.substring(0, 2) : null;
    final stateName = code == null ? null : gstStateNames[code];

    final String hintText;
    final Color hintColor;
    if (_editing) {
      hintText = 'GSTIN is locked after creation — deactivate and add a new one instead of changing it.';
      hintColor = p.inkMuted;
    } else if (code == null) {
      hintText = 'State auto-derives from the first 2 digits. Saved in uppercase.';
      hintColor = p.inkMuted;
    } else if (stateName != null) {
      hintText = '$stateName · state code $code';
      hintColor = p.info;
    } else {
      hintText = 'Unrecognized state code "$code" — double-check the first 2 digits.';
      hintColor = p.danger;
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + media.padding.bottom + media.viewInsets.bottom),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_editing ? 'Edit GSTIN' : 'Add GSTIN', style: AppType.h2.copyWith(color: p.ink)),
            const SizedBox(height: 4),
            Text(
              'Drives which sales & purchases are filed under this registration.',
              style: AppType.caption.copyWith(color: p.inkMuted),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _gstinCtrl,
              maxLength: 15,
              enabled: !_editing,
              style: AppType.body.copyWith(fontWeight: FontWeight.w700, color: p.ink),
              decoration: InputDecoration(
                labelText: 'GSTIN',
                hintText: 'e.g. 27ABCDE1234F1Z5',
                counterText: '',
                errorText: _gstinError,
                suffixIcon: _gstinCtrl.text.isEmpty
                    ? null
                    : Icon(
                        validFormat ? Icons.check_circle_rounded : Icons.error_rounded,
                        color: validFormat ? p.success : p.danger,
                      ),
              ),
              onChanged: (_) => setState(() => _gstinError = null),
              validator: (v) {
                final value = (v ?? '').trim().toUpperCase();
                if (value.isEmpty) return 'GSTIN is required';
                if (!gstinFormat.hasMatch(value)) {
                  return '15 characters: state + PAN + entity + Z + check digit';
                }
                return null;
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(hintText, style: AppType.caption.copyWith(color: hintColor)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _legalCtrl,
              maxLength: 150,
              decoration: const InputDecoration(labelText: 'Legal name', counterText: ''),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Legal name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tradeCtrl,
              maxLength: 150,
              decoration: const InputDecoration(labelText: 'Trade name (optional)', counterText: ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressCtrl,
              maxLength: 255,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Address', counterText: ''),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: Text('Active', style: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Selectable for new sales & purchases',
                style: AppType.caption.copyWith(color: p.inkMuted),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _save,
              child: Text(_editing ? 'Save changes' : 'Save GSTIN'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
