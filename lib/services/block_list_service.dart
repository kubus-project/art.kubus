import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/wallet_utils.dart';

/// Local block list for wallets/users.
///
/// Backend enforcement can be layered later; this keeps UX functional even when
/// moderation endpoints are unavailable.
class BlockListService {
  static final BlockListService _instance = BlockListService._internal();
  factory BlockListService() => _instance;
  BlockListService._internal();

  static const String _blockedWalletsKey = 'blocked_wallets_v1';

  Future<Set<String>> loadBlockedWallets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_blockedWalletsKey);
      if (raw == null || raw.trim().isEmpty) return <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded
          .whereType<String>()
          .map((e) => WalletUtils.canonical(e))
          .where((e) => e.isNotEmpty)
          .toSet();
    } catch (e) {
      debugPrint('BlockListService.loadBlockedWallets failed: $e');
      return <String>{};
    }
  }

  Future<bool> isWalletBlocked(String wallet) async {
    final normalized = WalletUtils.canonical(wallet);
    if (normalized.isEmpty) return false;
    final blocked = await loadBlockedWallets();
    return blocked.contains(normalized);
  }

  Future<void> blockWallet(String wallet) async {
    final normalized = WalletUtils.canonical(wallet);
    if (normalized.isEmpty) return;
    final blocked = await loadBlockedWallets();
    blocked.add(normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_blockedWalletsKey, jsonEncode(blocked.toList()));
  }

  Future<void> unblockWallet(String wallet) async {
    final normalized = WalletUtils.canonical(wallet);
    if (normalized.isEmpty) return;
    final blocked = await loadBlockedWallets();
    blocked.remove(normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_blockedWalletsKey, jsonEncode(blocked.toList()));
  }
}

