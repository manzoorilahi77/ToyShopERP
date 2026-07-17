import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../core/models/branch.dart';
import '../../core/models/branches_data.dart';
import '../notifications/notifications_screen.dart';
import '../purchase/new_purchase_screen.dart';
import '../catalog/product_catalog_management_screen.dart';
import '../staff/staff_management_screen.dart';
import '../reports/reports_screen.dart';
import '../gst/gst_registrations_screen.dart';
import 'dashboard_data.dart';
/// Owner Dashboard Home — the owner's glanceable pulse of the shop (R5).
/// Doc: docs/mobile/owner/dashboard/dashboard-home.md
class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final _repo = const OwnerDashboardRepository();
  OwnerDashboardData? _data;
  String? _selectedBranchId; // null means 'All Branches'
  String _selectedPeriod = 'Today';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final d = await _repo.load(branchId: _selectedBranchId, period: _selectedPeriod);
    if (mounted) setState(() => _data = d);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return ListenableBuilder(
      listenable: branchesData,
      builder: (context, _) {
        final branches = branchesData.branches;
        return AppScaffold(
          title: 'ToyShop · Owner',
          subtitle: data == null
              ? null
              : '${Fmt.dateMed(data.date)} · updated ${Fmt.ago(data.asOf)}',
          actions: [
            if (data != null)
              _BellButton(
                count: data.unreadNotifications,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              ),
          ],
          body: data == null
              ? _loading()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _filters(branches),
                      const SizedBox(height: 18),
                      _kpiGrid(data),
                      const SizedBox(height: 18),
                      _sectionTitle('🏆  Top performer today'),
                      const SizedBox(height: 8),
                      _topPerformer(data.topPerformer),
                      const SizedBox(height: 18),
                      _sectionTitle('⚠  Alerts'),
                      const SizedBox(height: 8),
                      _alerts(data),
                      const SizedBox(height: 18),
                      _sectionTitle('Quick nav'),
                      const SizedBox(height: 8),
                      _quickNav(),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _filters(List<Branch> branches) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: context.palette.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedBranchId,
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down_rounded, color: context.palette.primary),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Branches')),
                  ...branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                ],
                onChanged: (val) {
                  if (_selectedBranchId != val) {
                    setState(() {
                      _selectedBranchId = val;
                      _data = null; // show loading
                    });
                    _loadData();
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: context.palette.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: ['Today', 'Yesterday', 'Last 7 Days', 'This Month'].contains(_selectedPeriod) 
                       ? _selectedPeriod 
                       : _selectedPeriod,
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down_rounded, color: context.palette.primary),
                items: [
                  const DropdownMenuItem(value: 'Today', child: Text('Today')),
                  const DropdownMenuItem(value: 'Yesterday', child: Text('Yesterday')),
                  const DropdownMenuItem(value: 'Last 7 Days', child: Text('Last 7 Days')),
                  const DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                  if (!['Today', 'Yesterday', 'Last 7 Days', 'This Month'].contains(_selectedPeriod))
                    DropdownMenuItem(value: _selectedPeriod, child: Text(_selectedPeriod)),
                ],
                onChanged: (val) {
                  if (val != null && _selectedPeriod != val) {
                    setState(() {
                      _selectedPeriod = val;
                      _data = null;
                    });
                    _loadData();
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.calendar_month_rounded, color: context.palette.primary),
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              setState(() {
                _selectedPeriod = dateStr;
                _data = null;
              });
              _loadData();
            }
          },
        ),
      ],
    );
  }

  Widget _loading() => GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
        children: const [
          SkeletonBox(radius: 12),
          SkeletonBox(radius: 12),
          SkeletonBox(radius: 12),
          SkeletonBox(radius: 12),
        ],
      );

  Widget _sectionTitle(String t) {
    final p = context.palette;
    return Text(t, style: AppType.title.copyWith(color: p.ink));
  }

  Widget _kpiGrid(OwnerDashboardData d) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        KpiCard(
          label: 'Revenue',
          value: Fmt.money0(d.salesTotal),
          icon: Icons.attach_money_rounded,
          accent: context.palette.primary, // blue
          trend: '${d.salesTrendPct.abs().toStringAsFixed(1)}% vs last month',
          trendUp: d.salesTrendPct >= 0,
          onTap: () {},
        ),
        KpiCard(
          label: 'Profit (Est.)',
          value: Fmt.money0(d.profitEstimate),
          icon: Icons.auto_graph_rounded,
          accent: context.palette.success, // green
          trend: 'Margin: ${d.marginPct}%',
          trendUp: true,
          onTap: () {},
        ),
        KpiCard(
          label: 'Online Orders',
          value: Fmt.money0(d.onlineRevenue),
          icon: Icons.language_rounded,
          accent: context.palette.primary, // blue
          trend: 'Revenue',
          trendUp: true,
          onTap: () {},
        ),
        KpiCard(
          label: 'Offline Orders',
          value: Fmt.money0(d.offlineRevenue),
          icon: Icons.storefront_rounded,
          accent: context.palette.success, // green
          trend: 'Revenue',
          trendUp: true,
          onTap: () {},
        ),
        KpiCard(
          label: 'Purchases',
          value: Fmt.money0(d.purchasesTotal),
          icon: Icons.shopping_bag_outlined,
          accent: context.palette.warning, // orange
          trend: '${d.purchasesTrendPct.abs().toStringAsFixed(1)}% vs last month',
          trendUp: d.purchasesTrendPct >= 0,
          onTap: () {},
        ),

        KpiCard(
          label: 'Inventory Alerts',
          value: '${d.lowStockCount} items',
          icon: Icons.inventory_2_outlined,
          accent: context.palette.danger, // red
          trend: '${d.alertsTrendPct.abs().toStringAsFixed(1)}% vs last month',
          trendUp: d.alertsTrendPct >= 0,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _topPerformer(TopPerformer t) {
    final p = context.palette;
    return AppCard(
      onTap: () {},
      child: Row(
        children: [
          AvatarBadge(initials: t.initials, color: t.color, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name, style: AppType.title.copyWith(color: p.ink)),
                const SizedBox(height: 2),
                Text(
                  '${Fmt.money0(t.revenue)} · ${t.units} units',
                  style: AppType.body.copyWith(color: p.inkMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.inkMuted),
        ],
      ),
    );
  }

  Widget _alerts(OwnerDashboardData d) {
    final p = context.palette;
    return Row(
      children: [
        Expanded(
          child: AlertTile(
            icon: Icons.warning_amber_rounded,
            title: '${d.lowStockCount} items',
            subtitle: 'Low stock',
            color: p.warning,
            onTap: () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AlertTile(
            icon: Icons.hourglass_bottom_rounded,
            title: '${d.agingStockCount} items',
            subtitle: 'Aging >60d',
            color: p.info,
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _quickNav() {
    final items = [
      ('Purchase', Icons.add_business_rounded, () => const NewPurchaseScreen()),
      ('Catalog', Icons.inventory_2_rounded, () => const ProductCatalogManagementScreen()),
      ('Staff', Icons.groups_rounded, () => const StaffManagementScreen()),
      ('Reports', Icons.insights_rounded, () => const ReportsScreen()),
      ('GST', Icons.description_rounded, () => const GstRegistrationsScreen()),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (label, icon, screenBuilder) in items)
          ActionChip(
            avatar: Icon(icon, size: 18, color: context.palette.primary),
            label: Text(label),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => screenBuilder()));
            },
          ),
      ],
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(onPressed: onTap, icon: const Icon(Icons.notifications_none_rounded)),
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(color: p.danger, shape: BoxShape.circle),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}
