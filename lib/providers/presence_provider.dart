import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../models/user_presence.dart';
import '../providers/app_refresh_provider.dart';
import '../providers/profile_provider.dart';
import '../services/presence_api.dart';

class PresenceProvider extends ChangeNotifier {
  static const Duration _cacheTtl = Duration(seconds: 30);
  static const Duration _batchDebounce = Duration(milliseconds: 60);
  static const Duration _visitDebounce = Duration(milliseconds: 400);
  static const Duration _visitDedupeWindow = Duration(minutes: 5);
  static const Duration _autoRefreshInterval = Duration(seconds: 15);
  static const Duration _heartbeatInterval = Duration(seconds: 45);

  final PresenceApi _api;

  AppRefreshProvider? _boundRefreshProvider;
  ProfileProvider? _profileProvider;
  VoidCallback? _profileListener;

  bool _initialized = false;

  Timer? _batchTimer;
  bool _batchInFlight = false;
  final Set<String> _pendingWalletsLower = <String>{};
  final Set<String> _watchedWalletsLower = <String>{};
  Timer? _autoRefreshTimer;

  Timer? _heartbeatTimer;
  bool _heartbeatInFlight = false;
  DateTime? _lastHeartbeatAt;

  Timer? _visitTimer;
  ({String type, String id})? _pendingVisit;
  final Map<String, DateTime> _lastVisitSentAt = <String, DateTime>{};

  int _lastGlobalVersion = 0;
  int _lastCommunityVersion = 0;
  int _lastChatVersion = 0;

  final Map<String, _PresenceCacheEntry> _cacheByWalletLower = <String, _PresenceCacheEntry>{};

