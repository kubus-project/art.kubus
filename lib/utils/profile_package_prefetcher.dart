import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../services/profile_package_service.dart';
import 'wallet_utils.dart';

class ProfilePackagePrefetcher {
  ProfilePackagePrefetcher._();

  static const int _maxConcurrent = 3;
  static const Duration _recentWindow = Duration(minutes: 3);
  static const Duration _lowPriorityDelay = Duration(milliseconds: 90);

  static final Queue<_ProfilePrefetchRequest> _queue =
      Queue<_ProfilePrefetchRequest>();
  static final Set<String> _queuedKeys = <String>{};
  static final Set<String> _inFlightKeys = <String>{};
  static final Map<String, DateTime> _recentlyPrefetched = <String, DateTime>{};
  static int _active = 0;

  static void prefetchVisible(
    String walletAddress, {
    String? username,
    String? selfWallet,
  }) {
    _enqueue(
      walletAddress,
      username: username,
      selfWallet: selfWallet,
      includeExtended: false,
    );
  }

  static void prefetchHighIntent(
    String walletAddress, {
    String? username,
    String? selfWallet,
  }) {
    _enqueue(
      walletAddress,
      username: username,
      selfWallet: selfWallet,
      includeExtended: true,
    );
  }

  @visibleForTesting
  static void resetForTesting() {
    _queue.clear();
    _queuedKeys.clear();
    _inFlightKeys.clear();
    _recentlyPrefetched.clear();
    _active = 0;
  }

  static void _enqueue(
    String walletAddress, {
    String? username,
    String? selfWallet,
    required bool includeExtended,
  }) {
    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty) return;
    if (!WalletUtils.looksLikeWallet(wallet)) return;
    if (selfWallet != null && WalletUtils.equals(wallet, selfWallet)) return;

    final now = DateTime.now();
    _recentlyPrefetched.removeWhere(
      (_, touchedAt) => now.difference(touchedAt) > _recentWindow,
    );

    final key = '$wallet|extended:$includeExtended';
    final cached = ProfilePackageService.getCachedCriticalPackage(
      wallet,
      allowStale: false,
    );
    if (cached != null && !includeExtended) {
      return;
    }
    if (_queuedKeys.contains(key) ||
        _inFlightKeys.contains(key) ||
        _recentlyPrefetched.containsKey(key)) {
      _debug('profile_package_prefetch_skipped_duplicate', wallet);
      return;
    }

    _queuedKeys.add(key);
    _queue.add(
      _ProfilePrefetchRequest(
        wallet: wallet,
        username: username,
        includeExtended: includeExtended,
        key: key,
      ),
    );
    _pump();
  }

  static void _pump() {
    while (_active < _maxConcurrent && _queue.isNotEmpty) {
      final request = _queue.removeFirst();
      _queuedKeys.remove(request.key);
      _active += 1;
      _inFlightKeys.add(request.key);
      unawaited(_run(request));
    }
  }

  static Future<void> _run(_ProfilePrefetchRequest request) async {
    await Future<void>.delayed(_lowPriorityDelay);
    _debug('profile_package_prefetch_started', request.wallet);
    try {
      final critical =
          await ProfilePackageService.prefetchPublicProfileCriticalPackage(
        request.wallet,
        username: request.username,
      );
      if (request.includeExtended && critical != null) {
        await ProfilePackageService.prefetchPublicProfileExtendedPackage(
          critical.user.id,
          user: critical.user,
        );
      }
      _recentlyPrefetched[request.key] = DateTime.now();
      _debug('profile_package_prefetch_completed', request.wallet);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePackagePrefetcher._run: $e');
      }
    } finally {
      _active -= 1;
      _inFlightKeys.remove(request.key);
      _pump();
    }
  }

  static void _debug(String event, String wallet) {
    if (!kDebugMode) return;
    debugPrint('ProfilePackagePrefetcher.telemetry $event wallet=$wallet');
  }
}

class _ProfilePrefetchRequest {
  const _ProfilePrefetchRequest({
    required this.wallet,
    required this.username,
    required this.includeExtended,
    required this.key,
  });

  final String wallet;
  final String? username;
  final bool includeExtended;
  final String key;
}
