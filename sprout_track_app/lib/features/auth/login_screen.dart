import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../core/auth/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 860;
    if (isWide) return const Scaffold(body: _WideLayout());
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
        // Left brand panel
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

        // Right form panel
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Dark brand header — same gradient as the desktop left panel
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF23271A), Color(0xFF3D4A22), Color(0xFF606C38)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(28, 44, 28, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.sand.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.sand.withValues(alpha: .25)),
                ),
                child: const Icon(Icons.eco_rounded, color: AppTheme.sand, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                'Sprout Track',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.sand,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ledger in motion',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.sand.withValues(alpha: .65),
                    ),
              ),
            ],
          ),
        ),

        // White form section — proper contrast for input fields
        Expanded(
          child: ColoredBox(
            color: scheme.surface,
            child: SingleChildScrollView(
              child: const _LoginForm(),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Login form ─────────────────────────────────────────────────────────────────

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm();

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _formKey       = GlobalKey<FormState>();
  final _email         = TextEditingController();
  final _password      = TextEditingController();
  final _emailFocus    = FocusNode();
  final _passwordFocus = FocusNode();
  bool  _obscure       = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).login(_email.text.trim(), _password.text);
  }

  void _goToForgotPassword() => context.push('/forgot-password');

  @override
  Widget build(BuildContext context) {
    final scheme    = Theme.of(context).colorScheme;
    final auth      = ref.watch(authProvider);
    final isLoading = auth.isLoading;
    final error     = auth.error;

    final isNarrow = MediaQuery.sizeOf(context).width < 860;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isNarrow ? 24 : 36,
          vertical: 36,
        ),
        child: Form(
          key: _formKey,
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

              // Email field
              TextFormField(
                controller: _email,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enabled: !isLoading,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required.';
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Password field
              TextFormField(
                controller: _password,
                focusNode: _passwordFocus,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                enabled: !isLoading,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: isLoading
                        ? null
                        : () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required.';
                  if (v.length < 6) return 'Password must be at least 6 characters.';
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isLoading ? null : _goToForgotPassword,
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
              const SizedBox(height: 16),

              // Error banner
              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.terracotta.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.terracotta.withValues(alpha: .25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: AppTheme.terracotta,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.terracotta,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Sign in button
              FilledButton(
                onPressed: isLoading ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sign in'),
                ),
              ),
              const SizedBox(height: 20),

              // Demo divider
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

              // Demo login
              OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => ref.read(authProvider.notifier).loginDemo(),
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text('Continue with demo data'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'New to Sprout Track? ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  GestureDetector(
                    onTap: isLoading ? null : () => context.push('/signup'),
                    child: Text(
                      'Create account',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.moss,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Feature list ───────────────────────────────────────────────────────────────

class _Feature {
  const _Feature(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String   title;
  final String   subtitle;
}

const _features = [
  _Feature(
    Icons.receipt_long_rounded,
    'Smart invoicing',
    'Create, track, and collect payments with VAT support.',
  ),
  _Feature(
    Icons.inventory_2_rounded,
    'Inventory control',
    'Real-time stock levels, reorder alerts, and history.',
  ),
  _Feature(
    Icons.account_balance_wallet_rounded,
    'Expense tracking',
    'Categorise spend and keep deductibles visible.',
  ),
  _Feature(
    Icons.query_stats_rounded,
    'Financial reports',
    'P&L statements, cash flow, and margin analysis.',
  ),
];
