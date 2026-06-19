import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../app/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  static const destinations = [
    ShellDestination('Dashboard', '/', Icons.dashboard_rounded),
    ShellDestination('Invoices', '/invoices', Icons.receipt_long_rounded),
    ShellDestination('Customers', '/customers', Icons.groups_rounded),
    ShellDestination('Inventory', '/inventory', Icons.inventory_2_rounded),
    ShellDestination('Expenses', '/expenses', Icons.account_balance_wallet_rounded),
    ShellDestination('Reports', '/reports', Icons.query_stats_rounded),
    ShellDestination('Settings', '/settings', Icons.tune_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = destinations.indexWhere((d) => d.path == location);
    final activeIndex = selectedIndex < 0 ? 0 : selectedIndex;
    final mobileDestinations = destinations.take(5).toList();
    final mobileIndex = activeIndex >= mobileDestinations.length ? 0 : activeIndex;

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 68,
          titleSpacing: 16,
          title: const _BrandLockup(compact: true),
          surfaceTintColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: 'Search',
              onPressed: () {},
              icon: const Icon(Icons.search_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: child,
        bottomNavigationBar: NavigationBar(
          height: 72,
          selectedIndex: mobileIndex,
          onDestinationSelected: (index) => context.go(destinations[index].path),
          destinations: [
            for (final item in mobileDestinations)
              NavigationDestination(
                icon: Icon(item.icon),
                label: item.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          _DesktopSidebar(
            destinations: destinations,
            activeIndex: activeIndex,
          ),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.sand,
                    Color(0xFFD4B895),
                    Color(0xFFBFC9B2),
                  ],
                ),
              ),
              child: SafeArea(
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.destinations,
    required this.activeIndex,
  });

  final List<ShellDestination> destinations;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 286,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .78),
        border: Border(
          right: BorderSide(color: scheme.outlineVariant.withValues(alpha: .7)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BrandLockup(),
          const SizedBox(height: 26),
          for (var i = 0; i < destinations.length; i++)
            _SidebarItem(
              destination: destinations[i],
              selected: i == activeIndex,
              onTap: () => context.go(destinations[i].path),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.moss,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.offline_bolt_rounded, color: AppTheme.sand),
                const SizedBox(height: 10),
                Text(
                  'Offline-ready PWA',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.sand,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Local workflows stay responsive while backend sync is wired in.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.sand.withValues(alpha: .82),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? AppTheme.moss : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(
                destination.icon,
                size: 21,
                color: selected ? AppTheme.sand : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  destination.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: selected ? AppTheme.sand : scheme.onSurface,
                        fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 38 : 44,
          height: compact ? 38 : 44,
          decoration: BoxDecoration(
            color: AppTheme.moss,
            borderRadius: BorderRadius.circular(16),
          ),
        child: const Icon(
            Icons.eco_rounded,
            color: AppTheme.sand,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sprout Track',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 15 : 17,
                      color: scheme.onSurface,
                    ),
              ),
              if (!compact)
                Text(
                  'Ledger in motion',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class ShellDestination {
  const ShellDestination(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;
}
