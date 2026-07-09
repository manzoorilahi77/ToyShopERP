import 'package:flutter/material.dart';

import '../../core/core.dart';
import 'notifications_data.dart';

/// Owner Notifications — the single inbox for discount requests, low/aging
/// stock, sync failures, GST reminders and incentive/sale milestones (R6).
/// Doc: docs/mobile/owner/notifications/notifications.md
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repo = const OwnerNotificationsRepository();
  List<AppNotification>? _data;

  /// `null` = the "All" chip.
  NotifType? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await _repo.all();
    if (mounted) setState(() => _data = d);
  }

  int get _unreadCount => _data?.where((n) => !n.isRead).length ?? 0;

  void _markAllRead() {
    setState(() {
      for (final n in _data!) {
        n.isRead = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked read')),
    );
  }

  /// Tap = mark read + deep-link in one gesture (doc §7/§8 rule 2).
  void _open(AppNotification n) {
    setState(() => n.isRead = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening ${n.type.target}…')),
    );
  }

  void _toggleRead(AppNotification n) {
    setState(() => n.isRead = !n.isRead);
  }

  void _showTimestamp(AppNotification n) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${n.title} · ${Fmt.dateTime(n.createdAt)}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return AppScaffold(
      title: 'Notifications',
      subtitle: data == null
          ? null
          : (_unreadCount > 0 ? '$_unreadCount unread' : 'All caught up'),
      actions: [
        TextButton(
          onPressed: (data != null && _unreadCount > 0) ? _markAllRead : null,
          child: const Text('Mark all read'),
        ),
      ],
      body: data == null ? _loading() : _body(data),
    );
  }

  Widget _loading() {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, __) => const SkeletonBox(height: 78, radius: 12),
    );
  }

  Widget _body(List<AppNotification> data) {
    final filtered = _filter == null
        ? List<AppNotification>.of(data)
        : data.where((n) => n.type == _filter).toList();
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      children: [
        _filterRow(),
        Expanded(
          child: filtered.isEmpty
              ? _empty()
              : RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _data = null);
                    await _load();
                  },
                  child: _groupedList(filtered),
                ),
        ),
      ],
    );
  }

  Widget _filterRow() {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip(null, 'All', Icons.apps_rounded, Tone.primary),
            for (final t in NotifType.values) ...[
              const SizedBox(width: 8),
              _chip(t, t.label, t.icon, t.tone),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(NotifType? type, String label, IconData icon, Tone tone) {
    final selected = _filter == type;
    return InkWell(
      borderRadius: AppRadii.chip,
      onTap: () => setState(() => _filter = type),
      child: TonePill.tone(tone, label, icon: icon, filled: selected),
    );
  }

  Widget _empty() {
    final f = _filter;
    return EmptyState(
      icon: Icons.notifications_off_rounded,
      title: f == null ? "You're all caught up" : 'No ${f.label.toLowerCase()} alerts',
      message: f == null
          ? 'No notifications right now — nice and quiet.'
          : 'Nothing in this category. Try another filter.',
      actionLabel: f == null ? null : 'Show all',
      onAction: f == null ? null : () => setState(() => _filter = null),
    );
  }

  Widget _groupedList(List<AppNotification> items) {
    final now = DateTime(2026, 7, 3, 19, 45); // matches Fmt.ago's reference "now"
    final yesterday = now.subtract(const Duration(days: 1));
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    final today = <AppNotification>[];
    final ystd = <AppNotification>[];
    final earlier = <AppNotification>[];
    for (final n in items) {
      if (sameDay(n.createdAt, now)) {
        today.add(n);
      } else if (sameDay(n.createdAt, yesterday)) {
        ystd.add(n);
      } else {
        earlier.add(n);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        if (today.isNotEmpty) ..._section('Today', today),
        if (ystd.isNotEmpty) ..._section('Yesterday', ystd),
        if (earlier.isNotEmpty) ..._section('Earlier', earlier),
      ],
    );
  }

  List<Widget> _section(String label, List<AppNotification> items) {
    final p = context.palette;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, AppSpacing.sm, 4, AppSpacing.sm),
        child: Text(
          label,
          style: AppType.label.copyWith(color: p.inkMuted, fontWeight: FontWeight.w700),
        ),
      ),
      for (final n in items) ...[
        _tile(n),
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
  }

  Widget _tile(AppNotification n) {
    final p = context.palette;
    final color = n.type.tone.color(p);
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.horizontal,
      background: _swipeBg(alignStart: true, isRead: n.isRead),
      secondaryBackground: _swipeBg(alignStart: false, isRead: n.isRead),
      confirmDismiss: (_) async {
        _toggleRead(n);
        return false; // never actually remove — just toggle read state
      },
      child: GestureDetector(
        onLongPress: () => _showTimestamp(n),
        child: AppCard(
          onTap: () => _open(n),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(n.type.icon, size: 20, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.body.copyWith(
                              color: p.ink,
                              fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Fmt.ago(n.createdAt),
                          style: AppType.caption.copyWith(color: p.inkMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      n.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption.copyWith(color: p.inkMuted),
                    ),
                    const SizedBox(height: 8),
                    TonePill.tone(n.type.tone, n.type.label, icon: n.type.icon, dense: true),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  SizedBox(
                    width: 9,
                    height: 9,
                    child: n.isRead
                        ? null
                        : DecoratedBox(
                            decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
                          ),
                  ),
                  const SizedBox(height: 10),
                  Icon(Icons.chevron_right_rounded, size: 18, color: p.inkMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Swipe-reveal background — swipe a row to toggle read/unread (doc §7).
  Widget _swipeBg({required bool alignStart, required bool isRead}) {
    final p = context.palette;
    final label = isRead ? 'Mark unread' : 'Mark read';
    final icon = isRead ? Icons.mark_email_unread_rounded : Icons.done_rounded;
    final color = isRead ? p.inkMuted : p.success;
    final content = [
      Icon(icon, color: color),
      const SizedBox(width: 8),
      Text(label, style: AppType.label.copyWith(color: color, fontWeight: FontWeight.w600)),
    ];
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.card,
      ),
      alignment: alignStart ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignStart ? content : content.reversed.toList(),
      ),
    );
  }
}
