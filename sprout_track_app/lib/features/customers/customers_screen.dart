import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/sprout_state.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/sprout_card.dart';
import '../../shared/widgets/sprout_page.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(sproutStoreProvider).customers;

    return SproutPage(
      title: 'Customers',
      subtitle: 'Payment history, outstanding balances, and top-spending customers.',
      children: [
        SproutCard(
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              for (final customer in customers)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  leading: CircleAvatar(child: Text(customer.name.characters.first.toUpperCase())),
                  title: Text(customer.name),
                  subtitle: Text(customer.phone.isEmpty ? customer.address : '${customer.phone} • ${customer.address}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Spent ${money(customer.totalSpent)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('Owes ${money(customer.amountOwed)}'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
