import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_provider.dart';
import '../../state/sprout_state.dart';
import '../api_client.dart';

class ApiProduct {
  const ApiProduct({
    required this.id,
    required this.name,
    required this.sku,
    this.category,
    this.supplier,
    required this.sellingPrice,
    required this.currentStock,
    required this.reorderLevel,
    required this.averageCost,
    this.trackInventory = true,
  });

  final String  id;
  final String  name;
  final String  sku;
  final String? category;
  final String? supplier;
  final double  sellingPrice;
  final int     currentStock;
  final int     reorderLevel;
  final double  averageCost;
  final bool    trackInventory;

  bool get isLowStock => currentStock <= reorderLevel;
  double get stockValue => currentStock * averageCost;

  factory ApiProduct.fromJson(Map<String, dynamic> j) => ApiProduct(
        id:             j['id'] as String? ?? '',
        name:           j['name'] as String? ?? '',
        sku:            j['sku'] as String? ?? '',
        category:       j['category'] as String?,
        supplier:       j['supplier'] as String?,
        sellingPrice:   (j['selling_price'] as num? ?? 0).toDouble(),
        currentStock:   (j['current_stock'] as num? ?? 0).toInt(),
        reorderLevel:   (j['reorder_level'] as num? ?? 0).toInt(),
        averageCost:    (j['average_cost'] as num? ?? 0).toDouble(),
        trackInventory: j['track_inventory'] as bool? ?? true,
      );

  factory ApiProduct.fromLocal(InventoryItem i) => ApiProduct(
        id:           i.id,
        name:         i.name,
        sku:          i.sku,
        category:     i.category,
        supplier:     i.supplier,
        sellingPrice: i.unitCost.toDouble(),
        currentStock: i.quantity,
        reorderLevel: i.reorderLevel,
        averageCost:  i.unitCost.toDouble(),
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class ProductsNotifier extends AutoDisposeAsyncNotifier<List<ApiProduct>> {
  @override
  Future<List<ApiProduct>> build() => _load();

  Future<List<ApiProduct>> _load() async {
    final isDemo = ref.watch(authProvider).isDemo;
    if (isDemo) {
      return ref
          .watch(sproutStoreProvider)
          .inventory
          .map(ApiProduct.fromLocal)
          .toList();
    }
    final res = await ref.watch(apiClientProvider).get(
      '/api/products',
      query: {'limit': 100},
    );
    final body = res.data as Map<String, dynamic>;
    final items = (body['data'] ?? body['items'] ?? body['products'] ?? []) as List;
    return items
        .map((e) => ApiProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> receiveStock({
    required String productId,
    required int quantity,
    required double unitCost,
    String? supplierRef,
    String? batchNumber,
    String? notes,
  }) async {
    await ref.read(apiClientProvider).post(
      '/api/inventory/receive',
      data: {
        'product_id':   productId,
        'quantity':     quantity,
        'unit_cost':    unitCost,
        if (supplierRef != null) 'supplier_ref': supplierRef,
        if (batchNumber != null) 'batch_number': batchNumber,
        if (notes != null) 'notes': notes,
      },
    );
    await refresh();
  }

  Future<void> adjustStock({
    required String productId,
    required int quantity,
    required String reason,
    String? notes,
  }) async {
    await ref.read(apiClientProvider).post(
      '/api/inventory/adjust',
      data: {
        'product_id': productId,
        'quantity':   quantity,
        'reason':     reason,
        if (notes != null) 'notes': notes,
      },
    );
    await refresh();
  }

  Future<void> deleteProduct(String id) async {
    final isDemo = ref.read(authProvider).isDemo;
    if (!isDemo) {
      await ref.read(apiClientProvider).delete('/api/products/$id');
    }
    await refresh();
  }

  Future<void> addProduct({
    required String name,
    required double sellingPrice,
    String? sku,
    String? category,
    String? supplier,
    int reorderLevel = 0,
    bool trackInventory = true,
  }) async {
    await ref.read(apiClientProvider).post(
      '/api/products',
      data: {
        'name':             name,
        'selling_price':    sellingPrice,
        if (sku != null) 'sku': sku,
        if (category != null) 'category': category,
        if (supplier != null) 'supplier': supplier,
        'reorder_level':    reorderLevel,
        'track_inventory':  trackInventory,
      },
    );
    await refresh();
  }
}

final productsProvider =
    AsyncNotifierProvider.autoDispose<ProductsNotifier, List<ApiProduct>>(
  ProductsNotifier.new,
);
