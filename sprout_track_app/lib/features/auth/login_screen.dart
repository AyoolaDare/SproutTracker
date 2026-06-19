import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 860;

    if (isWide) {
      return const Scaffold(body: _WideLayout());
    }
    return const Scaffold(body: _NarrowLayout());
  }
}

// ── Wide (desktop) layout ──────────────────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  const _WideLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left brand panel ─────────────────────────────────────────────────────
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF23271A), Color(0xFF3D4A22), Color(0xFF606C38)],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand mark
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.sand.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.sand.withValues(alpha: .25)),
                  ),
                  child: const Icon(Icons.eco_rounded, color: AppTheme.sand, size: 26),
                ),
                const SizedBox(height: 20),
                Text(
                  'Sprout Track',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: AppTheme.sand,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ledger in motion',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.sand.withValues(alpha: .7),
                      ),
                ),
                const Spacer(),

                // Feature bullets ──────────────────────────────────────────────
                ..._features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppTheme.sand.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(f.icon, color: AppTheme.sand, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.title,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: AppTheme.sand,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              Text(
                                f.subtitle,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.sand.withValues(alpha: .65),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                Text(
                  '© ${DateTime.now().year} Sprout Track · Built for Nigerian SMEs',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.sand.withValues(alpha: .4),
                      ),
                ),
              ],
            ),
          ),
        ),

        // Right form panel ─────────────────────────────────────────────────────
        Expanded(
          flex: 6,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: const Center(child: _LoginForm()),
          ),
        ),
      ],
    );
  }
}

// ── Narrow (mobile / tablet) layout ───────────────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.canvas,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.moss, Color(0xFF3D4A22)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.eco_rounded, color: AppTheme.sand, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sprout Track',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ledger in motion',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 32),
                const _LoginForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared login form ──────────────────────────────────────────────────────────

class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _email    = TextEditingController();
  final _password = TextEditingController();
  bool _obscure   = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome back',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to manage invoices, inventory, and finances.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 28),

            // Email
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),

            // Password
            TextField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Forgot password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Forgot password?',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.moss,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Sign in button
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Text('Sign in'),
              ),
            ),
            const SizedBox(height: 20),

            // Divider with "or" label
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Demo access',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),

            // Demo login shortcut
            OutlinedButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text('Continue with demo data'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feature list data ──────────────────────────────────────────────────────────

class _Feature {
  const _Feature(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String   title;
  final String   subtitle;
}

const _features = [
  _Feature(Icons.receipt_long_rounded,          'Smart invoicing',      'Create, track, and collect payments with VAT support.'),
  _Feature(Icons.inventory_2_rounded,           'Inventory control',    'Real-time stock levels, reorder alerts, and history.'),
  _Feature(Icons.account_balance_wallet_rounded,'Expense tracking',     'Categorise spend and keep deductibles visible.'),
  _Feature(Icons.query_stats_rounded,           'Financial reports',    'P&L statements, cash flow, and margin analysis.'),
];
