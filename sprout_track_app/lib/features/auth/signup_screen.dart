import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import 'widgets/google_auth_button.dart';

const _businessTypes = [
  ('RETAIL', 'Retail / Shop'),
  ('WHOLESALE', 'Wholesale / Distribution'),
  ('SERVICE', 'Services'),
  ('MIXED', 'Mixed (goods + services)'),
];

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 860;
    if (isWide) return const Scaffold(body: _WideLayout());
    return const Scaffold(body: _NarrowLayout());
  }
}

// ── Wide layout ────────────────────────────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  const _WideLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
                  'Nigerian business accounting\nbuilt for the way you trade.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.sand.withValues(alpha: .7),
                      ),
                ),
                const Spacer(),
                ...[
                  (Icons.receipt_long_rounded, 'VAT-compliant invoicing with WHT support'),
                  (Icons.inventory_2_rounded, 'FIFO inventory with real COGS tracking'),
                  (Icons.bar_chart_rounded, 'P&L, cash flow, and VAT returns'),
                  (Icons.lock_rounded, 'Secure, multi-user, Nigerian-built'),
                ].map(
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
                          child: Icon(f.$1, color: AppTheme.sand, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Text(
                              f.$2,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.sand.withValues(alpha: .85),
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: const _SignupForm(isNarrow: false),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Narrow (mobile) layout ─────────────────────────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
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
          padding: const EdgeInsets.fromLTRB(28, 44, 28, 30),
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
                'Create your business account',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.sand.withValues(alpha: .65),
                    ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: scheme.surface,
            child: SingleChildScrollView(child: const _SignupForm(isNarrow: true)),
          ),
        ),
      ],
    );
  }
}

// ── Signup form ────────────────────────────────────────────────────────────────

class _SignupForm extends ConsumerStatefulWidget {
  const _SignupForm({required this.isNarrow});
  final bool isNarrow;

  @override
  ConsumerState<_SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends ConsumerState<_SignupForm> {
  final _formKey       = GlobalKey<FormState>();
  final _fullName      = TextEditingController();
  final _email         = TextEditingController();
  final _businessName  = TextEditingController();
  final _password      = TextEditingController();
  final _confirm       = TextEditingController();
  String _businessType = 'RETAIL';
  bool _obscure        = true;
  bool _loading        = false;
  bool _created        = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _businessName.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/api/auth/register',
        data: {
          'full_name':     _fullName.text.trim(),
          'email':         _email.text.trim().toLowerCase(),
          'password':      _password.text,
          'business_name': _businessName.text.trim(),
          'business_type': _businessType,
        },
      );
      if (mounted) setState(() => _created = true);
    } on DioException catch (e) {
      final code   = e.response?.statusCode;
      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response!.data as Map<String, dynamic>)['detail']
          : null;
      setState(() {
        _error = code == 409
            ? 'An account with this email already exists.'
            : detail is String
                ? detail
                : 'Registration failed. Please try again.';
      });
    } catch (_) {
      setState(() { _error = 'Something went wrong. Check your connection.'; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hPad   = widget.isNarrow ? 24.0 : 0.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 32),
      child: Form(
        key: _formKey,
        child: _created
            ? _SignupSuccess(email: _email.text.trim().toLowerCase())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.isNarrow) ...[
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.moss, Color(0xFF3D4A22)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.eco_rounded, color: AppTheme.sand),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Sprout Track',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
            ],
            Text(
              'Create your account',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Set up your business on Sprout Track in under a minute.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),

            // Full name
            TextFormField(
              controller: _fullName,
              enabled: !_loading,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Your full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Enter your full name.'
                  : null,
            ),
            const SizedBox(height: 14),

            // Business name
            TextFormField(
              controller: _businessName,
              enabled: !_loading,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Business name',
                prefixIcon: Icon(Icons.store_outlined),
              ),
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Enter your business name.'
                  : null,
            ),
            const SizedBox(height: 14),

            // Business type
            DropdownButtonFormField<String>(
              initialValue: _businessType,
              decoration: const InputDecoration(
                labelText: 'Business type',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _businessTypes
                  .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                  .toList(),
              onChanged: _loading
                  ? null
                  : (v) => setState(() => _businessType = v ?? 'RETAIL'),
            ),
            const SizedBox(height: 14),

            // Email
            TextFormField(
              controller: _email,
              enabled: !_loading,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required.';
                if (!v.contains('@')) return 'Enter a valid email.';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Password
            TextFormField(
              controller: _password,
              enabled: !_loading,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required.';
                if (v.length < 8) return 'Use at least 8 characters.';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Confirm password
            TextFormField(
              controller: _confirm,
              enabled: !_loading,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
              validator: (v) =>
                  v != _password.text ? 'Passwords do not match.' : null,
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.terracotta.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.terracotta.withValues(alpha: .22)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 18, color: AppTheme.terracotta),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.terracotta,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 22),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create account'),
            ),
            const SizedBox(height: 12),
            GoogleAuthButton(
              label: 'Sign up with Google',
              businessName: _businessName.text.trim().isEmpty
                  ? null
                  : _businessName.text.trim(),
              businessType: _businessType,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Divider(color: scheme.outlineVariant)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
                Expanded(child: Divider(color: scheme.outlineVariant)),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () => ref.read(authProvider.notifier).loginDemo(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.moss,
                side: BorderSide(color: AppTheme.moss.withValues(alpha: .45)),
              ),
              icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
              label: const Text('Explore demo — no account needed'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                GestureDetector(
                  onTap: _loading ? null : () => context.go('/login'),
                  child: Text(
                    'Sign in',
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
    );
  }
}

class _SignupSuccess extends StatelessWidget {
  const _SignupSuccess({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_read_rounded, size: 56, color: scheme.primary),
        const SizedBox(height: 18),
        Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a verification link to $email. Verify your email, then sign in.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/login'),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }
}
