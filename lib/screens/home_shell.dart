import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../theme.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'more_screen.dart';
import 'sales_screen.dart';

/// Bottom-navigation shell holding the core pages. An IndexedStack keeps each
/// page's state (and loaded data) alive when switching tabs. The bar itself
/// floats above the content with rounded edges and a soft shadow.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _navVisible = true;

  /// Hide the floating bar when the user scrolls the content down, and bring it
  /// straight back on any scroll up — so the tabs are never more than a small
  /// upward flick away.
  bool _onScroll(UserScrollNotification n) {
    // Ignore horizontal scrollers (chart carousels, wide tables).
    if (n.metrics.axis != Axis.vertical) return false;
    if (n.direction == ScrollDirection.reverse && _navVisible) {
      setState(() => _navVisible = false);
    } else if (n.direction == ScrollDirection.forward && !_navVisible) {
      setState(() => _navVisible = true);
    }
    return false;
  }

  static const _pages = [
    DashboardScreen(),
    SalesScreen(),
    InventoryScreen(),
    MoreScreen(),
  ];

  static const _items = <_NavItem>[
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Overview'),
    _NavItem(Icons.trending_up_outlined, Icons.trending_up, 'Sales'),
    _NavItem(Icons.inventory_2_outlined, Icons.inventory_2, 'Inventory'),
    _NavItem(Icons.grid_view_outlined, Icons.grid_view, 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Let page content flow behind the floating bar; pages add bottom padding.
      extendBody: true,
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: AnimatedSlide(
        offset: _navVisible ? Offset.zero : const Offset(0, 1.6),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: _navVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: _FloatingNavBar(
            index: _index,
            items: _items,
            onTap: (i) => setState(() {
              _index = i;
              _navVisible = true;
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

class _FloatingNavBar extends StatelessWidget {
  final int index;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;
  const _FloatingNavBar({required this.index, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: t.chrome,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: t.chromeBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: t.isDark ? 0.4 : 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < items.length; i++)
                _NavButton(
                  item: items[i],
                  selected: i == index,
                  onTap: () => onTap(i),
                  tokens: t,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final BiTokens tokens;
  const _NavButton({required this.item, required this.selected, required this.onTap, required this.tokens});

  @override
  Widget build(BuildContext context) {
    final color = selected ? tokens.brandInk : tokens.chromeTextSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? tokens.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? item.activeIcon : item.icon, size: 22, color: color),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
