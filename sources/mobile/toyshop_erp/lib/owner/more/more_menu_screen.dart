import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../branches/branches_screen.dart';
import '../catalog/product_catalog_management_screen.dart';
import '../gst/gst_registrations_screen.dart';
import '../notifications/notifications_screen.dart';
import '../staff/staff_management_screen.dart';
import '../settings/settings_screen.dart';
import '../sales/sales_screen.dart';

/// Owner "More" tab — hub to the secondary owner screens that don't fit the
/// bottom nav (Catalog, Staff, GST, Notifications), plus profile + sign out.
class OwnerMoreScreen extends StatelessWidget {
  const OwnerMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final session = SessionScope.of(context);
    final account = session.account;

    return AppScaffold(
      title: 'More',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (account != null)
            AppCard(
              child: Row(
                children: [
                  AvatarBadge.account(account, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(account.name, style: AppType.title.copyWith(color: p.ink)),
                        const SizedBox(height: 2),
                        TonePill.tone(Tone.info, account.roleLabel,
                            icon: Icons.shield_rounded, dense: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          _tile(context, Icons.receipt_long_rounded, 'Sales History',
              'View all shop sales', const SalesScreen()),
          _tile(context, Icons.inventory_2_rounded, 'Product Catalog',
              'Add, edit, deactivate products', const ProductCatalogManagementScreen()),
          _tile(context, Icons.store_rounded, 'Branches Management',
              'View and add branches', const BranchesScreen()),
          _tile(context, Icons.groups_rounded, 'Staff Management',
              'Roster, PINs, incentive rules', const StaffManagementScreen()),
          _tile(context, Icons.description_rounded, 'GST Registrations',
              'Manage GSTINs & filing status', const GstRegistrationsScreen()),
          _tile(context, Icons.notifications_rounded, 'Notifications',
              'Alerts, approvals, sync events', const NotificationsScreen()),
          const SizedBox(height: 18),
          _tile(context, Icons.settings_rounded, 'Settings', 'App & shop preferences', const SettingsScreen()),
          const SizedBox(height: 8),
          Material(
            color: p.danger.withValues(alpha: 0.08),
            borderRadius: AppRadii.card,
            child: ListTile(
              shape: const RoundedRectangleBorder(borderRadius: AppRadii.card),
              leading: Icon(Icons.logout_rounded, color: p.danger),
              title: Text('Sign out',
                  style: AppType.body.copyWith(color: p.danger, fontWeight: FontWeight.w600)),
              onTap: () => _confirmSignOut(context, session),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('ToyShop ERP · v1.0.0 · dev',
                style: AppType.caption.copyWith(color: p.inkMuted)),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, Widget? dest) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: dest == null
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings — prototype')),
                )
            : () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => dest)),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: p.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: p.primary, size: 20),
          ),
          title: Text(title,
              style: AppType.body.copyWith(color: p.ink, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: AppType.caption.copyWith(color: p.inkMuted)),
          trailing: Icon(Icons.chevron_right_rounded, color: p.inkMuted),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AppSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will return to the login screen.'),
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
