import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/achievements.dart';
import 'backend_api_service.dart';
import '../utils/wallet_utils.dart';

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
  // NOTE: Removed prior cacheVersion notifier. UI components should call
  // UserService.getUsersByWallets/getUserById for explicit fetches and not rely on
  // an implicit cache notification system.

  // Sample users data
  static final List<User> _sampleUsers = [
    const User(
      id: 'maya_3d',
      name: 'Maya Digital',
      username: '@maya_3d',
      bio: 'AR artist exploring the intersection of digital and physical reality. Creating immersive experiences that transform everyday spaces.',
      followersCount: 1250,
      followingCount: 189,
      postsCount: 42,
      isFollowing: false,
      isVerified: true,
      joinedDate: 'Joined March 2024',
      achievementProgress: [
        AchievementProgress(achievementId: 'first_ar_visit', currentProgress: 1, isCompleted: true),
        AchievementProgress(achievementId: 'ar_collector', currentProgress: 10, isCompleted: true),
        AchievementProgress(achievementId: 'community_member', currentProgress: 1, isCompleted: true),
        AchievementProgress(achievementId: 'early_adopter', currentProgress: 1, isCompleted: true),
      ],
    ),
    const User(
      id: 'alex_nft',
      name: 'Alex Creator',
      username: '@alex_nft',
      bio: 'NFT creator and blockchain enthusiast. Building the future of digital ownership through art and technology.',
      followersCount: 892,
      followingCount: 341,
      postsCount: 67,
      isFollowing: false,
      isVerified: false,
      joinedDate: 'Joined January 2024',
      achievementProgress: [
        AchievementProgress(achievementId: 'first_ar_visit', currentProgress: 1, isCompleted: true),
        AchievementProgress(achievementId: 'supporter', currentProgress: 1, isCompleted: true),
        AchievementProgress(achievementId: 'first_favorite', currentProgress: 1, isCompleted: true),
      ],
    ),
    const User(
      id: 'sam_ar',
      name: 'Sam Artist',
      username: '@sam_ar',
      bio: 'Interactive AR sculptor. Passionate about collaborative art that responds to viewer interaction. Let\'s build the future together! 🚀',
      followersCount: 2150,
      followingCount: 203,
      postsCount: 28,
      isFollowing: false,
      isVerified: true,
      joinedDate: 'Joined February 2024',
      achievementProgress: [
        AchievementProgress(achievementId: 'first_ar_visit', currentProgress: 1, isCompleted: true),
        AchievementProgress(achievementId: 'ar_collector', currentProgress: 8, isCompleted: false),
        AchievementProgress(achievementId: 'social_butterfly', currentProgress: 20, isCompleted: true),
        AchievementProgress(achievementId: 'patron', currentProgress: 5, isCompleted: false),
      ],
    ),
    const User(
      id: 'luna_viz',
      name: 'Luna Vision',
      username: '@luna_viz',
      bio: 'Exploring the infinite possibilities at the intersection of blockchain and creativity. Every pixel tells a story.',
      followersCount: 743,
      followingCount: 156,
      postsCount: 91,
      isFollowing: false,
      isVerified: false,
      joinedDate: 'Joined April 2024',
      achievementProgress: [
        AchievementProgress(achievementId: 'first_ar_visit', currentProgress: 1, isCompleted: true),
        AchievementProgress(achievementId: 'art_critic', currentProgress: 7, isCompleted: false),
        AchievementProgress(achievementId: 'gallery_explorer', currentProgress: 3, isCompleted: false),
      ],
    ),
  ];

  static Future<User?> getUserById(String userId, {bool forceRefresh = false}) async {
    try {
      // Consult cache first (unless caller requests fresh data)
      if (!forceRefresh) {
        if (userId.isNotEmpty && _cache.containsKey(userId)) {
          // Check TTL
          try {
            final ts = _cacheTimestamps[userId] ?? 0;
            if (ts > 0 && DateTime.now().millisecondsSinceEpoch - ts > _ttlMillis) {
              // expired
              _cache.remove(userId);
              _cacheTimestamps.remove(userId);
            } else {
              return _cache[userId];
            }
          } catch (_) {
            return _cache[userId];
          }
        }
      }
    } catch (_) {}
    try {
      // Fetch profile from backend using wallet address (force or cache miss)
      final profile = await BackendApiService().getProfileByWallet(userId);
      // Log (briefly) the profile payload for diagnostics if it has unexpected shapes
      try {
        debugPrint('UserService.getUserById: profile keys = ${profile.keys}');
      } catch (_) {}

      final followingList = await getFollowingUsers();
      final isFollowing = followingList.contains(userId);

      // Convert backend profile to User model
      // Safely compute defaults, avoid substring errors when wallet length is short
      final safeId = userId.toString();
      String shortWallet() => safeId.length > 8 ? safeId.substring(0, 8) : safeId;
      String rawUsername() => (profile['username'] ?? '').toString();
      final user = User(
        id: (profile['walletAddress'] ?? userId).toString(),
        name: profile['displayName']?.toString() ?? (rawUsername().isNotEmpty ? rawUsername() : 'Anonymous'),
        username: '@${rawUsername().isNotEmpty ? rawUsername() : shortWallet()}',
        bio: profile['bio']?.toString() ?? '',
        followersCount: 0, // TODO: Get from backend followers API
        followingCount: 0, // TODO: Get from backend following API
        postsCount: 0, // TODO: Get from backend posts count
        isFollowing: isFollowing,
        isVerified: profile['isVerified'] ?? false,
        joinedDate: profile['createdAt'] != null 
            ? 'Joined ${DateTime.parse(profile['createdAt']).month}/${DateTime.parse(profile['createdAt']).year}'
            : 'Joined recently',
        achievementProgress: [], // TODO: Load achievements from backend
        profileImageUrl: _extractAvatarCandidate(profile['avatar'], userId),
      );
      try { debugPrint('UserService.getUserById: built user: id=${user.id}, username=${user.username}, avatar=${user.profileImageUrl}'); } catch (_) {}
      // populate cache & timestamp
      try {
        if (user.id.isNotEmpty) {
          // Use the central cache setter to remain consistent and avoid direct cacheVersion bumps
          setUsersInCache([user]);
        }
      } catch (_) {}
      return user;
    } catch (e) {
      debugPrint('Error loading user profile for $userId: $e');
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
        if (candidate['url'] != null && candidate['url'].toString().isNotEmpty) url = candidate['url'].toString();
        else if (candidate['httpUrl'] != null && candidate['httpUrl'].toString().isNotEmpty) url = candidate['httpUrl'].toString();
        else if (candidate['ipfsUrl'] != null && candidate['ipfsUrl'].toString().isNotEmpty) url = candidate['ipfsUrl'].toString();
        else if (candidate['path'] != null && candidate['path'].toString().isNotEmpty) url = candidate['path'].toString();
        else url = candidate.toString();
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

  /// Populate UserService internal cache with a list of users
  // By default, do not attempt to perform global cache-based UI notifications; callers should
  // explicitly trigger UI updates (e.g., call provider refresh methods) if they want to
  // reflect cache changes. The `notify` flag is kept for API compatibility but does
  // not perform any implicit global notification.
  static void setUsersInCache(List<User> users) {
    try {
      for (final u in users) {
        if (u.id.isNotEmpty) _cache[u.id] = u;
        try {
          _cacheTimestamps[u.id] = DateTime.now().millisecondsSinceEpoch;
        } catch (_) {}
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
        final sorted = entries..sort((a, b) => (_cacheTimestamps[a] ?? 0).compareTo(_cacheTimestamps[b] ?? 0));
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
            'joinedDate': u.joinedDate,
            'profileImageUrl': u.profileImageUrl,
            'cachedAt': _cacheTimestamps[k] ?? DateTime.now().millisecondsSinceEpoch,
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
            'joinedDate': u.joinedDate,
            'profileImageUrl': u.profileImageUrl,
            'cachedAt': _cacheTimestamps[k] ?? DateTime.now().millisecondsSinceEpoch,
          };
        }
      }
      await prefs.setString(_cachePrefsKey, json.encode(map));
    } catch (e) {
      debugPrint('UserService._persistCache failed: $e');
    }
  }

  /// Initialize persistent cache into memory. Call once at app startup.
  static Future<void> initialize({int maxEntries = 500, Duration ttl = const Duration(hours: 24)}) async {
    try {
      _maxEntries = maxEntries;
      _ttlMillis = ttl.inMilliseconds;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachePrefsKey) ?? '{}';
      final Map<String, dynamic> map = json.decode(raw) as Map<String, dynamic>;
      final now = DateTime.now().millisecondsSinceEpoch;
      final entries = <String, User>{};
      final timestamps = <String, int>{};
      for (final k in map.keys) {
        try {
          final v = map[k] as Map<String, dynamic>;
          final cachedAt = (v['cachedAt'] is int) ? v['cachedAt'] as int : int.tryParse((v['cachedAt'] ?? '').toString()) ?? 0;
          if (cachedAt == 0) continue;
          if (now - cachedAt > _ttlMillis) continue; // expired
          final user = User(
            id: v['id']?.toString() ?? k,
            name: v['name']?.toString() ?? k,
            username: v['username']?.toString() ?? '@${k.substring(0, k.length > 8 ? 8 : k.length)}',
            bio: v['bio']?.toString() ?? '',
            followersCount: (v['followersCount'] is int) ? v['followersCount'] as int : int.tryParse((v['followersCount'] ?? '0').toString()) ?? 0,
            followingCount: (v['followingCount'] is int) ? v['followingCount'] as int : int.tryParse((v['followingCount'] ?? '0').toString()) ?? 0,
            postsCount: (v['postsCount'] is int) ? v['postsCount'] as int : int.tryParse((v['postsCount'] ?? '0').toString()) ?? 0,
            isFollowing: (v['isFollowing'] == true),
            isVerified: (v['isVerified'] == true),
            joinedDate: v['joinedDate']?.toString() ?? 'Joined recently',
            achievementProgress: [],
            profileImageUrl: v['profileImageUrl']?.toString(),
          );
          entries[k] = user;
          timestamps[k] = cachedAt;
        } catch (_) {}
      }
      // If entries exceed max, evict oldest
      if (entries.length > _maxEntries) {
        final sorted = timestamps.keys.toList()..sort((a, b) => (timestamps[a] ?? 0).compareTo(timestamps[b] ?? 0));
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
        try { await _persistCache(); } catch (_) {}
      } catch (_) {}
    } catch (e) {
      debugPrint('UserService.initialize failed: $e');
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachePrefsKey);
    } catch (e) {
      debugPrint('UserService.clearCache failed: $e');
    }
  }

  static Future<User?> getUserByUsername(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return null;
    final lookup = trimmed.replaceFirst(RegExp(r'^@+'), '').toLowerCase();

    // Check in-memory cache first for instant hits
    try {
      for (final entry in _cache.values) {
        final cachedUsername = entry.username.replaceFirst(RegExp(r'^@+'), '').toLowerCase();
        if (cachedUsername == lookup) {
          return entry;
        }
      }
    } catch (_) {}

    try {
      final profile = await BackendApiService().findProfileByUsername(lookup);
      if (profile == null) return null;

      final wallet = WalletUtils.normalize((profile['walletAddress'] ?? profile['wallet_address'] ?? profile['wallet'])?.toString());
      if (wallet.isEmpty) return null;

      final followingList = await getFollowingUsers();
      final stats = profile['stats'];
      int followers = 0;
      int following = 0;
      if (stats is Map<String, dynamic>) {
        followers = int.tryParse((stats['followers'] ?? stats['followersCount'] ?? 0).toString()) ?? 0;
        following = int.tryParse((stats['following'] ?? stats['followingCount'] ?? 0).toString()) ?? 0;
      }

      String joinedDate = 'Joined recently';
      final createdAtRaw = profile['createdAt'] ?? profile['created_at'];
      if (createdAtRaw != null) {
        try {
          final dt = DateTime.parse(createdAtRaw.toString());
          joinedDate = 'Joined ${dt.month}/${dt.year}';
        } catch (_) {}
      }

      final resolvedUsername = (profile['username'] ?? lookup).toString().replaceAll('@', '');
      final avatarCandidate = profile['avatar'] ?? profile['avatar_url'] ?? profile['avatarUrl'];

      final user = User(
        id: wallet,
        name: profile['displayName']?.toString() ?? profile['username']?.toString() ?? wallet,
        username: '@$resolvedUsername',
        bio: profile['bio']?.toString() ?? '',
        followersCount: followers,
        followingCount: following,
        postsCount: 0,
        isFollowing: followingList.contains(wallet),
        isVerified: profile['isVerified'] == true,
        joinedDate: joinedDate,
        achievementProgress: const [],
        profileImageUrl: _extractAvatarCandidate(avatarCandidate, wallet),
      );

      setUsersInCache([user]);
      return user;
    } catch (e) {
      debugPrint('UserService.getUserByUsername failed: $e');
      return null;
    }
  }

  static Future<List<String>> getFollowingUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final followingJson = prefs.getString(_followingKey) ?? '[]';
    return List<String>.from(json.decode(followingJson));
  }

  static Future<void> followUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final followingList = await getFollowingUsers();
    
    if (!followingList.contains(userId)) {
      followingList.add(userId);
      await prefs.setString(_followingKey, json.encode(followingList));
    }
  }

  static Future<void> unfollowUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final followingList = await getFollowingUsers();
    
    followingList.remove(userId);
    await prefs.setString(_followingKey, json.encode(followingList));
  }

  static Future<bool> toggleFollow(String userId) async {
    final followingList = await getFollowingUsers();
    final isCurrentlyFollowing = followingList.contains(userId);
    
    if (isCurrentlyFollowing) {
      await unfollowUser(userId);
      return false;
    } else {
      await followUser(userId);
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
    final sanitized = normalized.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '').toLowerCase();
    final token = sanitized.isNotEmpty ? sanitized : normalized.hashCode.toRadixString(16);
    return '$_placeholderAvatarScheme$token';
  }

  /// Returns a safe avatar URL for a provided seed that may be a wallet, username, or other id.
  /// If the input looks like a non-wallet (UUID, contains '-' or spaces, or contains '@'),
  /// this returns the anonymous identicon URL to avoid producing invalid upstream requests.
  static String safeAvatarUrl(dynamic seedOrWallet) {
    final s = (seedOrWallet ?? '').toString();
    if (s.isEmpty) return defaultAvatarUrl('');
    // UUID-like or contains dashes/spaces -> treat as non-wallet
    final uuidLike = RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}');
    if (uuidLike.hasMatch(s) || s.contains('-') || s.contains(' ') || s.contains('@')) {
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

  /// Fetches multiple users by wallet addresses. Returns a list of User objects (skips missing profiles).
  ///
  /// Parameters:
  /// - `forceRefresh`: when true, try the backend batch endpoint first for freshest data.
  /// - `batchFirstThreshold`: if the number of wallets >= this threshold, call the batch endpoint first.
  static Future<List<User>> getUsersByWallets(List<String> wallets, {bool forceRefresh = false, int batchFirstThreshold = 4}) async {
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
              final wallet = (profile['walletAddress'] ?? profile['id'] ?? '').toString();
              if (wallet.isEmpty) continue;
              final user = User(
                id: wallet,
                name: profile['displayName'] ?? profile['username'] ?? wallet,
                username: '@${(profile['username'] ?? wallet).toString().replaceAll('@', '')}',
                bio: profile['bio'] ?? '',
                followersCount: 0,
                followingCount: 0,
                postsCount: 0,
                isFollowing: false,
                isVerified: profile['isVerified'] ?? false,
                joinedDate: profile['createdAt'] != null ? 'Joined ${DateTime.parse(profile['createdAt']).month}/${DateTime.parse(profile['createdAt']).year}' : 'Joined recently',
                achievementProgress: [],
                profileImageUrl: _extractAvatarCandidate(profile['avatar'], wallet),
              );
              found[wallet] = user;
            } catch (e, st) {
              try { debugPrint('UserService.getUsersByWallets (batch): failed to parse profile entry: $e - entry: $p'); } catch(_){}
              debugPrint('Stack trace: $st');
            }
          }
        }

        // Populate internal cache with found users
        if (found.isNotEmpty) setUsersInCache(found.values.toList());

        // Build ordered results using found when present, otherwise cached or fallback
        for (final w in wallets) {
          if (w.isEmpty) continue;
          if (found.containsKey(w)) {
            results.add(found[w]!);
          } else if (_cache.containsKey(w)) results.add(_cache[w]!);
          else {
            results.add(User(
              id: w,
              name: w,
              username: '@${w.substring(0, w.length > 8 ? 8 : w.length)}',
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
        }
        return results;
      } catch (e) {
        debugPrint('UserService.getUsersByWallets batch-first attempt failed: $e');
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
            final wallet = (profile['walletAddress'] ?? profile['id'] ?? '').toString();
            if (wallet.isEmpty) continue;
              final user = User(
              id: wallet,
              name: profile['displayName'] ?? profile['username'] ?? wallet,
              username: '@${(profile['username'] ?? wallet).toString().replaceAll('@', '')}',
              bio: profile['bio'] ?? '',
              followersCount: 0,
              followingCount: 0,
              postsCount: 0,
              isFollowing: false,
              isVerified: profile['isVerified'] ?? false,
              joinedDate: profile['createdAt'] != null ? 'Joined ${DateTime.parse(profile['createdAt']).month}/${DateTime.parse(profile['createdAt']).year}' : 'Joined recently',
              achievementProgress: [],
              profileImageUrl: _extractAvatarCandidate(profile['avatar'], wallet),
            );
            found[wallet] = user;
            } catch (e, st) {
              try { debugPrint('UserService.getUsersByWallets (batch fallback): failed to parse profile entry: $e - entry: $p'); } catch(_){}
              debugPrint('Stack trace: $st');
          }
        }
      }

      // Populate internal cache with found users
      if (found.isNotEmpty) setUsersInCache(found.values.toList());

      // Build ordered results using cached values when present, found when present, otherwise minimal fallback
      for (final w in wallets) {
        if (w.isEmpty) continue;
        if (orderedCache.containsKey(w)) {
          results.add(orderedCache[w]!);
        } else if (found.containsKey(w)) results.add(found[w]!);
        else {
          results.add(User(
            id: w,
            name: w,
            username: '@${w.substring(0, w.length > 8 ? 8 : w.length)}',
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
      }
      return results;
    } catch (e) {
      debugPrint('UserService.getUsersByWallets batch call failed: $e');
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
          name: w,
          username: '@${w.substring(0, w.length > 8 ? 8 : w.length)}',
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
          name: w,
          username: '@${w.substring(0, w.length > 8 ? 8 : w.length)}',
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
    }
    return results;
  }

  /// Update achievement progress for a user
  static Future<void> updateAchievementProgress(String userId, String achievementId, int newProgress) async {
    // In a real app, this would make an API call to update the server
    // For now, this is just an example of how you might handle achievement updates
    debugPrint('Updating achievement $achievementId for user $userId to progress $newProgress');
  }

  /// Increment achievement progress for a user
  static Future<void> incrementAchievementProgress(String userId, String achievementId, {int increment = 1}) async {
    // In a real app, this would make an API call to increment the server-side progress
    debugPrint('Incrementing achievement $achievementId for user $userId by $increment');
  }

  /// Trigger achievement events (call when user performs actions)
  static Future<void> triggerAchievementEvent(String userId, String event, {Map<String, dynamic>? data}) async {
    // Example achievement event triggers
    switch (event) {
      case 'ar_view':
        await incrementAchievementProgress(userId, 'first_ar_visit');
        await incrementAchievementProgress(userId, 'ar_collector');
        break;
      case 'gallery_visit':
        await incrementAchievementProgress(userId, 'gallery_explorer');
        break;
      case 'artwork_like':
        await incrementAchievementProgress(userId, 'social_butterfly');
        break;
      case 'review_posted':
        await incrementAchievementProgress(userId, 'art_critic');
        break;
      case 'dao_vote':
        await incrementAchievementProgress(userId, 'community_member');
        break;
      case 'artwork_shared':
        await incrementAchievementProgress(userId, 'social_butterfly');
        break;
      case 'nft_purchase':
        await incrementAchievementProgress(userId, 'supporter');
        break;
    }
  }
}
