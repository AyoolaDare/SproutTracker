import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final sproutStoreProvider =
    StateNotifierProvider<SproutStore, SproutState>((ref) => SproutStore());

class SproutStore extends StateNotifier<SproutState> {
  SproutStore() : super(SproutState.seed());

  String _id(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  String nextInvoiceNumber() {
    final initials = state.businessProfile.businessName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    final prefix = initials.isEmpty ? 'INV' : initials.substring(0, min(3, initials.length));
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}-${100 + Random().nextInt(900)}';
  }

  void addProduct({
    required String name,
    required int quantity,
    required num unitCost,
    String? category,
    String? supplier,
    int reorderLevel = 0,
    String? sku,
  }) {
    final productSku = sku?.trim().isNotEmpty == true
        ? sku!.trim()
        : '${name.substring(0, min(3, name.length)).toUpperCase()}-${100 + Random().nextInt(900)}';
    final product = InventoryItem(
      id: _id('product'),
      name: name.trim(),
      sku: productSku,
      category: category?.trim().isEmpty == true ? 'Uncategorized' : category?.trim() ?? 'Uncategorized',
      supplier: supplier?.trim() ?? '',
      unitCost: unitCost,
      quantity: quantity,
      reorderLevel: reorderLevel,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      inventory: [...state.inventory, product]..sort((a, b) => a.name.compareTo(b.name)),
      inventoryHistory: [
        InventoryHistoryEntry(
          id: _id('history'),
          itemId: product.id,
          itemName: product.name,
          date: DateTime.now(),
          type: 'Created',
          change: quantity,
          newQuantity: quantity,
          details: 'Initial stock created',
        ),
        ...state.inventoryHistory,
      ],
    );
  }

  void adjustInventory({
    required String itemId,
    required int adjustment,
    required String reason,
  }) {
    if (adjustment == 0) {
      throw StateError('Adjustment cannot be zero.');
    }

    final item = state.inventory.firstWhere((entry) => entry.id == itemId);
    final newQuantity = item.quantity + adjustment;
    if (newQuantity < 0) {
      throw StateError('Stock quantity cannot be negative.');
    }

    state = state.copyWith(
      inventory: [
        for (final entry in state.inventory)
          if (entry.id == itemId) entry.copyWith(quantity: newQuantity) else entry,
      ],
      inventoryHistory: [
        InventoryHistoryEntry(
          id: _id('history'),
          itemId: item.id,
          itemName: item.name,
          date: DateTime.now(),
          type: 'Adjustment',
          change: adjustment,
          newQuantity: newQuantity,
          details: reason,
        ),
        ...state.inventoryHistory,
      ],
    );
  }

  void deleteInventoryItem(String itemId) {
    final item = state.inventory.firstWhere((entry) => entry.id == itemId);
    state = state.copyWith(
      inventory: state.inventory.where((entry) => entry.id != itemId).toList(),
      inventoryHistory: [
        InventoryHistoryEntry(
          id: _id('history'),
          itemId: item.id,
          itemName: item.name,
          date: DateTime.now(),
          type: 'Deleted',
          change: -item.quantity,
          newQuantity: 0,
          details: 'Item permanently deleted',
        ),
        ...state.inventoryHistory,
      ],
    );
  }

