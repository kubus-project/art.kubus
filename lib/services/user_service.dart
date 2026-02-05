import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config/config.dart';
import '../models/achievement_progress.dart';
import '../models/user.dart';
import 'backend_api_service.dart';
import 'stats_api_service.dart';
import 'achievement_service.dart' as achievement_svc;
import '../utils/wallet_utils.dart';
import 'user_action_logger.dart';

class UserService {
  static const String _followingKey = 'following_users';
  static const String _cachePrefsKey = 'user_cache_v1';
  static const String _placeholderAvatarScheme = 'placeholder://';

  // Persistence defaults: keep entries for 6 hours and cap stored entries to avoid unbounded growth
  static int _maxEntries = 500;
  static int _ttlMillis = 6 * 60 * 60 * 1000; // 6 hours

  // Simple in-memory cache for user profiles to reduce network round-trips
  static final Map<String, User> _cache = {};
  // Timestamps (epoch millis) for when entries were cached
  static final Map<String, int> _cacheTimestamps = {};
  // Tracks legacy cache entries that were persisted before we stored `coverImageUrl`.
  // Used to force a one-time refresh so profile covers load without manual reload.
  static final Set<String> _legacyCacheMissingCoverKey = <String>{};
  // NOTE: Removed prior cacheVersion notifier. UI components should call
  // UserService.getUsersByWallets/getUserById for explicit fetches and not rely on
  // an implicit cache notification system.

  // Sample users data
  static final List<User> _sampleUsers = [
    const User(
      id: 'maya_3d',
      name: 'Maya Digital',
      username: 'maya_3d',
      bio:
          'AR artist exploring the intersection of digital and physical reality. Creating immersive experiences that transform everyday spaces.',
      followersCount: 1250,
      followingCount: 189,
      postsCount: 42,
      isFollowing: false,
      isVerified: true,
      isArtist: true,
      joinedDate: 'Joined March 2024',
      achievementProgress: [
        AchievementProgress(
            achievementId: 'first_ar_view',
            currentProgress: 1,
            isCompleted: true),
        AchievementProgress(
            achievementId: 'ar_enthusiast',
            currentProgress: 10,
            isCompleted: false),
        AchievementProgress(
            achievementId: 'community_builder',
            currentProgress: 12,
            isCompleted: false),
        AchievementProgress(
            achievementId: 'early_adopter',
            currentProgress: 1,
            isCompleted: true),
      ],
    ),
    const User(
      id: 'alex_nft',
      name: 'Alex Creator',
      username: 'alex_nft',
      bio:
          'NFT creator and blockchain enthusiast. Building the future of digital ownership through art and technology.',
      followersCount: 892,
      followingCount: 341,
      postsCount: 67,
      isFollowing: false,
      isVerified: false,
      isArtist: true,
      joinedDate: 'Joined January 2024',
      achievementProgress: [
        AchievementProgress(
            achievementId: 'first_nft_mint',
            currentProgress: 1,
            isCompleted: true),
        AchievementProgress(
            achievementId: 'nft_collector',
            currentProgress: 3,
            isCompleted: false),
        AchievementProgress(
            achievementId: 'art_supporter',
            currentProgress: 1,
            isCompleted: false),
      ],
    ),
    const User(
      id: 'sam_ar',
      name: 'Sam Artist',
      username: 'sam_ar',
      bio:
          'Interactive AR sculptor. Passionate about collaborative art that responds to viewer interaction. Let\'s build the future together! 🚀',
      followersCount: 2150,
      followingCount: 203,
      postsCount: 28,
      isFollowing: false,
      isVerified: true,
      isArtist: true,
      joinedDate: 'Joined February 2024',
      achievementProgress: [
        AchievementProgress(
            achievementId: 'first_ar_view',
            currentProgress: 1,
            isCompleted: true),
        AchievementProgress(
            achievementId: 'ar_enthusiast',
            currentProgress: 8,
            isCompleted: false),
        AchievementProgress(
            achievementId: 'first_post', currentProgress: 1, isCompleted: true),
        AchievementProgress(
            achievementId: 'art_supporter',
            currentProgress: 5,
            isCompleted: false),
      ],
    ),
    const User(
      id: 'luna_viz',
      name: 'Luna Vision',
      username: 'luna_viz',
      bio:
          'Exploring the infinite possibilities at the intersection of blockchain and creativity. Every pixel tells a story.',
      followersCount: 743,
      followingCount: 156,
      postsCount: 91,
      isFollowing: false,
      isVerified: false,
      isArtist: false,
      joinedDate: 'Joined April 2024',
      achievementProgress: [
        AchievementProgress(
            achievementId: 'first_comment',
            currentProgress: 1,
            isCompleted: true),
        AchievementProgress(
            achievementId: 'commentator',
            currentProgress: 7,
            isCompleted: false),
        AchievementProgress(
            achievementId: 'gallery_visitor',
            currentProgress: 1,
            isCompleted: true),
      ],
    ),
  ];

