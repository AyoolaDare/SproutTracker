import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../app/app_theme.dart';
import '../../core/state/sprout_state.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  static const destinations = [
    ShellDestination('Dashboard',  '/',          Icons.dashboard_rounded),
    ShellDestination('Invoices',   '/invoices',  Icons.receipt_long_rounded),
    ShellDestination('Customers',  '/customers', Icons.groups_rounded),
    ShellDestination('Inventory',  '/inventory', Icons.inventory_2_rounded),
    ShellDestination('Expenses',   '/expenses',  Icons.account_balance_wallet_rounded),
    ShellDestination('Reports',    '/reports',   Icons.query_stats_rounded),
    ShellDestination('Settings',   '/settings',  Icons.tune_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read unconditionally so Riverpod tracks it on every layout path
    final profile     = ref.watch(sproutStoreProvider).businessProfile;
    final isMobile    = ResponsiveBreakpoints.of(context).isMobile;
    final location    = GoRouterState.of(context).uri.path;
    final activeIndex = _resolveIndex(location);

    final mobileDestinations = destinations.take(5).toList();
    final mobileIndex        = activeIndex >= mobileDestinations.length ? 0 : activeIndex;

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
          onDestinationSelected: (i) => context.go(destinations[i].path),
          destinations: [
            for (final d in mobileDestinations)
              NavigationDestination(icon: Icon(d.icon), label: d.label),
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
            profile: profile,
          ),
          Expanded(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(child: child),
            ),
          ),
        ],
      ),
    );
  }

  static int _resolveIndex(String path) {
    for (var i = 0; i < destinations.length; i++) {
      if (destinations[i].path == path) return i;
    }
    return 0;
  }
}

// ── Desktop sidebar ────────────────────────────────────────────────────────────

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.destinations,
    required this.activeIndex,
    required this.profile,
  });

  final List<ShellDestination> destinations;
  final int                    activeIndex;
  final BusinessProfile        profile;

  @override
  Widget build(BuildContext context) {
    final scheme  = Theme.of(context).colorScheme;
    final initials = profile.businessName.isNotEmpty
        ? profile.businessName.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : 'ST';

    return Container(
      width: 272,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          right: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BrandLockup(),
          const SizedBox(height: 24),

          // ── Nav items ───────────────────────────────────────────────────────
          for (var i = 0; i < destinations.length; i++)
            _SidebarItem(
              destination: destinations[i],
              selected: i == activeIndex,
              onTap: () => context.go(destinations[i].path),
            ),

          const Spacer(),

          // ── Business profile footer ─────────────────────────────────────────
          const Divider(height: 20),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.go('/settings'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .45),
                ),
              ),
              child: Row(
                children: [
                  // Avatar circle with initials
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppTheme.moss,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: AppTheme.sand,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          profile.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          'Business account',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.tune_rounded, size: 16, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sidebar item ───────────────────────────────────────────────────────────────

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final ShellDestination destination;
  final bool             selected;
  final VoidCallback     onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.moss.withValues(alpha: .12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(
                color: selected ? AppTheme.moss : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                destination.icon,
                size: 20,
                color: selected ? AppTheme.moss : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  destination.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: selected ? AppTheme.moss : scheme.onSurface,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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

// ── Brand lockup ───────────────────────────────────────────────────────────────

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
          width: compact ? 36 : 42,
          height: compact ? 36 : 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.moss, Color(0xFF3D4A22)],
            ),
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
          ),
          child: Icon(
            Icons.eco_rounded,
            color: AppTheme.sand,
            size: compact ? 18 : 22,
          ),
        ),
        const SizedBox(width: 11),
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
                      fontSize: compact ? 14 : 16,
                      color: scheme.onSurface,
                    ),
              ),
              if (!compact)
                Text(
                  'Ledger in motion',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Data class ─────────────────────────────────────────────────────────────────

class ShellDestination {
  const ShellDestination(this.label, this.path, this.icon);
  final String   label;
  final String   path;
  final IconData icon;
}
