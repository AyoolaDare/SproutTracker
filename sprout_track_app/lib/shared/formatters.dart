import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(
  locale: 'en_NG',
  symbol: 'NGN ',
  decimalDigits: 0,
);

String money(num value) => _currency.format(value);

String compactMoney(num value) {
  final abs = value.abs();
  if (abs >= 1000000000) return 'NGN ${(value / 1000000000).toStringAsFixed(1)}B';
  if (abs >= 1000000) return 'NGN ${(value / 1000000).toStringAsFixed(1)}M';
  if (abs >= 1000) return 'NGN ${(value / 1000).toStringAsFixed(0)}K';
  return money(value);
}

final _date = DateFormat('MMM d, yyyy');
String shortDate(DateTime value) => _date.format(value);
