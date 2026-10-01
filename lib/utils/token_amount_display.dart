// Display helpers for token amounts held as raw integer base units.
//
// Economic figures shown next to an eligibility decision must come from the
// same raw units the decision used, and must never round up: a balance of
// 9.996 KUB8 against a 10 KUB8 requirement is insufficient and must not be
// displayed as "10.00".

/// Formats [raw] base units with [decimals] as a decimal string, TRUNCATED
/// (never rounded up) to at most [maxFractionDigits], trailing zeros
/// removed. `formatTokenRawFloor(BigInt.from(9996000), 6)` → `9.996`;
/// with `maxFractionDigits: 2` → `9.99`.
String formatTokenRawFloor(
  BigInt raw,
  int decimals, {
  int maxFractionDigits = 4,
}) {
  final negative = raw.isNegative;
  final value = raw.abs();
  if (decimals <= 0) return '${negative ? '-' : ''}$value';
  final scale = BigInt.from(10).pow(decimals);
  final whole = value ~/ scale;
  final fraction = value % scale;
  var fractionText = fraction.toString().padLeft(decimals, '0');
  if (fractionText.length > maxFractionDigits) {
    fractionText = fractionText.substring(0, maxFractionDigits);
  }
  fractionText = fractionText.replaceFirst(RegExp(r'0+$'), '');
  final sign = negative ? '-' : '';
  return fractionText.isEmpty ? '$sign$whole' : '$sign$whole.$fractionText';
}