  Invoice createInvoice({
    required String customerName,
    required List<InvoiceLineItem> lineItems,
    required PaymentMethod paymentMethod,
    DateTime? issueDate,
    DateTime? dueDate,
    String? phone,
    String? company,
    String? address,
    bool calculateVat = false,
  }) {
    if (customerName.trim().isEmpty) {
      throw StateError('Customer name is required.');
    }
    if (lineItems.isEmpty) {
      throw StateError('Please add at least one product to the invoice.');
    }

    for (final item in lineItems) {
      if (item.productId == null) continue;
      final product = state.inventory.firstWhere((entry) => entry.id == item.productId);
      if (product.quantity < item.quantity) {
        throw StateError('Not enough stock for ${product.name}. Only ${product.quantity} available.');
      }
    }

    final subtotal = lineItems.fold<num>(0, (sum, item) => sum + item.lineTotal);
    final vat = calculateVat ? subtotal * .075 : 0;
    final total = subtotal + vat;
    final paidNow = paymentMethod == PaymentMethod.cash || paymentMethod == PaymentMethod.transfer;
    final invoiceNumber = nextInvoiceNumber();
    final customer = _upsertCustomer(
      name: customerName,
      phone: phone,
      company: company,
      address: address,
      totalAmount: total,
      amountPaid: paidNow ? total : 0,
    );

    final updatedInventory = [...state.inventory];
    final history = <InventoryHistoryEntry>[];
    final sales = <SaleEntry>[];

    for (final item in lineItems) {
      final productId = item.productId;
      if (productId == null) continue;
      final index = updatedInventory.indexWhere((entry) => entry.id == productId);
      final product = updatedInventory[index];
      final newQuantity = product.quantity - item.quantity;
      updatedInventory[index] = product.copyWith(quantity: newQuantity);
      history.add(
        InventoryHistoryEntry(
          id: _id('history'),
          itemId: product.id,
          itemName: product.name,
          date: DateTime.now(),
          type: 'Sale',
          change: -item.quantity,
          newQuantity: newQuantity,
          details: 'Sold on Invoice #$invoiceNumber',
        ),
      );
      sales.add(
        SaleEntry(
          id: _id('sale'),
          productId: product.id,
          productName: product.name,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          total: item.lineTotal,
          invoiceNumber: invoiceNumber,
          date: DateTime.now(),
        ),
      );
    }

    final invoice = Invoice(
      id: _id('invoice'),
      invoiceNumber: invoiceNumber,
      customerId: customer.id,
      customerName: customer.name,
      customerPhone: phone ?? customer.phone,
      customerCompany: company ?? customer.company,
      customerAddress: address ?? customer.address,
      lineItems: lineItems,
      issueDate: issueDate ?? DateTime.now(),
      dueDate: dueDate ?? DateTime.now().add(const Duration(days: 30)),
      paymentMethod: paymentMethod,
      status: paidNow ? InvoiceStatus.paid : InvoiceStatus.pending,
      subtotal: subtotal,
      vatAmount: vat,
      amount: total,
      amountPaid: paidNow ? total : 0,
      transactionId: paidNow ? '${paymentMethod.label.toUpperCase()}-${DateTime.now().millisecondsSinceEpoch}' : null,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      customers: [
        for (final entry in state.customers)
          if (entry.id == customer.id) customer else entry,
        if (!state.customers.any((entry) => entry.id == customer.id)) customer,
      ]..sort((a, b) => a.name.compareTo(b.name)),
      inventory: updatedInventory..sort((a, b) => a.name.compareTo(b.name)),
      invoices: [invoice, ...state.invoices],
      inventoryHistory: [...history, ...state.inventoryHistory],
      sales: [...sales, ...state.sales],
    );
    return invoice;
  }

  Customer _upsertCustomer({
    required String name,
    String? phone,
    String? company,
    String? address,
    required num totalAmount,
    required num amountPaid,
  }) {
    final existing = state.customers
        .where((customer) => customer.name.toLowerCase() == name.trim().toLowerCase())
        .firstOrNull;
    if (existing == null) {
      return Customer(
        id: _id('customer'),
        name: name.trim(),
        phone: phone ?? '',
        company: company ?? '',
        address: address ?? '',
        amountOwed: totalAmount - amountPaid,
        amountPaid: amountPaid,
        totalSpent: totalAmount,
      );
    }
    return existing.copyWith(
      phone: phone?.trim().isNotEmpty == true ? phone!.trim() : existing.phone,
      company: company?.trim().isNotEmpty == true ? company!.trim() : existing.company,
      address: address?.trim().isNotEmpty == true ? address!.trim() : existing.address,
      amountOwed: existing.amountOwed + totalAmount - amountPaid,
      amountPaid: existing.amountPaid + amountPaid,
      totalSpent: existing.totalSpent + totalAmount,
    );
  }

  void recordInvoicePayment(String invoiceId, num amount) {
    if (amount <= 0) throw StateError('Payment amount must be positive.');
    final invoice = state.invoices.firstWhere((entry) => entry.id == invoiceId);
    final newPaid = invoice.amountPaid + amount;
    final newStatus = newPaid >= invoice.amount ? InvoiceStatus.paid : invoice.status;
    final customer = state.customers.firstWhere((entry) => entry.id == invoice.customerId);

    state = state.copyWith(
      invoices: [
        for (final entry in state.invoices)
          if (entry.id == invoiceId) entry.copyWith(amountPaid: newPaid, status: newStatus) else entry,
      ],
      customers: [
        for (final entry in state.customers)
          if (entry.id == customer.id)
            entry.copyWith(
              amountPaid: entry.amountPaid + amount,
              amountOwed: max<num>(0, entry.amountOwed - amount),
            )
          else
            entry,
      ],
    );
  }

