import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/core.dart';
import 'discount_approval_data.dart';

/// Owner Discount Approval — the 🔒 PIN-gated approve/reject queue for staff
/// discount requests; the anti money-leak control referenced across the
/// owner flows (overview.md §6.5).
/// Doc: docs/mobile/owner/approvals/discount-approval.md
class DiscountApprovalScreen extends StatefulWidget {
  const DiscountApprovalScreen({super.key});

  @override
  State<DiscountApprovalScreen> createState() => _DiscountApprovalScreenState();
}

class _DiscountApprovalScreenState extends State<DiscountApprovalScreen> {
  final _repo = const DiscountApprovalRepository();
  List<DiscountRequest>? _pending;
  List<DiscountRequest>? _history;
  _ApprovalTab _tab = _ApprovalTab.pending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([_repo.pending(), _repo.history()]);
    if (!mounted) return;
    setState(() {
      _pending = results[0];
      _history = results[1];
    });
  }

  /// 🔒 The money-leak guard: nothing leaves `pending` without the owner's PIN.
  Future<void> _approve(DiscountRequest r) async {
    final approved = await showOwnerPinSheet(
      context,
      title: 'Approve discount',
      subtitle: '${r.staffName} · ${Fmt.money(r.discountAmount)} off ${r.itemSummary}',
    );
    if (approved != true || !mounted) return;
    final owner = SessionScope.read(context).account?.name;
    setState(() {
      _pending = _pending?.where((e) => e.id != r.id).toList();
      _history = [
        r.copyWith(status: DiscountRequestStatus.approved, decidedAt: DateTime.now(), decidedBy: owner),
        ...?_history,
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.palette.success,
        content: Text('Approved ${Fmt.money(r.requestedPrice)} for ${r.staffName}'),
      ),
    );
    _repo.decide(r.id, DiscountRequestStatus.approved, decidedBy: owner);
  }

  /// 🔒 Every decision needs the owner's PIN — not just Approve (doc rule 1,
  /// §5 row 10). Rejecting still unblocks the staff cart at full price.
  Future<void> _reject(DiscountRequest r) async {
    final confirmed = await showOwnerPinSheet(
      context,
      title: 'Reject discount',
      subtitle: '${r.staffName} asked for ${Fmt.money(r.discountAmount)} off '
          '"${r.itemSummary}" — they\'ll see this was not approved.',
    );
    if (confirmed != true || !mounted) return;
    final owner = SessionScope.read(context).account?.name;
    setState(() {
      _pending = _pending?.where((e) => e.id != r.id).toList();
      _history = [
        r.copyWith(status: DiscountRequestStatus.rejected, decidedAt: DateTime.now(), decidedBy: owner),
        ...?_history,
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rejected — ${r.staffName} will be notified')),
    );
    _repo.decide(r.id, DiscountRequestStatus.rejected, decidedBy: owner);
  }

  void _showHistoryDetail(DiscountRequest r) {
    final p = context.palette;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(sheetContext).padding.bottom),
        child: SingleChildScrollView(child: _RequestDetailSheet(request: r)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _pending?.length;
    return AppScaffold(
      title: 'Approvals',
      subtitle: pendingCount == null
          ? null
          : (pendingCount == 0 ? 'All caught up' : '$pendingCount awaiting your approval'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: _ApprovalTabs(
              tab: _tab,
              pendingCount: pendingCount ?? 0,
              onChanged: (t) => setState(() => _tab = t),
            ),
          ),
          Expanded(child: _tab == _ApprovalTab.pending ? _pendingView() : _historyView()),
        ],
      ),
    );
  }

  Widget _pendingView() {
    final list = _pending;
    if (list == null) return _skeleton();
    // Approve/Reject are control actions that must reach the server to
    // unblock the staff cart — they're disabled (not hidden) offline, never
    // queued (doc §10 "Requires online").
    final online = SessionScope.of(context).isOnline;
    return RefreshIndicator(
      onRefresh: _load,
      child: list.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 60),
                EmptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'All caught up',
                  message: 'No discount requests are waiting for your approval right now.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _PendingCard(
                request: list[i],
                online: online,
                onApprove: () => _approve(list[i]),
                onReject: () => _reject(list[i]),
              ),
            ),
    );
  }

  Widget _historyView() {
    final list = _history;
    if (list == null) return _skeleton();
    return RefreshIndicator(
      onRefresh: _load,
      child: list.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 60),
                EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No decisions yet',
                  message: 'Approved and rejected discount requests will show up here.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _HistoryTile(
                request: list[i],
                onTap: () => _showHistoryDetail(list[i]),
              ),
            ),
    );
  }

  Widget _skeleton() => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SkeletonBox(height: 190, radius: 12),
          SizedBox(height: 12),
          SkeletonBox(height: 190, radius: 12),
          SizedBox(height: 12),
          SkeletonBox(height: 120, radius: 12),
        ],
      );
}

enum _ApprovalTab { pending, history }

/// Full-width Pending/History segmented switch.
class _ApprovalTabs extends StatelessWidget {
  const _ApprovalTabs({
    required this.tab,
    required this.pendingCount,
    required this.onChanged,
  });

  final _ApprovalTab tab;
  final int pendingCount;
  final ValueChanged<_ApprovalTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    Widget seg(_ApprovalTab value, String label) {
      final selected = value == tab;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? p.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: p.ink.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: AppType.label.copyWith(
                color: selected ? p.ink : p.inkMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          seg(_ApprovalTab.pending, pendingCount > 0 ? 'Pending ($pendingCount)' : 'Pending'),
          seg(_ApprovalTab.history, 'History'),
        ],
      ),
    );
  }
}

