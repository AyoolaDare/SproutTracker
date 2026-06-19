import 'package:flutter_riverpod/flutter_riverpod.dart';

final demoDataProvider = Provider<DemoData>((ref) => DemoData.sample());

class DemoData {
  const DemoData({
    required this.metrics,
    required this.cashFlow,
    required this.invoices,
    required this.inventory,
    required this.expenses,
  });

  final List<MetricTileData> metrics;
  final List<CashFlowPoint> cashFlow;
  final List<InvoiceRowData> invoices;
  final List<InventoryRowData> inventory;
  final List<ExpenseRowData> expenses;

  factory DemoData.sample() {
    return DemoData(
      metrics: const [
        MetricTileData('Revenue', 12750000, 18.4, MetricKind.money),
        MetricTileData('Expenses', 3840000, -6.2, MetricKind.money),
        MetricTileData('Net Profit', 8910000, 21.8, MetricKind.money),
        MetricTileData('Inventory Health', 86, 4.0, MetricKind.percent),
      ],
      cashFlow: const [
        CashFlowPoint('Jan', 1.8, 1.1),
        CashFlowPoint('Feb', 2.4, 1.2),
        CashFlowPoint('Mar', 3.1, 1.8),
        CashFlowPoint('Apr', 3.5, 2.0),
        CashFlowPoint('May', 4.2, 2.4),
        CashFlowPoint('Jun', 5.0, 2.8),
      ],
      invoices: const [
        InvoiceRowData('INV-2026-0042', 'Musa Retail Ltd', 870000, 'Paid'),
        InvoiceRowData('INV-2026-0041', 'Adenike Stores', 420000, 'Pending'),
        InvoiceRowData('INV-2026-0040', 'Kano Fresh Mart', 1260000, 'Overdue'),
        InvoiceRowData('INV-2026-0039', 'Yaba Foods', 310000, 'Paid'),
      ],
      inventory: const [
        InventoryRowData('Golden Rice 25kg', 'GOL-RIC-223', 184, 35, 82),
        InventoryRowData('Palm Oil 5L', 'PAL-OIL-882', 39, 45, 31),
        InventoryRowData('Tomato Paste Carton', 'TOM-PAS-411', 12, 30, 18),
        InventoryRowData('Beans 10kg', 'BEA-10K-104', 96, 30, 76),
      ],
      expenses: const [
        ExpenseRowData('Delivery fuel', 'Logistics', 78000),
        ExpenseRowData('Market levy', 'Operations', 35000),
        ExpenseRowData('Warehouse rent', 'Rent', 420000),
        ExpenseRowData('Internet subscription', 'Utilities', 28000),
      ],
    );
  }
}

enum MetricKind { money, percent }

class MetricTileData {
  const MetricTileData(this.label, this.value, this.delta, this.kind);
  final String label;
  final num value;
  final double delta;
  final MetricKind kind;
}

class CashFlowPoint {
  const CashFlowPoint(this.month, this.income, this.expenses);
  final String month;
  final double income;
  final double expenses;
}

class InvoiceRowData {
  const InvoiceRowData(this.number, this.customer, this.amount, this.status);
  final String number;
  final String customer;
  final num amount;
  final String status;
}

class InventoryRowData {
  const InventoryRowData(
    this.name,
    this.sku,
    this.quantity,
    this.reorderLevel,
    this.health,
  );

  final String name;
  final String sku;
  final int quantity;
  final int reorderLevel;
  final int health;
}

class ExpenseRowData {
  const ExpenseRowData(this.description, this.category, this.amount);
  final String description;
  final String category;
  final num amount;
}
