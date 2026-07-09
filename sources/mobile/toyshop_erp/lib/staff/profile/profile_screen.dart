import 'package:flutter/material.dart';

import '../../core/core.dart';
import 'profile_data.dart';

/// Staff "Profile" — personal stats, badges, favorites, incentive tier,
/// settings and sign-out.
/// Doc: docs/mobile/staff/profile/profile.md (Requirement 5).
class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  final _repo = const StaffProfileRepository();
  StaffProfileData? _data;
  List<Product> _favorites = const [];
  List<Product> _catalog = const [];
  bool _biometricOn = false;
  bool _biometricEnrolled = true;
  String _language = 'English';
  int _queued = 0;
  bool? _wasOnline;

  @override
  void initState() {
    super.initState();
    _repo.load().then((d) {
      if (!mounted) return;
      setState(() {
        _data = d;
        _favorites = List.of(d.favorites);
        _catalog = List.of(d.favoriteCatalog);
        _biometricOn = d.preferences.biometricEnabled;
        _biometricEnrolled = d.preferences.biometricEnrolled;
        _language = d.preferences.voiceLanguage;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Simulate the outbox flushing the moment connectivity returns.
    final online = SessionScope.of(context).isOnline;
    if (_wasOnline == false && online && _queued > 0) {
      final n = _queued;
      _queued = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Back online — synced $n change${n == 1 ? '' : 's'}')),
        );
      });
    }
    _wasOnline = online;
  }

  /// Confirms an edit; if offline, queues it (outbox) instead of "syncing" it.
  void _afterEdit(String action) {
    final online = SessionScope.read(context).isOnline;
    if (!online) setState(() => _queued++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(online ? action : '$action — queued, will sync when online')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final session = SessionScope.of(context);
    final account = session.account;
    final data = _data;

    return AppScaffold(
      title: 'Profile',
      subtitle: data == null ? null : 'as of ${Fmt.time(data.stats.asOf)}',
      pendingCount: _queued,
      body: (data == null || account == null)
          ? _loading()
          : RefreshIndicator(
              onRefresh: () async {
                final d = await _repo.load();
                if (!mounted) return;
                setState(() => _data = d);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _header(account, data.stats),
                  const SizedBox(height: 14),
                  _kpiGrid(data.stats),
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: 'Badges earned',
                    subtitle:
                        '${data.badges.where((b) => b.earned).length} of ${data.badges.length} unlocked',
                    padding: const EdgeInsets.only(bottom: 8),
                  ),
                  _badgeGrid(data.badges),
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: 'My favorites',
                    subtitle: _favorites.isEmpty
                        ? 'Pin items you sell often'
                        : '${_favorites.length} pinned · tap to preview',
                    actionLabel: 'Manage ▸',
                    onAction: _openManageFavorites,
                    padding: const EdgeInsets.only(bottom: 8),
                  ),
                  _favoritesStrip(),
                  const SizedBox(height: 20),
                  _tierCard(data.tier),
                  const SizedBox(height: 20),
                  const SectionHeader(
                    title: 'Settings',
                    padding: EdgeInsets.only(bottom: 8),
                  ),
                  _settingsCard(),
                  const SizedBox(height: 20),
                  _signOutTile(session),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'ToyShop ERP · v1.0.0 · dev',
                      style: AppType.caption.copyWith(color: p.inkMuted),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _loading() => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SkeletonBox(height: 92, radius: 12),
          SizedBox(height: 14),
          SkeletonBox(height: 180, radius: 12),
          SizedBox(height: 14),
          SkeletonBox(height: 100, radius: 12),
          SizedBox(height: 14),
          SkeletonBox(height: 140, radius: 12),
          SizedBox(height: 14),
          SkeletonBox(height: 220, radius: 12),
        ],
      );

  // ---- Header ------------------------------------------------------------

  Widget _header(Account account, ProfileStats stats) {
    final p = context.palette;
    return AppCard(
      child: Row(
        children: [
          AvatarBadge.account(account, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name, style: AppType.h2.copyWith(color: p.ink)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    TonePill.tone(Tone.info, account.roleLabel,
                        icon: Icons.shield_rounded, dense: true),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        account.joinDate == null
                            ? 'Join date —'
                            : 'Joined ${Fmt.dateMed(account.joinDate!)}',
                        style: AppType.caption.copyWith(color: p.inkMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- KPIs ----------------------------------------------------------------

  Widget _kpiGrid(ProfileStats stats) {
    final p = context.palette;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: KpiCard(
                label: 'Lifetime units',
                value: Fmt.count(stats.lifetimeUnits),
                icon: Icons.toys_rounded,
                footnote: 'all-time',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KpiCard(
                label: 'Lifetime sales',
                value: Fmt.money0(stats.lifetimeSales),
                icon: Icons.payments_rounded,
                accent: p.success,
                footnote: 'all-time',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: KpiCard(
                label: 'This month',
                value: '${stats.monthPoints}',
                icon: Icons.star_rounded,
                accent: p.warning,
                footnote: 'points earned',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KpiCard(
                label: 'Leaderboard',
                value: stats.rankLabel,
                icon: Icons.leaderboard_rounded,
                accent: p.info,
                footnote: 'this month',
                onTap: () => _showRankInfo(stats),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showRankInfo(ProfileStats stats) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leaderboard rank'),
        content: Text(
          'You are ranked ${stats.rankLabel} this month, based on points earned from sales, '
          'speed and badges. Check the dashboard for the full leaderboard.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  // ---- Badges ----------------------------------------------------------------

  Widget _badgeGrid(List<ProfileBadge> badges) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [for (final b in badges) _badgeChip(b)],
    );
  }

  Widget _badgeChip(ProfileBadge b) {
    final p = context.palette;
    final c = b.earned ? p.warning : p.inkMuted;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showBadgeDetail(b),
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: b.earned ? c.withValues(alpha: 0.10) : p.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: b.earned ? c.withValues(alpha: 0.35) : p.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(b.icon, color: c, size: 26),
            const SizedBox(height: 6),
            Text(
              b.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.label.copyWith(
                color: b.earned ? p.ink : p.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetail(ProfileBadge b) {
    final p = context.palette;
    final c = b.earned ? p.warning : p.inkMuted;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(b.icon, color: c),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(b.label, style: AppType.h2.copyWith(color: p.ink))),
              ],
            ),
            const SizedBox(height: 14),
            TonePill.tone(
              b.earned ? Tone.success : Tone.neutral,
              b.earned ? 'Earned' : 'Locked',
              icon: b.earned ? Icons.check_circle_rounded : Icons.lock_rounded,
            ),
            const SizedBox(height: 12),
            Text(b.criteria, style: AppType.body.copyWith(color: p.inkMuted)),
            if (b.earned && b.earnedOn != null) ...[
              const SizedBox(height: 10),
              Text(
                'Earned on ${Fmt.dateMed(b.earnedOn!)}',
                style: AppType.caption.copyWith(color: p.inkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---- Favorites ----------------------------------------------------------------

  Widget _favoritesStrip() {
    final p = context.palette;
    if (_favorites.isEmpty) {
      return AppCard(
        onTap: _openManageFavorites,
        child: Row(
          children: [
            Icon(Icons.star_border_rounded, color: p.inkMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No favorites yet — tap Manage to pin items you sell often.',
                style: AppType.body.copyWith(color: p.inkMuted),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _favorites.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(
          width: 128,
          child: ProductTile(
            product: _favorites[i],
            onTap: () => _previewFavorite(_favorites[i]),
          ),
        ),
      ),
    );
  }

  void _previewFavorite(Product product) {
    final p = context.palette;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProductThumb(product: product, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: AppType.title.copyWith(color: p.ink)),
                      const SizedBox(height: 2),
                      Text(product.category, style: AppType.caption.copyWith(color: p.inkMuted)),
                      const SizedBox(height: 6),
                      MoneyText(Fmt.money0(product.price), style: AppType.h2),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StockPill(product.stock, qty: product.stockQty),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _removeFavorite(product);
                },
                icon: const Icon(Icons.star_rounded, size: 18),
                label: const Text('Remove from favorites'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeFavorite(Product product) {
    setState(() => _favorites = _favorites.where((f) => f.id != product.id).toList());
    _afterEdit('Removed from favorites');
  }

  Future<void> _openManageFavorites() async {
    final result = await showModalBottomSheet<List<Product>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ManageFavoritesSheet(initialFavorites: _favorites, catalog: _catalog),
    );
    if (!mounted) return;
    if (result == null) return;
    setState(() => _favorites = result);
    _afterEdit('Favorites updated');
  }

  // ---- Incentive tier ----------------------------------------------------------------

  Widget _tierCard(IncentiveTierProgress tier) {
    final p = context.palette;
    return AppCard(
      onTap: () => _showTierLadder(tier),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, size: 18, color: p.warning),
              const SizedBox(width: 8),
              Text('Incentive tier', style: AppType.title.copyWith(color: p.ink)),
              const Spacer(),
              TonePill.tone(Tone.warning, tier.currentTierName,
                  icon: Icons.military_tech_rounded, dense: true),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: tier.fraction,
              minHeight: 12,
              backgroundColor: p.border,
              valueColor: AlwaysStoppedAnimation(p.warning),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${tier.currentPoints} pts',
                style: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  tier.isMaxTier
                      ? 'Top tier reached · ${tier.currentReward}'
                      : '${tier.toGo} to ${tier.nextTierName} → ${tier.currentReward}',
                  style: AppType.caption.copyWith(color: p.inkMuted),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTierLadder(IncentiveTierProgress tier) {
    final p = context.palette;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Incentive ladder · ${tier.periodLabel}', style: AppType.h2.copyWith(color: p.ink)),
            const SizedBox(height: 12),
            for (var i = 0; i < tier.tierNames.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      i < tier.currentIndex
                          ? Icons.check_circle_rounded
                          : i == tier.currentIndex
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                      color: i <= tier.currentIndex ? p.warning : p.inkMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${tier.tierNames[i]} · ${tier.tierThresholds[i]}+ pts',
                        style: AppType.body.copyWith(
                          color: i == tier.currentIndex ? p.ink : p.inkMuted,
                          fontWeight: i == tier.currentIndex ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                    Text(tier.tierRewards[i], style: AppType.caption.copyWith(color: p.inkMuted)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---- Settings ----------------------------------------------------------------

  Widget _settingsCard() {
    final p = context.palette;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _settingsTile(
            icon: Icons.translate_rounded,
            title: 'Voice search language',
            subtitle: _language,
            onTap: _openLanguagePicker,
          ),
          Divider(height: 1, color: p.border),
          _biometricTile(),
          Divider(height: 1, color: p.border),
          _settingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Appearance',
            subtitle: 'Follows system · light in this prototype',
            onTap: _showAppearanceNote,
          ),
          Divider(height: 1, color: p.border),
          _settingsTile(
            icon: Icons.sync_rounded,
            title: 'Sync status',
            subtitle: _queued > 0 ? '$_queued pending · tap to retry' : 'All synced',
            onTap: _openSyncSheet,
          ),
          Divider(height: 1, color: p.border),
          _settingsTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & support',
            subtitle: 'FAQs, contact your owner/admin',
            onTap: _openHelp,
          ),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final p = context.palette;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: p.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: p.primary, size: 19),
      ),
      title: Text(title, style: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: AppType.caption.copyWith(color: p.inkMuted)),
      trailing: Icon(Icons.chevron_right_rounded, color: p.inkMuted),
    );
  }

  Widget _biometricTile() {
    final p = context.palette;
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: p.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.fingerprint_rounded, color: p.primary, size: 19),
      ),
      title: Text('Biometric unlock',
          style: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
      subtitle: Text(
        _biometricEnrolled
            ? (_biometricOn ? 'Enabled for this device' : 'Off')
            : 'Not set up on this device',
        style: AppType.caption.copyWith(color: p.inkMuted),
      ),
      trailing: Switch(value: _biometricOn, onChanged: _toggleBiometric),
    );
  }

  void _toggleBiometric(bool v) {
    if (v && !_biometricEnrolled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set up fingerprint/Face unlock in device settings first')),
      );
      return;
    }
    setState(() => _biometricOn = v);
    _afterEdit(v ? 'Biometric unlock enabled' : 'Biometric unlock disabled');
  }

  void _openLanguagePicker() {
    final p = context.palette;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Voice search language', style: AppType.h2.copyWith(color: p.ink)),
              ),
            ),
            for (final lang in kVoiceLanguages)
              ListTile(
                title: Text(lang),
                trailing: lang == _language ? Icon(Icons.check_rounded, color: p.primary) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  if (lang == _language) return;
                  setState(() => _language = lang);
                  _afterEdit('Voice search language set to $lang');
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showAppearanceNote() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Appearance'),
        content: const Text(
          "This prototype renders in light theme only. In the shipped app, appearance follows "
          "your device's system light/dark setting.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
  }

  void _openSyncSheet() {
    final p = context.palette;
    final online = SessionScope.read(context).isOnline;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sync status', style: AppType.h2.copyWith(color: p.ink)),
            const SizedBox(height: 12),
            LabeledRow(
              'Connection',
              Text(
                online ? 'Online' : 'Offline',
                style: AppType.body.copyWith(
                  color: online ? p.success : p.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            LabeledRow('Pending changes', Text('$_queued')),
            const LabeledRow('Failed', Text('0')),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_queued == 0 || !online)
                    ? null
                    : () {
                        final n = _queued;
                        setState(() => _queued = 0);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Synced $n change${n == 1 ? '' : 's'}')),
                        );
                      },
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: Text(online ? 'Retry now' : 'Waiting for connection'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openHelp() {
    final p = context.palette;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Help & support', style: AppType.h2.copyWith(color: p.ink)),
            const SizedBox(height: 8),
            const _HelpRow(icon: Icons.menu_book_rounded, text: 'Billing FAQs & how-to guides'),
            const _HelpRow(icon: Icons.call_rounded, text: 'Shop owner/admin: +91 98765 43210'),
            const _HelpRow(icon: Icons.mail_outline_rounded, text: 'support@toyshoperp.example'),
            const SizedBox(height: 8),
            Text(
              'Identity, PIN and photo changes are made by your owner in Staff Management.',
              style: AppType.caption.copyWith(color: p.inkMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Sign out ----------------------------------------------------------------

  Widget _signOutTile(AppSession session) {
    final p = context.palette;
    return Material(
      color: p.danger.withValues(alpha: 0.08),
      borderRadius: AppRadii.card,
      child: ListTile(
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.card),
        leading: Icon(Icons.logout_rounded, color: p.danger),
        title: Text('Sign out',
            style: AppType.body.copyWith(color: p.danger, fontWeight: FontWeight.w600)),
        onTap: () => _confirmSignOut(session),
      ),
    );
  }

  void _confirmSignOut(AppSession session) {
    final pending = _queued;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text(
          pending > 0
              ? 'You will return to the login screen. $pending change${pending == 1 ? '' : 's'} '
                  "still syncing — they'll finish syncing when this device is back online."
              : 'You will return to the login screen.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              session.signOut();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  const _HelpRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: p.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppType.body.copyWith(color: p.ink))),
        ],
      ),
    );
  }
}

/// "Manage favorites" bottom sheet — reorder (drag), remove (✕) and add from
/// the catalog. Changes are only committed back to the screen when the user
/// taps "Done" (design-system.md §1.3 "confirm before commit").
class _ManageFavoritesSheet extends StatefulWidget {
  const _ManageFavoritesSheet({required this.initialFavorites, required this.catalog});

  final List<Product> initialFavorites;
  final List<Product> catalog;

  @override
  State<_ManageFavoritesSheet> createState() => _ManageFavoritesSheetState();
}

class _ManageFavoritesSheetState extends State<_ManageFavoritesSheet> {
  late List<Product> _favorites = List.of(widget.initialFavorites);
  late List<Product> _available =
      widget.catalog.where((c) => !_favorites.any((f) => f.id == c.id)).toList();
  bool _showAdd = false;

  void _remove(Product product) {
    setState(() {
      _favorites = _favorites.where((f) => f.id != product.id).toList();
      _available = [..._available, product];
    });
  }

  void _add(Product product) {
    setState(() {
      _favorites = [..._favorites, product];
      _available = _available.where((p) => p.id != product.id).toList();
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final items = List.of(_favorites);
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
      _favorites = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Manage favorites', style: AppType.h2.copyWith(color: p.ink))),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_favorites),
                  child: const Text('Done'),
                ),
              ],
            ),
            Text(
              'Drag to reorder · tap ✕ to remove',
              style: AppType.caption.copyWith(color: p.inkMuted),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  if (_favorites.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No favorites yet — add some below.',
                        style: AppType.body.copyWith(color: p.inkMuted),
                      ),
                    )
                  else
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: _reorder,
                      children: [
                        for (final product in _favorites)
                          _favoriteRow(product, key: ValueKey(product.id)),
                      ],
                    ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _available.isEmpty ? null : () => setState(() => _showAdd = !_showAdd),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            _showAdd ? Icons.expand_less_rounded : Icons.add_circle_outline_rounded,
                            color: _available.isEmpty ? p.inkMuted : p.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _available.isEmpty ? 'All catalog items pinned' : 'Add a favorite',
                            style: AppType.body.copyWith(
                              color: _available.isEmpty ? p.inkMuted : p.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showAdd) for (final product in _available) _availableRow(product),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _favoriteRow(Product product, {required Key key}) {
    final p = context.palette;
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(Icons.drag_indicator_rounded, color: p.inkMuted),
            const SizedBox(width: 4),
            ProductThumb(product: product, size: 44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppType.label.copyWith(color: p.ink, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(Fmt.money0(product.price), style: AppType.caption.copyWith(color: p.inkMuted)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, color: p.danger),
              tooltip: 'Remove',
              onPressed: () => _remove(product),
            ),
          ],
        ),
      ),
    );
  }

  Widget _availableRow(Product product) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(8),
        onTap: () => _add(product),
        child: Row(
          children: [
            ProductThumb(product: product, size: 44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppType.label.copyWith(color: p.ink, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(Fmt.money0(product.price), style: AppType.caption.copyWith(color: p.inkMuted)),
                ],
              ),
            ),
            Icon(Icons.add_circle_rounded, color: p.primary),
          ],
        ),
      ),
    );
  }
}