/// One pending request — everything the owner needs to decide, plus the
/// Approve/Reject actions, on a single card (no drill-down required).
class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.request,
    required this.online,
    required this.onApprove,
    required this.onReject,
  });

  final DiscountRequest request;
  final bool online;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  void _copyRef(BuildContext context) {
    Clipboard.setData(ClipboardData(text: request.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${request.id}'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = request;
    return AppCard(
      borderColor: r.isHighRisk ? p.danger.withValues(alpha: 0.4) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TonePill.tone(Tone.warning, 'Pending', icon: Icons.hourglass_bottom_rounded, dense: true),
              const Spacer(),
              Text(Fmt.ago(r.requestedAt), style: AppType.caption.copyWith(color: p.inkMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              AvatarBadge(initials: r.staffInitials, color: r.staffColor, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.staffName, style: AppType.title.copyWith(color: p.ink)),
                    Text(
                      '${r.saleRef} · ${r.itemCount} item${r.itemCount == 1 ? '' : 's'}',
                      style: AppType.caption.copyWith(color: p.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            r.itemSummary,
            style: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    MoneyText(Fmt.money(r.originalPrice), strikethrough: true, color: p.inkMuted),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: p.inkMuted),
                    MoneyText(Fmt.money(r.requestedPrice), style: AppType.title, color: p.ink),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TonePill.tone(
                r.isHighRisk ? Tone.danger : Tone.warning,
                '-${Fmt.money(r.discountAmount)} · ${r.discountPct.toStringAsFixed(0)}%',
                icon: Icons.local_offer_rounded,
                dense: true,
              ),
            ],
          ),
          if (r.isHighRisk) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.report_rounded, size: 15, color: p.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'High discount — read the reason carefully before approving.',
                    style: AppType.caption.copyWith(color: p.danger, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(10)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded, size: 16, color: p.inkMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    r.reason,
                    style: AppType.body.copyWith(color: p.ink, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _copyRef(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tag_rounded, size: 13, color: p.inkMuted),
                  const SizedBox(width: 4),
                  Text(
                    'ref: ${r.id} · tap to copy',
                    style: AppType.caption.copyWith(
                      color: p.inkMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!online) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.cloud_off_rounded, size: 15, color: p.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Connect to approve discounts',
                    style: AppType.caption.copyWith(color: p.warning, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: online ? onReject : null,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.danger,
                      side: BorderSide(color: p.danger.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: online ? onApprove : null,
                    icon: const Icon(Icons.lock_rounded, size: 18),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact, tappable audit row for a decided request.
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.request, required this.onTap});

  final DiscountRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = request;
    final approved = r.status == DiscountRequestStatus.approved;
    final tone = approved ? Tone.success : Tone.danger;

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarBadge(initials: r.staffInitials, color: r.staffColor, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.staffName} · ${r.itemSummary}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${Fmt.money(r.originalPrice)} → ${Fmt.money(r.requestedPrice)} '
                  '· ${r.discountPct.toStringAsFixed(0)}% off',
                  style: AppType.caption.copyWith(color: p.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TonePill.tone(
                tone,
                approved ? 'Approved' : 'Rejected',
                icon: approved ? Icons.check_circle_rounded : Icons.cancel_rounded,
                dense: true,
              ),
              const SizedBox(height: 4),
              Text(
                Fmt.ago(r.decidedAt ?? r.requestedAt),
                style: AppType.caption.copyWith(color: p.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full detail sheet opened from a [_HistoryTile] tap — the compact row
/// trims the reason text, so this is where the full record lives.
class _RequestDetailSheet extends StatelessWidget {
  const _RequestDetailSheet({required this.request});

  final DiscountRequest request;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = request;
    final approved = r.status == DiscountRequestStatus.approved;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AvatarBadge(initials: r.staffInitials, color: r.staffColor, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.staffName, style: AppType.title.copyWith(color: p.ink)),
                  Text(r.saleRef, style: AppType.caption.copyWith(color: p.inkMuted)),
                ],
              ),
            ),
            TonePill.tone(
              approved ? Tone.success : Tone.danger,
              approved ? 'Approved' : 'Rejected',
              icon: approved ? Icons.check_circle_rounded : Icons.cancel_rounded,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        LabeledRow('Items', Text(r.itemSummary)),
        LabeledRow(
          'Original price',
          MoneyText(Fmt.money(r.originalPrice), strikethrough: true, color: p.inkMuted),
        ),
        LabeledRow('Requested price', MoneyText(Fmt.money(r.requestedPrice))),
        LabeledRow(
          'Discount',
          Text(
            '${Fmt.money(r.discountAmount)} (${r.discountPct.toStringAsFixed(0)}%)',
            style: AppType.money.copyWith(color: p.danger),
          ),
        ),
        LabeledRow('Requested', Text(Fmt.dateTime(r.requestedAt))),
        if (r.decidedAt != null)
          LabeledRow(
            approved ? 'Approved' : 'Rejected',
            Text(
              r.decidedBy == null
                  ? Fmt.dateTime(r.decidedAt!)
                  : '${Fmt.dateTime(r.decidedAt!)} · ${r.decidedBy}',
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text('Reason given', style: AppType.label.copyWith(color: p.inkMuted)),
        const SizedBox(height: 4),
        Text(r.reason, style: AppType.body.copyWith(color: p.ink)),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }
}
