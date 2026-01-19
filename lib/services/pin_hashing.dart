import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

enum PinVerifyOutcome {
  success,
  incorrect,
  notSet,
  lockedOut,
  error,
}

class PinVerifyResult {
  const PinVerifyResult(
    this.outcome, {
    this.remainingLockoutSeconds = 0,
    this.needsMigration = false,
    this.remainingAttempts = 0,
    this.maxAttempts = 0,
  });

  final PinVerifyOutcome outcome;
  final int remainingLockoutSeconds;
  final int remainingAttempts;
  final int maxAttempts;

  /// True when the stored hash was a legacy unsalted SHA-256 hex digest.
  /// Callers may re-hash with PBKDF2 after a successful verification.
  final bool needsMigration;

  bool get isSuccess => outcome == PinVerifyOutcome.success;
}

class PinHashV1 {
  const PinHashV1({
    required this.iterations,
    required this.salt,
    required this.hash,
  });

  final int iterations;
  final Uint8List salt;
  final Uint8List hash;

  String encode() {
    return 'v1:$iterations:${base64Url.encode(salt)}:${base64Url.encode(hash)}';
  }

  static PinHashV1? tryParse(String raw) {
    final value = raw.trim();
    if (!value.startsWith('v1:')) return null;
    final parts = value.split(':');
    if (parts.length != 4) return null;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 10000) return null;
    try {
      final salt = Uint8List.fromList(base64Url.decode(parts[2]));
      final hash = Uint8List.fromList(base64Url.decode(parts[3]));
      if (salt.isEmpty || hash.isEmpty) return null;
      return PinHashV1(iterations: iterations, salt: salt, hash: hash);
    } catch (_) {
      return null;
    }
  }
}

PinHashV1 derivePinHashV1(
  String pin, {
  int iterations = 120000,
  int saltBytes = 16,
  int keyLength = 32,
  Random? random,
}) {
  final resolvedRandom = random ?? Random.secure();
  final salt = Uint8List.fromList(
    List<int>.generate(saltBytes, (_) => resolvedRandom.nextInt(256)),
  );
  final derived = _pbkdf2HmacSha256(
    utf8.encode(pin),
    salt,
    iterations: iterations,
    keyLength: keyLength,
  );
  return PinHashV1(iterations: iterations, salt: salt, hash: derived);
}

PinVerifyResult verifyPinAgainstStoredHash(
  String pin,
  String? stored, {
  int remainingLockoutSeconds = 0,
}) {
  if (remainingLockoutSeconds > 0) {
    return PinVerifyResult(
      PinVerifyOutcome.lockedOut,
      remainingLockoutSeconds: remainingLockoutSeconds,
    );
  }

  final raw = (stored ?? '').trim();
  if (raw.isEmpty) return const PinVerifyResult(PinVerifyOutcome.notSet);

  final parsed = PinHashV1.tryParse(raw);
  if (parsed != null) {
    try {
      final derived = _pbkdf2HmacSha256(
        utf8.encode(pin),
        parsed.salt,
        iterations: parsed.iterations,
        keyLength: parsed.hash.length,
      );
      return PinVerifyResult(
        _constantTimeEquals(derived, parsed.hash)
            ? PinVerifyOutcome.success
            : PinVerifyOutcome.incorrect,
      );
    } catch (_) {
      return const PinVerifyResult(PinVerifyOutcome.error);
    }
  }

  // Legacy format: unsalted SHA-256 hex string.
  final isLegacySha256Hex = RegExp(r'^[0-9a-f]{64}$').hasMatch(raw);
  if (!isLegacySha256Hex) return const PinVerifyResult(PinVerifyOutcome.error);

  try {
    final derivedHex = _sha256Hex(pin);
    final ok = _constantTimeEquals(
      Uint8List.fromList(utf8.encode(derivedHex)),
      Uint8List.fromList(utf8.encode(raw)),
    );
    return PinVerifyResult(
      ok ? PinVerifyOutcome.success : PinVerifyOutcome.incorrect,
      needsMigration: ok,
    );
  } catch (_) {
    return const PinVerifyResult(PinVerifyOutcome.error);
  }
}

Uint8List _pbkdf2HmacSha256(
  List<int> password,
  Uint8List salt, {
  required int iterations,
  required int keyLength,
}) {
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
  derivator.init(Pbkdf2Parameters(salt, iterations, keyLength));
  return derivator.process(Uint8List.fromList(password));
}

String _sha256Hex(String input) {
  final digest = SHA256Digest().process(Uint8List.fromList(utf8.encode(input)));
  final sb = StringBuffer();
  for (final b in digest) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

bool _constantTimeEquals(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
