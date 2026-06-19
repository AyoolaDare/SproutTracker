import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/sprout_state.dart';
import '../../shared/widgets/sprout_card.dart';
import '../../shared/widgets/sprout_page.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sproutStoreProvider).businessProfile;

    return SproutPage(
      title: 'Settings',
      subtitle: 'Business profile, taxes, bank details, storage, and notification controls.',
      action: FilledButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => _BusinessProfileDialog(profile: profile),
        ),
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Edit profile'),
      ),
      children: [
        SproutCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.businessName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(profile.address),
              Text('${profile.email} • ${profile.phone}'),
              const Divider(height: 32),
              Text(
                'Payment accounts',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              for (final account in profile.accounts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_balance_rounded),
                  title: Text(account.bankName),
                  subtitle: Text(account.accountName),
                  trailing: Text(account.accountNumber, style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              const Divider(height: 32),
              const _SettingsRow(
                icon: Icons.percent_rounded,
                title: 'Tax settings',
                subtitle: 'VAT defaults to 7.5%, matching the current invoice form.',
              ),
              const _SettingsRow(
                icon: Icons.notifications_active_rounded,
                title: 'Notifications',
                subtitle: 'Push subscription support is preserved in the migration plan.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BusinessProfileDialog extends ConsumerStatefulWidget {
  const _BusinessProfileDialog({required this.profile});

  final BusinessProfile profile;

  @override
  ConsumerState<_BusinessProfileDialog> createState() => _BusinessProfileDialogState();
}

class _BusinessProfileDialogState extends ConsumerState<_BusinessProfileDialog> {
  late final businessName = TextEditingController(text: widget.profile.businessName);
  late final email = TextEditingController(text: widget.profile.email);
  late final phone = TextEditingController(text: widget.profile.phone);
  late final address = TextEditingController(text: widget.profile.address);
  BankAccount? get firstAccount => widget.profile.accounts.isEmpty ? null : widget.profile.accounts.first;
  late final bankName = TextEditingController(text: firstAccount?.bankName ?? '');
  late final accountName = TextEditingController(text: firstAccount?.accountName ?? '');
  late final accountNumber = TextEditingController(text: firstAccount?.accountNumber ?? '');

  @override
  void dispose() {
    businessName.dispose();
    email.dispose();
    phone.dispose();
    address.dispose();
    bankName.dispose();
    accountName.dispose();
    accountNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Business profile'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: businessName, decoration: const InputDecoration(labelText: 'Business name')),
              const SizedBox(height: 10),
              TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 10),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 10),
              TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 16),
              TextField(controller: bankName, decoration: const InputDecoration(labelText: 'Bank name')),
              const SizedBox(height: 10),
              TextField(controller: accountName, decoration: const InputDecoration(labelText: 'Account name')),
              const SizedBox(height: 10),
              TextField(controller: accountNumber, decoration: const InputDecoration(labelText: 'Account number')),
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

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
