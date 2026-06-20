import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_provider.dart';
import '../../state/sprout_state.dart';
import '../api_client.dart';

class ApiExpense {
  const ApiExpense({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    this.vendor,
    this.receiptUrl,
    this.isTaxDeductible = false,
  });

  final String  id;
  final String  description;
  final double  amount;
  final String  category;
  final DateTime date;
  final String? vendor;
  final String? receiptUrl;
  final bool    isTaxDeductible;

  bool get hasReceipt => receiptUrl != null && receiptUrl!.isNotEmpty;

  factory ApiExpense.fromJson(Map<String, dynamic> j) => ApiExpense(
        id:              j['id'] as String? ?? '',
        description:     j['description'] as String? ?? '',
        amount:          (j['amount'] as num? ?? 0).toDouble(),
        category:        j['category'] as String? ?? 'General',
        date:            DateTime.tryParse(j['expense_date'] as String? ?? '') ?? DateTime.now(),
        vendor:          j['vendor'] as String?,
        receiptUrl:      j['receipt_url'] as String?,
        isTaxDeductible: j['is_tax_deductible'] as bool? ?? false,
      );

  factory ApiExpense.fromLocal(Expense e) => ApiExpense(
        id:          e.id,
        description: e.description,
        amount:      e.amount.toDouble(),
        category:    e.category,
        date:        e.date,
        receiptUrl:  null,
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class ExpensesNotifier extends AutoDisposeAsyncNotifier<List<ApiExpense>> {
  @override
  Future<List<ApiExpense>> build() => _load();

  Future<List<ApiExpense>> _load() async {
    final isDemo = ref.watch(authProvider).isDemo;
    if (isDemo) {
      return ref
          .watch(sproutStoreProvider)
          .expenses
          .map(ApiExpense.fromLocal)
          .toList();
    }
    final res = await ref.watch(apiClientProvider).get(
      '/api/expenses',
      query: {'limit': 200},
    );
    final items = (res.data['items'] ?? res.data['expenses'] ?? res.data) as List;
    return items
        .map((e) => ApiExpense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> add({
    required String description,
    required double amount,
    required String category,
    DateTime? date,
    String? vendor,
    bool isTaxDeductible = false,
  }) async {
    await ref.read(apiClientProvider).post(
      '/api/expenses',
      data: {
        'description':       description,
        'amount':            amount,
        'category':          category,
        'expense_date':      (date ?? DateTime.now()).toIso8601String().split('T').first,
        if (vendor != null) 'vendor': vendor,
        'is_tax_deductible': isTaxDeductible,
      },
    );
    await refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(apiClientProvider).delete('/api/expenses/$id');
    await refresh();
  }
}

final expensesProvider =
    AsyncNotifierProvider.autoDispose<ExpensesNotifier, List<ApiExpense>>(
  ExpensesNotifier.new,
);
