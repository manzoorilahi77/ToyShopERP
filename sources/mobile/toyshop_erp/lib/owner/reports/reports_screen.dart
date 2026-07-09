import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../core/models/branches_data.dart';
import '../purchase/new_purchase_screen.dart';
import 'reports_data.dart';

/// Owner Reports — sales/profit summary with Day/Week/Month filters, a
/// sales-trend chart, category mix, top products/staff, and aging/low-stock
/// drill-downs, plus a mock CSV/XLSX export.
/// Doc: docs/mobile/owner/reports/reports.md
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _repo = const ReportsRepository();

  ReportPeriod _period = ReportPeriod.day;
  AgingThreshold _agingThreshold = AgingThreshold.d60;
  String? _selectedBranchId = 'all';

  SalesSummary? _sales;
  List<TopProductStat>? _topProducts;
  List<TopStaffStat>? _topStaff;
  List<CategoryShare>? _categories;
  List<AgingStockItem>? _aging;
  List<LowStockItem>? _lowStock;
  List<GstSnapshotRow>? _gst;

  bool _agingExpanded = false;
  bool _lowStockExpanded = false;

  static const _collapsedCount = 4;

  @override
  void initState() {
    super.initState();
    _fetchSales();
    _fetchAging();
    _fetchLowStock();
    _fetchGst();
  }

  // --- loading (independent per section, per doc §6) ------------------------
  //
  // Each _fetchX() only ever calls setState from inside its async `.then()`
  // (after a `mounted` check) — matching the dashboard's load() pattern. The
  // "reset to null so skeletons show again" step lives in the user-triggered
  // call sites below (refresh / period / threshold change), never in
  // initState, since the very first build already reads the null defaults.

  void _fetchSales() {
    final period = _period;
    final branchId = _selectedBranchId;
    _repo.salesSummary(period, branchId: branchId).then((v) {
      if (mounted && _period == period && _selectedBranchId == branchId) setState(() => _sales = v);
    });
    _repo.topProducts(period).then((v) {
      if (mounted && _period == period) setState(() => _topProducts = v);
    });
    _repo.topStaff(period).then((v) {
      if (mounted && _period == period) setState(() => _topStaff = v);
    });
    _repo.categoryMix(period).then((v) {
      if (mounted && _period == period) setState(() => _categories = v);
    });
  }

  void _fetchAging() {
    final threshold = _agingThreshold;
    _repo.agingStock(threshold).then((v) {
      if (mounted && _agingThreshold == threshold) setState(() => _aging = v);
    });
  }

  void _fetchLowStock() {
    _repo.lowStock().then((v) {
      if (mounted) setState(() => _lowStock = v);
    });
  }

  void _fetchGst() {
    _repo.gstSnapshot().then((v) {
      if (mounted) setState(() => _gst = v);
    });
  }

  Future<void> _refreshAll() async {
    setState(() {
      _sales = null;
      _topProducts = null;
      _topStaff = null;
      _categories = null;
      _aging = null;
      _lowStock = null;
      _gst = null;
    });
    _fetchSales();
    _fetchAging();
    _fetchLowStock();
    _fetchGst();
  }

  // --- actions ---------------------------------------------------------------

  void _onPeriodChanged(ReportPeriod p) {
    if (p == _period) return;
    setState(() {
      _period = p;
      _sales = null;
      _topProducts = null;
      _topStaff = null;
      _categories = null;
    });
    _fetchSales();
  }

  void _onBranchChanged(String? branchId) {
    if (branchId == _selectedBranchId) return;
    setState(() {
      _selectedBranchId = branchId;
      _sales = null;
    });
    _fetchSales();
  }

  void _onAgingThresholdChanged(AgingThreshold t) {
    if (t == _agingThreshold) return;
    setState(() {
      _agingThreshold = t;
      _aging = null;
    });
    _fetchAging();
  }

  void _export(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported $format (prototype)')),
    );
  }

  void _openWebLink(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — opens on web (prototype)')),
    );
  }

  void _openNewPurchase() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NewPurchaseScreen()),
    );
  }

  void _openReorder(Product product) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('New Purchase — prefilling ${product.name} (prototype)')),
    );
    _openNewPurchase();
  }

  // --- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Reports',
      subtitle: _sales == null
          ? null
          : '${_period.label} view · updated ${Fmt.ago(kReportsAsOf)}',
      actions: [_exportAction()],
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _salesHeader(),
            const SizedBox(height: 12),
            _kpiRow(),
            const SizedBox(height: 10),
            _statLine(),
            const SizedBox(height: 6),
            _webLink('View sales ledger on web', 'Sales ledger'),
            const SizedBox(height: 16),
            _chartCard(),
            const SizedBox(height: 16),
            _categoryCard(),
            const SizedBox(height: 24),
            _topProductsSection(),
            const SizedBox(height: 24),
            _topStaffSection(),
            const SizedBox(height: 24),
            _agingSection(),
            const SizedBox(height: 24),
            _lowStockSection(),
            const SizedBox(height: 24),
            _gstSection(),
          ],
        ),
      ),
    );
  }

  Widget _exportAction() {
    return PopupMenuButton<String>(
      tooltip: 'Export report',
      icon: const Icon(Icons.ios_share_rounded),
      onSelected: _export,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'CSV', child: Text('Export CSV')),
        PopupMenuItem(value: 'XLSX', child: Text('Export XLSX')),
      ],
    );
  }

  // --- sales: header / KPIs / stat line / chart / category mix ------------

  Widget _salesHeader() {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Sales', style: AppType.h2.copyWith(color: p.ink)),
            const Spacer(),
            _SegTabs<ReportPeriod>(
              value: _period,
              options: ReportPeriod.values,
              labelOf: (v) => v.label,
              onChanged: _onPeriodChanged,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _branchSelector(),
      ],
    );
  }

  Widget _branchSelector() {
    final p = context.palette;
    return ListenableBuilder(
      listenable: branchesData,
      builder: (context, _) {
        final branches = branchesData.branches;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedBranchId,
              isExpanded: true,
              icon: Icon(Icons.store_rounded, color: p.primary),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All Branches')),
                ...branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
              ],
              onChanged: _onBranchChanged,
            ),
          ),
        );
      },
    );
  }

  Widget _kpiRow() {
    final s = _sales;
    if (s == null) {
      return GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.35,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: const [SkeletonBox(radius: 12), SkeletonBox(radius: 12)],
      );
    }
    final p = context.palette;
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.35,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        KpiCard(
          label: 'SALES',
          value: Fmt.money0(s.salesTotal),
          icon: Icons.payments_rounded,
          trend: '${s.trendPct.abs().toStringAsFixed(0)}% vs prev',
          trendUp: s.trendPct >= 0,
          onTap: () => _openWebLink('Sales ledger'),
        ),
        KpiCard(
          label: 'PROFIT (est.)',
          value: Fmt.money0(s.profitEstimate),
          icon: Icons.trending_up_rounded,
          accent: p.success,
          footnote: '~${s.marginPct}% margin',
          onTap: () => _openWebLink('Sales ledger'),
        ),
      ],
    );
  }

  Widget _statLine() {
    final s = _sales;
    if (s == null) return const SkeletonBox(height: 18, width: 240);
    final p = context.palette;
    return Text(
      'Items ${Fmt.count(s.itemsSold)}  ·  Sales ${Fmt.count(s.salesCount)}  ·  '
      'Avg ${Fmt.money0(s.avgSale)}',
      style: AppType.body.copyWith(color: p.inkMuted),
    );
  }

  Widget _webLink(String label, String target) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => _openWebLink(target),
        child: Text('$label →'),
      ),
    );
  }

  Widget _chartCard() {
    final p = context.palette;
    final s = _sales;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 18, color: p.primary),
              const SizedBox(width: 8),
              Text('Sales trend', style: AppType.title.copyWith(color: p.ink)),
              const Spacer(),
              Text(_period.label, style: AppType.caption.copyWith(color: p.inkMuted)),
            ],
          ),
          const SizedBox(height: 16),
          if (s == null)
            const SkeletonBox(height: 150, radius: 10)
          else
            _BarChart(series: s.series, color: p.primary),
        ],
      ),
    );
  }

  Widget _categoryCard() {
    final p = context.palette;
    final cats = _categories;
    final total = cats == null ? 0.0 : cats.fold<double>(0, (a, c) => a + c.value);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Category mix', style: AppType.title.copyWith(color: p.ink)),
          const SizedBox(height: 14),
          if (cats == null)
            const SkeletonBox(height: 14, radius: 8)
          else
            _stackedBar(cats, total),
          const SizedBox(height: 12),
          if (cats != null)
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [for (final c in cats) _legendChip(c, total)],
            ),
        ],
      ),
    );
  }

  Widget _stackedBar(List<CategoryShare> cats, double total) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 14,
        child: Row(
          children: [
            for (final c in cats)
              Expanded(
                flex: total <= 0 ? 1 : (c.value / total * 1000).clamp(1.0, 1000.0).round(),
                child: Container(color: c.color),
              ),
          ],
        ),
      ),
    );
  }

  Widget _legendChip(CategoryShare c, double total) {
    final p = context.palette;
    final pct = total <= 0 ? 0 : (c.value / total * 100).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('${c.category} · $pct%', style: AppType.caption.copyWith(color: p.inkMuted)),
      ],
    );
  }

  // --- top products / top staff --------------------------------------------

  Widget _topProductsSection() {
    final items = _topProducts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Top products',
          subtitle: '${_period.label} · by revenue',
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        if (items == null)
          SizedBox(
            height: 172,
            child: Row(
              children: const [
                Expanded(child: SkeletonBox(height: 172, radius: 14)),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 172, radius: 14)),
              ],
            ),
          )
        else if (items.isEmpty)
          const EmptyState(
            icon: Icons.shopping_bag_rounded,
            title: 'No sales yet',
            message: 'Top products will appear once sales come in.',
          )
        else
          SizedBox(
            height: 172,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _topProductTile(i + 1, items[i]),
            ),
          ),
      ],
    );
  }

  Widget _topProductTile(int rank, TopProductStat t) {
    final p = context.palette;
    return SizedBox(
      width: 132,
      child: Stack(
        children: [
          ProductTile(
            product: t.product,
            showStock: false,
            trailing: Text(
              Fmt.moneyCompact(t.revenue),
              style: AppType.caption.copyWith(color: p.success, fontWeight: FontWeight.w700),
            ),
            onTap: () => _showTopProductSheet(t),
          ),
          Positioned(top: 6, left: 6, child: TonePill.tone(Tone.primary, '#$rank', dense: true)),
        ],
      ),
    );
  }

  Widget _topStaffSection() {
    final p = context.palette;
    final staff = _topStaff;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Top staff',
          subtitle: '${_period.label} · by revenue',
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        if (staff == null)
          const SkeletonBox(height: 220, radius: 12)
        else if (staff.isEmpty)
          const EmptyState(icon: Icons.groups_rounded, title: 'No sales yet')
        else
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Column(
              children: [
                for (var i = 0; i < staff.length; i++) ...[
                  _staffRow(i + 1, staff[i]),
                  if (i != staff.length - 1) Divider(height: 14, color: p.border),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _staffRow(int rank, TopStaffStat s) {
    final p = context.palette;
    final medal = switch (rank) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '' };
    return InkWell(
      onTap: () => _showStaffSheet(s),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(width: 20, child: Text('$rank', style: AppType.title.copyWith(color: p.inkMuted))),
            AvatarBadge(initials: s.initials, color: s.color, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
                  Text(
                    '${s.unitsSold} units · ${s.salesCount} sales',
                    style: AppType.caption.copyWith(color: p.inkMuted),
                  ),
                ],
              ),
            ),
            Text(Fmt.money0(s.revenue), style: AppType.money.copyWith(color: p.ink)),
            if (medal.isNotEmpty) ...[const SizedBox(width: 6), Text(medal)],
          ],
        ),
      ),
    );
  }

  // --- aging stock / low stock ----------------------------------------------

  Widget _agingSection() {
    final p = context.palette;
    final items = _aging;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.hourglass_bottom_rounded, size: 18, color: p.info),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Aging stock',
                style: AppType.title.copyWith(color: p.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (items != null) TonePill.tone(Tone.info, '${items.length}', dense: true),
            const Spacer(),
            _SegTabs<AgingThreshold>(
              value: _agingThreshold,
              options: AgingThreshold.values,
              labelOf: (v) => v.label,
              onChanged: _onAgingThresholdChanged,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (items == null)
          _tileGridSkeleton()
        else if (items.isEmpty)
          const EmptyState(
            icon: Icons.hourglass_bottom_rounded,
            title: 'Nothing aging',
            message: 'No stock has sat past this threshold.',
          )
        else
          _expandableGrid<AgingStockItem>(
            items: items,
            expanded: _agingExpanded,
            tileBuilder: _agingTile,
            onToggle: () => setState(() => _agingExpanded = !_agingExpanded),
          ),
      ],
    );
  }

  Widget _agingTile(AgingStockItem a) {
    final p = context.palette;
    return ProductTile(
      product: a.product,
      onTap: () => _showAgingSheet(a),
      trailing: Text(
        '${a.daysInStock}d',
        style: AppType.caption.copyWith(color: p.info, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _lowStockSection() {
    final items = _lowStock;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Low stock',
          subtitle: items == null ? null : '${items.length} at or below reorder level',
          actionLabel: '+ New PO',
          onAction: _openNewPurchase,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        if (items == null)
          _tileGridSkeleton()
        else if (items.isEmpty)
          const EmptyState(
            icon: Icons.check_circle_rounded,
            title: 'All stock healthy',
            message: 'Nothing below its reorder threshold.',
          )
        else
          _expandableGrid<LowStockItem>(
            items: items,
            expanded: _lowStockExpanded,
            tileBuilder: _lowStockTile,
            onToggle: () => setState(() => _lowStockExpanded = !_lowStockExpanded),
          ),
      ],
    );
  }

  Widget _lowStockTile(LowStockItem item) {
    final p = context.palette;
    return ProductTile(
      product: item.product,
      onTap: () => _showLowStockSheet(item),
      trailing: item.oversold
          ? TonePill.tone(Tone.danger, 'Oversold', dense: true, icon: Icons.error_outline_rounded)
          : Text(
              '≤ ${item.reorderThreshold}',
              style: AppType.caption.copyWith(color: p.warning, fontWeight: FontWeight.w700),
            ),
    );
  }

  Widget _expandableGrid<T>({
    required List<T> items,
    required bool expanded,
    required Widget Function(T) tileBuilder,
    required VoidCallback onToggle,
  }) {
    final visible = expanded ? items : items.take(_collapsedCount).toList();
    return Column(
      children: [
        _productGrid(visible.map(tileBuilder).toList()),
        if (items.length > _collapsedCount) _expandToggle(expanded, items.length, onToggle),
      ],
    );
  }

  Widget _productGrid(List<Widget> tiles) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 0.74,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: tiles,
    );
  }

  Widget _tileGridSkeleton() {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 0.74,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: const [SkeletonBox(radius: 14), SkeletonBox(radius: 14)],
    );
  }

  Widget _expandToggle(bool expanded, int total, VoidCallback onTap) {
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
        label: Text(expanded ? 'Show less' : 'Show all ($total)'),
      ),
    );
  }

  // --- GST snapshot ----------------------------------------------------------

  Widget _gstSection() {
    final gst = _gst;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'GST snapshot',
          subtitle: 'this month',
          actionLabel: 'Open on web',
          onAction: () => _openWebLink('GST filing'),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        if (gst == null)
          const Column(
            children: [
              SkeletonBox(height: 118, radius: 12),
              SizedBox(height: 10),
              SkeletonBox(height: 118, radius: 12),
            ],
          )
        else if (gst.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'No GST activity',
            message: 'Nothing to report this period.',
          )
        else
          Column(
            children: [
              for (final row in gst) ...[
                _gstCard(row),
                const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }

  Widget _gstCard(GstSnapshotRow row) {
    final p = context.palette;
    return AppCard(
      onTap: () => _openWebLink('GST filing · ${row.gstin}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, size: 16, color: p.inkMuted),
              const SizedBox(width: 6),
              Expanded(child: Text(row.gstin, style: AppType.title.copyWith(color: p.ink))),
              if (row.itcRiskCount > 0)
                TonePill.tone(
                  Tone.warning,
                  '${row.itcRiskCount} ITC risk',
                  icon: Icons.warning_amber_rounded,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 10),
          LabeledRow('Output GST', MoneyText(Fmt.money0(row.outputGst))),
          LabeledRow('ITC', MoneyText(Fmt.money0(row.itc))),
          LabeledRow(
            'Net payable',
            MoneyText(Fmt.money0(row.netPayable)),
            emphasize: true,
            valueColor: p.primary,
          ),
        ],
      ),
    );
  }

  // --- drill-down sheets -------------------------------------------------

  void _showTopProductSheet(TopProductStat t) {
    final p = context.palette;
    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(sheetContext).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProductThumb(product: t.product, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.product.name, style: AppType.title.copyWith(color: p.ink)),
                      Text(t.product.category, style: AppType.caption.copyWith(color: p.inkMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LabeledRow('Units sold', Text('${t.unitsSold}')),
            LabeledRow('Revenue', MoneyText(Fmt.money0(t.revenue))),
            LabeledRow('Unit price', MoneyText(Fmt.money(t.product.price))),
          ],
        ),
      ),
    );
  }

  void _showStaffSheet(TopStaffStat s) {
    final p = context.palette;
    final avgTicket = s.salesCount == 0 ? 0.0 : s.revenue / s.salesCount;
    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(sheetContext).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarBadge(initials: s.initials, color: s.color, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: AppType.title.copyWith(color: p.ink)),
                      Text(
                        '${_period.label} performance',
                        style: AppType.caption.copyWith(color: p.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LabeledRow('Revenue', MoneyText(Fmt.money0(s.revenue))),
            LabeledRow('Units sold', Text('${s.unitsSold}')),
            LabeledRow('Sales', Text('${s.salesCount}')),
            LabeledRow('Avg ticket', MoneyText(Fmt.money0(avgTicket))),
          ],
        ),
      ),
    );
  }

  void _showAgingSheet(AgingStockItem a) {
    final p = context.palette;
    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(sheetContext).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProductThumb(product: a.product, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.product.name, style: AppType.title.copyWith(color: p.ink)),
                      Text(a.product.category, style: AppType.caption.copyWith(color: p.inkMuted)),
                    ],
                  ),
                ),
                const StockPill(StockState.aging, dense: true),
              ],
            ),
            const SizedBox(height: 16),
            LabeledRow('Days in stock', Text('${a.daysInStock} d')),
            LabeledRow('Tied-up value', MoneyText(Fmt.money0(a.tiedValue))),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.primaryAction,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _openReorder(a.product);
                },
                icon: const Icon(Icons.add_business_rounded, size: 18),
                label: const Text('Create purchase order'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLowStockSheet(LowStockItem item) {
    final p = context.palette;
    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(sheetContext).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProductThumb(product: item.product, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.product.name, style: AppType.title.copyWith(color: p.ink)),
                      Text(item.product.category, style: AppType.caption.copyWith(color: p.inkMuted)),
                    ],
                  ),
                ),
                StockPill(item.oversold ? StockState.out : StockState.low, dense: true),
              ],
            ),
            const SizedBox(height: 16),
            LabeledRow('On hand', Text('${item.onHand}')),
            LabeledRow('Reorder threshold', Text('${item.reorderThreshold}')),
            if (item.oversold) ...[
              const SizedBox(height: 10),
              AlertTile(
                icon: Icons.error_outline_rounded,
                title: 'Oversold',
                subtitle: 'On-hand is negative — needs a physical stock count.',
                color: p.danger,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.primaryAction,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _openReorder(item.product);
                },
                icon: const Icon(Icons.add_business_rounded, size: 18),
                label: const Text('Create purchase order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small segmented control for the sales-period and aging-threshold toggles —
/// a lightweight stand-in built from the shared palette/typography tokens
/// (mirrors the `_PeriodToggle` pattern used on the staff dashboard).
class _SegTabs<T> extends StatelessWidget {
  const _SegTabs({
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: AppRadii.chip,
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            GestureDetector(
              onTap: () => onChanged(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: o == value ? p.primary : Colors.transparent,
                  borderRadius: AppRadii.chip,
                ),
                child: Text(
                  labelOf(o),
                  style: AppType.caption.copyWith(
                    color: o == value ? p.primaryInk : p.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Simple bar chart drawn from plain Containers — bars are sized with
/// [FractionallySizedBox] relative to the series max. No chart package.
class _BarChart extends StatelessWidget {
  const _BarChart({required this.series, required this.color});

  final List<SalesPoint> series;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final maxVal = series.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final pt in series)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.moneyCompact(pt.value),
                      style: AppType.caption.copyWith(color: p.inkMuted, fontSize: 9),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: maxVal <= 0 ? 0.02 : (pt.value / maxVal).clamp(0.03, 1.0).toDouble(),
                          widthFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.85),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pt.label,
                      style: AppType.caption.copyWith(color: p.inkMuted, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
