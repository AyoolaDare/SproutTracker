# Firestore to Supabase Migration Map

The live Firestore database is user-scoped:

```text
users/{firebaseUid}
users/{firebaseUid}/profile/business
users/{firebaseUid}/customers/{customerDocId}
users/{firebaseUid}/inventory/{inventoryDocId}
users/{firebaseUid}/inventoryHistory/{historyDocId}
users/{firebaseUid}/sales/{saleDocId}
users/{firebaseUid}/invoices/{invoiceDocId}
users/{firebaseUid}/expenses/{expenseDocId}
users/{firebaseUid}/subscriptions/{subscriptionDocId}
```

Supabase PostgreSQL is normalized and tenant-scoped. During migration each Firebase user becomes one tenant and one owner user.

## Mapping

| Firestore path | PostgreSQL table | Notes |
| --- | --- | --- |
| `users/{firebaseUid}` | `tenants.firebase_user_id`, `users.firebase_uid` | Preserve Firebase UID for reconciliation and support lookup during import. |
| `users/{firebaseUid}/profile/business` | `tenants` | Business name, contact details, logo, bank details, currency, tax flags. |
| `users/{firebaseUid}/customers/{docId}` | `customers.firestore_id` | `amountOwed -> outstanding_balance`, `amountPaid -> total_paid`, `totalSpent -> total_revenue`. |
| `users/{firebaseUid}/inventory/{docId}` | `products.firestore_id` plus opening `inventory_batches.firestore_id` | Product metadata maps to products; current quantity and unit cost become an opening stock batch. |
| `users/{firebaseUid}/inventoryHistory/{docId}` | `stock_movements.firestore_id` | `type`, `change`, `newQuantity`, `details`, and `amount` become stock audit data. |
| `users/{firebaseUid}/sales/{docId}` | Derived from invoices/invoice items, or imported as stock movement references | Existing dashboard best-seller data can be rebuilt from invoice items after migration. |
| `users/{firebaseUid}/invoices/{docId}` | `invoices.firestore_id` and `invoice_items` | `lineItems[]` becomes `invoice_items`. Legacy `Pending/Paid/Overdue` maps to invoice/payment status. |
| `users/{firebaseUid}/expenses/{docId}` | `expenses.firestore_id` | Expense date, amount, category, receipt flags, and receipt URL are preserved. |
| `users/{firebaseUid}/subscriptions/{docId}` | Future `notifications` module | Push subscriptions are app/device runtime data and should be re-consented after migration. |

## Important Business Rules to Preserve

- Invoice creation validates inventory stock before writing.
- Invoice creation deducts stock and writes inventory history in one transaction.
- Paid cash/transfer invoices update customer paid totals immediately.
- Credit invoices increase customer outstanding balance.
- Recording invoice payment updates invoice amount paid and customer balances.
- Deleting an invoice restores inventory quantities and records a goods return history event.
- Dashboard revenue uses paid invoices only in the legacy app.
- Dashboard expenses use all recorded expenses.
- Inventory health uses product `quantity`, `unitCost`, and `reorderLevel`.

## Import Order

1. Firebase users and `profile/business`.
2. Customers.
3. Inventory products and opening stock batches.
4. Inventory history.
5. Invoices and invoice items.
6. Payments inferred from paid invoices and payment updates.
7. Expenses.
8. Rebuild dashboard cache in Redis by deleting `sprout-track:dashboard:*`.

## Compatibility Columns

The initial PostgreSQL migration includes:

- `tenants.firebase_user_id`
- `users.firebase_uid`
- `customers.firestore_id`
- `products.firestore_id`
- `inventory_batches.firestore_id`
- `stock_movements.firestore_id`
- `invoices.firestore_id`
- `expenses.firestore_id`

These columns let the importer be idempotent and allow old QR verification links or legacy IDs to be resolved after migration.
