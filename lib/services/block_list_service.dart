import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/wallet_utils.dart';
import 'account_identity.dart';

/// Local block list for wallets/users, kept per account.
///
/// Blocking is a safety control, so a returning account keeps its blocks: each
/// signed-in account has its own stored set. A guest has no stored set, so a
/// guest's blocks last for the session only.
///
/// Backend enforcement can be layered later; this keeps UX functional even when
/// moderation endpoints are unavailable.
class BlockListService {
  static final BlockListService _instance = BlockListService._internal();
  factory BlockListService() => _instance;

  BlockListService._internal() {
    AccountIdentity.addListener(_handleIdentityChanged);
  }

  /// The account whose set is [_blocked]. Null until that set is loaded.
  String? _loadedFor;
  Set<String> _blocked = <String>{};

  /// The read in progress for [_pendingFor]. Concurrent first reads share it,
  /// so two of them cannot each hold a different copy of the same set.
  String? _pendingFor;
  Future<Set<String>>? _pendingLoad;

  void _handleIdentityChanged() {
    // The previous account's blocks leave memory now, before anything awaits.
    _loadedFor = null;
    _blocked = <String>{};
    _pendingFor = null;
    _pendingLoad = null;
    // Load the new account's set straight away. A failed read is retried by
    // the next caller, so the error is not raised here.
    unawaited(_current().then<void>((_) {}, onError: (_) {}));
  }

  /// The set for the account signed in right now, with the key it belongs to.
  /// Loads it on first use, and again after the account changes.
  Future<({String key, Set<String> blocked})> _current() async {
    final key = AccountIdentity.accountKey;
    if (_loadedFor == key) return (key: key, blocked: _blocked);
    if (key.isEmpty) {
      // A guest has no stored set: blocks made now last for this session.
      _loadedFor = key;
      _blocked = <String>{};
      return (key: key, blocked: _blocked);
    }
    final load = _pendingFor == key && _pendingLoad != null
        ? _pendingLoad!
        : _startLoad(key);
    final Set<String> loaded;
    try {
      loaded = await load;
    } catch (_) {
      // Forget the failed read so the next caller reads again.
      if (_pendingLoad == load) {
        _pendingFor = null;
        _pendingLoad = null;
      }
      rethrow;
    }
    // The account changed while this read was in flight: load the new one.
    if (AccountIdentity.accountKey != key) return _current();
    if (_loadedFor != key) {
      _loadedFor = key;
      _blocked = loaded;
    }
    return (key: key, blocked: _blocked);
  }

  Future<Set<String>> _startLoad(String key) {
    final load = _readAccountSet(key);
    _pendingFor = key;
    _pendingLoad = load;
    return load;
  }

  /// Reads one account's stored set. A failed read throws rather than yielding
  /// an empty set, so a later write cannot overwrite the stored blocks.
  Future<Set<String>> _readAccountSet(String key) async {
    await AccountIdentity.adoptLegacyRecords(key);
    final scoped = AccountIdentity.scopedKey(
      AccountIdentity.blockedWalletsKey,
      accountKey: key,
    );
    if (scoped == null) return <String>{};
    final prefs = await SharedPreferences.getInstance();
    return AccountIdentity.decodeWalletList(prefs.getString(scoped));
  }

  Future<Set<String>> loadBlockedWallets() async {
    try {
      final current = await _current();
      return Set<String>.of(current.blocked);
    } catch (e) {
      debugPrint('BlockListService.loadBlockedWallets failed: $e');
      return <String>{};
    }
  }

  Future<bool> isWalletBlocked(String wallet) async {
    final normalized = WalletUtils.canonical(wallet);
    if (normalized.isEmpty) return false;
    try {
      final current = await _current();
      return current.blocked.contains(normalized);
    } catch (e) {
      debugPrint('BlockListService.isWalletBlocked failed: $e');
      return false;
    }
  }

  Future<void> blockWallet(String wallet) => _mutate(wallet, add: true);

  Future<void> unblockWallet(String wallet) => _mutate(wallet, add: false);

  Future<void> _mutate(String wallet, {required bool add}) async {
    final normalized = WalletUtils.canonical(wallet);
    if (normalized.isEmpty) return;
    final current = await _current();
    if (add) {
      current.blocked.add(normalized);
    } else {
      current.blocked.remove(normalized);
    }
    // The set and its key come from one read, so the write goes to the account
    // whose set changed, even if the session moved on while this awaited.
    final scoped = AccountIdentity.scopedKey(
      AccountIdentity.blockedWalletsKey,
      accountKey: current.key,
    );
    if (scoped == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(scoped, jsonEncode(current.blocked.toList()));
  }
}
