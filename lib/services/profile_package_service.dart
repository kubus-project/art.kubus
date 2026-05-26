import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../community/community_interactions.dart';
import '../models/achievement_progress.dart' as legacy;
import '../models/achievements.dart' as backend;
import '../models/profile_package.dart';
import '../models/user.dart';
import '../utils/profile_showcase_normalizer.dart';
import '../utils/wallet_utils.dart';
import 'backend_api_service.dart';
import 'stats_api_service.dart';
import 'user_service.dart';

enum ProfilePackageCacheStatus {
  none,
  profileShellOnly,
  complete,
  staleComplete,
  failed,
}

/// Owns public profile package loading and cache storage.
///
/// Critical packages contain profile, stats, and backend-owned achievement
/// data. Extended packages contain posts and showcase data. UI/provider write
/// paths should use ProfilePackageMutationTracker instead of calling cache
/// invalidation or patch methods here directly.
class ProfilePackageService {
  ProfilePackageService._();

  static const Duration cacheTtl = Duration(minutes: 5);
  static const String _criticalCachePrefsKey = 'profile_critical_cache_v2';
  static const int _maxPersistedPackages = 80;

  static final Map<String, ProfileCriticalPackage> _criticalCache =
      <String, ProfileCriticalPackage>{};
  static final Map<String, ProfileExtendedPackage> _extendedCache =
      <String, ProfileExtendedPackage>{};
  static final Map<String, Future<ProfileCriticalPackage?>> _criticalInFlight =
      <String, Future<ProfileCriticalPackage?>>{};
  static final Map<String, Future<ProfileExtendedPackage?>> _extendedInFlight =
      <String, Future<ProfileExtendedPackage?>>{};
  static final Map<String, DateTime> _failedAt = <String, DateTime>{};
  static final Map<String, int> _criticalInvalidationEpoch = <String, int>{};
  static final Map<String, int> _extendedInvalidationEpoch = <String, int>{};
  static bool _persistentCacheLoaded = false;

  static Future<ProfileCriticalPackage?> loadPublicProfileCriticalPackage(
    String walletAddress, {
    bool forceRefresh = false,
    String? username,
  }) async {
    final lookup = _ProfileLookup(walletAddress, username: username);
    if (!lookup.hasLookup) return null;

    await _ensurePersistentCacheLoaded();

    final cached = _criticalCache[lookup.cacheKey] ??
        (lookup.wallet.isNotEmpty ? _criticalCache[lookup.wallet] : null);
    if (!forceRefresh &&
        cached != null &&
        cached.isComplete &&
        cached.isFresh(cacheTtl)) {
      _debugTelemetry('profile_package_critical_cache_hit',
          wallet: cached.user.id);
      return cached;
    }
    if (!forceRefresh && cached != null && cached.isComplete) {
      _debugTelemetry('profile_package_critical_stale_hit',
          wallet: cached.user.id);
    }

    final existing = _criticalInFlight[lookup.cacheKey];
    if (existing != null) return existing;

    final watch = Stopwatch()..start();
    _debugTelemetry('profile_package_critical_network_load',
        wallet: lookup.cacheKey);
    final shouldCheckInvalidation = lookup.wallet.isNotEmpty;
    final invalidationEpoch = shouldCheckInvalidation
        ? (_criticalInvalidationEpoch[lookup.wallet] ?? 0)
        : 0;
    final future = _loadFreshPublicProfileCriticalPackage(lookup);
    _criticalInFlight[lookup.cacheKey] = future;
    try {
      final critical = await future;
      if (critical != null && critical.isComplete) {
        if (shouldCheckInvalidation &&
            _criticalInvalidatedSince(critical.user.id, invalidationEpoch)) {
          return null;
        }
        _storeCriticalPackage(critical);
        if (lookup.wallet.isEmpty && lookup.cacheKey.isNotEmpty) {
          _criticalCache[lookup.cacheKey] = critical;
        }
        if (critical.achievementsUnavailable) {
          _debugTelemetry(
            'profile_package_achievement_unavailable',
            wallet: critical.user.id,
          );
        }
      } else {
        _failedAt[lookup.cacheKey] = DateTime.now();
      }
      return critical;
    } finally {
      watch.stop();
      _debugTelemetry(
        'profile_package_critical_load_ms',
        wallet: lookup.cacheKey,
        value: watch.elapsedMilliseconds,
      );
      _criticalInFlight.remove(lookup.cacheKey);
    }
  }

