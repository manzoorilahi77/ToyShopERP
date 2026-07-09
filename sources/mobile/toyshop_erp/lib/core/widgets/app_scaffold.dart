import 'package:flutter/material.dart';

import '../models/status.dart';
import '../session/app_session.dart';
import '../theme/app_colors.dart';
import 'pills.dart';

/// Standard screen scaffold — title, a top-right [SyncStatusChip] wired to the
/// session's connectivity, an optional calm offline banner, and an optional
/// pinned bottom action bar (design-system.md §6 `AppScaffold`).
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.showSync = true,
    this.pendingCount = 0,
    this.bottomBar,
    this.floatingActionButton,
    this.showOfflineBanner = true,
    this.scrollable = false,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final Widget? leading;
  final bool showSync;
  final int pendingCount;
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final bool showOfflineBanner;

  /// When true the [body] is wrapped in a scroll view with [padding].
  final bool scrollable;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final session = SessionScope.of(context);
    final online = session.isOnline;
    final syncState = online
        ? (pendingCount > 0 ? SyncState.pending : SyncState.synced)
        : SyncState.offline;

    Widget content = body;
    if (scrollable) {
      content = SingleChildScrollView(
        padding: padding ?? const EdgeInsets.all(16),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        leading: leading,
        titleSpacing: leading == null ? 16 : 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: p.inkMuted, fontWeight: FontWeight.w400),
              ),
          ],
        ),
        actions: [
          ...actions,
          if (showSync)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: SyncStatusChip(
                  syncState,
                  pendingCount: pendingCount,
                  onTap: session.toggleConnectivity,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (showOfflineBanner && !online) const OfflineBanner(),
          Expanded(child: content),
        ],
      ),
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
