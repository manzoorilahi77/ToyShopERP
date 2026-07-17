import 'package:flutter/material.dart';

import '../../core/core.dart';
import 'staff_management_data.dart';

/// Owner Staff Management — roster with performance, add/edit staff, PIN
/// admin and incentive rules (R5/R6).
/// Doc: docs/mobile/owner/staff/staff-management.md
class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final _repo = const StaffRepository();

  // Fixed "today" reference — matches Fmt.ago's hardcoded "now" used across
  // the prototype's dummy data (dashboard/reports/purchase all pin 03-07-2026).
  static final DateTime _today = DateTime(2026, 7, 3);

  List<StaffMember>? _staff;
  List<IncentiveRule>? _rules;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final staff = await _repo.staff();
    final rules = await _repo.rules();
    if (!mounted) return;
    setState(() {
      _staff = staff;
      _rules = rules;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Business rule (§8.2): no self-lockout — can't deactivate/demote the last
  /// active owner.
  bool _isLastActiveOwner(StaffMember m) {
    final staff = _staff;
    if (staff == null || m.role != UserRole.owner || !m.isActive) return false;
    return staff.where((s) => s.role == UserRole.owner && s.isActive).length <= 1;
  }

  // ---- gated actions -------------------------------------------------

  Future<void> _toggleActive(StaffMember m, {VoidCallback? after}) async {
    if (m.isActive && _isLastActiveOwner(m)) {
      _toast("Can't deactivate the last active owner");
      return;
    }
    final ok = await showOwnerPinSheet(
      context,
      title: m.isActive ? 'Deactivate ${m.name}?' : 'Activate ${m.name}?',
      subtitle: m.isActive
          ? '${m.name} will lose Staff App access; sales history stays intact.'
          : '${m.name} will regain Staff App access.',
    );
    if (ok != true || !mounted) return;
    
    await _repo.updateActiveStatus(m.id, !m.isActive);
    await _load();
    
    if (!mounted) return;
    after?.call();
    _toast(!m.isActive ? 'Staff activated' : 'Staff deactivated');
  }

  Future<void> _resetPin(StaffMember m) async {
    final newPin = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResetPinSheet(name: m.name),
    );
    if (newPin == null || !mounted) return;
    final ok = await showOwnerPinSheet(
      context,
      title: 'Verify to reset PIN',
      subtitle: "Confirm with your owner PIN to reset ${m.name}'s PIN.",
    );
    if (ok != true || !mounted) return;
    // PROTOTYPE: pin_hash would be overwritten server-side; never displayed.
    _toast('PIN reset for ${m.name}');
  }

  int _getRoleId(UserRole role) {
    switch (role) {
      case UserRole.superAdmin: return 1;
      case UserRole.owner: return 2;
      case UserRole.manager: return 3;
      case UserRole.staff: return 4;
      default: return 4;
    }
  }

  Future<void> _openAddEdit({StaffMember? existing}) async {
    final online = SessionScope.read(context).isOnline;
    final result = await showModalBottomSheet<_StaffFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StaffFormSheet(
        existing: existing,
        isLastActiveOwner: existing != null && _isLastActiveOwner(existing),
        online: online,
        today: _today,
      ),
    );
    if (result == null || !mounted) return;
    
    final staffData = {
      'name': result.name,
      'email': result.email,
      'roleId': _getRoleId(result.role),
      'branchId': 1, // Defaulting to first branch for now
      'phone': result.phone,
    };

    if (existing == null) {
      staffData['password'] = result.pin;
      await _repo.add(staffData);
    } else {
      if (result.pin.isNotEmpty) {
        staffData['password'] = result.pin;
      }
      await _repo.update(existing.id, staffData);
    }
    
    await _load();
    if (!mounted) return;
    _toast(existing == null ? 'Staff added' : 'Staff saved');
  }

  Future<void> _openRuleForm({IncentiveRule? existing}) async {
    final result = await showModalBottomSheet<_RuleFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RuleFormSheet(existing: existing),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (existing == null) {
        final list = _rules ?? <IncentiveRule>[];
        _rules = [
          ...list,
          IncentiveRule(
            id: 'NEW-${DateTime.now().millisecondsSinceEpoch}',
            label: result.label,
            targetUnits: result.targetUnits,
            reward: result.reward,
            isActive: result.isActive,
          ),
        ];
      } else {
        existing
          ..label = result.label
          ..targetUnits = result.targetUnits
          ..reward = result.reward
          ..isActive = result.isActive;
      }
    });
    _toast(existing == null ? 'Incentive rule added' : 'Incentive rule saved');
  }

  void _toggleRule(IncentiveRule r) {
    setState(() => r.isActive = !r.isActive);
    _toast(r.isActive ? 'Rule activated' : 'Rule paused');
  }

  void _openDetail(StaffMember m) {
    final online = SessionScope.read(context).isOnline;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (innerCtx, setSheetState) => _StaffDetailSheet(
          member: m,
          online: online,
          isLastActiveOwner: _isLastActiveOwner(m),
          today: _today,
          onResetPin: () {
            Navigator.of(sheetCtx).pop();
            _resetPin(m);
          },
          onEdit: () {
            Navigator.of(sheetCtx).pop();
            _openAddEdit(existing: m);
          },
          onToggleActive: () => _toggleActive(m, after: () => setSheetState(() {})),
          onViewHistory: () => _toast('Opens full history on Web — prototype'),
        ),
      ),
    );
  }

  // ---- build -------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final staff = _staff;
    final rules = _rules;
    final loading = staff == null || rules == null;
    final online = SessionScope.of(context).isOnline;

    return AppScaffold(
      title: 'Staff',
      subtitle: loading ? null : '${staff.length} team members',
      actions: [
        IconButton(
          tooltip: 'Add staff',
          onPressed: loading ? null : () => _openAddEdit(),
          icon: const Icon(Icons.person_add_alt_1_rounded),
        ),
      ],
      body: loading
          ? _loading()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _search(),
                  const SizedBox(height: 12),
                  ..._staffSection(staff, online),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openAddEdit(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Staff'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SectionHeader(
                    title: 'Incentive Rules',
                    subtitle: 'Monthly-unit tiers & rewards',
                    actionLabel: '+ Add rule',
                    onAction: () => _openRuleForm(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 10),
                  ..._ruleSection(rules),
                ],
              ),
            ),
    );
  }

  Widget _loading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SkeletonBox(height: 44, radius: 12),
        SizedBox(height: 14),
        SkeletonBox(height: 90, radius: 12),
        SizedBox(height: 10),
        SkeletonBox(height: 90, radius: 12),
        SizedBox(height: 10),
        SkeletonBox(height: 90, radius: 12),
        SizedBox(height: 26),
        SkeletonBox(height: 18, width: 160, radius: 6),
        SizedBox(height: 12),
        SkeletonBox(height: 64, radius: 12),
        SizedBox(height: 10),
        SkeletonBox(height: 64, radius: 12),
      ],
    );
  }

  Widget _search() {
    return TextField(
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        hintText: 'Search staff',
        prefixIcon: const Icon(Icons.search_rounded),
        isDense: true,
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _query = ''),
              ),
      ),
    );
  }

  List<Widget> _staffSection(List<StaffMember> staff, bool online) {
    final p = context.palette;
    if (staff.isEmpty) {
      return [
        EmptyState(
          icon: Icons.groups_rounded,
          title: 'No staff yet',
          message: 'Add your team to get started.',
          actionLabel: 'Add staff',
          onAction: () => _openAddEdit(),
        ),
      ];
    }
    final q = _query.trim().toLowerCase();
    final visible =
        q.isEmpty ? staff : staff.where((s) => s.name.toLowerCase().contains(q)).toList();
    if (visible.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text('No staff match "$_query"', style: AppType.body.copyWith(color: p.inkMuted)),
          ),
        ),
      ];
    }
    return [
      for (final m in visible) ...[
        _staffRow(m, online),
        const SizedBox(height: 10),
      ],
    ];
  }

  Widget _staffRow(StaffMember m, bool online) {
    final p = context.palette;
    final blockDeactivate = m.isActive && _isLastActiveOwner(m);
    final switchEnabled = online && !blockDeactivate;
    final tooltip = !online
        ? 'Connect to change'
        : blockDeactivate
            ? "Last active owner — can't deactivate"
            : (m.isActive ? 'Deactivate' : 'Activate');

    return AppCard(
      onTap: () => _openDetail(m),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarBadge(initials: m.initials, color: m.color, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        m.name,
                        style: AppType.title.copyWith(color: p.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    TonePill.tone(Tone.info, m.role.label, dense: true),
                  ],
                ),
                const SizedBox(height: 3),
                Text('Joined ${Fmt.date(m.joinDate)}', style: AppType.caption.copyWith(color: p.inkMuted)),
                const SizedBox(height: 6),
                Text(
                  '${Fmt.money0(m.monthRevenue)} · ${m.monthUnits} units this month',
                  style: AppType.caption.copyWith(color: p.ink, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: tooltip,
                child: Switch(
                  value: m.isActive,
                  onChanged: switchEnabled ? (_) => _toggleActive(m) : null,
                ),
              ),
              Text(
                m.isActive ? 'Active' : 'Inactive',
                style: AppType.caption.copyWith(
                  color: m.isActive ? p.success : p.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _ruleSection(List<IncentiveRule> rules) {
    final p = context.palette;
    if (rules.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'No incentive rules yet — add one to motivate the team.',
            style: AppType.body.copyWith(color: p.inkMuted),
          ),
        ),
      ];
    }
    return [
      for (final r in rules) ...[
        _ruleRow(r),
        const SizedBox(height: 10),
      ],
    ];
  }

  Widget _ruleRow(IncentiveRule r) {
    final p = context.palette;
    return AppCard(
      onTap: () => _openRuleForm(existing: r),
      padding: const EdgeInsets.all(12),
      borderColor: r.isActive ? null : p.border,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (r.isActive ? p.primary : p.inkMuted).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: r.isActive ? p.primary : p.inkMuted,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.label, style: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${r.targetUnits} units/month → ${r.reward}',
                  style: AppType.caption.copyWith(color: p.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Switch(value: r.isActive, onChanged: (_) => _toggleRule(r)),
        ],
      ),
    );
  }
}

