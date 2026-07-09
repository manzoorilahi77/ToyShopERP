import 'package:flutter/material.dart';

import '../core/core.dart';
import 'approvals/discount_approval_screen.dart';
import 'dashboard/dashboard_home_screen.dart';
import 'more/more_menu_screen.dart';
import 'purchase/new_purchase_screen.dart';
import 'reports/reports_screen.dart';

/// Owner app shell — lightweight, glanceable. Bottom nav holds the 4 highest-
/// frequency owner actions; the remaining screens live under "More".
class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _index = 0;

  static const _tabs = <NavItem>[
    NavItem('Home', Icons.dashboard_outlined, Icons.dashboard_rounded),
    NavItem('Approvals', Icons.verified_outlined, Icons.verified_rounded),
    NavItem('Purchase', Icons.add_business_outlined, Icons.add_business_rounded),
    NavItem('Reports', Icons.insights_outlined, Icons.insights_rounded),
    NavItem('More', Icons.menu_rounded, Icons.menu_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const OwnerDashboardScreen(),
      const DiscountApprovalScreen(),
      const NewPurchaseScreen(),
      const ReportsScreen(),
      const OwnerMoreScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: AppBottomNav(
        items: _tabs,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}