  static Future<ProfileExtendedPackage?> loadPublicProfileExtendedPackage(
    String walletAddress, {
    bool forceRefresh = false,
    bool includePosts = true,
    bool includeShowcase = true,
    User? user,
  }) async {
    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty) return null;

    final cached =
        _extendedCache[wallet] ?? _extendedCache[WalletUtils.normalize(wallet)];
    if (!forceRefresh && cached != null) return cached;

    final inFlightKey = '$wallet|posts:$includePosts|showcase:$includeShowcase';
    final existing = _extendedInFlight[inFlightKey];
    if (existing != null) return existing;

    final watch = Stopwatch()..start();
    _debugTelemetry('profile_package_extended_network_load', wallet: wallet);
    final invalidationEpoch = _extendedInvalidationEpoch[wallet] ?? 0;
    final future = _loadFreshPublicProfileExtendedPackage(
      wallet,
      includePosts: includePosts,
      includeShowcase: includeShowcase,
      user: user,
    );
    _extendedInFlight[inFlightKey] = future;
    try {
      final extended = await future;
      if (extended != null) {
        if (_extendedInvalidatedSince(wallet, invalidationEpoch)) {
          return null;
        }
        _storeExtendedPackage(wallet, extended);
      }
      return extended;
    } finally {
      watch.stop();
      _debugTelemetry(
        'profile_package_extended_load_ms',
        wallet: wallet,
        value: watch.elapsedMilliseconds,
      );
      _extendedInFlight.remove(inFlightKey);
    }
  }

  static Future<ProfilePackage?> loadPublicProfilePackage(
    String walletAddress, {
    bool forceRefresh = false,
    bool includePosts = true,
    bool includeShowcase = true,
    String? username,
  }) async {
    final critical = await loadPublicProfileCriticalPackage(
      walletAddress,
      forceRefresh: forceRefresh,
      username: username,
    );
    if (critical == null || !critical.isComplete) return null;

    final extended = (includePosts || includeShowcase)
        ? await loadPublicProfileExtendedPackage(
            critical.user.id,
            forceRefresh: forceRefresh,
            includePosts: includePosts,
            includeShowcase: includeShowcase,
            user: critical.user,
          )
        : getCachedExtendedPackage(critical.user.id, allowStale: true);

    return ProfilePackage.fromParts(
      critical: critical,
      extended: extended,
    );
  }

  static ProfileCriticalPackage? getCachedCriticalPackage(
    String walletAddress, {
    bool allowStale = true,
  }) {
    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty) return null;
    final cached =
        _criticalCache[wallet] ?? _criticalCache[WalletUtils.normalize(wallet)];
    if (cached == null || !cached.isComplete) return null;
    final fresh = cached.isFresh(cacheTtl);
    if (!allowStale && !fresh) return null;
    if (allowStale && !fresh) {
      _debugTelemetry('profile_package_critical_stale_hit', wallet: wallet);
    }
    return cached;
  }

  static ProfileExtendedPackage? getCachedExtendedPackage(
    String walletAddress, {
    bool allowStale = true,
  }) {
    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty) return null;
    return _extendedCache[wallet] ??
        _extendedCache[WalletUtils.normalize(wallet)];
  }

  static ProfilePackage? getCachedPackage(
    String walletAddress, {
    bool allowStale = true,
  }) {
    final critical = getCachedCriticalPackage(
      walletAddress,
      allowStale: allowStale,
    );
    if (critical == null) return null;
    return ProfilePackage.fromParts(
      critical: critical,
      extended: getCachedExtendedPackage(walletAddress, allowStale: allowStale),
    );
  }

  static Future<ProfileCriticalPackage?> prefetchPublicProfileCriticalPackage(
    String walletAddress, {
    bool forceRefresh = false,
    String? username,
  }) {
    return loadPublicProfileCriticalPackage(
      walletAddress,
      forceRefresh: forceRefresh,
      username: username,
    );
  }

  static Future<ProfileExtendedPackage?> prefetchPublicProfileExtendedPackage(
    String walletAddress, {
    bool forceRefresh = false,
    bool includePosts = true,
    bool includeShowcase = true,
    User? user,
  }) {
    return loadPublicProfileExtendedPackage(
      walletAddress,
      forceRefresh: forceRefresh,
      includePosts: includePosts,
      includeShowcase: includeShowcase,
      user: user,
    );
  }

  static Future<ProfilePackage?> prefetchPublicProfilePackage(
    String walletAddress, {
    bool forceRefresh = false,
    String? username,
  }) {
    return loadPublicProfilePackage(
      walletAddress,
      forceRefresh: forceRefresh,
      includePosts: true,
      includeShowcase: true,
      username: username,
    );
  }

  static ProfilePackageCacheStatus cacheStatus(String walletAddress) {
    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty) return ProfilePackageCacheStatus.none;
    final critical = _criticalCache[wallet];
    if (critical != null && critical.isComplete) {
      return critical.isFresh(cacheTtl)
          ? ProfilePackageCacheStatus.complete
          : ProfilePackageCacheStatus.staleComplete;
    }
    if (_failedAt.containsKey(wallet)) return ProfilePackageCacheStatus.failed;
    if (UserService.getCachedUser(wallet) != null) {
      return ProfilePackageCacheStatus.profileShellOnly;
    }
    return ProfilePackageCacheStatus.none;
  }

  static void invalidate(String walletAddress) {
    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty) return;
    _removeKeys(wallet, critical: true, extended: true);
    unawaited(_persistCriticalCache());
  }

  static void invalidateMany(Iterable<String> walletAddresses) {
    var changed = false;
    for (final walletAddress in walletAddresses) {
      final wallet = WalletUtils.canonical(walletAddress);
      if (wallet.isEmpty) continue;
      _removeKeys(wallet, critical: true, extended: true);
      changed = true;
    }
    if (changed) unawaited(_persistCriticalCache());
  }

  static void invalidateAchievements(String walletAddress) {
    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty) return;
    _removeKeys(wallet, critical: true, extended: false);
    unawaited(_persistCriticalCache());
  }

  static void invalidatePosts(String walletAddress) {
    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty) return;
    _removeKeys(wallet, critical: false, extended: true);
  }

  static void invalidateShowcase(String walletAddress) {
    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty) return;
    _removeKeys(wallet, critical: false, extended: true);
  }

  static void patchUser(
    String walletAddress,
    User Function(User current) patch,
  ) {
    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty) return;
    final critical = _criticalCache[wallet];
    if (critical == null) return;
    final nextUser = patch(critical.user);
    _storeCriticalPackage(critical.copyWith(user: nextUser));
  }

  static void patchStats(String walletAddress, Map<String, int> patch) {
    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty || patch.isEmpty) return;
    final critical = _criticalCache[wallet];
    if (critical == null) return;
    final updatedStats = <String, int>{...critical.publicStats, ...patch};
    _storeCriticalPackage(
      critical.copyWith(
        publicStats: updatedStats,
        user: critical.user.copyWith(
          postsCount: updatedStats['posts'] ?? critical.user.postsCount,
          followersCount:
              updatedStats['followers'] ?? critical.user.followersCount,
          followingCount:
              updatedStats['following'] ?? critical.user.followingCount,
        ),
      ),
    );
  }

  static void patchPosts(
    String walletAddress,
    List<CommunityPost> posts, {
    bool updateCount = true,
  }) {
    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty) return;
    final current = _extendedCache[wallet];
    _storeExtendedPackage(
      wallet,
      (current ?? ProfileExtendedPackage(fetchedAt: DateTime.now())).copyWith(
        initialPosts: List<CommunityPost>.from(posts),
        fetchedAt: DateTime.now(),
      ),
    );
    if (updateCount) {
      patchStats(wallet, <String, int>{'posts': posts.length});
    }
  }

  static void patchAchievementResult(
    String walletAddress,
    backend.AchievementEventResult result,
  ) {
    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty) return;
    final critical = _criticalCache[wallet];
    if (critical == null) return;

    final progressById = <String, legacy.AchievementProgress>{
      for (final item in critical.achievementProgress) item.achievementId: item,
    };
    for (final progress in result.progress) {
      final code = progress.achievementCode.trim();
      if (code.isEmpty) continue;
      progressById[code] = legacy.AchievementProgress(
        achievementId: code,
        currentProgress: progress.currentProgress,
        isCompleted: progress.isCompleted,
        completedDate: progress.completedAt,
      );
    }
    for (final unlocked in result.unlocked) {
      final code = unlocked.code.trim();
      if (code.isEmpty) continue;
      final current = progressById[code];
      progressById[code] = legacy.AchievementProgress(
        achievementId: code,
        currentProgress: current?.currentProgress ?? 1,
        isCompleted: true,
        completedDate: unlocked.unlockedAt ?? current?.completedDate,
      );
    }

    final nextProgress = progressById.values.toList(growable: false);
    _storeCriticalPackage(
      critical.copyWith(
        achievementProgress: nextProgress,
        user: critical.user.copyWith(achievementProgress: nextProgress),
        fetchedAt: DateTime.now(),
      ),
    );
  }

  @visibleForTesting
  static void clearMemoryCacheForTesting() {
    _criticalCache.clear();
    _extendedCache.clear();
    _criticalInFlight.clear();
    _extendedInFlight.clear();
    _failedAt.clear();
    _criticalInvalidationEpoch.clear();
    _extendedInvalidationEpoch.clear();
    _persistentCacheLoaded = false;
  }

  @visibleForTesting
  static void setCachedCriticalPackageForTesting(
    ProfileCriticalPackage critical,
  ) {
    _storeCriticalPackage(critical, persist: false);
  }

  @visibleForTesting
  static void setCachedExtendedPackageForTesting(
    String walletAddress,
    ProfileExtendedPackage extended,
  ) {
    _storeExtendedPackage(walletAddress, extended);
  }

  @visibleForTesting
  static void setCachedPackageForTesting(ProfilePackage package) {
    _storeCriticalPackage(package.critical, persist: false);
    final extended = package.extended;
    if (extended != null) {
      _storeExtendedPackage(package.user.id, extended);
    }
  }

  static Future<ProfileCriticalPackage?> _loadFreshPublicProfileCriticalPackage(
    _ProfileLookup lookup,
  ) async {
    final hasWallet = lookup.wallet.isNotEmpty;

    final userFuture = hasWallet
        ? UserService.getUserById(
            lookup.wallet,
            forceRefresh: true,
            includeAchievements: false,
          )
        : UserService.getUserByUsername(
            lookup.username ?? '',
            includeAchievements: false,
          );

    final achievementFuture = hasWallet
        ? UserService.loadPublicAchievementSummaryResult(lookup.wallet)
        : Future<UserAchievementSummaryResult>.value(
            const UserAchievementSummaryResult(unavailable: true),
          );
    final statsFuture = hasWallet
        ? _loadPublicStats(lookup.wallet)
        : Future<Map<String, int>>.value(const <String, int>{});

    final userShell = await userFuture;
    if (userShell == null) return null;

    final resolvedWallet = WalletUtils.canonical(userShell.id);
    final achievementResult = hasWallet
        ? await achievementFuture
        : await UserService.loadPublicAchievementSummaryResult(resolvedWallet);
    final stats =
        hasWallet ? await statsFuture : await _loadPublicStats(resolvedWallet);

    final statsWithFallback = <String, int>{
      'posts': userShell.postsCount,
      'followers': userShell.followersCount,
      'following': userShell.followingCount,
      ...stats,
    };

    final user = userShell.copyWith(
      postsCount: statsWithFallback['posts'],
      followersCount: statsWithFallback['followers'],
      followingCount: statsWithFallback['following'],
      achievementProgress: achievementResult.progress,
      achievementDefinitions: achievementResult.definitions,
    );

    final critical = ProfileCriticalPackage(
      user: user,
      achievementProgress: achievementResult.progress,
      achievementDefinitions: achievementResult.definitions,
      publicStats: statsWithFallback,
      fetchedAt: DateTime.now(),
      isComplete: achievementResult.isResolved,
      achievementsUnavailable: achievementResult.unavailable,
    );

    if (critical.isComplete) {
      UserService.setUsersInCacheAuthoritative([critical.user]);
    }
    return critical;
  }

  static Future<ProfileExtendedPackage?> _loadFreshPublicProfileExtendedPackage(
    String walletAddress, {
    required bool includePosts,
    required bool includeShowcase,
    User? user,
  }) async {
    final wallet = WalletUtils.canonical(walletAddress);
    final effectiveUser = user ??
        getCachedCriticalPackage(wallet, allowStale: true)?.user ??
        UserService.getCachedUser(wallet);

    final postsFuture = includePosts
        ? _loadInitialPosts(wallet)
        : Future<List<CommunityPost>?>.value(null);
    final showcaseFuture = includeShowcase && effectiveUser != null
        ? _loadShowcase(effectiveUser, wallet)
        : Future<_ProfileShowcasePayload>.value(
            const _ProfileShowcasePayload(),
          );

    final results = await Future.wait<dynamic>([
      postsFuture,
      showcaseFuture,
    ]);
    final showcase = results[1] as _ProfileShowcasePayload;
    return ProfileExtendedPackage(
      initialPosts: results[0] as List<CommunityPost>?,
      artistArtworks: showcase.artworks,
      artistCollections: showcase.collections,
      artistEvents: showcase.events,
      fetchedAt: DateTime.now(),
    );
  }

  static Future<Map<String, int>> _loadPublicStats(String walletAddress) async {
    try {
      final snapshot = await StatsApiService().fetchSnapshot(
        entityType: 'user',
        entityId: walletAddress,
        metrics: const <String>[
          'posts',
          'followers',
          'following',
          'publicStreetArtAdded',
        ],
        scope: 'public',
        forceRefresh: true,
      );
      return Map<String, int>.from(snapshot.counters);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePackageService._loadPublicStats: $e');
      }
      return const <String, int>{};
    }
  }

  static Future<List<CommunityPost>?> _loadInitialPosts(
      String walletAddress) async {
    try {
      return await BackendApiService().getCommunityPosts(
        page: 1,
        limit: 20,
        authorWallet: walletAddress,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePackageService._loadInitialPosts: $e');
      }
      return const <CommunityPost>[];
    }
  }

  static Future<_ProfileShowcasePayload> _loadShowcase(
    User user,
    String walletAddress,
  ) async {
    final isCreator = user.isArtist || user.isInstitution;
    if (!isCreator) return const _ProfileShowcasePayload();

    try {
      final api = BackendApiService();
      final artworksFuture = api.getArtistArtworks(walletAddress, limit: 6);
      final collectionsFuture =
          api.getCollections(walletAddress: walletAddress, limit: 6);
      final eventsFuture = api.listEvents(limit: 100);

      final results = await Future.wait<dynamic>([
        artworksFuture,
        collectionsFuture,
        eventsFuture,
      ]);

      final events = (results[2] as List<Map<String, dynamic>>)
          .where((event) => profileEventBelongsToWallet(event, walletAddress))
          .take(6)
          .map((event) => Map<String, dynamic>.from(event))
          .toList(growable: false);

      return _ProfileShowcasePayload(
        artworks: (results[0] as List<Map<String, dynamic>>)
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false),
        collections: (results[1] as List<Map<String, dynamic>>)
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false),
        events: events,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePackageService._loadShowcase: $e');
      }
      return const _ProfileShowcasePayload();
    }
  }

  static void _storeCriticalPackage(
    ProfileCriticalPackage critical, {
    bool persist = true,
  }) {
    if (!critical.isComplete) return;
    final wallet = WalletUtils.canonical(critical.user.id);
    if (wallet.isEmpty) return;
    _criticalCache[wallet] = critical;
    _criticalCache[WalletUtils.normalize(wallet)] = critical;
    _failedAt.remove(wallet);
    if (persist) {
      unawaited(_persistCriticalCache());
    }
  }

  static void _storeExtendedPackage(
    String walletAddress,
    ProfileExtendedPackage extended,
  ) {
    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty) return;
    _extendedCache[wallet] = extended;
    _extendedCache[WalletUtils.normalize(wallet)] = extended;
  }

  static void _removeKeys(
    String wallet, {
    required bool critical,
    required bool extended,
  }) {
    final normalized = WalletUtils.normalize(wallet);
    final keys = <String>{wallet, normalized};
    if (critical) {
      _bumpEpoch(_criticalInvalidationEpoch, keys);
      for (final key in keys) {
        _criticalCache.remove(key);
        _failedAt.remove(key);
      }
      _criticalInFlight.removeWhere(
        (key, _) => keys.contains(key) || key.startsWith('$wallet|'),
      );
    }
    if (extended) {
      _bumpEpoch(_extendedInvalidationEpoch, keys);
      for (final key in keys) {
        _extendedCache.remove(key);
      }
      _extendedInFlight.removeWhere(
        (key, _) => keys.contains(key) || key.startsWith('$wallet|'),
      );
    }
  }

  static void _bumpEpoch(Map<String, int> epochs, Set<String> keys) {
    for (final key in keys) {
      if (key.isEmpty) continue;
      epochs[key] = (epochs[key] ?? 0) + 1;
    }
  }

  static bool _criticalInvalidatedSince(String walletAddress, int startEpoch) {
    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty) return false;
    return (_criticalInvalidationEpoch[wallet] ?? 0) != startEpoch;
  }

  static bool _extendedInvalidatedSince(String walletAddress, int startEpoch) {
    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty) return false;
    return (_extendedInvalidationEpoch[wallet] ?? 0) != startEpoch;
  }

  static Future<void> _ensurePersistentCacheLoaded() async {
    if (_persistentCacheLoaded) return;
    _persistentCacheLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_criticalCachePrefsKey) ??
          prefs.getString('profile_package_cache_v1');
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        try {
          final payload = entry.value;
          if (payload is! Map) continue;
          final map = Map<String, dynamic>.from(payload);
          final critical = map['critical'] is Map
              ? ProfileCriticalPackage.fromJson(
                  Map<String, dynamic>.from(map['critical'] as Map),
                )
              : ProfilePackage.fromJson(map).critical;
          if (!critical.isComplete) continue;
          if (!critical.isFresh(const Duration(hours: 24))) continue;
          _storeCriticalPackage(critical, persist: false);
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePackageService._ensurePersistentCacheLoaded: $e');
      }
    }
  }

  static Future<void> _persistCriticalCache() async {
    try {
      final entries = _criticalCache.entries
          .where((entry) =>
              WalletUtils.canonical(entry.key) == entry.key &&
              WalletUtils.looksLikeWallet(entry.key))
          .map((entry) => MapEntry(entry.key, entry.value))
          .toList(growable: false)
        ..sort((a, b) => b.value.fetchedAt.compareTo(a.value.fetchedAt));
      final limited = entries.take(_maxPersistedPackages);
      final payload = <String, dynamic>{
        for (final entry in limited) entry.key: entry.value.toJson(),
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_criticalCachePrefsKey, jsonEncode(payload));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePackageService._persistCriticalCache: $e');
      }
    }
  }

  static void _debugTelemetry(
    String event, {
    String? wallet,
    int? value,
  }) {
    if (!kDebugMode) return;
    final suffix = <String>[
      if (wallet != null && wallet.isNotEmpty) 'wallet=$wallet',
      if (value != null) 'value=$value',
    ].join(' ');
    debugPrint(
      suffix.isEmpty
          ? 'ProfilePackageService.telemetry $event'
          : 'ProfilePackageService.telemetry $event $suffix',
    );
  }
}

class _ProfileLookup {
  _ProfileLookup(String walletAddress, {String? username})
      : wallet = WalletUtils.canonical(walletAddress),
        username = username?.trim().replaceFirst(RegExp(r'^@+'), '');

  final String wallet;
  final String? username;

  bool get hasLookup =>
      wallet.isNotEmpty || (username != null && username!.isNotEmpty);

  String get cacheKey =>
      wallet.isNotEmpty ? wallet : 'username:${username!.toLowerCase()}';
}

class _ProfileShowcasePayload {
  const _ProfileShowcasePayload({
    this.artworks = const <Map<String, dynamic>>[],
    this.collections = const <Map<String, dynamic>>[],
    this.events = const <Map<String, dynamic>>[],
  });

  final List<Map<String, dynamic>> artworks;
  final List<Map<String, dynamic>> collections;
  final List<Map<String, dynamic>> events;
}
