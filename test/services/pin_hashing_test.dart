import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/services/pin_hashing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

String _sha256Hex(String input) {
  final digest = SHA256Digest().process(Uint8List.fromList(utf8.encode(input)));
  final sb = StringBuffer();
  for (final b in digest) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

void main() {
  test('PBKDF2 hash verifies and rejects wrong PIN', () {
    final hash = derivePinHashV1('1234', iterations: 20000);
    final ok = verifyPinAgainstStoredHash('1234', hash.encode());
    expect(ok.outcome, PinVerifyOutcome.success);

    final bad = verifyPinAgainstStoredHash('0000', hash.encode());
    expect(bad.outcome, PinVerifyOutcome.incorrect);
  });

  test('legacy sha256 hex verifies and requests migration', () {
    final legacy = _sha256Hex('9999');
    final ok = verifyPinAgainstStoredHash('9999', legacy);
    expect(ok.outcome, PinVerifyOutcome.success);
    expect(ok.needsMigration, isTrue);

    final bad = verifyPinAgainstStoredHash('0000', legacy);
    expect(bad.outcome, PinVerifyOutcome.incorrect);
  });
}

