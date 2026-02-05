import 'package:flutter/foundation.dart';

import 'wallet_utils.dart';

@immutable
class CreatorDisplay {
  final String primary;
  final String? secondary;

  const CreatorDisplay({
    required this.primary,
    this.secondary,
  });
}

class CreatorDisplayFormat {
  const CreatorDisplayFormat._();

  static CreatorDisplay format({
    required String fallbackLabel,
    String? displayName,
    String? username,
    String? wallet,
  }) {
    final safeName = _cleanName(displayName);
    final safeUsername = _cleanUsername(username);

    // Primary: human display name.
    if (safeName.isNotEmpty) {
      // Secondary: explicit @username/handle (never derived).
      final secondary = safeUsername == null ? null : '@$safeUsername';
      return CreatorDisplay(primary: safeName, secondary: secondary);
    }

    // If we only have a username, show it as the primary label.
    if (safeUsername != null && safeUsername.isNotEmpty) {
      return CreatorDisplay(primary: '@$safeUsername', secondary: null);
    }

    // Wallet is intentionally not shown unless explicitly requested by the UI.
    // Still accept it for future diagnostics or caller logic.
    final _ = WalletUtils.canonical(wallet);

    return CreatorDisplay(primary: fallbackLabel, secondary: null);
  }

  static String _cleanName(String? value) {
    final s = (value ?? '').toString().trim();
    if (s.isEmpty) return '';
    final lower = s.toLowerCase();
    if (lower == 'unknown creator' ||
        lower == 'unknown artist' ||
        lower == 'unknown' ||
        lower == 'anonymous') {
      return '';
    }
    if (WalletUtils.looksLikeWallet(s)) return '';
    return s;
  }

  static String? _cleanUsername(String? value) {
    var s = (value ?? '').toString().trim();
    if (s.isEmpty) return null;
    if (s.startsWith('@')) s = s.substring(1).trim();
    if (s.isEmpty) return null;
    if (WalletUtils.looksLikeWallet(s)) return null;

    // Keep a conservative handle set.
    s = s.toLowerCase();
    final sb = StringBuffer();
    for (final codeUnit in s.codeUnits) {
      final isAlphaNum = (codeUnit >= 97 && codeUnit <= 122) ||
          (codeUnit >= 48 && codeUnit <= 57);
      final c = String.fromCharCode(codeUnit);
      if (isAlphaNum || c == '_' || c == '.') {
        sb.write(c);
      } else if (c == ' ' || c == '-') {
        sb.write('_');
      }
    }
    var normalized = sb.toString();
    normalized = normalized.replaceAll(RegExp(r'_+'), '_');
    normalized = normalized.replaceAll(RegExp(r'^[_\.]+|[_\.]+$'), '');
    if (normalized.length < 3) return null;
    if (normalized.length > 24) normalized = normalized.substring(0, 24);
    if (normalized.isEmpty) return null;
    if (normalized.codeUnitAt(0) >= 48 && normalized.codeUnitAt(0) <= 57) {
      normalized = 'u$normalized';
      if (normalized.length > 24) normalized = normalized.substring(0, 24);
    }
    return normalized;
  }
}
