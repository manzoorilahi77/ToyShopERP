import 'package:flutter/material.dart';

import '../core/core.dart';
import 'dashboard/dashboard_home_screen.dart';
import 'more/more_menu_screen.dart';
import 'purchase/new_purchase_screen.dart';
import 'reports/reports_screen.dart';
import 'stock_addition/stock_addition_screen.dart';

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
    NavItem('Stock Addition', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
    NavItem('Reports', Icons.insights_outlined, Icons.insights_rounded),
    NavItem('More', Icons.menu_rounded, Icons.menu_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const OwnerDashboardScreen(),
      const StockAdditionScreen(),
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