  /// Whether [walletAddress] refers to the currently authenticated/active user.
  ///
  /// Some endpoints (like detailed achievements) are intentionally self-only on
  /// the backend and return 403 for other wallets. Public profile viewing must
  /// not call those endpoints.
  static Future<bool> _isCurrentUserWallet(String walletAddress) async {
    final normalizedTarget = WalletUtils.normalize(walletAddress);
    if (normalizedTarget.isEmpty) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = (prefs.getString(PreferenceKeys.walletAddress) ??
              prefs.getString('wallet_address') ??
              prefs.getString('wallet') ??
              prefs.getString('walletAddress') ??
              '')
          .trim();
      if (stored.isEmpty) return false;
      return WalletUtils.equals(stored, normalizedTarget);
    } catch (_) {
      return false;
    }
  }

  static Future<User?> getUserById(String userId,
      {bool forceRefresh = false}) async {
    try {
      // Consult cache first (unless caller requests fresh data)
      if (!forceRefresh) {
        if (userId.isNotEmpty && _cache.containsKey(userId)) {
          // Check TTL
          try {
            final ts = _cacheTimestamps[userId] ?? 0;
            if (ts > 0 &&
                DateTime.now().millisecondsSinceEpoch - ts > _ttlMillis) {
              // expired
              _cache.remove(userId);
              _cacheTimestamps.remove(userId);
              _legacyCacheMissingCoverKey.remove(userId);
            } else {
              // Force a one-time refresh for legacy cache entries that predate
              // coverImageUrl persistence so profile covers load automatically.
              if (!_legacyCacheMissingCoverKey.contains(userId)) {
                return _cache[userId];
              }
            }
          } catch (_) {
            if (!_legacyCacheMissingCoverKey.contains(userId)) {
              return _cache[userId];
            }
          }
        }
      }
    } catch (_) {}
    try {
      // Fetch profile from backend using wallet address (force or cache miss)
      final profile = await BackendApiService().getProfileByWallet(userId);
      // Log (briefly) the profile payload for diagnostics if it has unexpected shapes
      if (kDebugMode) {
        try {
          debugPrint('UserService.getUserById: profile keys = ${profile.keys}');
        } catch (_) {}
      }

      final followingList = await getFollowingUsers();
      final isFollowing = followingList.contains(userId);
      final isArtist =
          (profile['isArtist'] == true) || (profile['is_artist'] == true);
      final isInstitution = (profile['isInstitution'] == true) ||
          (profile['is_institution'] == true);
      final resolvedWallet = (profile['walletAddress'] ?? userId).toString();
      // Try to parse embedded stats if the profile payload contains them
      int followersFromProfile = 0;
      int followingFromProfile = 0;
      int postsFromProfile = 0;
      try {
        final stats =
            profile['stats'] ?? profile['statistics'] ?? profile['meta'];
        if (stats is Map<String, dynamic>) {
          followersFromProfile = _parseInt(stats['followers'] ??
              stats['followersCount'] ??
              stats['followers_count']);
          followingFromProfile = _parseInt(stats['following'] ??
              stats['followingCount'] ??
              stats['following_count']);
          postsFromProfile = _parseInt(
              stats['posts'] ?? stats['postsCount'] ?? stats['posts_count']);
        }
      } catch (_) {}
      List<AchievementProgress> achievementProgress = const [];
      try {
        if (await _isCurrentUserWallet(resolvedWallet)) {
          achievementProgress = await loadAchievementProgress(resolvedWallet);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              'UserService.getUserById: failed to load achievements for $resolvedWallet: $e');
        }
      }

      List<String> fieldOfWork = const <String>[];
      int yearsActive = 0;
      try {
        final artistInfo = profile['artistInfo'] ?? profile['artist_info'];
        if (artistInfo is Map<String, dynamic>) {
          final rawSpecialty = artistInfo['specialty'] ??
              artistInfo['fieldOfWork'] ??
              artistInfo['field_of_work'];
          if (rawSpecialty is List) {
            fieldOfWork = rawSpecialty
                .map((v) => (v ?? '').toString().trim())
                .where((v) => v.isNotEmpty)
                .toList(growable: false);
          } else if (rawSpecialty is String) {
            fieldOfWork = rawSpecialty
                .split(',')
                .map((v) => v.trim())
                .where((v) => v.isNotEmpty)
                .toList(growable: false);
          }
          yearsActive = _parseInt(
              artistInfo['yearsActive'] ?? artistInfo['years_active']);
        } else {
          final raw = profile['fieldOfWork'] ?? profile['field_of_work'];
          if (raw is List) {
            fieldOfWork = raw
                .map((v) => (v ?? '').toString().trim())
                .where((v) => v.isNotEmpty)
                .toList(growable: false);
          } else if (raw is String) {
            fieldOfWork = raw
                .split(',')
                .map((v) => v.trim())
                .where((v) => v.isNotEmpty)
                .toList(growable: false);
          }
          yearsActive =
              _parseInt(profile['yearsActive'] ?? profile['years_active']);
        }
      } catch (_) {}

      // Convert backend profile to User model
      // NOTE: Do not fabricate @handles from wallet addresses. Keep username
      // as the backend-provided handle (without leading '@') or empty.
      final rawUsername = (profile['username'] ?? '').toString().trim();
      final normalizedUsername =
          rawUsername.replaceFirst(RegExp(r'^@+'), '').trim();
      final safeUsername = normalizedUsername.isNotEmpty &&
              !WalletUtils.looksLikeWallet(normalizedUsername)
          ? normalizedUsername
          : '';

      final rawDisplayName =
          (profile['displayName'] ?? profile['display_name'] ?? '')
              .toString()
              .trim();
      final safeDisplayName = rawDisplayName.isNotEmpty &&
              !WalletUtils.looksLikeWallet(rawDisplayName)
          ? rawDisplayName
          : '';

      final effectiveName = safeDisplayName.isNotEmpty
          ? safeDisplayName
          : (safeUsername.isNotEmpty ? safeUsername : 'Unknown artist');
      final user = User(
        id: resolvedWallet,
        name: effectiveName,
        username: safeUsername,
        bio: profile['bio']?.toString() ?? '',
        followersCount: followersFromProfile,
        followingCount: followingFromProfile,
        postsCount: postsFromProfile,
        isFollowing: isFollowing,
        isVerified: profile['isVerified'] ?? false,
        isArtist: isArtist,
        isInstitution: isInstitution,
        fieldOfWork: fieldOfWork,
        yearsActive: yearsActive,
        joinedDate: profile['createdAt'] != null
            ? 'Joined ${DateTime.parse(profile['createdAt']).month}/${DateTime.parse(profile['createdAt']).year}'
            : 'Joined recently',
        achievementProgress: achievementProgress,
        profileImageUrl: _extractAvatarCandidate(profile['avatar'], userId),
        coverImageUrl: _extractMediaCandidate(
          profile['coverImage'] ??
              profile['coverImageUrl'] ??
              profile['cover_image_url'] ??
              profile['cover_image'] ??
              profile['coverUrl'] ??
              profile['cover_url'] ??
              profile['cover'],
        ),
      );
      if (kDebugMode) {
        try {
          debugPrint(
              'UserService.getUserById: built user: id=${user.id}, username=${user.username}, avatar=${user.profileImageUrl}');
        } catch (_) {}
      }
      // populate cache & timestamp
      try {
        if (user.id.isNotEmpty) {
          // Use the central cache setter to remain consistent and avoid direct cacheVersion bumps
          setUsersInCacheAuthoritative([user]);
          // Legacy cache entries should force-refresh only once.
          try {
            _legacyCacheMissingCoverKey.remove(userId);
            _legacyCacheMissingCoverKey.remove(user.id);
          } catch (_) {}
        }
      } catch (_) {}
      // Trigger a background refresh of authoritative stats. This is intentionally
      // non-blocking so callers of getUserById stay fast. The background fetch
      // will update the cached User when it completes.
      try {
        Future(() async {
          await fetchAndUpdateUserStats(resolvedWallet);
        });
      } catch (_) {}
      return user;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'UserService.getUserById: failed to load profile for $userId: $e');
      }
      // Return null if profile not found
      return null;
    }
  }

  // Helper to extract avatar string from various payload shapes that may be returned
  static String? _extractAvatarCandidate(dynamic candidate, String wallet) {
    try {
      String? url;
      if (candidate == null) return null;
      if (candidate is String) {
        url = candidate.isEmpty ? null : candidate;
      } else if (candidate is Map) {
        if (candidate['url'] != null &&
            candidate['url'].toString().isNotEmpty) {
          url = candidate['url'].toString();
        } else if (candidate['httpUrl'] != null &&
            candidate['httpUrl'].toString().isNotEmpty) {
          url = candidate['httpUrl'].toString();
        } else if (candidate['ipfsUrl'] != null &&
            candidate['ipfsUrl'].toString().isNotEmpty) {
          url = candidate['ipfsUrl'].toString();
        } else if (candidate['path'] != null &&
            candidate['path'].toString().isNotEmpty) {
          url = candidate['path'].toString();
        } else {
          url = candidate.toString();
        }
      } else {
        url = candidate.toString();
      }

      if (url == null) return null;
      final trimmed = url.trim();
      if (trimmed.isEmpty) return null;
      // Treat DiceBear/placeholder URLs as missing so UI renders local initials instead of remote SVGs
      if (isPlaceholderAvatarUrl(trimmed)) {
        return null;
      }
      if (trimmed.contains('api.dicebear.com') && trimmed.contains('/svg')) {
        return trimmed.replaceAll('/svg', '/png');
      }
      return trimmed;
    } catch (_) {
      return null;
    }
  }

  // Helper to extract cover/media strings from various payload shapes that may be returned.
  // This intentionally does not attempt to resolve URLs; widgets should use MediaUrlResolver.
  static String? _extractMediaCandidate(dynamic candidate) {
    try {
      if (candidate == null) return null;
      final String url = candidate is String
          ? candidate
          : candidate is Map
              ? ((candidate['url'] ??
                          candidate['httpUrl'] ??
                          candidate['ipfsUrl'] ??
                          candidate['path'] ??
                          candidate['cid'] ??
                          candidate['hash'])
                      ?.toString() ??
                  candidate.toString())
              : candidate.toString();
      final trimmed = url.trim();
      if (trimmed.isEmpty) return null;
      final lower = trimmed.toLowerCase();
      if (lower == 'null' || lower == 'undefined') return null;
      if (lower.startsWith(_placeholderAvatarScheme)) return null;
      return trimmed;
    } catch (_) {
      return null;
    }
  }

  /// Populate UserService internal cache with a list of users
  // By default, do not attempt to perform global cache-based UI notifications; callers should
  // explicitly trigger UI updates (e.g., call provider refresh methods) if they want to
  // reflect cache changes. The `notify` flag is kept for API compatibility but does
  // not perform any implicit global notification.
  static void setUsersInCache(List<User> users) {
    _setUsersInCache(users, allowNullMediaOverwrite: false);
  }

  /// Same as `setUsersInCache` but treats null media fields as authoritative updates.
  /// Use this when the caller has fetched a full profile payload or explicitly updated profile media.
  static void setUsersInCacheAuthoritative(List<User> users) {
    _setUsersInCache(users, allowNullMediaOverwrite: true);
  }

  static void _setUsersInCache(List<User> users,
      {required bool allowNullMediaOverwrite}) {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final u in users) {
        if (u.id.isEmpty) continue;

        final existing = _cache[u.id];
        if (allowNullMediaOverwrite || existing == null) {
          _cache[u.id] = u;
        } else {
          _cache[u.id] = User(
            id: u.id,
            name: u.name,
            username: u.username,
            bio: u.bio,
            profileImageUrl: u.profileImageUrl ?? existing.profileImageUrl,
            coverImageUrl: u.coverImageUrl ?? existing.coverImageUrl,
            followersCount: u.followersCount,
            followingCount: u.followingCount,
            postsCount: u.postsCount,
            isFollowing: u.isFollowing,
            isVerified: u.isVerified,
            isArtist: u.isArtist,
            isInstitution: u.isInstitution,
            joinedDate: u.joinedDate,
            achievementProgress: u.achievementProgress.isNotEmpty
                ? u.achievementProgress
                : existing.achievementProgress,
          );
        }
        try {
          _cacheTimestamps[u.id] = now;
        } catch (_) {}
        if (allowNullMediaOverwrite) {
          try {
            _legacyCacheMissingCoverKey.remove(u.id);
          } catch (_) {}
        }
      }
      // Persist asynchronously (best-effort)
      try {
        _persistCache();
        // prefer explicit API fetches by consumers; no implicit global cache notification
      } catch (_) {}
    } catch (_) {}
  }

  static Future<void> _persistCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Build map of wallet -> serialized user + cachedAt
      final map = <String, dynamic>{};
      final entries = _cache.keys.toList();
      // Enforce max entries by oldest-first eviction
      if (entries.length > _maxEntries) {
        final sorted = entries
          ..sort((a, b) =>
              (_cacheTimestamps[a] ?? 0).compareTo(_cacheTimestamps[b] ?? 0));
        final keep = sorted.reversed.take(_maxEntries).toList();
        for (final k in keep) {
          final u = _cache[k]!;
          map[k] = {
            'id': u.id,
            'name': u.name,
            'username': u.username,
            'bio': u.bio,
            'followersCount': u.followersCount,
            'followingCount': u.followingCount,
            'postsCount': u.postsCount,
            'isFollowing': u.isFollowing,
            'isVerified': u.isVerified,
            'isArtist': u.isArtist,
            'isInstitution': u.isInstitution,
            'joinedDate': u.joinedDate,
            'profileImageUrl': u.profileImageUrl,
            'coverImageUrl': u.coverImageUrl,
            'cachedAt':
                _cacheTimestamps[k] ?? DateTime.now().millisecondsSinceEpoch,
          };
        }
      } else {
        for (final k in entries) {
          final u = _cache[k]!;
          map[k] = {
            'id': u.id,
            'name': u.name,
            'username': u.username,
            'bio': u.bio,
            'followersCount': u.followersCount,
            'followingCount': u.followingCount,
            'postsCount': u.postsCount,
            'isFollowing': u.isFollowing,
            'isVerified': u.isVerified,
            'isArtist': u.isArtist,
            'isInstitution': u.isInstitution,
            'joinedDate': u.joinedDate,
            'profileImageUrl': u.profileImageUrl,
            'coverImageUrl': u.coverImageUrl,
            'cachedAt':
                _cacheTimestamps[k] ?? DateTime.now().millisecondsSinceEpoch,
          };
        }
      }
      await prefs.setString(_cachePrefsKey, json.encode(map));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserService._persistCache: $e');
      }
    }
  }

  /// Initialize persistent cache into memory. Call once at app startup.
  static Future<void> initialize(
      {int maxEntries = 500, Duration ttl = const Duration(hours: 24)}) async {
    try {
      _maxEntries = maxEntries;
      _ttlMillis = ttl.inMilliseconds;
      _legacyCacheMissingCoverKey.clear();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachePrefsKey) ?? '{}';
      final Map<String, dynamic> map = json.decode(raw) as Map<String, dynamic>;
      final now = DateTime.now().millisecondsSinceEpoch;
      final entries = <String, User>{};
      final timestamps = <String, int>{};
      for (final k in map.keys) {
        try {
          final v = map[k] as Map<String, dynamic>;
          final cachedAt = (v['cachedAt'] is int)
              ? v['cachedAt'] as int
              : int.tryParse((v['cachedAt'] ?? '').toString()) ?? 0;
          if (cachedAt == 0) continue;
          if (now - cachedAt > _ttlMillis) continue; // expired
          // Entries persisted before cover support did not include `coverImageUrl`.
          // Mark them so first access forces a refresh and profile covers load automatically.
          if (!v.containsKey('coverImageUrl')) {
            _legacyCacheMissingCoverKey.add(k);
          }
          final user = User(
            id: v['id']?.toString() ?? k,
            name: v['name']?.toString() ?? 'Unknown artist',
            username: (v['username']?.toString() ?? '')
                .replaceFirst(RegExp(r'^@+'), ''),
            bio: v['bio']?.toString() ?? '',
            followersCount: (v['followersCount'] is int)
                ? v['followersCount'] as int
                : int.tryParse((v['followersCount'] ?? '0').toString()) ?? 0,
            followingCount: (v['followingCount'] is int)
                ? v['followingCount'] as int
                : int.tryParse((v['followingCount'] ?? '0').toString()) ?? 0,
            postsCount: (v['postsCount'] is int)
                ? v['postsCount'] as int
                : int.tryParse((v['postsCount'] ?? '0').toString()) ?? 0,
            isFollowing: (v['isFollowing'] == true),
            isVerified: (v['isVerified'] == true),
            isArtist: (v['isArtist'] == true),
            isInstitution: (v['isInstitution'] == true),
            joinedDate: v['joinedDate']?.toString() ?? 'Joined recently',
            achievementProgress: [],
            profileImageUrl: v['profileImageUrl']?.toString(),
            coverImageUrl: v['coverImageUrl']?.toString(),
          );
          entries[k] = user;
          timestamps[k] = cachedAt;
        } catch (_) {}
      }
      // If entries exceed max, evict oldest
      if (entries.length > _maxEntries) {
        final sorted = timestamps.keys.toList()
          ..sort((a, b) => (timestamps[a] ?? 0).compareTo(timestamps[b] ?? 0));
        final toKeep = sorted.reversed.take(_maxEntries).toSet();
        final newEntries = <String, User>{};
        final newTimestamps = <String, int>{};
        for (final k in toKeep) {
          newEntries[k] = entries[k]!;
          newTimestamps[k] = timestamps[k]!;
        }
        _cache.clear();
        _cache.addAll(newEntries);
        _cacheTimestamps.clear();
        _cacheTimestamps.addAll(newTimestamps);
      } else {
        _cache.clear();
        _cache.addAll(entries);
        _cacheTimestamps.clear();
        _cacheTimestamps.addAll(timestamps);
      }
      // Cleanup legacy fabricated avatars persisted in cache: if a cached
      // profileImageUrl matches our placeholder token/legacy DiceBear URL,
      // remove it so UI fallback logic can decide whether to render a
      // synthesized image without persisting it.
      try {
        final keys = _cache.keys.toList();
        for (final k in keys) {
          final u = _cache[k];
          if (u != null && isPlaceholderAvatarUrl(u.profileImageUrl)) {
            _cache[k] = u.copyWith(profileImageUrl: null);
          }
        }
        // Persist cleaned cache back to prefs (best-effort)
        try {
          await _persistCache();
        } catch (_) {}
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserService.initialize: $e');
      }
    }
  }

  /// Returns a cached User if present in the in-memory cache. This is synchronous
  /// and useful for UI paths that need immediate access to previously persisted
  /// user profiles without performing async calls.
  static User? getCachedUser(String userId) {
    try {
      if (userId.isEmpty) return null;
      return _cache[userId];
    } catch (_) {
      return null;
    }
  }

  /// Returns a map of cached User objects for the given ids. Non-existing ids are omitted.
  static Map<String, User> getCachedUsers(List<String> walletIds) {
    final Map<String, User> result = {};
    try {
      for (final id in walletIds) {
        if (id.isEmpty) continue;
        final u = _cache[id];
        if (u != null) result[id] = u;
      }
    } catch (_) {}
    return result;
  }

  /// Clear persistent and in-memory cache
  static Future<void> clearCache() async {
    try {
      _cache.clear();
      _cacheTimestamps.clear();
      _legacyCacheMissingCoverKey.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachePrefsKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserService.clearCache: $e');
      }
    }
  }

  static Future<User?> getUserByUsername(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return null;
    final lookup = trimmed.replaceFirst(RegExp(r'^@+'), '').toLowerCase();

    // Check in-memory cache first for instant hits
    try {
      for (final entry in _cache.values) {
        final cachedUsername =
            entry.username.replaceFirst(RegExp(r'^@+'), '').toLowerCase();
        if (cachedUsername == lookup) {
          return entry;
        }
      }
    } catch (_) {}

    try {
      final profile = await BackendApiService().findProfileByUsername(lookup);
      if (profile == null) return null;

      final wallet = WalletUtils.normalize((profile['walletAddress'] ??
              profile['wallet_address'] ??
              profile['wallet'])
          ?.toString());
      if (wallet.isEmpty) return null;

      final followingList = await getFollowingUsers();
      final stats = profile['stats'];
      int followers = 0;
      int following = 0;
      if (stats is Map<String, dynamic>) {
        followers = int.tryParse(
                (stats['followers'] ?? stats['followersCount'] ?? 0)
                    .toString()) ??
            0;
        following = int.tryParse(
                (stats['following'] ?? stats['followingCount'] ?? 0)
                    .toString()) ??
            0;
      }

      String joinedDate = 'Joined recently';
      final createdAtRaw = profile['createdAt'] ?? profile['created_at'];
      if (createdAtRaw != null) {
        try {
          final dt = DateTime.parse(createdAtRaw.toString());
          joinedDate = 'Joined ${dt.month}/${dt.year}';
        } catch (_) {}
      }

      final resolvedUsername =
          (profile['username'] ?? lookup).toString().replaceAll('@', '');
      final avatarCandidate =
          profile['avatar'] ?? profile['avatar_url'] ?? profile['avatarUrl'];
      final isArtist =
          profile['isArtist'] == true || profile['is_artist'] == true;
      final isInstitution =
          profile['isInstitution'] == true || profile['is_institution'] == true;

      List<AchievementProgress> achievementProgress = const [];
      try {
        if (await _isCurrentUserWallet(wallet)) {
          achievementProgress = await loadAchievementProgress(wallet);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              'UserService.getUserByUsername: failed to load achievements for $wallet: $e');
        }
      }

      final user = User(
        id: wallet,
        name: ((profile['displayName'] ?? '').toString().trim().isNotEmpty &&
                !WalletUtils.looksLikeWallet(
                    (profile['displayName'] ?? '').toString().trim()))
            ? (profile['displayName'] ?? '').toString().trim()
            : ((resolvedUsername.trim().isNotEmpty &&
                    !WalletUtils.looksLikeWallet(resolvedUsername.trim()))
                ? resolvedUsername.trim()
                : 'Unknown artist'),
        username: (!WalletUtils.looksLikeWallet(resolvedUsername.trim()))
            ? resolvedUsername.trim()
            : '',
        bio: profile['bio']?.toString() ?? '',
        followersCount: followers,
        followingCount: following,
        postsCount: 0,
        isFollowing: followingList.contains(wallet),
        isVerified: profile['isVerified'] == true,
        isArtist: isArtist,
        isInstitution: isInstitution,
        joinedDate: joinedDate,
        achievementProgress: achievementProgress,
        profileImageUrl: _extractAvatarCandidate(avatarCandidate, wallet),
        coverImageUrl: _extractMediaCandidate(
          profile['coverImage'] ??
              profile['coverImageUrl'] ??
              profile['cover_image_url'] ??
              profile['cover_image'] ??
              profile['coverUrl'] ??
              profile['cover_url'] ??
              profile['cover'],
        ),
      );

      setUsersInCacheAuthoritative([user]);
      try {
        _legacyCacheMissingCoverKey.remove(wallet);
      } catch (_) {}
      return user;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserService.getUserByUsername: $e');
      }
      return null;
    }
  }

  static Future<List<String>> getFollowingUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final followingJson = prefs.getString(_followingKey);
    if (followingJson == null || followingJson.isEmpty) return <String>[];
    try {
      return List<String>.from(json.decode(followingJson));
    } catch (_) {
      return <String>[];
    }
  }

  static Future<void> _saveFollowingUsers(List<String> wallets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_followingKey, json.encode(wallets));
  }

  static Future<void> followUser(String walletAddress) async {
    if (walletAddress.isEmpty) return;
    final followingList = await getFollowingUsers();
    if (!followingList.contains(walletAddress)) {
      followingList.add(walletAddress);
      await _saveFollowingUsers(followingList);
    }
  }

  static Future<void> unfollowUser(String walletAddress) async {
    if (walletAddress.isEmpty) return;
    final followingList = await getFollowingUsers();
    followingList.remove(walletAddress);
    await _saveFollowingUsers(followingList);
  }

  static Future<bool> toggleFollow(
    String walletAddress, {
    String? displayName,
    String? username,
    String? avatarUrl,
  }) async {
    if (walletAddress.isEmpty) return false;

    final followingList = await getFollowingUsers();
    final isCurrentlyFollowing = followingList.contains(walletAddress);
    final backendApi = BackendApiService();

    if (isCurrentlyFollowing) {
      await backendApi.unfollowUser(walletAddress);
      followingList.remove(walletAddress);
      await _saveFollowingUsers(followingList);
      return false;
    } else {
      await backendApi.followUser(walletAddress);
      followingList.add(walletAddress);
      await _saveFollowingUsers(followingList);
      UserActionLogger.logFollow(
        walletAddress: walletAddress,
        displayName: displayName,
        username: username,
        avatarUrl: avatarUrl,
      );
      return true;
    }
  }

  static Future<List<User>> getFollowingUsersList() async {
    final followingList = await getFollowingUsers();
    final followingUsers = <User>[];

    for (String userId in followingList) {
      final user = await getUserById(userId);
      if (user != null) {
        followingUsers.add(user);
      }
    }

    return followingUsers;
  }

  static Future<List<User>> getAllUsers() async {
    final followingList = await getFollowingUsers();

    return _sampleUsers.map((user) {
      return user.copyWith(isFollowing: followingList.contains(user.id));
    }).toList();
  }

  /// Returns a deterministic placeholder identifier for wallets without avatars.
  /// This never points to a remote image; the UI should render local initials.
  static String defaultAvatarUrl(String wallet) {
    final seed = wallet.isEmpty ? 'anon' : WalletUtils.identiconKey(wallet);
    final normalized = seed.trim().isEmpty ? 'anon' : seed.trim();
    final sanitized =
        normalized.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '').toLowerCase();
    final token = sanitized.isNotEmpty
        ? sanitized
        : normalized.hashCode.toRadixString(16);
    return '$_placeholderAvatarScheme$token';
  }

  /// Returns a safe avatar URL for a provided seed that may be a wallet, username, or other id.
  /// If the input looks like a non-wallet (UUID, contains '-' or spaces, or contains '@'),
  /// this returns the anonymous identicon URL to avoid producing invalid upstream requests.
  static String safeAvatarUrl(dynamic seedOrWallet) {
    final s = (seedOrWallet ?? '').toString();
    if (s.isEmpty) return defaultAvatarUrl('');
    // UUID-like or contains dashes/spaces -> treat as non-wallet
    final uuidLike = RegExp(
        r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}');
    if (uuidLike.hasMatch(s) ||
        s.contains('-') ||
        s.contains(' ') ||
        s.contains('@')) {
      return defaultAvatarUrl('');
    }
    // Otherwise assume it's a wallet/seed and return identicon
    return defaultAvatarUrl(s);
  }

  /// Detects whether a URL/string represents a synthesized placeholder avatar.
  static bool isPlaceholderAvatarUrl(String? value) {
    if (value == null || value.isEmpty) return false;
    final lower = value.toLowerCase();
    if (lower.startsWith(_placeholderAvatarScheme)) return true;
    // Consider external DiceBear URLs as placeholders (we prefer internal proxy URLs)
    if (lower.contains('dicebear.com')) return true;
    // Do NOT treat internal proxy paths ("/api/avatar/") or query params like
    // "style=identicon" as placeholders — those are legitimate proxied avatars
    // returned by the backend and should be displayed by the UI.
    return false;
  }

  /// Fetch detailed achievement progress for a given wallet from backend
  static Future<List<AchievementProgress>> loadAchievementProgress(
      String walletAddress) async {
    if (walletAddress.isEmpty) return const [];
    try {
      final resp = await BackendApiService().getUserAchievements(walletAddress);
      final definitionsById = <String, achievement_svc.AchievementDefinition>{
        for (final def
            in achievement_svc.AchievementService.achievementDefinitions.values)
          def.id: def,
      };
      final progressEntries = <String, AchievementProgress>{};

      void addOrUpdate(Map<String, dynamic>? item,
          {bool forceCompleted = false}) {
        if (item == null) return;
        final idRaw =
            item['achievementId'] ?? item['achievement_id'] ?? item['id'];
        if (idRaw == null) return;
        final id = idRaw.toString();
        if (id.isEmpty) return;

        final def = definitionsById[id];
        final requiredProgress = (def?.requiredCount ?? 1).clamp(1, 1 << 30);
        final progressValue = _parseInt(
          item['currentProgress'] ??
              item['current_progress'] ??
              item['progress'],
        ).clamp(0, requiredProgress);
        final completedFlag = forceCompleted ||
            item['isCompleted'] == true ||
            item['is_completed'] == true ||
            (item['status']?.toString().toLowerCase() == 'completed');
        final currentProgress = completedFlag
            ? requiredProgress
            : (progressValue == 0 ? 0 : progressValue);

        DateTime? completedAt;
        final completedRaw = item['completedAt'] ??
            item['completed_at'] ??
            item['unlockedAt'] ??
            item['unlocked_at'];
        if (completedRaw != null) {
          try {
            completedAt = DateTime.parse(completedRaw.toString());
          } catch (_) {}
        }

        progressEntries[id] = AchievementProgress(
          achievementId: id,
          currentProgress: completedFlag && currentProgress < requiredProgress
              ? requiredProgress
              : currentProgress,
          isCompleted: completedFlag,
          completedDate: completedAt,
        );
      }

      final progressList = resp['progress'] as List<dynamic>?;
      if (progressList != null) {
        for (final entry in progressList) {
          if (entry is Map<String, dynamic>) {
            addOrUpdate(entry);
          }
        }
      }

      final unlockedList = resp['unlocked'] as List<dynamic>?;
      if (unlockedList != null) {
        for (final entry in unlockedList) {
          if (entry is Map<String, dynamic>) {
            addOrUpdate(entry, forceCompleted: true);
          } else if (entry is String) {
            addOrUpdate({'achievementId': entry}, forceCompleted: true);
          }
        }
      }

      return progressEntries.values.toList();
    } catch (e) {
      AppConfig.debugPrint('UserService.loadAchievementProgress: $e');
      return const [];
    }
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    final parsed = int.tryParse(value.toString());
    return parsed ?? 0;
  }

  /// Fetch authoritative follower/following/posts stats for a wallet and
  /// update the internal cache. This is intended to be called in the
  /// background (non-blocking) to avoid slowing down profile fetch paths.
  static Future<void> fetchAndUpdateUserStats(String walletAddress) async {
    if (walletAddress.isEmpty) return;
    try {
      final snapshot = await StatsApiService().fetchSnapshot(
        entityType: 'user',
        entityId: walletAddress,
        metrics: const ['followers', 'following', 'posts'],
        scope: 'public',
      );
      final followers = snapshot.counters['followers'] ?? 0;
      final following = snapshot.counters['following'] ?? 0;
      final posts = snapshot.counters['posts'] ?? 0;

      final existing = _cache[walletAddress];
      final isFollowing = (await getFollowingUsers()).contains(walletAddress);

      final updated = existing != null
          ? existing.copyWith(
              followersCount: followers,
              followingCount: following,
              postsCount: posts,
              isFollowing: isFollowing,
            )
          : User(
              id: walletAddress,
              name: 'Unknown artist',
              username: '',
              bio: '',
              followersCount: followers,
              followingCount: following,
              postsCount: posts,
              isFollowing: isFollowing,
              isVerified: false,
              isArtist: false,
              isInstitution: false,
              joinedDate: 'Joined recently',
              achievementProgress: [],
              profileImageUrl: null,
            );

      setUsersInCache([updated]);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserService.fetchAndUpdateUserStats: $e');
      }
    }
  }

  /// Fetches multiple users by wallet addresses. Returns a list of User objects (skips missing profiles).
  ///
  /// Parameters:
  /// - `forceRefresh`: when true, try the backend batch endpoint first for freshest data.
  /// - `batchFirstThreshold`: if the number of wallets >= this threshold, call the batch endpoint first.
  static Future<List<User>> getUsersByWallets(List<String> wallets,
      {bool forceRefresh = false, int batchFirstThreshold = 4}) async {
    final results = <User>[];
    final clean = wallets.where((w) => w.isNotEmpty).toSet().toList();
    if (clean.isEmpty) return results;
    // If caller asked for fresh data (forceRefresh) or there are many wallets,
    // attempt the backend batch endpoint first to get the freshest data.
    if (forceRefresh || wallets.length >= batchFirstThreshold) {
      try {
        final resp = await BackendApiService().getProfilesBatch(wallets);
        final found = <String, User>{};
        if (resp['success'] == true && resp['data'] != null) {
          final list = resp['data'] as List<dynamic>;
          for (final p in list) {
            try {
              final profile = p as Map<String, dynamic>;
              final wallet =
                  (profile['walletAddress'] ?? profile['id'] ?? '').toString();
              if (wallet.isEmpty) continue;
              final user = User(
                id: wallet,
                name: ((profile['displayName'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty &&
                        !WalletUtils.looksLikeWallet(
                            (profile['displayName'] ?? '').toString().trim()))
                    ? (profile['displayName'] ?? '').toString().trim()
                    : (((profile['username'] ?? '')
                                .toString()
                                .replaceAll('@', '')
                                .trim()
                                .isNotEmpty &&
                            !WalletUtils.looksLikeWallet(
                                (profile['username'] ?? '')
                                    .toString()
                                    .replaceAll('@', '')
                                    .trim()))
                        ? (profile['username'] ?? '')
                            .toString()
                            .replaceAll('@', '')
                            .trim()
                        : 'Unknown artist'),
                username: (!WalletUtils.looksLikeWallet(
                        (profile['username'] ?? '')
                            .toString()
                            .replaceAll('@', '')
                            .trim()))
                    ? (profile['username'] ?? '')
                        .toString()
                        .replaceAll('@', '')
                        .trim()
                    : '',
                bio: profile['bio'] ?? '',
                followersCount: 0,
                followingCount: 0,
                postsCount: 0,
                isFollowing: false,
                isVerified: profile['isVerified'] ?? false,
                isArtist:
                    profile['isArtist'] == true || profile['is_artist'] == true,
                isInstitution: profile['isInstitution'] == true ||
                    profile['is_institution'] == true,
                joinedDate: profile['createdAt'] != null
                    ? 'Joined ${DateTime.parse(profile['createdAt']).month}/${DateTime.parse(profile['createdAt']).year}'
                    : 'Joined recently',
                achievementProgress: [],
                profileImageUrl:
                    _extractAvatarCandidate(profile['avatar'], wallet),
                coverImageUrl: _extractMediaCandidate(
                  profile['coverImage'] ??
                      profile['coverImageUrl'] ??
                      profile['cover_image_url'] ??
                      profile['cover_image'] ??
                      profile['coverUrl'] ??
                      profile['cover_url'] ??
                      profile['cover'],
                ),
              );
              found[wallet] = user;
              _legacyCacheMissingCoverKey.remove(wallet);
            } catch (e, st) {
              if (kDebugMode) {
                try {
                  debugPrint(
                      'UserService.getUsersByWallets (batch): failed to parse profile entry: $e');
                } catch (_) {}
                debugPrint(
                    'UserService.getUsersByWallets (batch): stack trace: $st');
              }
            }
          }
        }

        // Populate internal cache with found users
        if (found.isNotEmpty) {
          setUsersInCacheAuthoritative(found.values.toList());
        }

        // Build ordered results using found when present, otherwise cached or fallback
        for (final w in wallets) {
          if (w.isEmpty) continue;
          if (found.containsKey(w)) {
            results.add(found[w]!);
          } else if (_cache.containsKey(w)) {
            results.add(_cache[w]!);
          } else {
            results.add(User(
              id: w,
              name: 'Unknown artist',
              username: '',
              bio: '',
              followersCount: 0,
              followingCount: 0,
              postsCount: 0,
              isFollowing: false,
              isVerified: false,
              isArtist: false,
              isInstitution: false,
              joinedDate: 'Joined recently',
              achievementProgress: [],
              profileImageUrl: null,
            ));
          }
        }
        return results;
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              'UserService.getUsersByWallets: batch-first attempt failed: $e');
        }
        // fall through to normal cached-first behavior
      }
    }

    // First, return any cached users synchronously (respecting TTL)
    final missing = <String>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    final Map<String, User> orderedCache = {};
    for (final w in wallets) {
      if (w.isEmpty) continue;
      try {
        if (_cache.containsKey(w)) {
          final ts = _cacheTimestamps[w] ?? 0;
          if (ts > 0 && now - ts <= _ttlMillis) {
            orderedCache[w] = _cache[w]!;
            continue;
          } else {
            // expired
            _cache.remove(w);
            _cacheTimestamps.remove(w);
          }
        }
      } catch (_) {}
      missing.add(w);
    }

    // If nothing is missing, build ordered results from cache and return immediately
    if (missing.isEmpty) {
      for (final w in wallets) {
        if (w.isEmpty) continue;
        results.add(orderedCache[w]!);
      }
    }

    // For missing wallets, call batch endpoint and merge with cached entries
    try {
      final resp = await BackendApiService().getProfilesBatch(missing);
      final found = <String, User>{};
      if (resp['success'] == true && resp['data'] != null) {
        final list = resp['data'] as List<dynamic>;
        for (final p in list) {
          try {
            final profile = p as Map<String, dynamic>;
            final wallet =
                (profile['walletAddress'] ?? profile['id'] ?? '').toString();
            if (wallet.isEmpty) continue;
            final user = User(
              id: wallet,
              name: ((profile['displayName'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty &&
                      !WalletUtils.looksLikeWallet(
                          (profile['displayName'] ?? '').toString().trim()))
                  ? (profile['displayName'] ?? '').toString().trim()
                  : (((profile['username'] ?? '')
                              .toString()
                              .replaceAll('@', '')
                              .trim()
                              .isNotEmpty &&
                          !WalletUtils.looksLikeWallet(
                              (profile['username'] ?? '')
                                  .toString()
                                  .replaceAll('@', '')
                                  .trim()))
                      ? (profile['username'] ?? '')
                          .toString()
                          .replaceAll('@', '')
                          .trim()
                      : 'Unknown artist'),
              username: (!WalletUtils.looksLikeWallet(
                      (profile['username'] ?? '')
                          .toString()
                          .replaceAll('@', '')
                          .trim()))
                  ? (profile['username'] ?? '')
                      .toString()
                      .replaceAll('@', '')
                      .trim()
                  : '',
              bio: profile['bio'] ?? '',
              followersCount: 0,
              followingCount: 0,
              postsCount: 0,
              isFollowing: false,
              isVerified: profile['isVerified'] ?? false,
              isArtist:
                  profile['isArtist'] == true || profile['is_artist'] == true,
              isInstitution: profile['isInstitution'] == true ||
                  profile['is_institution'] == true,
              joinedDate: profile['createdAt'] != null
                  ? 'Joined ${DateTime.parse(profile['createdAt']).month}/${DateTime.parse(profile['createdAt']).year}'
                  : 'Joined recently',
              achievementProgress: [],
              profileImageUrl:
                  _extractAvatarCandidate(profile['avatar'], wallet),
              coverImageUrl: _extractMediaCandidate(
                profile['coverImage'] ??
                    profile['coverImageUrl'] ??
                    profile['cover_image_url'] ??
                    profile['cover_image'] ??
                    profile['coverUrl'] ??
                    profile['cover_url'] ??
                    profile['cover'],
              ),
            );
            found[wallet] = user;
            _legacyCacheMissingCoverKey.remove(wallet);
          } catch (e, st) {
            if (kDebugMode) {
              try {
                debugPrint(
                    'UserService.getUsersByWallets (batch fallback): failed to parse profile entry: $e');
              } catch (_) {}
              debugPrint(
                  'UserService.getUsersByWallets (batch fallback): stack trace: $st');
            }
          }
        }
      }

      // Populate internal cache with found users
      if (found.isNotEmpty) setUsersInCacheAuthoritative(found.values.toList());

      // Build ordered results using cached values when present, found when present, otherwise minimal fallback
      for (final w in wallets) {
        if (w.isEmpty) continue;
        if (orderedCache.containsKey(w)) {
          results.add(orderedCache[w]!);
        } else if (found.containsKey(w)) {
          results.add(found[w]!);
        } else {
          results.add(User(
            id: w,
            name: 'Unknown artist',
            username: '',
            bio: '',
            followersCount: 0,
            followingCount: 0,
            postsCount: 0,
            isFollowing: false,
            isVerified: false,
            isArtist: false,
            isInstitution: false,
            joinedDate: 'Joined recently',
            achievementProgress: [],
            profileImageUrl: null,
          ));
        }
      }
      return results;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserService.getUsersByWallets: batch call failed: $e');
      }
    }

    // If batch failed, attempt per-wallet fallback (this will also populate cache via getUserById)
    for (final w in wallets) {
      if (w.isEmpty) continue;
      try {
        final u = await getUserById(w);
        if (u != null) {
          results.add(u);
        } else {
          results.add(User(
            id: w,
            name: 'Unknown artist',
            username: '',
            bio: '',
            followersCount: 0,
            followingCount: 0,
            postsCount: 0,
            isFollowing: false,
            isVerified: false,
            joinedDate: 'Joined recently',
            achievementProgress: [],
            profileImageUrl: null,
          ));
        }
      } catch (_) {
        results.add(User(
          id: w,
          name: 'Unknown artist',
          username: '',
          bio: '',
          followersCount: 0,
          followingCount: 0,
          postsCount: 0,
          isFollowing: false,
          isVerified: false,
          isArtist: false,
          joinedDate: 'Joined recently',
          achievementProgress: [],
          profileImageUrl: null,
        ));
      }
    }
    return results;
  }
}
