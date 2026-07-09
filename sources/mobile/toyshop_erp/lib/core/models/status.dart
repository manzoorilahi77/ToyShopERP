import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Sync status vocabulary — design-system.md §8 / sync doc §8.
/// ✓ synced · ↻ syncing · • pending · ! failed.
enum SyncState {
  synced('Synced', Icons.check_circle_rounded),
  syncing('Syncing…', Icons.sync_rounded),
  pending('Pending', Icons.schedule_rounded),
  offline('Offline', Icons.cloud_off_rounded),
  failed('Sync failed', Icons.error_rounded);

  const SyncState(this.label, this.icon);
  final String label;
  final IconData icon;

  Color color(AppPalette p) => switch (this) {
    SyncState.synced => p.success,
    SyncState.syncing => p.info,
    SyncState.pending => p.warning,
    SyncState.offline => p.inkMuted,
    SyncState.failed => p.danger,
  };
}

/// Stock health — design-system.md §8. 🟢 healthy · 🟠 low · 🔴 out · ⏳ aging.
enum StockState {
  healthy('In stock', Icons.check_circle_rounded),
  low('Low stock', Icons.warning_amber_rounded),
  out('Out of stock', Icons.remove_circle_rounded),
  aging('Aging', Icons.hourglass_bottom_rounded);

  const StockState(this.label, this.icon);
  final String label;
  final IconData icon;

  Color color(AppPalette p) => switch (this) {
    StockState.healthy => p.success,
    StockState.low => p.warning,
    StockState.out => p.danger,
    StockState.aging => p.info,
  };
}

/// Generic outcome tone for pills/badges used across screens.
enum Tone {
  neutral,
  primary,
  success,
  warning,
  danger,
  info;

  Color color(AppPalette p) => switch (this) {
    Tone.neutral => p.inkMuted,
    Tone.primary => p.primary,
    Tone.success => p.success,
    Tone.warning => p.warning,
    Tone.danger => p.danger,
    Tone.info => p.info,
  };
}