  void deleteInvoice(String invoiceId) {
    final invoice = state.invoices.firstWhere((entry) => entry.id == invoiceId);
    final inventory = [...state.inventory];
    num refundValue = 0;

    for (final item in invoice.lineItems) {
      if (item.productId == null) continue;
      final index = inventory.indexWhere((entry) => entry.id == item.productId);
      if (index < 0) continue;
      final product = inventory[index];
      inventory[index] = product.copyWith(quantity: product.quantity + item.quantity);
      refundValue += item.quantity * product.unitCost;
    }

    state = state.copyWith(
      invoices: state.invoices.where((entry) => entry.id != invoiceId).toList(),
      inventory: inventory..sort((a, b) => a.name.compareTo(b.name)),
      inventoryHistory: [
        InventoryHistoryEntry(
          id: _id('history'),
          itemId: null,
          itemName: 'Refund of Invoice #${invoice.invoiceNumber}',
          date: DateTime.now(),
          type: 'Goods Return',
          change: 0,
          newQuantity: 0,
          details: 'Invoice deleted. Refunded value: ${refundValue.toStringAsFixed(2)}',
          amount: refundValue,
        ),
        ...state.inventoryHistory,
      ],
    );
  }

  void addExpense({
    required String description,
    required num amount,
    required String category,
    DateTime? date,
  }) {
    state = state.copyWith(
      expenses: [
        Expense(
          id: _id('expense'),
          description: description,
          amount: amount,
          category: category.trim().isEmpty ? 'General' : category.trim(),
          date: date ?? DateTime.now(),
          hasReceipt: false,
          createdAt: DateTime.now(),
        ),
        ...state.expenses,
      ],
    );
  }

  void deleteExpense(String expenseId) {
    state = state.copyWith(
      expenses: state.expenses.where((entry) => entry.id != expenseId).toList(),
    );
  }

  void updateBusinessProfile(BusinessProfile profile) {
    state = state.copyWith(businessProfile: profile);
  }
}

class SproutState {
  const SproutState({
    required this.businessProfile,
    required this.customers,
    required this.inventory,
    required this.invoices,
    required this.expenses,
    required this.inventoryHistory,
    required this.sales,
  });

  final BusinessProfile businessProfile;
  final List<Customer> customers;
  final List<InventoryItem> inventory;
  final List<Invoice> invoices;
  final List<Expense> expenses;
  final List<InventoryHistoryEntry> inventoryHistory;
  final List<SaleEntry> sales;

