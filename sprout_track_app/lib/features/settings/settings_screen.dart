import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/state/sprout_state.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/sprout_card.dart';
import '../../shared/widgets/sprout_page.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sproutStoreProvider).businessProfile;
    final scheme  = Theme.of(context).colorScheme;

    final initials = profile.businessName.isNotEmpty
        ? profile.businessName.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : 'ST';

    return SproutPage(
      title: 'Settings',
      subtitle: 'Business profile, taxes, bank details, and notification controls.',
      action: FilledButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => _BusinessProfileDialog(profile: profile),
        ),
        icon: const Icon(Icons.edit_rounded, size: 18),
        label: const Text('Edit profile'),
      ),
      children: [
        // ── Business profile card ─────────────────────────────────────────────
        SproutCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar + name header
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.moss, Color(0xFF3D4A22)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: AppTheme.sand,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.businessName,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.email,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Contact details
              _InfoRow(icon: Icons.phone_rounded,    value: profile.phone.isEmpty ? '—' : profile.phone),
              const SizedBox(height: 8),
              _InfoRow(icon: Icons.location_on_rounded, value: profile.address.isEmpty ? '—' : profile.address),
              const SizedBox(height: 24),

              // Payment accounts
              const SectionHeader(title: 'Payment accounts'),
              const SizedBox(height: 12),
              if (profile.accounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No bank accounts added yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                )
              else
                for (var i = 0; i < profile.accounts.length; i++) ...[
                  if (i > 0)
                    Divider(height: 16, color: scheme.outlineVariant.withValues(alpha: .4)),
                  _BankAccountRow(profile.accounts[i]),
                ],

              const SizedBox(height: 24),

              // System settings
              const SectionHeader(title: 'System'),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.percent_rounded,
                color: AppTheme.ochre,
                title: 'Tax settings',
                subtitle: 'VAT defaults to 7.5% on all new invoices.',
              ),
              Divider(height: 16, color: scheme.outlineVariant.withValues(alpha: .4)),
              _SettingsTile(
                icon: Icons.notifications_active_rounded,
                color: AppTheme.sage,
                title: 'Notifications',
                subtitle: 'Push subscriptions preserved in the deployment plan.',
              ),
              Divider(height: 16, color: scheme.outlineVariant.withValues(alpha: .4)),
              _SettingsTile(
                icon: Icons.cloud_sync_rounded,
                color: AppTheme.moss,
                title: 'Data sync',
                subtitle: 'Local-first storage. Backend sync connects on deployment.',
              ),

              const SizedBox(height: 24),
              Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: .4)),
              const SizedBox(height: 12),

              // Sign out
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => ref.read(authProvider.notifier).logout(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.terracotta.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: AppTheme.terracotta,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sign out',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: AppTheme.terracotta,
                                fontWeight: FontWeight.w700,
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
      ],
    );
  }
}

// ── Info row ───────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.value});
  final IconData icon;
  final String   value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

// ── Bank account row ───────────────────────────────────────────────────────────

class _BankAccountRow extends StatelessWidget {
  const _BankAccountRow(this.account);
  final BankAccount account;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.moss.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.account_balance_rounded, size: 18, color: AppTheme.moss),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(account.bankName, style: Theme.of(context).textTheme.titleSmall),
              Text(
                account.accountName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: .5)),
          ),
          child: Text(
            account.accountNumber,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
          ),
        ),
      ],
    );
  }
}

// ── Settings tile ──────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color    color;
  final String   title;
  final String   subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
      ],
    );
  }
}

// ── Business profile dialog ────────────────────────────────────────────────────

class _BusinessProfileDialog extends ConsumerStatefulWidget {
  const _BusinessProfileDialog({required this.profile});
  final BusinessProfile profile;

  @override
  ConsumerState<_BusinessProfileDialog> createState() => _BusinessProfileDialogState();
}

class _BusinessProfileDialogState extends ConsumerState<_BusinessProfileDialog> {
  late final businessName = TextEditingController(text: widget.profile.businessName);
  late final email        = TextEditingController(text: widget.profile.email);
  late final phone        = TextEditingController(text: widget.profile.phone);
  late final address      = TextEditingController(text: widget.profile.address);
  BankAccount? get first => widget.profile.accounts.isEmpty ? null : widget.profile.accounts.first;
  late final bankName     = TextEditingController(text: first?.bankName ?? '');
  late final accountName  = TextEditingController(text: first?.accountName ?? '');
  late final accountNumber = TextEditingController(text: first?.accountNumber ?? '');

  @override
  void dispose() {
    businessName.dispose(); email.dispose(); phone.dispose(); address.dispose();
    bankName.dispose(); accountName.dispose(); accountNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Business profile'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Business details', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              TextField(controller: businessName, decoration: const InputDecoration(labelText: 'Business name')),
              const SizedBox(height: 10),
              TextField(controller: email,        decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: phone,   decoration: const InputDecoration(labelText: 'Phone'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: address, decoration: const InputDecoration(labelText: 'Address'))),
                ],
              ),
              const SizedBox(height: 20),
              Text('Bank account', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              TextField(controller: bankName,      decoration: const InputDecoration(labelText: 'Bank name')),
              const SizedBox(height: 10),
              TextField(controller: accountName,   decoration: const InputDecoration(labelText: 'Account name')),
              const SizedBox(height: 10),
              TextField(controller: accountNumber, decoration: const InputDecoration(labelText: 'Account number'), keyboardType: TextInputType.number),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            ref.read(sproutStoreProvider.notifier).updateBusinessProfile(
                  BusinessProfile(
                    businessName: businessName.text,
                    email: email.text,
                    phone: phone.text,
                    address: address.text,
                    accounts: [
                      BankAccount(
                        bankName: bankName.text,
                        accountName: accountName.text,
                        accountNumber: accountNumber.text,
                      ),
                    ],
                  ),
                );
            Navigator.pop(context);
          },
          child: const Text('Save profile'),
        ),
      ],
    );
  }
}
