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
    final safeName = normalizeDisplayName(displayName);
    final safeUsername = normalizeUsername(username);

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

    final safeWallet = WalletUtils.canonical(wallet);
    if (safeWallet.isNotEmpty) {
      return CreatorDisplay(
        primary: compactWalletForDisplay(safeWallet),
        secondary: null,
      );
    }

    return CreatorDisplay(primary: fallbackLabel, secondary: null);
  }

  static String normalizeDisplayName(dynamic value) {
    final s = (value ?? '').toString().trim();
    if (s.isEmpty) return '';
    final lower = s.toLowerCase();
    if (lower == 'unknown creator' ||
        lower == 'unknown artist' ||
        lower == 'unknown author' ||
        lower == 'unknown' ||
        lower == 'anonymous' ||
        lower == 'user') {
      return '';
    }
    if (lower.startsWith('user_')) return '';
    if (WalletUtils.looksLikeWallet(s)) return '';
    return s;
  }

  static String? normalizeUsername(dynamic value) {
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
      if (isAlphaNum || c == '_' || c == '.' || c == '-') {
        sb.write(c);
      } else if (c == ' ') {
        sb.write('_');
      }
    }
    var normalized = sb.toString();
    normalized = normalized.replaceAll(RegExp(r'_+'), '_');
    normalized = normalized.replaceAll(RegExp(r'^[_\.-]+|[_\.-]+$'), '');
    if (normalized.length < 3) return null;
    if (normalized.length > 24) normalized = normalized.substring(0, 24);
    if (normalized.isEmpty) return null;
    if (normalized.codeUnitAt(0) >= 48 && normalized.codeUnitAt(0) <= 57) {
      normalized = 'u$normalized';
      if (normalized.length > 24) normalized = normalized.substring(0, 24);
    }
    return normalized;
  }

  static String? normalizePayloadText(dynamic value) {
    final normalized = (value ?? '').toString().trim();
    if (normalized.isEmpty) return null;
    final lower = normalized.toLowerCase();
    if (lower == 'unknown' ||
        lower == 'anonymous' ||
        lower == 'n/a' ||
        lower == 'none') {
      return null;
    }
    return normalized;
  }

  static String compactWalletForDisplay(String wallet) {
    final trimmed = wallet.trim();
    if (trimmed.length <= 12) return trimmed;
    return '${trimmed.substring(0, 6)}...${trimmed.substring(trimmed.length - 4)}';
  }
}
