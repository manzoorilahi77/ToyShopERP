import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/core.dart';
import 'my_sales_history_data.dart';
import 'new_sale_screen.dart';
import 'receipt_data.dart';
import 'receipt_screen.dart';

/// Staff My Sales History — a scrollable, filterable/searchable list of the
/// logged-in staff member's own sales, with a totals summary and a per-row
/// sync-status icon; tap → [ReceiptScreen] for reprint/re-share.
/// Doc: docs/mobile/staff/sales/my-sales-history.md.
class MySalesHistoryScreen extends StatefulWidget {
  const MySalesHistoryScreen({super.key});

  @override
  State<MySalesHistoryScreen> createState() => _MySalesHistoryScreenState();
}

class _MySalesHistoryScreenState extends State<MySalesHistoryScreen> {
  final _repo = const MySalesHistoryRepository();
  final _receiptRepo = const ReceiptRepository();
  final _searchCtrl = TextEditingController();

  List<ReceiptData>? _rows;
  DateRangeFilter _filter = DateRangeFilter.today;
  DateTimeRange? _customRange;
  String _query = '';
  final Set<String> _retrying = {};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// `GET /sales?staff_id={me}&from=&to=` (doc §9) — own sales only, local +
  /// server union in a real build; here the demo dataset stands in for both.
  Future<void> _load() async {
    final rows = await _repo.load(
      filter: _filter,
      from: _customRange?.start,
      to: _customRange?.end,
      query: _query,
    );
    if (mounted) setState(() => _rows = rows);
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _query = v);
      _load();
    });
  }

  Future<void> _onFilterChanged(DateRangeFilter f) async {
    if (f == DateRangeFilter.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2026, 1, 1),
        lastDate: DateTime(2026, 12, 31),
        initialDateRange: _customRange ?? DateTimeRange(start: DateTime(2026, 7, 3), end: DateTime(2026, 7, 3)),
      );
      if (picked == null || !mounted) return;
      setState(() {
        _filter = DateRangeFilter.custom;
        _customRange = picked;
      });
      _load();
      return;
    }
    setState(() => _filter = f);
    _load();
  }

  /// Re-enqueues the same `client_uuid` — retrying never creates a duplicate
  /// sale (my-sales-history doc rule 3, receipt doc rule 6).
  Future<void> _retry(ReceiptData row) async {
    setState(() => _retrying.add(row.clientUuid));
    final updated = await _receiptRepo.awaitInvoiceNumber(row);
    if (!mounted) return;
    setState(() {
      _retrying.remove(row.clientUuid);
      _rows = _rows?.map((r) => r.clientUuid == row.clientUuid ? updated : r).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Synced')));
  }

  void _openReceipt(ReceiptData row) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(data: row)));
  }

  void _openNewSale() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewSaleScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final pending = rows?.where((r) => r.syncStatus != SyncState.synced).length ?? 0;
    return AppScaffold(
      title: 'My Sales',
      subtitle: rows == null ? null : '${_filter.label} · ${rows.length} sale${rows.length == 1 ? '' : 's'}',
      pendingCount: pending,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewSale,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Sale'),
      ),
      body: rows == null ? _loadingBody() : _content(rows),
    );
  }

  Widget _loadingBody() => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SkeletonBox(height: 40, radius: 20),
          SizedBox(height: 14),
          SkeletonBox(height: 96, radius: 14),
          SizedBox(height: 16),
          SkeletonBox(height: 68, radius: 12),
          SizedBox(height: 10),
          SkeletonBox(height: 68, radius: 12),
          SizedBox(height: 10),
          SkeletonBox(height: 68, radius: 12),
        ],
      );

  Widget _content(List<ReceiptData> rows) {
    final summary = _repo.summarize(rows);
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _filterRow()),
          SliverToBoxAdapter(child: _searchBar()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: _summaryCard(summary),
            ),
          ),
          if (rows.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _emptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _saleRow(rows[i]),
                  ),
                  childCount: rows.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterRow() {
    final p = context.palette;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        scrollDirection: Axis.horizontal,
        itemCount: DateRangeFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = DateRangeFilter.values[i];
          final selected = _filter == f;
          final isCustom = f == DateRangeFilter.custom;
          final label = isCustom && selected && _customRange != null
              ? '${Fmt.date(_customRange!.start)} – ${Fmt.date(_customRange!.end)}'
              : f.label;
          return InkWell(
            onTap: () => _onFilterChanged(f),
            borderRadius: AppRadii.chip,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? p.primary : p.surface,
                borderRadius: AppRadii.chip,
                border: Border.all(color: selected ? p.primary : p.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCustom) ...[
                    Icon(Icons.date_range_rounded, size: 14, color: selected ? p.primaryInk : p.inkMuted),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: AppType.label.copyWith(
                      color: selected ? p.primaryInk : p.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _searchBar() {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadii.chip,
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: p.inkMuted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onQueryChanged,
                style: AppType.body.copyWith(color: p.ink),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Search invoice or item…',
                  hintStyle: AppType.body.copyWith(color: p.inkMuted),
                ),
              ),
            ),
            if (_query.isNotEmpty)
              InkWell(
                onTap: () {
                  _searchCtrl.clear();
                  _onQueryChanged('');
                },
                child: Icon(Icons.close_rounded, size: 16, color: p.inkMuted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(SalesSummary s) {
    final p = context.palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 18, color: p.primary),
              const SizedBox(width: 8),
              Text('Summary', style: AppType.title.copyWith(color: p.ink)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statBlock('${s.saleCount}', 'sales'),
              _statBlock('${s.units}', 'units'),
              _statBlock(Fmt.money0(s.revenue), 'revenue'),
            ],
          ),
          if (s.byPayment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final m in PaymentMode.values)
                  if (s.byPayment[m] != null)
                    Text(
                      '${m.label} ${Fmt.money0(s.byPayment[m]!)}',
                      style: AppType.caption.copyWith(color: p.inkMuted, fontWeight: FontWeight.w600),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBlock(String value, String label) {
    final p = context.palette;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppType.h1.copyWith(color: p.ink)),
          Text(label, style: AppType.caption.copyWith(color: p.inkMuted)),
        ],
      ),
    );
  }

  Widget _saleRow(ReceiptData r) {
    final p = context.palette;
    final busy = _retrying.contains(r.clientUuid);
    final Widget statusWidget;
    if (r.syncStatus == SyncState.failed) {
      statusWidget = busy
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : InkWell(
              borderRadius: AppRadii.chip,
              onTap: () => _retry(r),
              child: TonePill(label: 'Failed · retry', color: p.danger, icon: Icons.error_rounded, dense: true),
            );
    } else {
      statusWidget = TonePill(
        label: r.syncStatus.label,
        color: r.syncStatus.color(p),
        icon: r.syncStatus.icon,
        dense: true,
      );
    }
    return AppCard(
      onTap: () => _openReceipt(r),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(Fmt.time(r.soldAt), style: AppType.caption.copyWith(color: p.inkMuted)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.displayRef,
                  style: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.totalUnits} item${r.totalUnits == 1 ? '' : 's'}',
                  style: AppType.caption.copyWith(color: p.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MoneyText(Fmt.money(r.total)),
              const SizedBox(height: 4),
              statusWidget,
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final filtered = _query.isNotEmpty || _filter != DateRangeFilter.today;
    return EmptyState(
      icon: Icons.receipt_long_rounded,
      title: filtered ? 'No sales match' : 'No sales yet today',
      message: filtered ? 'Try a different range, or clear your search.' : 'Make your first sale of the day!',
      actionLabel: 'New Sale',
      onAction: _openNewSale,
    );
  }
}
