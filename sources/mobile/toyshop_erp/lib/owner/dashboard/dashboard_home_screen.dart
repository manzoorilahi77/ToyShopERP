import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../notifications/notifications_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _repo.load().then((d) {
      if (mounted) setState(() => _data = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
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
              onRefresh: () async => setState(() {}),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
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
  }

  Widget _loading() => GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
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
      childAspectRatio: 1.45,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        KpiCard(
          label: 'TODAY SALES',
          value: Fmt.money0(d.salesTotal),
          icon: Icons.payments_rounded,
          trend: '${d.salesTrendPct.toStringAsFixed(0)}% vs avg',
          trendUp: d.salesTrendPct >= 0,
          onTap: () {},
        ),
        KpiCard(
          label: 'PROFIT (est.)',
          value: Fmt.money0(d.profitEstimate),
          icon: Icons.trending_up_rounded,
          accent: context.palette.success,
          footnote: '~${d.marginPct}% margin',
          onTap: () {},
        ),
        KpiCard(
          label: 'ITEMS SOLD',
          value: Fmt.count(d.itemsSold),
          icon: Icons.shopping_bag_rounded,
          accent: context.palette.info,
          footnote: '${d.salesCount} sales',
          onTap: () {},
        ),
        KpiCard(
          label: 'GST LIABILITY',
          value: Fmt.money0(d.gstLiability),
          icon: Icons.receipt_long_rounded,
          accent: context.palette.warning,
          footnote: 'this month · unfiled',
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
      ('Purchase', Icons.add_business_rounded),
      ('Catalog', Icons.inventory_2_rounded),
      ('Staff', Icons.groups_rounded),
      ('Reports', Icons.insights_rounded),
      ('GST', Icons.description_rounded),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (label, icon) in items)
          ActionChip(
            avatar: Icon(icon, size: 18, color: context.palette.primary),
            label: Text(label),
            onPressed: () {},
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
