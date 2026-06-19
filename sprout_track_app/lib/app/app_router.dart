import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_provider.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/customers/customers_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/expenses/expenses_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/invoices/invoice_print_screen.dart';
import '../features/invoices/invoices_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';

Page<void> _fadePage({required GoRouterState state, required Widget child}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 160),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    transitionsBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.read(authProvider.notifier);

  return GoRouter(
    initialLocation: '/',
    // Re-evaluate redirect every time auth state changes
    refreshListenable: GoRouterRefreshStream(authNotifier.stream),
    redirect: (context, routerState) {
      final auth      = ref.read(authProvider);
      final isOnLogin = routerState.matchedLocation == '/login';
      final isOnReset = routerState.matchedLocation == '/reset-password';

      // Still initialising — don't redirect, AppShell shows a spinner instead
      if (auth.status == AuthStatus.loading) return null;

      // Force unauthenticated users to the login page
      if (auth.status == AuthStatus.unauthenticated && !isOnLogin && !isOnReset) {
        return '/login';
      }

      // Authenticated user hitting the login page — send home
      if (auth.status == AuthStatus.authenticated && (isOnLogin || isOnReset)) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/reset-password',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: ResetPasswordScreen(
            token: state.uri.queryParameters['token'] ?? '',
          ),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => _fadePage(
              state: state,
              child: const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/invoices',
            pageBuilder: (context, state) => _fadePage(
              state: state,
              child: const InvoicesScreen(),
            ),
          ),
          GoRoute(
            path: '/invoices/:id/print',
            pageBuilder: (context, state) => _fadePage(
              state: state,
              child: InvoicePrintScreen(
                invoiceId: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: '/customers',
            pageBuilder: (context, state) => _fadePage(
              state: state,
              child: const CustomersScreen(),
            ),
          ),
          GoRoute(
            path: '/inventory',
            pageBuilder: (context, state) => _fadePage(
              state: state,
              child: const InventoryScreen(),
            ),
          ),
          GoRoute(
            path: '/expenses',
            pageBuilder: (context, state) => _fadePage(
              state: state,
              child: const ExpensesScreen(),
            ),
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (context, state) => _fadePage(
              state: state,
              child: const ReportsScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => _fadePage(
              state: state,
              child: const SettingsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});
