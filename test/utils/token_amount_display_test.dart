import 'package:art_kubus/utils/token_amount_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('truncates, never rounds up', () {
    expect(formatTokenRawFloor(BigInt.from(9996000), 6), '9.996');
    expect(formatTokenRawFloor(BigInt.from(9999999), 6, maxFractionDigits: 2),
        '9.99');
    expect(formatTokenRawFloor(BigInt.from(69999600), 6), '69.9996');
    expect(formatTokenRawFloor(BigInt.from(70000000), 6), '70');
  });

  test('handles zero, whole units and no decimals', () {
    expect(formatTokenRawFloor(BigInt.zero, 6), '0');
    expect(formatTokenRawFloor(BigInt.from(250000000), 6), '250');
    expect(formatTokenRawFloor(BigInt.from(42), 0), '42');
    expect(formatTokenRawFloor(BigInt.from(1), 6), '0');
    expect(formatTokenRawFloor(BigInt.from(1), 6, maxFractionDigits: 6),
        '0.000001');
  });
}
