import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: scheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .06),
                      blurRadius: 30,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: const Padding(
                  padding: EdgeInsets.all(28),
                  child: _ForgotPasswordForm(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordForm extends ConsumerStatefulWidget {
  const _ForgotPasswordForm();

  @override
  ConsumerState<_ForgotPasswordForm> createState() =>
      _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends ConsumerState<_ForgotPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _email   = TextEditingController();
  bool  _loading = false;
  bool  _sent    = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await ref.read(apiClientProvider).post(
        '/api/auth/password-reset/request',
        data: {'email': _email.text.trim().toLowerCase()},
      );
      if (mounted) setState(() => _sent = true);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      setState(() {
        _error = code == 429
            ? 'Too many attempts. Wait a few minutes and try again.'
            : 'Could not send reset email. Check your connection.';
      });
    } catch (_) {
      setState(() { _error = 'Something went wrong. Please try again.'; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Brand mark
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
        const SizedBox(height: 24),

        if (_sent) ...[
          // ── Success state ─────────────────────────────────────────────────
          Icon(Icons.mark_email_read_rounded, size: 54, color: scheme.primary),
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
            'If an account exists for ${_email.text.trim()}, a password reset link has been sent. Check your spam folder if you don\'t see it.',
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
        ] else ...[
          // ── Request form ──────────────────────────────────────────────────
          Text(
            'Reset your password',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the email address linked to your account and we\'ll send a reset link.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _email,
              enabled: !_loading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required.';
                if (!v.contains('@')) return 'Enter a valid email address.';
                return null;
              },
            ),
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
                : const Text('Send reset link'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loading ? null : () => context.go('/login'),
            child: const Text('Back to sign in'),
          ),
        ],
      ],
    );
  }
}