String _initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length > 1 ? 2 : 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

/// Shared rounded-sheet chrome (drag handle + title, keyboard-safe) for the
/// form sheets on this screen — mirrors the New Purchase screen's
/// `_SheetShell` since `bottomSheetTheme` is bypassed via
/// `backgroundColor: Colors.transparent`.
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Container(
          decoration: BoxDecoration(color: p.surface, borderRadius: AppRadii.sheet),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(title, style: AppType.h2.copyWith(color: p.ink)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppType.caption.copyWith(color: p.inkMuted)),
                ],
                const SizedBox(height: AppSpacing.lg),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Staff detail — performance snapshot + Reset PIN / Edit / Activate.
// ---------------------------------------------------------------------------

class _StaffDetailSheet extends StatelessWidget {
  const _StaffDetailSheet({
    required this.member,
    required this.online,
    required this.isLastActiveOwner,
    required this.today,
    required this.onResetPin,
    required this.onEdit,
    required this.onToggleActive,
    required this.onViewHistory,
  });

  final StaffMember member;
  final bool online;
  final bool isLastActiveOwner;
  final DateTime today;
  final VoidCallback onResetPin;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = member;
    final blockDeactivate = m.isActive && isLastActiveOwner;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AvatarBadge(initials: m.initials, color: m.color, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: AppType.h2.copyWith(color: p.ink)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          TonePill.tone(Tone.info, m.role.label, dense: true),
                          TonePill.tone(
                            m.isActive ? Tone.success : Tone.neutral,
                            m.isActive ? 'Active' : 'Inactive',
                            icon: m.isActive
                                ? Icons.check_circle_rounded
                                : Icons.remove_circle_outline_rounded,
                            dense: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LabeledRow('Phone', Text(m.phone.isEmpty ? '—' : m.phone)),
            LabeledRow('Joined', Text(Fmt.date(m.joinDate))),
            const SizedBox(height: 6),
            Divider(color: p.border),
            const SizedBox(height: 6),
            Text('Performance snapshot', style: AppType.title.copyWith(color: p.ink)),
            const SizedBox(height: 6),
            LabeledRow('Today', Text('${Fmt.money0(m.todayRevenue)} · ${m.todayUnits} units')),
            LabeledRow(
              'This month',
              Text('${Fmt.money0(m.monthRevenue)} · pts ${Fmt.count(m.points)}'),
            ),
            LabeledRow('Lifetime', Text(Fmt.money0(m.lifetimeSales))),
            if (m.rank > 0) LabeledRow('Rank', Text('#${m.rank} this month')),
            if (m.badges.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Badges', style: AppType.label.copyWith(color: p.inkMuted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final b in m.badges)
                    TonePill.tone(Tone.warning, b, icon: Icons.military_tech_rounded, dense: true),
                ],
              ),
            ],
            if (m.incentiveTierLabel.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Incentive progress', style: AppType.label.copyWith(color: p.inkMuted)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: m.incentiveProgressPct / 100,
                  minHeight: 8,
                  backgroundColor: p.border,
                  color: p.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${m.incentiveProgressPct}% to ${m.incentiveTierLabel}',
                style: AppType.caption.copyWith(color: p.inkMuted),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Snapshot cached · as of ${Fmt.dateMed(today)}',
              style: AppType.caption.copyWith(color: p.inkMuted),
            ),
            const SizedBox(height: 16),
            if (!online)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Connect to the internet to reset PIN or change active state.',
                  style: AppType.caption.copyWith(color: p.warning),
                ),
              ),
            if (blockDeactivate)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "Can't deactivate — this is the last active owner.",
                  style: AppType.caption.copyWith(color: p.warning),
                ),
              ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: online ? onResetPin : null,
                  icon: const Icon(Icons.lock_rounded, size: 16),
                  label: const Text('Reset PIN'),
                ),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  onPressed: (online && !blockDeactivate) ? onToggleActive : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: m.isActive ? p.danger : p.success,
                    side: BorderSide(color: m.isActive ? p.danger : p.success),
                  ),
                  icon: Icon(m.isActive ? Icons.lock_rounded : Icons.lock_open_rounded, size: 16),
                  label: Text(m.isActive ? 'Deactivate' : 'Activate'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: onViewHistory,
                child: const Text('View full history → web'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add / edit staff form.
// ---------------------------------------------------------------------------

class _StaffFormResult {
  const _StaffFormResult({
    required this.name,
    required this.email,
    required this.role,
    required this.phone,
    required this.pin,
    required this.joinDate,
  });
  final String name;
  final String email;
  final UserRole role;
  final String phone;
  final String pin;
  final DateTime joinDate;
}

class _StaffFormSheet extends StatefulWidget {
  const _StaffFormSheet({
    required this.existing,
    required this.isLastActiveOwner,
    required this.online,
    required this.today,
  });

  final StaffMember? existing;
  final bool isLastActiveOwner;
  final bool online;
  final DateTime today;

  @override
  State<_StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends State<_StaffFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  late UserRole _role;
  late DateTime _joinDate;
  String? _error;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  bool get _valid {
    if (_nameCtrl.text.trim().isEmpty) return false;
    if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) return false;
    if (!_isEdit) {
      final pin = _pinCtrl.text.trim();
      if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) return false;
      if (pin != _confirmCtrl.text.trim()) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _emailCtrl = TextEditingController(text: ''); // Demo doesn't have email
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _role = e?.role ?? UserRole.staff;
    _joinDate = e?.joinDate ?? widget.today;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickJoinDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joinDate,
      firstDate: DateTime(2015),
      lastDate: widget.today,
    );
    if (picked != null) setState(() => _joinDate = picked);
  }

  Future<void> _save() async {
    if (!_valid || _busy) return;
    setState(() => _error = null);

    final roleChanged = _isEdit && widget.existing!.role != _role;
    if (roleChanged) {
      if (widget.isLastActiveOwner && widget.existing!.role == UserRole.owner) {
        setState(() => _error = "Can't change the last active owner's role");
        return;
      }
      if (!widget.online) {
        setState(() => _error = 'Connect to the internet to change role');
        return;
      }
      setState(() => _busy = true);
      final ok = await showOwnerPinSheet(
        context,
        title: 'Verify role change',
        subtitle: "Confirm with your owner PIN to change ${widget.existing!.name}'s role.",
      );
      if (!mounted) return;
      setState(() => _busy = false);
      if (ok != true) return;
    }

    Navigator.of(context).pop(
      _StaffFormResult(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        role: _role,
        phone: _phoneCtrl.text.trim(),
        pin: _pinCtrl.text.trim(),
        joinDate: _joinDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _SheetShell(
      title: _isEdit ? 'Edit staff' : 'Add staff',
      subtitle: _isEdit ? null : 'Sets up their Staff App login',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: !_isEdit,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Name *'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Email *'),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<UserRole>(
            initialValue: _role,
            decoration: InputDecoration(
              labelText: 'Role',
              suffixIcon: _isEdit ? Icon(Icons.lock_rounded, size: 16, color: p.inkMuted) : null,
            ),
            items: [
              for (final r in UserRole.values) DropdownMenuItem(value: r, child: Text(r.label)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _role = v);
            },
          ),
          if (_isEdit) ...[
            const SizedBox(height: 4),
            Text(
              'Changing role needs owner verification',
              style: AppType.caption.copyWith(color: p.inkMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)'),
          ),
          const SizedBox(height: AppSpacing.md),
          _dateField(p),
          if (!_isEdit) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Initial PIN (4–6 digits)', counterText: ''),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Confirm PIN', counterText: ''),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: AppType.caption.copyWith(color: p.danger)),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _valid && !_busy ? _save : null,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEdit ? 'Save' : 'Add staff'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(AppPalette p) {
    return Material(
      color: p.surface,
      borderRadius: AppRadii.card,
      child: InkWell(
        borderRadius: AppRadii.card,
        onTap: _pickJoinDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(borderRadius: AppRadii.card, border: Border.all(color: p.border)),
          child: Row(
            children: [
              Icon(Icons.event_rounded, size: 18, color: p.inkMuted),
              const SizedBox(width: 10),
              Text('Join date', style: AppType.body.copyWith(color: p.inkMuted)),
              const Spacer(),
              Text(
                Fmt.date(_joinDate),
                style: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reset PIN — new PIN + confirm; owner-PIN verification happens afterwards
// via showOwnerPinSheet (see _resetPin above), matching the wireframe's
// "new PIN → confirm PIN → verify with owner PIN" order.
// ---------------------------------------------------------------------------

class _ResetPinSheet extends StatefulWidget {
  const _ResetPinSheet({required this.name});
  final String name;

  @override
  State<_ResetPinSheet> createState() => _ResetPinSheetState();
}

class _ResetPinSheetState extends State<_ResetPinSheet> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    final pin = _pinCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      setState(() => _error = 'PIN must be 4–6 digits');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PINs do not match');
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _SheetShell(
      title: 'Reset PIN',
      subtitle: 'Set a new PIN for ${widget.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinCtrl,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'New PIN (4–6 digits)', counterText: ''),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _confirmCtrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'Confirm PIN', counterText: ''),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: AppType.caption.copyWith(color: p.danger)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            "Next you'll verify with your owner PIN.",
            style: AppType.caption.copyWith(color: p.inkMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _continue, child: const Text('Continue')),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add / edit incentive rule.
// ---------------------------------------------------------------------------

class _RuleFormResult {
  const _RuleFormResult({
    required this.label,
    required this.targetUnits,
    required this.reward,
    required this.isActive,
  });
  final String label;
  final int targetUnits;
  final String reward;
  final bool isActive;
}

class _RuleFormSheet extends StatefulWidget {
  const _RuleFormSheet({this.existing});
  final IncentiveRule? existing;

  @override
  State<_RuleFormSheet> createState() => _RuleFormSheetState();
}

class _RuleFormSheetState extends State<_RuleFormSheet> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _rewardCtrl;
  late bool _active;

  bool get _isEdit => widget.existing != null;

  bool get _valid =>
      _labelCtrl.text.trim().isNotEmpty &&
      (int.tryParse(_targetCtrl.text.trim()) ?? 0) > 0 &&
      _rewardCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelCtrl = TextEditingController(text: e?.label ?? '');
    _targetCtrl = TextEditingController(text: e == null ? '' : e.targetUnits.toString());
    _rewardCtrl = TextEditingController(text: e?.reward ?? '');
    _active = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _targetCtrl.dispose();
    _rewardCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_valid) return;
    Navigator.of(context).pop(
      _RuleFormResult(
        label: _labelCtrl.text.trim(),
        targetUnits: int.parse(_targetCtrl.text.trim()),
        reward: _rewardCtrl.text.trim(),
        isActive: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _SheetShell(
      title: _isEdit ? 'Edit incentive rule' : 'Add incentive rule',
      subtitle: 'Hit a monthly-unit target, earn the reward',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labelCtrl,
            autofocus: !_isEdit,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Tier label *', hintText: 'e.g. Tier 2 — Pro'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _targetCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Target units / month *'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _rewardCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Reward *', hintText: 'e.g. ₹2,000 bonus'),
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            title: const Text('Active'),
            subtitle: Text(
              _active ? 'Counts toward staff progress' : 'Paused — hidden from staff progress',
              style: AppType.caption.copyWith(color: p.inkMuted),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _valid ? _save : null,
              child: Text(_isEdit ? 'Save rule' : 'Add rule'),
            ),
          ),
        ],
      ),
    );
  }
}
