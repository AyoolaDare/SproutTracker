import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../core/state/sprout_state.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/sprout_card.dart';
import '../../shared/widgets/sprout_page.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(sproutStoreProvider).customers;
    final scheme    = Theme.of(context).colorScheme;

    return SproutPage(
      title: 'Customers',
      subtitle: 'Payment history, outstanding balances, and top-spending customers.',
      children: [
        SproutCard(
          padding: EdgeInsets.zero,
          child: customers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.groups_rounded,
                          size: 40,
                          color: scheme.onSurfaceVariant.withValues(alpha: .35),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No customers yet.\nCustomers are added automatically when you create an invoice.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Column headers
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: .4),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 42 + 14),
                          Expanded(
                            child: Text(
                              'Name / Contact',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          Text(
                            'Balance',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    for (var i = 0; i < customers.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 18,
                          endIndent: 18,
                          color: scheme.outlineVariant.withValues(alpha: .45),
                        ),
                      _CustomerRow(customers[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow(this.customer);
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final scheme  = Theme.of(context).colorScheme;
    final initials = customer.name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();
    final hasDebt  = customer.amountOwed > 0;

    // Assign a deterministic avatar color from name hash
    final avatarColors = [
      AppTheme.moss,
      AppTheme.sage,
      AppTheme.clay,
      AppTheme.terracotta,
      AppTheme.ochre,
    ];
    final avatarColor = avatarColors[customer.name.length % avatarColors.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: .18),
              shape: BoxShape.circle,
              border: Border.all(color: avatarColor.withValues(alpha: .3)),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                color: avatarColor,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Name + contact
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  customer.phone.isEmpty ? customer.address : '${customer.phone} · ${customer.address}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Financial summary
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(customer.totalSpent),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              if (hasDebt)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.terracotta.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Owes ${money(customer.amountOwed)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.terracotta,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.moss.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Settled',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.moss,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
