import '../models/collectible.dart';

class MarketplaceValueFormatter {
  static String formatDisplayValue(
    MarketplaceDisplayValue? value, {
    String fallback = 'Not listed',
  }) {
    if (value == null || !value.hasAmount) return fallback;
    return '${formatAmount(value.amount!)} ${value.currency}';
  }

  static String formatAmount(double amount) {
    final rounded = amount.roundToDouble();
    if (rounded == amount) {
      return rounded.toInt().toString();
    }
    return amount.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
