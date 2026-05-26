import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../community/community_interactions.dart';
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

class ProfilePackageService {
  ProfilePackageService._();

  static const Duration cacheTtl = Duration(minutes: 5);
  static const String _cachePrefsKey = 'profile_package_cache_v1';
  static const int _maxPersistedPackages = 80;

  static final Map<String, ProfilePackage> _cache = <String, ProfilePackage>{};
  static final Map<String, Future<ProfilePackage?>> _inFlight =
      <String, Future<ProfilePackage?>>{};
  static final Map<String, DateTime> _failedAt = <String, DateTime>{};
  static bool _persistentCacheLoaded = false;

  static Future<ProfilePackage?> loadPublicProfilePackage(
    String walletAddress, {
    bool forceRefresh = false,
    bool includePosts = true,
    bool includeShowcase = true,
    String? username,
  }) async {
    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty && (username == null || username.trim().isEmpty)) {
      return null;
    }

    await _ensurePersistentCacheLoaded();

    final cacheKey = wallet.isNotEmpty
        ? wallet
        : 'username:${username!.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase()}';
    final cached = _cache[cacheKey] ??
        (wallet.isNotEmpty ? _cache[WalletUtils.normalize(wallet)] : null);
    if (!forceRefresh &&
        cached != null &&
        cached.isComplete &&
        cached.isFresh(cacheTtl)) {
      return cached;
    }

    final existing = _inFlight[cacheKey];
    if (existing != null) return existing;

    final future = _loadFreshPublicProfilePackage(
      wallet,
      username: username,
      includePosts: includePosts,
      includeShowcase: includeShowcase,
    );
    _inFlight[cacheKey] = future;
    try {
      final package = await future;
      if (package != null && package.isComplete) {
        _storePackage(package);
      } else {
        _failedAt[cacheKey] = DateTime.now();
      }
      return package;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  static ProfilePackage? getCachedPackage(
    String walletAddress, {
    bool allowStale = true,
  }) {
    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty) return null;
    final cached = _cache[wallet] ?? _cache[WalletUtils.normalize(wallet)];
    if (cached == null || !cached.isComplete) return null;
    if (!allowStale && !cached.isFresh(cacheTtl)) return null;
    return cached;
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
    final package = _cache[wallet];
    if (package != null && package.isComplete) {
      return package.isFresh(cacheTtl)
          ? ProfilePackageCacheStatus.complete
          : ProfilePackageCacheStatus.staleComplete;
    }
    if (_failedAt.containsKey(wallet)) return ProfilePackageCacheStatus.failed;
    if (UserService.getCachedUser(wallet) != null) {
      return ProfilePackageCacheStatus.profileShellOnly;
    }
    return ProfilePackageCacheStatus.none;
  }

  @visibleForTesting
  static void clearMemoryCacheForTesting() {
    _cache.clear();
    _inFlight.clear();
    _failedAt.clear();
    _persistentCacheLoaded = false;
  }

  @visibleForTesting
  static void setCachedPackageForTesting(ProfilePackage package) {
    _storePackage(package, persist: false);
  }

  static Future<ProfilePackage?> _loadFreshPublicProfilePackage(
    String walletAddress, {
    String? username,
    required bool includePosts,
    required bool includeShowcase,
  }) async {
    final wallet = WalletUtils.canonical(walletAddress);
    final hasWallet = wallet.isNotEmpty;

    final userFuture = hasWallet
        ? UserService.getUserById(
            wallet,
            forceRefresh: true,
            includeAchievements: false,
          )
        : UserService.getUserByUsername(
            username ?? '',
            includeAchievements: false,
          );

    final achievementFuture = hasWallet
        ? UserService.loadPublicAchievementSummaryResult(wallet)
        : Future<UserAchievementSummaryResult>.value(
            const UserAchievementSummaryResult(unavailable: true),
          );
    final statsFuture = hasWallet
        ? _loadPublicStats(wallet)
        : Future<Map<String, int>>.value(const <String, int>{});
    final postsFuture = hasWallet && includePosts
        ? _loadInitialPosts(wallet)
        : Future<List<CommunityPost>?>.value(null);

    final userShell = await userFuture;
    if (userShell == null) return null;

    final resolvedWallet = WalletUtils.canonical(userShell.id);
    final achievementResult = hasWallet
        ? await achievementFuture
        : await UserService.loadPublicAchievementSummaryResult(resolvedWallet);
    final stats =
        hasWallet ? await statsFuture : await _loadPublicStats(resolvedWallet);
    final posts = hasWallet && includePosts
        ? await postsFuture
        : includePosts
            ? await _loadInitialPosts(resolvedWallet)
            : null;
    final showcase = includeShowcase
        ? await _loadShowcase(userShell, resolvedWallet)
        : const _ProfileShowcasePayload();

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

    final package = ProfilePackage(
      user: user,
      achievementProgress: achievementResult.progress,
      achievementDefinitions: achievementResult.definitions,
      publicStats: statsWithFallback,
      initialPosts: posts,
      artistArtworks: showcase.artworks,
      artistCollections: showcase.collections,
      artistEvents: showcase.events,
      fetchedAt: DateTime.now(),
      isComplete: achievementResult.isResolved,
      achievementsUnavailable: achievementResult.unavailable,
    );

    if (package.isComplete) {
      UserService.setUsersInCacheAuthoritative([package.user]);
    }
    return package;
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

  static void _storePackage(
    ProfilePackage package, {
    bool persist = true,
  }) {
    if (!package.isComplete) return;
    final wallet = WalletUtils.canonical(package.user.id);
    if (wallet.isEmpty) return;
    _cache[wallet] = package;
    _cache[WalletUtils.normalize(wallet)] = package;
    _failedAt.remove(wallet);
    if (persist) {
      unawaited(_persistCache());
    }
  }

  static Future<void> _ensurePersistentCacheLoaded() async {
    if (_persistentCacheLoaded) return;
    _persistentCacheLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachePrefsKey);
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        try {
          final payload = entry.value;
          if (payload is! Map) continue;
          final package =
              ProfilePackage.fromJson(Map<String, dynamic>.from(payload));
          if (!package.isComplete) continue;
          if (!package.isFresh(const Duration(hours: 24))) continue;
          _storePackage(package, persist: false);
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePackageService._ensurePersistentCacheLoaded: $e');
      }
    }
  }

  static Future<void> _persistCache() async {
    try {
      final entries = _cache.entries
          .where((entry) => WalletUtils.canonical(entry.key) == entry.key)
          .map((entry) => MapEntry(entry.key, entry.value))
          .toList(growable: false)
        ..sort((a, b) => b.value.fetchedAt.compareTo(a.value.fetchedAt));
      final limited = entries.take(_maxPersistedPackages);
      final payload = <String, dynamic>{
        for (final entry in limited) entry.key: entry.value.toJson(),
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachePrefsKey, jsonEncode(payload));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePackageService._persistCache: $e');
      }
    }
  }
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