  factory SproutState.seed() {
    final inventory = [
      InventoryItem(
        id: 'product-rice',
        name: 'Golden Rice 25kg',
        sku: 'GOL-RIC-223',
        category: 'Food staples',
        supplier: 'Lagos Main Market',
        unitCost: 42000,
        quantity: 184,
        reorderLevel: 35,
        createdAt: DateTime.now().subtract(const Duration(days: 24)),
      ),
      InventoryItem(
        id: 'product-oil',
        name: 'Palm Oil 5L',
        sku: 'PAL-OIL-882',
        category: 'Cooking oil',
        supplier: 'Aba Wholesale',
        unitCost: 9500,
        quantity: 39,
        reorderLevel: 45,
        createdAt: DateTime.now().subtract(const Duration(days: 18)),
      ),
      InventoryItem(
        id: 'product-tomato',
        name: 'Tomato Paste Carton',
        sku: 'TOM-PAS-411',
        category: 'Canned goods',
        supplier: 'Trade Depot',
        unitCost: 18500,
        quantity: 12,
        reorderLevel: 30,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
    ];

    return SproutState(
      businessProfile: const BusinessProfile(
        businessName: 'Sprout Track Demo',
        email: 'hello@sprouttrack.local',
        phone: '0800 123 4567',
        address: '12 Market Road, Lagos',
        accounts: [
          BankAccount(bankName: 'GTBank', accountName: 'Sprout Track Demo', accountNumber: '0123456789'),
        ],
      ),
      customers: const [
        Customer(
          id: 'customer-musa',
          name: 'Musa Retail Ltd',
          phone: '0803 000 1111',
          company: 'Musa Retail Ltd',
          address: 'Kano Road',
          amountOwed: 0,
          amountPaid: 870000,
          totalSpent: 870000,
        ),
        Customer(
          id: 'customer-adenike',
          name: 'Adenike Stores',
          phone: '0802 333 7788',
          company: 'Adenike Stores',
          address: 'Yaba, Lagos',
          amountOwed: 420000,
          amountPaid: 0,
          totalSpent: 420000,
        ),
      ],
      inventory: inventory,
      invoices: [
        Invoice(
          id: 'invoice-1',
          invoiceNumber: 'STD-2026-0042',
          customerId: 'customer-musa',
          customerName: 'Musa Retail Ltd',
          customerPhone: '0803 000 1111',
          customerCompany: 'Musa Retail Ltd',
          customerAddress: 'Kano Road',
          lineItems: const [
            InvoiceLineItem(productId: 'product-rice', name: 'Golden Rice 25kg', quantity: 10, unitPrice: 58000),
            InvoiceLineItem(productId: 'product-oil', name: 'Palm Oil 5L', quantity: 20, unitPrice: 14500),
          ],
          issueDate: DateTime(2026, 6, 12),
          dueDate: DateTime(2026, 7, 12),
          paymentMethod: PaymentMethod.transfer,
          status: InvoiceStatus.paid,
          subtotal: 870000,
          vatAmount: 0,
          amount: 870000,
          amountPaid: 870000,
          createdAt: DateTime(2026, 6, 12),
          transactionId: 'TRANSFER-20260612',
        ),
        Invoice(
          id: 'invoice-2',
          invoiceNumber: 'STD-2026-0041',
          customerId: 'customer-adenike',
          customerName: 'Adenike Stores',
          customerPhone: '0802 333 7788',
          customerCompany: 'Adenike Stores',
          customerAddress: 'Yaba, Lagos',
          lineItems: const [
            InvoiceLineItem(productId: 'product-tomato', name: 'Tomato Paste Carton', quantity: 20, unitPrice: 21000),
          ],
          issueDate: DateTime(2026, 6, 9),
          dueDate: DateTime(2026, 7, 9),
          paymentMethod: PaymentMethod.credit,
          status: InvoiceStatus.pending,
          subtotal: 420000,
          vatAmount: 0,
          amount: 420000,
          amountPaid: 0,
          createdAt: DateTime(2026, 6, 9),
        ),
      ],
      expenses: [
        Expense(
          id: 'expense-1',
          description: 'Warehouse rent',
          amount: 420000,
          category: 'Rent',
          date: DateTime(2026, 6, 1),
          hasReceipt: false,
          createdAt: DateTime(2026, 6, 1),
        ),
        Expense(
          id: 'expense-2',
          description: 'Delivery fuel',
          amount: 78000,
          category: 'Logistics',
          date: DateTime(2026, 6, 14),
          hasReceipt: false,
          createdAt: DateTime(2026, 6, 14),
        ),
      ],
      inventoryHistory: [
        InventoryHistoryEntry(
          id: 'history-1',
          itemId: 'product-oil',
          itemName: 'Palm Oil 5L',
          date: DateTime(2026, 6, 14),
          type: 'Adjustment',
          change: -6,
          newQuantity: 39,
          details: 'Damaged units removed',
        ),
      ],
      sales: const [],
    );
  }

  SproutState copyWith({
    BusinessProfile? businessProfile,
    List<Customer>? customers,
    List<InventoryItem>? inventory,
    List<Invoice>? invoices,
    List<Expense>? expenses,
    List<InventoryHistoryEntry>? inventoryHistory,
    List<SaleEntry>? sales,
  }) {
    return SproutState(
      businessProfile: businessProfile ?? this.businessProfile,
      customers: customers ?? this.customers,
      inventory: inventory ?? this.inventory,
      invoices: invoices ?? this.invoices,
      expenses: expenses ?? this.expenses,
      inventoryHistory: inventoryHistory ?? this.inventoryHistory,
      sales: sales ?? this.sales,
    );
  }
}

class BusinessProfile {
  const BusinessProfile({
    required this.businessName,
    required this.email,
    required this.phone,
    required this.address,
    required this.accounts,
    this.logoUrl,
  });

  final String businessName;
  final String email;
  final String phone;
  final String address;
  final String? logoUrl;
  final List<BankAccount> accounts;

  BusinessProfile copyWith({
    String? businessName,
    String? email,
    String? phone,
    String? address,
    String? logoUrl,
    List<BankAccount>? accounts,
  }) {
    return BusinessProfile(
      businessName: businessName ?? this.businessName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      logoUrl: logoUrl ?? this.logoUrl,
      accounts: accounts ?? this.accounts,
    );
  }
}

class BankAccount {
  const BankAccount({
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
  });

