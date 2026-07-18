import 'package:flutter/material.dart';

import '../core/core.dart';
import 'catalog/product_search_browse_screen.dart';
import 'dashboard/dashboard_home_screen.dart';
import 'profile/profile_screen.dart';
import 'sales/my_sales_history_screen.dart';
import 'sales/new_sale_screen.dart';

/// Staff app shell — offline-first billing surface. Bottom nav per
/// design-system.md §11 (mobile: bottom nav, one-hand use).
class StaffShell extends StatefulWidget {
  const StaffShell({super.key});

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int _index = 0;

  static const _tabs = <NavItem>[
    NavItem('Home', Icons.home_outlined, Icons.home_rounded),
    NavItem('Sell', Icons.point_of_sale_outlined, Icons.point_of_sale_rounded),
    NavItem('History', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
    NavItem('Catalog', Icons.grid_view_outlined, Icons.grid_view_rounded),
    NavItem('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      StaffDashboardScreen(
        key: staffDashboardKey,
        onSell: () => setState(() => _index = 1),
      ),
      const NewSaleScreen(),
      const MySalesHistoryScreen(),
      const ProductSearchBrowseScreen(),
      const StaffProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: AppBottomNav(
        items: _tabs,
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 0) {
            staffDashboardKey.currentState?.reload();
          }
        },
      ),
    );
  }
}
