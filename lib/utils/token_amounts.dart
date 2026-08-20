/// Exact conversion between human-readable token amounts and raw base units.
///
/// Raw token amounts are integers. Multiplying a `double` by `pow(10, decimals)` loses
/// precision for values a mint can legitimately represent, so every conversion here is done
/// with string arithmetic and [BigInt].
library;

class TokenAmountException implements Exception {
  const TokenAmountException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TokenAmounts {
  const TokenAmounts._();

  static final RegExp _decimalPattern = RegExp(r'^-?\d+(\.\d+)?$');
  static final RegExp _integerPattern = RegExp(r'^\d+$');

  static void _assertDecimals(int decimals) {
    if (decimals < 0 || decimals > 18) {
      throw TokenAmountException(
        'Token decimals must be between 0 and 18 (got $decimals).',
      );
    }
  }

  /// Convert a decimal string such as `"238.5"` into raw base units.
  ///
  /// Throws when the value carries more precision than the mint supports, rather than
  /// silently rounding money.
  static BigInt toRawUnits(String amount, int decimals) {
    _assertDecimals(decimals);
    final normalized = amount.trim();
    if (!_decimalPattern.hasMatch(normalized)) {
      throw TokenAmountException(
          'Cannot convert "$amount" to raw token units.');
    }
    final negative = normalized.startsWith('-');
    final unsigned = negative ? normalized.substring(1) : normalized;
    final parts = unsigned.split('.');
    final whole = parts[0];
    final fractionRaw = parts.length > 1 ? parts[1] : '';
    if (fractionRaw.length > decimals) {
      final overflow = fractionRaw.substring(decimals);
      if (overflow.split('').any((digit) => digit != '0')) {
        throw TokenAmountException(
          'Amount $amount has more precision than the token\'s $decimals decimals allow.',
        );
      }
    }
    final fraction = fractionRaw.length >= decimals
        ? fractionRaw.substring(0, decimals)
        : fractionRaw.padRight(decimals, '0');
    final raw = BigInt.parse('${whole.isEmpty ? '0' : whole}$fraction');
    return negative ? -raw : raw;
  }

  /// Best-effort conversion from a `double`. Used only on legacy paths that still carry
  /// doubles; anything financial should pass a decimal string or raw units instead.
  static BigInt fromDouble(double amount, int decimals) =>
      toRawUnits(_shortestDecimalString(amount, decimals), decimals);

  static String _shortestDecimalString(double amount, int decimals) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }
    return amount.toStringAsFixed(decimals);
  }

  /// Render raw base units as a canonical decimal string, without trailing zeroes.
  static String fromRawUnits(BigInt raw, int decimals) {
    _assertDecimals(decimals);
    final negative = raw.isNegative;
    final absolute = negative ? -raw : raw;
    if (decimals == 0) {
      return '${negative ? '-' : ''}$absolute';
    }
    final divisor = BigInt.from(10).pow(decimals);
    final whole = absolute ~/ divisor;
    final fraction = absolute % divisor;
    final fractionText = fraction
        .toString()
        .padLeft(decimals, '0')
        .replaceAll(RegExp(r'0+$'), '');
    final sign = negative ? '-' : '';
    return fractionText.isEmpty ? '$sign$whole' : '$sign$whole.$fractionText';
  }

  /// Parse a non-negative integer string of raw base units.
  static BigInt parseRawUnits(String? value, {String field = 'amountRaw'}) {
    final normalized = (value ?? '').trim();
    if (!_integerPattern.hasMatch(normalized)) {
      throw TokenAmountException(
          '$field must be a non-negative integer string.');
    }
    return BigInt.parse(normalized);
  }

  /// Display value for UI. Never use the result for arithmetic that decides a payment.
  static double toDisplayDouble(BigInt raw, int decimals) {
    return double.parse(fromRawUnits(raw, decimals));
  }
}