  final String bankName;
  final String accountName;
  final String accountNumber;
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.company,
    required this.address,
    required this.amountOwed,
    required this.amountPaid,
    required this.totalSpent,
  });

  final String id;
  final String name;
  final String phone;
  final String company;
  final String address;
  final num amountOwed;
  final num amountPaid;
  final num totalSpent;

  Customer copyWith({
    String? phone,
    String? company,
    String? address,
    num? amountOwed,
    num? amountPaid,
    num? totalSpent,
  }) {
    return Customer(
      id: id,
      name: name,
      phone: phone ?? this.phone,
      company: company ?? this.company,
      address: address ?? this.address,
      amountOwed: amountOwed ?? this.amountOwed,
      amountPaid: amountPaid ?? this.amountPaid,
      totalSpent: totalSpent ?? this.totalSpent,
    );
  }
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.supplier,
    required this.unitCost,
    required this.quantity,
    required this.reorderLevel,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String sku;
  final String category;
  final String supplier;
  final num unitCost;
  final int quantity;
  final int reorderLevel;
  final DateTime createdAt;

  bool get isLowStock => quantity <= reorderLevel;
  num get stockValue => quantity * unitCost;

  InventoryItem copyWith({int? quantity}) {
    return InventoryItem(
      id: id,
      name: name,
      sku: sku,
      category: category,
      supplier: supplier,
      unitCost: unitCost,
      quantity: quantity ?? this.quantity,
      reorderLevel: reorderLevel,
      createdAt: createdAt,
    );
  }
}

class Invoice {
  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerCompany,
    required this.customerAddress,
    required this.lineItems,
    required this.issueDate,
    required this.dueDate,
    required this.paymentMethod,
    required this.status,
    required this.subtotal,
    required this.vatAmount,
    required this.amount,
    required this.amountPaid,
    required this.createdAt,
    this.transactionId,
  });

  final String id;
  final String invoiceNumber;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerCompany;
  final String customerAddress;
  final List<InvoiceLineItem> lineItems;
  final DateTime issueDate;
  final DateTime dueDate;
  final PaymentMethod paymentMethod;
  final InvoiceStatus status;
  final num subtotal;
  final num vatAmount;
  final num amount;
  final num amountPaid;
  final DateTime createdAt;
  final String? transactionId;

  num get amountDue => max<num>(0, amount - amountPaid);
  InvoiceStatus get derivedStatus {
    if (status == InvoiceStatus.paid) return InvoiceStatus.paid;
    final today = DateTime.now();
    if (DateTime(dueDate.year, dueDate.month, dueDate.day).isBefore(DateTime(today.year, today.month, today.day))) {
      return InvoiceStatus.overdue;
    }
    return status;
  }

  Invoice copyWith({num? amountPaid, InvoiceStatus? status}) {
    return Invoice(
      id: id,
      invoiceNumber: invoiceNumber,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerCompany: customerCompany,
      customerAddress: customerAddress,
      lineItems: lineItems,
      issueDate: issueDate,
      dueDate: dueDate,
      paymentMethod: paymentMethod,
      status: status ?? this.status,
      subtotal: subtotal,
      vatAmount: vatAmount,
      amount: amount,
      amountPaid: amountPaid ?? this.amountPaid,
      createdAt: createdAt,
      transactionId: transactionId,
    );
  }
}

class InvoiceLineItem {
  const InvoiceLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.productId,
  });

  final String? productId;
  final String name;
  final int quantity;
  final num unitPrice;
  num get lineTotal => quantity * unitPrice;
}

enum PaymentMethod {
  credit('Credit'),
  cash('Cash'),
  transfer('Transfer'),
  others('Others');

  const PaymentMethod(this.label);
  final String label;
}

enum InvoiceStatus {
  pending('Pending'),
  paid('Paid'),
  overdue('Overdue');

  const InvoiceStatus(this.label);
  final String label;
}

class Expense {
  const Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    required this.hasReceipt,
    required this.createdAt,
  });

  final String id;
  final String description;
  final num amount;
  final String category;
  final DateTime date;
  final bool hasReceipt;
  final DateTime createdAt;
}

class InventoryHistoryEntry {
  const InventoryHistoryEntry({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.date,
    required this.type,
    required this.change,
    required this.newQuantity,
    required this.details,
    this.amount,
  });

  final String id;
  final String? itemId;
  final String itemName;
  final DateTime date;
  final String type;
  final int change;
  final int newQuantity;
  final String details;
  final num? amount;
}

class SaleEntry {
  const SaleEntry({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.invoiceNumber,
    required this.date,
  });

  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final num unitPrice;
  final num total;
  final String invoiceNumber;
  final DateTime date;
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