  PresenceProvider({PresenceApi? api}) : _api = api ?? BackendPresenceApi();

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _ensureHeartbeatTimer();
  }

  void bindToRefresh(AppRefreshProvider refreshProvider) {
    if (identical(_boundRefreshProvider, refreshProvider)) return;
    _boundRefreshProvider = refreshProvider;
    _lastGlobalVersion = refreshProvider.globalVersion;
    _lastCommunityVersion = refreshProvider.communityVersion;
    _lastChatVersion = refreshProvider.chatVersion;

    refreshProvider.addListener(() {
      try {
        final nextGlobal = refreshProvider.globalVersion;
        final nextCommunity = refreshProvider.communityVersion;
        final nextChat = refreshProvider.chatVersion;

        final shouldRefresh = nextGlobal != _lastGlobalVersion ||
            nextCommunity != _lastCommunityVersion ||
            nextChat != _lastChatVersion;

        _lastGlobalVersion = nextGlobal;
        _lastCommunityVersion = nextCommunity;
        _lastChatVersion = nextChat;

        if (shouldRefresh) {
          // Mark cached entries stale by clearing timestamps, then allow next prefetch to fetch.
          final keys = _cacheByWalletLower.keys.toList(growable: false);
          for (final key in keys) {
            final existing = _cacheByWalletLower[key];
            if (existing == null) continue;
            _cacheByWalletLower[key] = existing.copyWith(
              fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
            );
          }
          _scheduleBatchFetch();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('PresenceProvider: bindToRefresh listener error: $e');
        }
      }
    });
  }

  void bindProfileProvider(ProfileProvider profileProvider) {
    if (identical(_profileProvider, profileProvider)) return;

    if (_profileProvider != null && _profileListener != null) {
      try {
        _profileProvider!.removeListener(_profileListener!);
      } catch (_) {}
    }

    _profileProvider = profileProvider;
    _profileListener = () {
      _ensureHeartbeatTimer();
    };
    profileProvider.addListener(_profileListener!);
    _ensureHeartbeatTimer();
  }

  UserPresenceEntry? presenceForWallet(String wallet) {
    final key = _walletLowerOrNull(wallet);
    if (key == null) return null;
    final cached = _cacheByWalletLower[key];
    return cached?.presence;
  }

  bool isPresenceVisible(String wallet) {
    final p = presenceForWallet(wallet);
    if (p == null) return false;
    return p.visible;
  }

  void prefetch(Iterable<String> wallets) {
    if (!AppConfig.isFeatureEnabled('presence')) return;
    for (final w in wallets) {
      final key = _walletLowerOrNull(w);
      if (key == null) continue;
      _pendingWalletsLower.add(key);
      _watchedWalletsLower.add(key);
    }
    _ensureAutoRefreshTimer();
    _ensureHeartbeatTimer();
    _scheduleBatchFetch();
  }

  Future<void> refreshWallet(String wallet) async {
    if (!AppConfig.isFeatureEnabled('presence')) return;
    final key = _walletLowerOrNull(wallet);
    if (key == null) return;
    final existing = _cacheByWalletLower[key];
    if (existing != null) {
      _cacheByWalletLower[key] = existing.copyWith(
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }
    _pendingWalletsLower.add(key);
    _watchedWalletsLower.add(key);
    _ensureAutoRefreshTimer();
    _ensureHeartbeatTimer();
    await _flushBatchFetch();
  }

  void _ensureAutoRefreshTimer() {
    if (_autoRefreshTimer != null) return;
    if (!AppConfig.isFeatureEnabled('presence')) return;
    if (_watchedWalletsLower.isEmpty) return;

    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (!AppConfig.isFeatureEnabled('presence')) return;
      if (_watchedWalletsLower.isEmpty) return;
      _pendingWalletsLower.addAll(_watchedWalletsLower);
      _scheduleBatchFetch();
    });
  }

  void _ensureHeartbeatTimer() {
    if (!_initialized) return;

    if (!AppConfig.isFeatureEnabled('presence')) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      return;
    }

    final profile = _profileProvider;
    final signedIn = profile?.isSignedIn == true;
    final wallet = (profile?.currentUser?.walletAddress ?? '').trim();
    final prefs = profile?.preferences;
    final allowVisible = prefs?.showActivityStatus == true;

    if (!signedIn || wallet.isEmpty || !allowVisible) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      return;
    }

    _heartbeatTimer ??= Timer.periodic(_heartbeatInterval, (_) {
      unawaited(_sendHeartbeat());
    });
  }

  Future<void> onAppResumed() async {
    _ensureHeartbeatTimer();
    await _sendHeartbeat(force: true);
  }

  Future<void> _sendHeartbeat({bool force = false}) async {
    if (_heartbeatInFlight) return;
    if (!AppConfig.isFeatureEnabled('presence')) return;

    final profile = _profileProvider;
    if (profile?.isSignedIn != true) return;
    final wallet = (profile?.currentUser?.walletAddress ?? '').trim();
    if (wallet.isEmpty) return;

    final prefs = profile?.preferences;
    if (prefs?.showActivityStatus != true) return;

    final last = _lastHeartbeatAt;
    if (!force && last != null && DateTime.now().difference(last) < _heartbeatInterval) {
      return;
    }

    _heartbeatInFlight = true;
    try {
      await _api.ensureAuthLoaded(walletAddress: wallet);
      await _api.pingPresence(walletAddress: wallet);
      _lastHeartbeatAt = DateTime.now();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PresenceProvider: heartbeat failed: $e');
      }
    } finally {
      _heartbeatInFlight = false;
    }
  }

  void recordVisit({required String type, required String id}) {
    if (!AppConfig.isFeatureEnabled('presence')) return;
    if (!AppConfig.isFeatureEnabled('presenceLastVisitedLocation')) return;

    final normalizedType = type.trim().toLowerCase();
    final normalizedId = id.trim();
    if (normalizedType.isEmpty || normalizedId.isEmpty) return;

    final profile = _profileProvider;
    final prefs = profile?.preferences;
    if (prefs != null) {
      if (prefs.showActivityStatus != true) return;
      if (prefs.shareLastVisitedLocation != true) return;
    }

    final visitKey = '$normalizedType:$normalizedId';
    final lastSent = _lastVisitSentAt[visitKey];
    if (lastSent != null && DateTime.now().difference(lastSent) < _visitDedupeWindow) {
      return;
    }

    _pendingVisit = (type: normalizedType, id: normalizedId);
    _visitTimer?.cancel();
    _visitTimer = Timer(_visitDebounce, () {
      unawaited(_flushVisit());
    });
  }

  void _scheduleBatchFetch() {
    _batchTimer?.cancel();
    _batchTimer = Timer(_batchDebounce, () {
      unawaited(_flushBatchFetch());
    });
  }

  Future<void> _flushBatchFetch() async {
    if (_batchInFlight) return;
    if (!AppConfig.isFeatureEnabled('presence')) return;

    final now = DateTime.now();
    final toRequest = <String>[];
    for (final key in _pendingWalletsLower) {
      final cached = _cacheByWalletLower[key];
      final isFresh = cached != null && now.difference(cached.fetchedAt) <= _cacheTtl;
      if (!isFresh) {
        toRequest.add(key);
      }
    }
    _pendingWalletsLower.clear();

    if (toRequest.isEmpty) return;

    _batchInFlight = true;
    try {
      final resp = await _api.getPresenceBatch(toRequest);
      if (resp['success'] == true) {
        final raw = resp['data'];
        final list = raw is List ? raw : (raw is Map<String, dynamic> && raw['data'] is List ? raw['data'] as List : const []);

        for (final entry in list) {
          if (entry is! Map) continue;
          final parsed = UserPresenceEntry.fromJson(Map<String, dynamic>.from(entry));
          final walletKey = _walletLowerOrNull(parsed.walletAddress);
          if (walletKey == null) continue;
          _cacheByWalletLower[walletKey] = _PresenceCacheEntry(
            presence: parsed,
            fetchedAt: now,
          );
        }
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PresenceProvider: batch fetch failed: $e');
      }
      // Best-effort: drop this batch on failure; next prefetch will retry.
    } finally {
      _batchInFlight = false;
    }
  }

  @override
  void dispose() {
    _batchTimer?.cancel();
    _visitTimer?.cancel();
    _autoRefreshTimer?.cancel();
    _heartbeatTimer?.cancel();
    if (_profileProvider != null && _profileListener != null) {
      try {
        _profileProvider!.removeListener(_profileListener!);
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _flushVisit() async {
    final pending = _pendingVisit;
    _pendingVisit = null;
    if (pending == null) return;
    if (!AppConfig.isFeatureEnabled('presence')) return;
    if (!AppConfig.isFeatureEnabled('presenceLastVisitedLocation')) return;

    final profile = _profileProvider;
    final wallet = profile?.currentUser?.walletAddress;
    if (profile?.isSignedIn != true || (wallet ?? '').trim().isEmpty) return;

    try {
      await _api.ensureAuthLoaded(walletAddress: wallet);
      final resp = await _api.recordPresenceVisit(
        type: pending.type,
        id: pending.id,
        walletAddress: wallet,
      );
      if (resp['success'] == true) {
        final key = '${pending.type}:${pending.id}';
        _lastVisitSentAt[key] = DateTime.now();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PresenceProvider: recordVisit failed: $e');
      }
    }
  }

  String? _walletLowerOrNull(String? wallet) {
    final raw = (wallet ?? '').trim();
    if (raw.isEmpty) return null;
    final normalized = raw.toLowerCase();
    const invalid = {'unknown', 'anonymous', 'n/a', 'none'};
    if (invalid.contains(normalized)) return null;
    return normalized;
  }
}

class _PresenceCacheEntry {
  final UserPresenceEntry presence;
  final DateTime fetchedAt;

  const _PresenceCacheEntry({
    required this.presence,
    required this.fetchedAt,
  });

  _PresenceCacheEntry copyWith({UserPresenceEntry? presence, DateTime? fetchedAt}) {
    return _PresenceCacheEntry(
      presence: presence ?? this.presence,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }
}
