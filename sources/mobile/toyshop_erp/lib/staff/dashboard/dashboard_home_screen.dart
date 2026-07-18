import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../sales/new_sale_screen.dart';
import 'dashboard_data.dart';

/// Staff Home / Dashboard (gamified) — the motivating landing screen.
/// Doc: docs/mobile/staff/dashboard/dashboard-home.md (Requirement 5).
final GlobalKey<StaffDashboardScreenState> staffDashboardKey = GlobalKey<StaffDashboardScreenState>();

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key, this.onSell});

  final VoidCallback? onSell;

  @override
  State<StaffDashboardScreen> createState() => StaffDashboardScreenState();
}

class StaffDashboardScreenState extends State<StaffDashboardScreen> {
  final _repo = const StaffDashboardRepository();
  StaffDashboardData? _data;
  DashPeriod _period = DashPeriod.day;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    _repo.load().then((d) {
      if (mounted) setState(() => _data = d);
    });
  }

  Future<void> _openSale({Product? preAdd}) async {
    if (preAdd != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => NewSaleScreen(preAdd: preAdd)),
      );
    } else if (widget.onSell != null) {
      widget.onSell!();
      return;
    } else {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewSaleScreen()));
    }
    
    // Refresh data after returning from a sale
    _repo.load().then((d) {
      if (mounted) setState(() => _data = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final name = session.account?.name.split(' ').first ?? 'there';
    final data = _data;

    return AppScaffold(
      title: 'Hi, $name 👋',
      subtitle: data == null ? null : 'Home · as of ${Fmt.time(data.asOf)}',
      body: data == null
          ? _loading()
          : RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView(
                // Extra bottom clearance so the floating "+ Sale" button
                // (fixed above the bottom nav) never sits on top of the
                // last section's content, however far the feed scrolls.
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                children: [
                  _statsCard(data),
                  const SizedBox(height: 14),
                  _leaderboardCard(data),
                  const SizedBox(height: 14),
                  // _incentiveCard(data.incentive),
                  // const SizedBox(height: 14),
                  // _badgeStrip(data.badges),
                  // const SizedBox(height: 18),
                  const SectionHeader(
                    title: 'Quick pick',
                    subtitle: 'Your hot items · 1-tap add',
                    padding: EdgeInsets.only(bottom: 8),
                  ),
                  _quickPicks(data.quickPicks),
                ],
              ),
            ),
      // A floating action button (not a docked bar) so New Sale reads as a
      // lightweight, always-on-top shortcut — reachable in one tap from
      // anywhere on the dashboard, no matter how far the feed is scrolled
      // (dashboard doc §5 row 12 / acceptance criteria — "always visible").
      floatingActionButton: data == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openSale(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Sale'),
            ),
    );
  }

  Widget _loading() => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SkeletonBox(height: 120, radius: 12),
          SizedBox(height: 14),
          SkeletonBox(height: 160, radius: 12),
          SizedBox(height: 14),
          SkeletonBox(height: 80, radius: 12),
        ],
      );

  Widget _statsCard(StaffDashboardData data) {
    final p = context.palette;
    final s = data.stats[_period]!;
    final up = s.trendPct >= 0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Your sales', style: AppType.title.copyWith(color: p.ink)),
              const Spacer(),
              _PeriodToggle(
                value: _period,
                onChanged: (v) => setState(() => _period = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s.units}', style: AppType.display.copyWith(color: p.ink)),
                    Text('units sold', style: AppType.caption.copyWith(color: p.inkMuted)),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        Fmt.money0(s.revenue),
                        maxLines: 1,
                        style: AppType.display.copyWith(color: p.ink, fontSize: 28),
                      ),
                    ),
                    FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child:Row(
                          children: [
                            Icon(
                              up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              size: 13,
                              color: up ? p.success : p.danger,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${s.trendPct.abs().toStringAsFixed(0)}% vs prev',
                              style: AppType.caption.copyWith(
                                color: up ? p.success : p.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                    )
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leaderboardCard(StaffDashboardData data) {
    final p = context.palette;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Icon(Icons.leaderboard_rounded, size: 18, color: p.primary),
                const SizedBox(width: 8),
                Text('Leaderboard', style: AppType.title.copyWith(color: p.ink)),
                const Spacer(),
                Text('this month', style: AppType.caption.copyWith(color: p.inkMuted)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          for (final e in data.leaderboard.take(3)) _leaderRow(e),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: const Text('See full ▸'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaderRow(LeaderboardEntry e) {
    final p = context.palette;
    final medal = switch (e.rank) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '' };
    return Container(
      margin: const EdgeInsets.only(right: 8, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: e.isMe ? p.primary.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: e.isMe ? Border.all(color: p.primary.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text('${e.rank}', style: AppType.title.copyWith(color: p.inkMuted)),
          ),
          AvatarBadge(initials: e.initials, color: e.color, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              e.name,
              style: AppType.body.copyWith(
                color: p.ink,
                fontWeight: e.isMe ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (e.movement != 0)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(
                children: [
                  Icon(
                    e.movement > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 12,
                    color: e.movement > 0 ? p.success : p.danger,
                  ),
                  Text(
                    '${e.movement.abs()}',
                    style: AppType.caption.copyWith(
                      color: e.movement > 0 ? p.success : p.danger,
                    ),
                  ),
                ],
              ),
            ),
          Text('${e.points} pts', style: AppType.money.copyWith(color: p.ink)),
          if (medal.isNotEmpty) ...[const SizedBox(width: 6), Text(medal)],
        ],
      ),
    );
  }

  Widget _incentiveCard(IncentiveProgress inc) {
    final p = context.palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.card_giftcard_rounded, size: 18, color: p.warning),
              const SizedBox(width: 8),
              Text('Next reward', style: AppType.title.copyWith(color: p.ink)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: inc.fraction,
              minHeight: 12,
              backgroundColor: p.border,
              valueColor: AlwaysStoppedAnimation(p.success),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${inc.current} / ${inc.target} ${inc.unitLabel}',
                style: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${inc.toGo} to go → ${inc.rewardLabel}',
                style: AppType.caption.copyWith(color: p.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badgeStrip(List<StaffBadge> badges) {
    final p = context.palette;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: badges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final b = badges[i];
          final c = b.earned ? p.warning : p.inkMuted;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: b.earned ? c.withValues(alpha: 0.12) : p.bg,
              borderRadius: AppRadii.chip,
              border: Border.all(color: b.earned ? c.withValues(alpha: 0.4) : p.border),
            ),
            child: Row(
              children: [
                Icon(b.icon, size: 15, color: c),
                const SizedBox(width: 6),
                Text(
                  b.label,
                  style: AppType.label.copyWith(
                    color: b.earned ? p.ink : p.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _quickPicks(List<Product> items) {
    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(
          width: 128,
          child: ProductTile(
            product: items[i],
            onTap: () => _openSale(preAdd: items[i]),
          ),
        ),
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.value, required this.onChanged});
  final DashPeriod value;
  final ValueChanged<DashPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget seg(DashPeriod v, String label) {
      final sel = v == value;
      return GestureDetector(
        onTap: () => onChanged(v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? p.primary : Colors.transparent,
            borderRadius: AppRadii.chip,
          ),
          child: Text(
            label,
            style: AppType.caption.copyWith(
              color: sel ? p.primaryInk : p.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

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
          seg(DashPeriod.day, 'Day'),
          seg(DashPeriod.week, 'Week'),
          seg(DashPeriod.month, 'Month'),
        ],
      ),
    );
  }
}
