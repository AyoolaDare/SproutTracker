import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_provider.dart';

class GoogleAuthButton extends ConsumerWidget {
  const GoogleAuthButton({
    super.key,
    required this.label,
    this.businessName,
    this.businessType = 'RETAIL',
  });

  final String label;
  final String? businessName;
  final String businessType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authProvider).isLoading;
    return OutlinedButton.icon(
      onPressed: isLoading
          ? null
          : () => ref.read(authProvider.notifier).loginWithGoogle(
                businessName: businessName,
                businessType: businessType,
              ),
      icon: const Text(
        'G',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
      ),
      label: Text(label),
    );
  }
}
