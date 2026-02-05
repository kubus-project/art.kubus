import 'package:flutter/foundation.dart';

import 'wallet_utils.dart';

@immutable
class UserIdentityDisplay {
  const UserIdentityDisplay({
    required this.name,
    required this.username,
  });

  /// Human display name (never a wallet address).
  final String name;

  /// Username handle without '@' (never a wallet address).
  final String? username;

  String? get handle {
    final u = (username ?? '').trim();
    if (u.isEmpty) return null;
    if (WalletUtils.looksLikeWallet(u)) return null;
    return '@$u';
  }
}

class UserIdentityDisplayUtils {
  const UserIdentityDisplayUtils._();

  static UserIdentityDisplay fromProfileMap(Map<String, dynamic> raw) {
    final displayName = _cleanName(
      raw['displayName'] ??
          raw['display_name'] ??
          raw['name'] ??
          raw['fullName'] ??
          raw['full_name'],
    );

    final username = _cleanUsername(
      raw['username'] ??
          raw['handle'] ??
          raw['userName'] ??
          raw['user_name'],
    );

    if (displayName.isNotEmpty) {
      // Do not derive usernames. Only show a handle when explicitly present.
      return UserIdentityDisplay(
        name: displayName,
        username: username,
      );
    }

    if (username != null && username.isNotEmpty) {
      // If we only have a username, show it as the primary label too.
      return UserIdentityDisplay(
        name: username,
        username: username,
      );
    }

    return const UserIdentityDisplay(name: 'Unknown artist', username: null);
  }

  static UserIdentityDisplay fromCreatorMap(Map<String, dynamic> raw) {
    // Creator summaries often use different keys (id/wallet/displayName/username).
    return fromProfileMap(raw);
  }

  static String _cleanName(dynamic value) {
    final s = (value ?? '').toString().trim();
    if (s.isEmpty) return '';
    if (WalletUtils.looksLikeWallet(s)) return '';
    return s;
  }

  static String? _cleanUsername(dynamic value) {
    var s = (value ?? '').toString().trim();
    if (s.isEmpty) return null;
    if (s.startsWith('@')) s = s.substring(1).trim();
    if (s.isEmpty) return null;
    if (WalletUtils.looksLikeWallet(s)) return null;

    // Normalize to a conservative, UI-safe handle set.
    s = s.toLowerCase();
    final sb = StringBuffer();
    for (final codeUnit in s.codeUnits) {
      final c = String.fromCharCode(codeUnit);
      final isAlphaNum = (codeUnit >= 97 && codeUnit <= 122) ||
          (codeUnit >= 48 && codeUnit <= 57);
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

  // Intentionally no derived username helpers.
}

