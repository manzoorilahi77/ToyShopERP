import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One bottom-nav tab: an outlined icon at rest, a filled one when selected
/// (design-system: never encode selection by color alone).
class NavItem {
  const NavItem(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Shared bottom navigation chrome for the owner and staff shells.
/// A hairline top border lifts the bar off the page — `NavigationBar`'s
/// elevation shadow doesn't read against a near-white surface, so without it
/// the bar and page content blend into one flat sheet.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: [
          for (final t in items)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.activeIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
