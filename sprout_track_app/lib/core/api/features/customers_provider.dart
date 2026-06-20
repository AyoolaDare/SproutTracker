import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_provider.dart';
import '../../state/sprout_state.dart';
import '../api_client.dart';

class ApiCustomer {
  const ApiCustomer({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.company,
    this.address,
    required this.outstandingBalance,
    required this.totalPaid,
    required this.totalRevenue,
    this.isWhtApplicable = false,
    this.status = 'ACTIVE',
  });

  final String  id;
  final String  name;
  final String? email;
  final String? phone;
  final String? company;
  final String? address;
  final double  outstandingBalance;
  final double  totalPaid;
  final double  totalRevenue;
  final bool    isWhtApplicable;
  final String  status;

  factory ApiCustomer.fromJson(Map<String, dynamic> j) => ApiCustomer(
        id:                 j['id'] as String? ?? '',
        name:               j['name'] as String? ?? '',
        email:              j['email'] as String?,
        phone:              j['phone'] as String?,
        company:            j['company'] as String?,
        address:            j['address'] as String?,
        outstandingBalance: (j['outstanding_balance'] as num? ?? 0).toDouble(),
        totalPaid:          (j['total_paid'] as num? ?? 0).toDouble(),
        totalRevenue:       (j['total_revenue'] as num? ?? 0).toDouble(),
        isWhtApplicable:    j['is_wht_applicable'] as bool? ?? false,
        status:             j['status'] as String? ?? 'ACTIVE',
      );

  factory ApiCustomer.fromLocal(Customer c) => ApiCustomer(
        id:                 c.id,
        name:               c.name,
        phone:              c.phone,
        company:            c.company,
        address:            c.address,
        outstandingBalance: c.amountOwed.toDouble(),
        totalPaid:          c.amountPaid.toDouble(),
        totalRevenue:       c.totalSpent.toDouble(),
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class CustomersNotifier extends AutoDisposeAsyncNotifier<List<ApiCustomer>> {
  @override
  Future<List<ApiCustomer>> build() => _load();

  Future<List<ApiCustomer>> _load() async {
    final isDemo = ref.watch(authProvider).isDemo;
    if (isDemo) {
      return ref
          .watch(sproutStoreProvider)
          .customers
          .map(ApiCustomer.fromLocal)
          .toList();
    }
    final res = await ref.watch(apiClientProvider).get(
      '/api/customers',
      query: {'limit': 200},
    );
    final body = res.data as Map<String, dynamic>;
    final items = (body['data'] ?? body['items'] ?? body['customers'] ?? []) as List;
    return items
        .map((e) => ApiCustomer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<ApiCustomer> create({
    required String name,
    String? email,
    String? phone,
    String? company,
    String? address,
    bool isWhtApplicable = false,
  }) async {
    final res = await ref.read(apiClientProvider).post(
      '/api/customers',
      data: {
        'name':               name,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (company != null) 'company': company,
        if (address != null) 'address': address,
        'is_wht_applicable':  isWhtApplicable,
      },
    );
    final customer = ApiCustomer.fromJson(res.data as Map<String, dynamic>);
    await refresh();
    return customer;
  }
}

final customersProvider =
    AsyncNotifierProvider.autoDispose<CustomersNotifier, List<ApiCustomer>>(
  CustomersNotifier.new,
);
