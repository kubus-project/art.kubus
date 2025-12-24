import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config.dart';
import '../models/user_profile.dart';
import '../models/user_persona.dart';
import '../services/backend_api_service.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../services/event_bus.dart';
import '../models/dao.dart';
import '../utils/media_url_resolver.dart';

class ProfileProvider extends ChangeNotifier {
  UserProfile? _currentUser;
  final List<UserProfile> _followingUsers = [];
  final List<UserProfile> _followers = [];
  bool _isSignedIn = false;
  bool _isLoading = false;
  String? _error;
  
  // Real data from backend
  int _collectionsCount = 0;
  int _realFollowersCount = 0;
  int _realFollowingCount = 0;
  int _realPostsCount = 0;
  late SharedPreferences _prefs;
  final BackendApiService _apiService = BackendApiService();
  Map<String, dynamic>? _lastUploadDebug;
  ProfilePreferences? _cachedPreferences;

  /// Debug info for last upload attempt (raw server response + extraction + verification)
  Map<String, dynamic>? get lastUploadDebug => _lastUploadDebug;

  // Normalize returned URLs (make absolute if backend returns relative paths or IPFS links)
  String _resolveUrl(String? url) {
    return MediaUrlResolver.resolve(url) ?? '';
  }

  // Convert known SVG avatar providers to raster (PNG) so the app renders images only
  String _convertSvgToRaster(String url) {
    if (url.isEmpty) return url;
    final lower = url.toLowerCase();

    // DiceBear: Use internal proxy instead of direct dicebear URLs for consistent CORS and caching
    if (lower.contains('dicebear') && (lower.contains('/svg') || lower.endsWith('.svg') || lower.contains('format=svg') || lower.contains('type=svg') || lower.contains('/identicon/') || lower.contains('/api/'))) {
      try {
        // Extract seed from known formats:
        // - https://api.dicebear.com/{style}/svg?seed=FOO
        // - https://avatars.dicebear.com/api/{style}/FOO.svg
        String seed = '';
        String style = 'identicon';
        try {
          final uri = Uri.parse(url);
          if (uri.queryParameters.containsKey('seed')) {
            seed = uri.queryParameters['seed']!;
            final pathSegments = uri.pathSegments;
            // styles may be in the first segment (e.g., 9.x/identicon or api/identicon)
            if (pathSegments.isNotEmpty) style = pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'identicon');
          } else {
            // Try to get seed from last path segment without extension
            final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
            seed = last.replaceAll('.svg', '');
            if (uri.pathSegments.length >= 2) style = uri.pathSegments[uri.pathSegments.length - 2];
          }
        } catch (_) {
          // Fallback: take last slash segment
          try {
            final p = url.split('/').last;
            seed = p.split('?').first.replaceAll('.svg', '');
          } catch (e) {
            seed = url;
          }
        }
        final proxy = '/api/avatar/${Uri.encodeComponent(seed)}?style=$style&format=png&raw=true';
        return _resolveUrl(proxy);
      } catch (_) {
        return url;
      }
    }

    // Generic .svg -> .png conversion (best-effort)
    if (lower.endsWith('.svg') || lower.contains('.svg?')) {
      return url.replaceAll(RegExp(r'\.svg', caseSensitive: false), '.png');
    }

    return url;
  }

  // Try to extract a usable URL from various upload response shapes
  String? _extractUrlFromUploadResult(Map<String, dynamic> resultMap) {
    try {
      debugPrint('_extractUrlFromUploadResult: resultMap keys = ${resultMap.keys}');
      
      // Direct normalized field from BackendApiService
      if (resultMap.containsKey('uploadedUrl') && resultMap['uploadedUrl'] != null && resultMap['uploadedUrl'].toString().isNotEmpty) {
        final url = resultMap['uploadedUrl'].toString();
        debugPrint('Found uploadedUrl: $url');
        return url;
      }

      // Common: top-level data.avatar (our backend response)
      if (resultMap.containsKey('data') && resultMap['data'] is Map<String, dynamic>) {
        final data = Map<String, dynamic>.from(resultMap['data'] as Map<String, dynamic>);
        debugPrint('data keys: ${data.keys}');
        
        // Check for avatar field first (our backend returns this)
        if (data.containsKey('avatar') && data['avatar'] != null && (data['avatar'] as String).isNotEmpty) {
          final url = data['avatar'] as String;
          debugPrint('Found data.avatar: $url');
          return url;
        }
        
        if (data.containsKey('url') && (data['url'] as String).isNotEmpty) return data['url'] as String;
        if (data.containsKey('ipfsUrl') && (data['ipfsUrl'] as String).isNotEmpty) return data['ipfsUrl'] as String;
        if (data.containsKey('httpUrl') && (data['httpUrl'] as String).isNotEmpty) return data['httpUrl'] as String;
        if (data.containsKey('fileUrl') && (data['fileUrl'] as String).isNotEmpty) return data['fileUrl'] as String;
        if (data.containsKey('path') && (data['path'] as String).isNotEmpty) return data['path'] as String;
        if (data.containsKey('result') && data['result'] is Map<String, dynamic>) {
          final r = Map<String, dynamic>.from(data['result'] as Map<String, dynamic>);
          if (r.containsKey('url') && (r['url'] as String).isNotEmpty) return r['url'] as String;
        }
        // IPFS cid
        if (data.containsKey('cid') && (data['cid'] as String).isNotEmpty) return 'ipfs://${data['cid']}';
      }

      // Some responses may embed raw body under 'raw'
      if (resultMap.containsKey('raw') && resultMap['raw'] is Map<String, dynamic>) {
        final raw = Map<String, dynamic>.from(resultMap['raw'] as Map<String, dynamic>);
        debugPrint('raw keys: ${raw.keys}');
        if (raw.containsKey('data') && raw['data'] is Map<String, dynamic>) {
          final d = Map<String, dynamic>.from(raw['data'] as Map<String, dynamic>);
          if (d.containsKey('avatar') && (d['avatar'] as String).isNotEmpty) return d['avatar'] as String;
          if (d.containsKey('url') && (d['url'] as String).isNotEmpty) return d['url'] as String;
          if (d.containsKey('cid') && (d['cid'] as String).isNotEmpty) return 'ipfs://${d['cid']}';
        }
        if (raw.containsKey('url') && (raw['url'] as String).isNotEmpty) return raw['url'] as String;
      }

      // Top-level url or path
      if (resultMap.containsKey('url') && (resultMap['url'] as String).isNotEmpty) return resultMap['url'] as String;
      if (resultMap.containsKey('path') && (resultMap['path'] as String).isNotEmpty) return resultMap['path'] as String;

      return null;
    } catch (e) {
      debugPrint('Error extracting upload URL: $e');
      return null;
    }
  }

  // Verify that a URL is reachable and points to an image (HEAD then GET fallback)
  Future<bool> _verifyImageUrl(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return false;

      // Try HEAD first
      try {
        final headResp = await http.head(uri).timeout(const Duration(seconds: 5));
        if (headResp.statusCode == 200) {
          final ct = headResp.headers['content-type'] ?? '';
          if (ct.toLowerCase().startsWith('image/')) return true;
          // Some hosts don't set content-type correctly; if content-length present and >0, accept
          final cl = headResp.headers['content-length'];
          if (cl != null && int.tryParse(cl) != null && int.parse(cl) > 0) return true;
        }
      } catch (_) {
        // ignore and fallback to GET
      }

      // Fallback to GET with small timeout
      final getResp = await http.get(uri).timeout(const Duration(seconds: 7));
      if (getResp.statusCode == 200) {
        final ct = getResp.headers['content-type'] ?? '';
        if (ct.toLowerCase().startsWith('image/')) return true;
        if (getResp.bodyBytes.isNotEmpty) return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error verifying image URL $url: $e');
      return false;
    }
  }
  
  UserProfile? get currentUser => _currentUser;
  UserProfile? get profile => _currentUser; // Alias for compatibility
  List<UserProfile> get followingUsers => _followingUsers;
  List<UserProfile> get followers => _followers;
  bool get isSignedIn => _isSignedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasProfile => _currentUser != null;
  ProfilePreferences get preferences => _currentUser?.preferences ?? _cachedPreferences ?? _cachedPreferencesFromPrefs();

  String? get _currentWalletAddress {
    final wallet = _currentUser?.walletAddress;
    if (wallet != null && wallet.isNotEmpty) return wallet;
    final stored = _prefs.getString(PreferenceKeys.walletAddress) ?? _prefs.getString('wallet_address');
    if (stored != null && stored.isNotEmpty) return stored;
    return null;
  }

  String _personaKeyForWallet(String walletAddress) => '${PreferenceKeys.userPersona}_$walletAddress';
  String _personaOnboardedKeyForWallet(String walletAddress) => '${PreferenceKeys.userPersonaOnboardedV1}_$walletAddress';

  UserPersona? get userPersona {
    final raw = preferences.persona;
    final parsed = UserPersonaX.tryParse(raw);
    if (parsed != null) return parsed;

    final wallet = _currentWalletAddress;
    if (wallet == null) return null;
    final persisted = _prefs.getString(_personaKeyForWallet(wallet));
    return UserPersonaX.tryParse(persisted);
  }

  bool get hasCompletedPersonaOnboarding {
    final wallet = _currentWalletAddress;
    if (wallet == null) return false;
    return _prefs.getBool(_personaOnboardedKeyForWallet(wallet)) ?? false;
  }

  /// Whether we should prompt the user to choose a UX persona.
  ///
  /// This is shown once per wallet/profile and is not an access control gate.
  bool get needsPersonaOnboarding {
    final wallet = _currentWalletAddress;
    if (wallet == null || wallet.isEmpty) return false;
    return userPersona == null;
  }
  
  // Dynamic getters for profile stats (from backend)
  int get artworksCount => _currentUser?.stats?.artworksDiscovered ?? 0;
    
  int get collectionsCount => _collectionsCount;
    
  int get followersCount => _realFollowersCount;
    
  int get followingCount => _realFollowingCount;
  
  int get postsCount => _realPostsCount;
    
  String get formattedFollowersCount => _formatCount(followersCount);
  String get formattedFollowingCount => _formatCount(followingCount);
  String get formattedArtworksCount => _formatCount(artworksCount);
  String get formattedCollectionsCount => _formatCount(collectionsCount);
  String get formattedPostsCount => _formatCount(postsCount);
  
  void setCurrentUser(UserProfile user) {
    _currentUser = user;
    _isSignedIn = true;
    notifyListeners();
    try { EventBus().emitProfileUpdated(_currentUser); } catch (_) {}
  }

  Future<void> setUserPersona(UserPersona persona, {bool persistToBackend = true}) async {
    final wallet = _currentWalletAddress;
    if (wallet == null || wallet.isEmpty) return;

    final nextValue = persona.storageValue;
    try {
      await _prefs.setString(_personaKeyForWallet(wallet), nextValue);
      await _prefs.setBool(_personaOnboardedKeyForWallet(wallet), true);
    } catch (_) {}

    final existing = _currentUser?.preferences ?? _cachedPreferencesFromPrefs();
    final nextPrefs = existing.copyWith(persona: nextValue);
    _cachedPreferences = nextPrefs;
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(preferences: nextPrefs);
      notifyListeners();
      try { EventBus().emitProfileUpdated(_currentUser); } catch (_) {}
    }

    await _persistPreferences(nextPrefs);

    if (!persistToBackend) return;
    try {
      await saveProfile(walletAddress: wallet, preferences: nextPrefs);
    } catch (_) {
      // Keep local preference even if backend update fails.
    }
  }

  void setRoleFlags({bool? isArtist, bool? isInstitution}) {
    if (_currentUser == null) return;
    var updated = _currentUser!;
    var changed = false;
    if (isArtist != null && isArtist != updated.isArtist) {
      updated = updated.copyWith(isArtist: isArtist);
      changed = true;
    }
    if (isInstitution != null && isInstitution != updated.isInstitution) {
      updated = updated.copyWith(isInstitution: isInstitution);
      changed = true;
    }
    if (!changed) return;
    _currentUser = updated;
    notifyListeners();
    try { EventBus().emitProfileUpdated(_currentUser); } catch (_) {}
  }
  
  // Initialize SharedPreferences and settings
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Try to load existing profile
    final walletAddress = _prefs.getString('wallet_address');
    // Initialize persisted user cache for returning users only
    if (walletAddress != null && walletAddress.isNotEmpty) {
      try { await UserService.initialize(); } catch (_) {}
    }
    if (walletAddress != null && walletAddress.isNotEmpty) {
      await loadProfile(walletAddress);
      // Load additional stats from backend
      await _loadBackendStats(walletAddress);
    }
    
    notifyListeners();
  }
  
  /// Load additional stats from backend (collections, followers, following)
  Future<void> _loadBackendStats(String walletAddress) async {
    try {
      // Load collections count
      final collections = await _apiService.getCollections(
        walletAddress: walletAddress,
        page: 1,
        limit: 1, // Just need count
      );
      _collectionsCount = collections.length;
      
      // Load followers
      try {
        final followers = await _apiService.getFollowers(
          walletAddress: walletAddress,
          page: 1,
          limit: 100,
        );
        _followers.clear();
        for (final followerData in followers) {
          try {
            _followers.add(UserProfile.fromJson(followerData));
          } catch (e) {
            debugPrint('Error parsing follower: $e');
          }
        }
        _realFollowersCount = _followers.length;
      } catch (e) {
        debugPrint('Error loading followers: $e');
        _realFollowersCount = 0;
      }
      
      // Load following
      try {
        final following = await _apiService.getFollowing(
          walletAddress: walletAddress,
          page: 1,
          limit: 100,
        );
        _followingUsers.clear();
        for (final followingData in following) {
          try {
            _followingUsers.add(UserProfile.fromJson(followingData));
          } catch (e) {
            debugPrint('Error parsing following user: $e');
          }
        }
        _realFollowingCount = _followingUsers.length;
      } catch (e) {
        debugPrint('Error loading following: $e');
        _realFollowingCount = 0;
      }

      // Load aggregated stats (posts, follower/following counts if available)
      try {
        final stats = await _apiService.getUserStats(walletAddress);
        _realPostsCount = _parseCount(stats['postsCount'] ?? stats['posts']);
        final statsFollowers = _parseCount(stats['followersCount'] ?? stats['followers']);
        final statsFollowing = _parseCount(stats['followingCount'] ?? stats['following']);
        if (statsFollowers > 0) {
          _realFollowersCount = statsFollowers;
        }
        if (statsFollowing > 0) {
          _realFollowingCount = statsFollowing;
        }
      } catch (e) {
        debugPrint('Error loading user stats: $e');
      }
      
      debugPrint('ProfileProvider: Stats loaded - Collections: $_collectionsCount, Followers: $_realFollowersCount, Following: $_realFollowingCount');
    } catch (e) {
      debugPrint('Error loading backend stats: $e');
    }
  }
  
  /// Load profile by wallet address
  Future<void> loadProfile(String walletAddress) async {
    _isLoading = true;
    _error = null;
    // Immediately set a provisional profile so UI can show a stable identicon
    // and a shortened wallet display name without waiting for the backend.
    try {
      final provisional = UserProfile(
        id: 'profile_${walletAddress.substring(0, 8)}',
        walletAddress: walletAddress,
        username: _generateUsername(walletAddress),
        displayName: _shortWallet(walletAddress),
        bio: '',
        avatar: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _currentUser = provisional;
    } catch (_) {}
    notifyListeners();

    try {
      debugPrint('ProfileProvider: Loading profile for wallet: $walletAddress');
      
      // Prefer cached user service profile to avoid extra backend calls
      try {
        final user = await UserService.getUserById(walletAddress);
        if (user != null) {
          // Normalize username coming from UserService: strip leading '@' if present
          final normalized = user.username.replaceFirst(RegExp(r'^@+'), '');
          _currentUser = UserProfile(
            id: 'profile_${user.id}',
            walletAddress: user.id,
            username: normalized,
            displayName: user.name,
            bio: user.bio,
            avatar: user.profileImageUrl ?? '',
            coverImage: MediaUrlResolver.resolve(user.coverImageUrl),
            isArtist: user.isArtist,
            isInstitution: user.isInstitution,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        } else {
          final profileData = await _apiService.getProfileByWallet(walletAddress);
          try {
            debugPrint('ProfileProvider.loadProfile: profileData keys = ${profileData.keys}');
            _currentUser = UserProfile.fromJson(profileData);
          } catch (e, st) {
            debugPrint('ProfileProvider.loadProfile: UserProfile.fromJson failed: $e');
            debugPrint('Stack trace: $st');
            // Fallback to a minimal profile to avoid crash in the UI
            _currentUser = UserProfile(
              id: 'profile_fallback_${walletAddress.substring(0, walletAddress.length > 8 ? 8 : walletAddress.length)}',
              walletAddress: walletAddress,
              username: _generateUsername(walletAddress),
              displayName: _shortWallet(walletAddress),
              bio: profileData['bio']?.toString() ?? '',
              avatar: profileData['avatar']?.toString() ?? '',
              coverImage: (profileData['coverImage'] ?? profileData['cover_image_url'])?.toString(),
              isArtist: profileData['isArtist'] == true || profileData['is_artist'] == true,
              isInstitution: profileData['isInstitution'] == true || profileData['is_institution'] == true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          }
        }
        // If profile missing role flags but DAO review approved, promote accordingly
        await _applyDaoReviewRoles(walletAddress);
        // Ensure avatar URL is rasterized and absolute
        try {
          final av = _currentUser?.avatar ?? '';
          final resolved = _resolveUrl(av);
          _currentUser = _currentUser?.copyWith(avatar: _convertSvgToRaster(resolved));
        } catch (_) {}
        _isSignedIn = true;
        // Merge backend preferences with locally cached toggles for offline continuity
        final mergedPrefs = _mergePreferencesWithLocalPersona(walletAddress);
        _currentUser = _currentUser?.copyWith(preferences: mergedPrefs);
        await _persistPreferences(mergedPrefs);
        debugPrint('ProfileProvider: Profile loaded from backend: ${_currentUser?.username}');
        
        // Load additional stats (collections, followers, following)
        await _loadBackendStats(walletAddress);
      } catch (e) {
        debugPrint('ProfileProvider: Profile not found on backend, auto-registering via auth: $e');
        // Profile doesn't exist — ask auth/register to create user+profile and return token
        try {
          final reg = await _apiService.registerWallet(
            walletAddress: walletAddress,
            username: 'user_${walletAddress.substring(0, 8)}',
          );
          debugPrint('ProfileProvider: Auto-registration (auth) response: $reg');

          // After registration, prefer cached UserService or fetch profile
          final user = await UserService.getUserById(walletAddress);
          if (user != null) {
            final normalized = user.username.replaceFirst(RegExp(r'^@+'), '');
            _currentUser = UserProfile(
              id: 'profile_${user.id}',
              walletAddress: user.id,
              username: normalized,
              displayName: user.name,
              bio: user.bio,
              avatar: user.profileImageUrl ?? '',
              coverImage: MediaUrlResolver.resolve(user.coverImageUrl),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          } else {
          final profileData = await _apiService.getProfileByWallet(walletAddress);
          _currentUser = UserProfile.fromJson(profileData);
          // If profile missing artist flag but DAO review approved, promote to artist
          try {
            final review = await _apiService.getDAOReview(idOrWallet: walletAddress);
            final status = review?['status']?.toString().toLowerCase();
            if (status == 'approved' && (_currentUser?.isArtist ?? false) == false) {
              _currentUser = _currentUser?.copyWith(isArtist: true);
            }
          } catch (_) {}
        }
          try {
            final av = _currentUser?.avatar ?? '';
            final resolved = _resolveUrl(av);
            _currentUser = _currentUser?.copyWith(avatar: _convertSvgToRaster(resolved));
          } catch (_) {}
          _isSignedIn = true;
          final mergedPrefs = _mergePreferencesWithLocalPersona(walletAddress);
          _currentUser = _currentUser?.copyWith(preferences: mergedPrefs);
          await _persistPreferences(mergedPrefs);
        } catch (regError) {
          debugPrint('ProfileProvider: Auto-registration failed: $regError, creating local default');
          // If registration also fails, create local default
          _currentUser = _createDefaultProfile(walletAddress);
          _isSignedIn = true;
          final mergedPrefs = _mergePreferencesWithLocalPersona(walletAddress);
          _currentUser = _currentUser?.copyWith(preferences: mergedPrefs);
          await _persistPreferences(mergedPrefs);
        }
      }
      
      // Save wallet address
      await _prefs.setString('wallet_address', walletAddress);
      debugPrint('ProfileProvider: Wallet address saved and profile loaded');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load profile: $e';
      _isLoading = false;
      debugPrint('Error loading profile: $e');
      notifyListeners();
    }
  }
  
  /// Create or update profile
  Future<bool> saveProfile({
    required String walletAddress,
    String? username,
    String? displayName,
    String? bio,
    String? avatar,
    String? coverImage,
    Map<String, String>? social,
    bool? isArtist,
    bool? isInstitution,
    ProfilePreferences? preferences,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Ensure persistent user cache is initialized on profile save (wallet registration)
      try { await UserService.initialize(); } catch (_) {}
      // If caller omitted profile fields, prefer existing in-memory values
      final rawUsername = username ?? _currentUser?.username;
      // Normalize username: strip any leading '@' characters so stored usernames
      // never contain the '@' prefix. UI can add '@' for display when needed.
      final effectiveUsername = rawUsername?.replaceFirst(RegExp(r'^@+'), '');
      final effectiveDisplayName = displayName ?? _currentUser?.displayName;
      final effectiveBio = bio ?? _currentUser?.bio;
      final effectiveAvatar = avatar ?? _currentUser?.avatar;
      final effectiveCover = coverImage ?? _currentUser?.coverImage;
      final effectiveSocial = social ?? _currentUser?.social;
      final effectiveIsArtist = isArtist ?? _currentUser?.isArtist;
      final effectiveIsInstitution = isInstitution ?? _currentUser?.isInstitution;
      final effectivePreferences = preferences;

      final profileData = {
        'walletAddress': walletAddress,
        if (effectiveUsername != null) 'username': effectiveUsername,
        if (effectiveDisplayName != null) 'displayName': effectiveDisplayName,
        if (effectiveBio != null) 'bio': effectiveBio,
        if (effectiveAvatar != null) 'avatar': effectiveAvatar,
        if (effectiveCover != null) 'coverImage': effectiveCover,
        if (effectiveSocial != null) 'social': effectiveSocial,
        if (effectiveIsArtist != null) 'isArtist': effectiveIsArtist,
        if (effectiveIsInstitution != null) 'isInstitution': effectiveIsInstitution,
        if (effectivePreferences != null) 'preferences': effectivePreferences.toJson(),
      };

      // Always save to backend
      final savedProfileRaw = await _apiService.saveProfile(profileData);

      debugPrint('ProfileProvider: raw saveProfile response: $savedProfileRaw');

      // savedProfileRaw is expected to be a Map<String,dynamic> (backend returns data.payload).
      // Defensively try to convert it; if parsing fails, fall back to merging submitted values.
      Map<String, dynamic> profileJson;
      try {
        // backend usually returns the profile map directly
        profileJson = Map<String, dynamic>.from(savedProfileRaw);
      } catch (e) {
        debugPrint('ProfileProvider: failed to parse saveProfile response: $e');
        final fallbackCover = profileData['coverImage'] ?? _currentUser?.coverImage;
        profileJson = {
          'id': _currentUser?.id ?? 'profile_${walletAddress.substring(0, 8)}',
          'walletAddress': walletAddress,
          'username': profileData['username'] ?? _currentUser?.username ?? '',
          'displayName': profileData['displayName'] ?? _currentUser?.displayName ?? '',
          'bio': profileData['bio'] ?? _currentUser?.bio ?? '',
          'avatar': profileData['avatar'] ?? _currentUser?.avatar ?? '',
          if (fallbackCover != null) 'coverImage': fallbackCover,
          'social': profileData['social'] ?? _currentUser?.social ?? {},
          'isArtist': profileData['isArtist'] ?? _currentUser?.isArtist ?? false,
          'isInstitution': profileData['isInstitution'] ?? _currentUser?.isInstitution ?? false,
          if (profileData['preferences'] != null) 'preferences': profileData['preferences'],
          'createdAt': _currentUser?.createdAt.toIso8601String() ?? DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        };
      }

      _currentUser = UserProfile.fromJson(profileJson);
      try {
        final av = _currentUser?.avatar ?? '';
        final resolved = _resolveUrl(av);
        _currentUser = _currentUser?.copyWith(avatar: _convertSvgToRaster(resolved));
      } catch (_) {}
      
      // Reload stats after profile update
      await _loadBackendStats(walletAddress);
      
      // Update sign-in state
      _isSignedIn = true;

      // Persist preferences (including persona) locally for offline continuity.
      try {
        final mergedPrefs = _mergePreferencesWithLocalPersona(walletAddress);
        _currentUser = _currentUser?.copyWith(preferences: mergedPrefs);
        await _persistPreferences(mergedPrefs);
      } catch (_) {}

      // Save to SharedPreferences
      await _prefs.setString('wallet_address', walletAddress);
      await _prefs.setString('username', _currentUser!.username);
      debugPrint('ProfileProvider: Profile saved successfully for wallet: $walletAddress');
      
      // Persist to UserService cache (and let ChatProvider be updated via EventBus)
      try {
        final u = _currentUser;
        if (u != null) {
          UserService.setUsersInCache([User(
            id: u.walletAddress,
            name: u.displayName,
            username: u.username,
            bio: u.bio,
            profileImageUrl: u.avatar,
            coverImageUrl: MediaUrlResolver.resolve(u.coverImage),
            followersCount: u.stats?.followersCount ?? 0,
            followingCount: u.stats?.followingCount ?? 0,
            postsCount: u.stats?.artworksCreated ?? 0,
            isFollowing: false,
            isVerified: false,
            joinedDate: u.createdAt.toIso8601String(),
            achievementProgress: [],
            isArtist: u.isArtist,
            isInstitution: u.isInstitution,
          )]);
        }
      } catch (_) {}
      _isLoading = false;
      notifyListeners();

      // Emit an application event indicating the profile was updated
      try {
        EventBus().emitProfileUpdated(_currentUser);
      } catch (_) {}
      return true;
    } catch (e) {
      // Detect 429 response message and provide a friendly error
      final errMsg = e.toString();
      if (errMsg.contains('429') || errMsg.toLowerCase().contains('too many requests')) {
        _error = 'Too many requests. Please wait a moment and try again.';
      } else {
        _error = 'Failed to save profile: $e';
      }
      _isLoading = false;
      debugPrint('Error saving profile: $e');
      notifyListeners();
      return false;
    }
  }
  
  /// Upload avatar image to backend
  Future<String> uploadAvatar({
    required String imagePath,
    required String walletAddress,
  }) async {
    try {
      // Read file bytes
      final file = File(imagePath);
      final fileBytes = await file.readAsBytes();
      final fileName = path.basename(imagePath);
      
      final result = await _apiService.uploadAvatarToProfile(
        fileBytes: fileBytes,
        fileName: fileName,
        fileType: 'avatar',
        metadata: {'walletAddress': walletAddress},
      );
      
      // Normalize response: backend may wrap in { data: { url: ... } }
      final Map<String, dynamic> resultMap = Map<String, dynamic>.from(result);
      debugPrint('ProfileProvider.uploadAvatar: raw upload result: $resultMap');

      // Store debug info early so UI can inspect it on failure
      _lastUploadDebug = {'result': resultMap};
      notifyListeners();

      // Prefer a normalized uploadedUrl if provided by BackendApiService
      // Try to extract URL from the upload result using helper
      String? rawUrl = _extractUrlFromUploadResult(resultMap);
      _lastUploadDebug ??= {};
      _lastUploadDebug!['extractedUrl'] = rawUrl;
      final url = rawUrl?.toString();
      final resolved = _resolveUrl(url);

      final raster = resolved.isNotEmpty ? _convertSvgToRaster(resolved) : '';

      // Verify the raster URL is reachable and points to an image
      final verified = await _verifyImageUrl(raster);
      _lastUploadDebug!['resolved'] = resolved;
      _lastUploadDebug!['raster'] = raster;
      _lastUploadDebug!['verified'] = verified;
      notifyListeners();
      if (!verified) {
        debugPrint('ProfileProvider.uploadAvatar: uploaded URL not verified as image: $raster');
        // Don't fail the upload if remote verification fails. Accept the URL
        // returned by backend so clients can use backend-hosted avatars even
        // when the URL is not directly reachable from the client (private
        // networks, proxy, or timing). Keep verification result in debug info.
      }

      if (raster.isNotEmpty && _currentUser != null) {
        try {
          _currentUser = _currentUser!.copyWith(avatar: raster);
          notifyListeners();
          try { EventBus().emitProfileUpdated(_currentUser); } catch (_) {}
        } catch (_) {}
      }

      return raster;
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      // Return empty string so the UI uses local initials instead of synthetic URLs
      return '';
    }
  }


  /// Upload avatar using raw bytes (works with Android content:// URIs from image_picker)
  Future<String> uploadAvatarBytes({
    required List<int> fileBytes,
    required String fileName,
    required String walletAddress,
    String? mimeType,
  }) async {
    try {
      debugPrint('📸 ProfileProvider.uploadAvatarBytes START');
      debugPrint('   fileName: $fileName');
      debugPrint('   mimeType: $mimeType');
      debugPrint('   fileBytes length: ${fileBytes.length}');
      debugPrint('   walletAddress: $walletAddress');
      
      // Determine MIME type from file extension if not provided
      String fileType = mimeType ?? 'image/jpeg';
      if (mimeType == null) {
        final ext = fileName.toLowerCase().split('.').last;
        if (ext == 'png') {
          fileType = 'image/png';
        } else if (ext == 'jpg' || ext == 'jpeg') {
          fileType = 'image/jpeg';

        } else if (ext == 'webp') {
          fileType = 'image/webp';
        }

        else if (ext == 'gif') {
          fileType = 'image/gif';
        } else if (ext == 'svg') {
          fileType = 'image/svg+xml';
          
      }
      }
      
      debugPrint('   determined fileType: $fileType');
      debugPrint('   calling API uploadAvatarToProfile...');
      
      final result = await _apiService.uploadAvatarToProfile(
        fileBytes: fileBytes,
        fileName: fileName,
        fileType: fileType,
        metadata: {'walletAddress': walletAddress},
      );
      
      debugPrint('   API call completed successfully');

      final Map<String, dynamic> resultMap = Map<String, dynamic>.from(result);
      debugPrint('ProfileProvider.uploadAvatarBytes: raw upload result: $resultMap');
      _lastUploadDebug = {'result': resultMap};
      notifyListeners();

      // Extract and normalize URL
      String? rawUrl = _extractUrlFromUploadResult(resultMap);
      _lastUploadDebug ??= {};
      _lastUploadDebug!['extractedUrl'] = rawUrl;
      final url = rawUrl?.toString();
      final resolved = _resolveUrl(url);
      final raster = resolved.isNotEmpty ? _convertSvgToRaster(resolved) : '';

      // Verify reachable image
      final verified = await _verifyImageUrl(raster);
      _lastUploadDebug!['resolved'] = resolved;
      _lastUploadDebug!['raster'] = raster;
      _lastUploadDebug!['verified'] = verified;
      notifyListeners();
      if (!verified) {
        debugPrint('ProfileProvider.uploadAvatarBytes: uploaded URL not verified as image: $raster');
        // Do not throw here; accept the returned URL so the app can display
        // backend-hosted images even if the quick HEAD/GET check fails.
      }

      if (raster.isNotEmpty && _currentUser != null) {
        try {
          _currentUser = _currentUser!.copyWith(avatar: raster);
          notifyListeners();
          try { EventBus().emitProfileUpdated(_currentUser); } catch (_) {}
        } catch (_) {}
      }

      return raster;
    } catch (e, stackTrace) {
      debugPrint('❌ Error uploading avatar bytes: $e');
      debugPrint('Stack trace: $stackTrace');
      _lastUploadDebug = {'error': e.toString(), 'stackTrace': stackTrace.toString()};
      notifyListeners();
      return '';
    }
  }
  
  /// Create profile when wallet is created
  Future<bool> createProfileFromWallet({
    required String walletAddress,
    String? username,
  }) async {
    debugPrint('ProfileProvider: Creating profile from wallet: $walletAddress');
    debugPrint('ProfileProvider: Username: ${username ?? _generateUsername(walletAddress)}');
    // Compute effective username once and use it for both username and displayName
    final effectiveUsername = username ?? _generateUsername(walletAddress);
    // Instead of saving profile client-side, call server auth/register so server
    // creates user+profile and returns a JWT. Backend will handle username/avatar defaults.
    final reg = await _apiService.registerWallet(walletAddress: walletAddress, username: effectiveUsername);
    final result = reg['success'] == true || reg['message'] != null;
    
    debugPrint('ProfileProvider: Profile creation result: $result');
    return result;
  }
  
  /// Helper: Create default profile
  UserProfile _createDefaultProfile(String walletAddress) {
    return UserProfile(
      id: 'profile_${walletAddress.substring(0, 8)}',
      walletAddress: walletAddress,
      username: _generateUsername(walletAddress),
      displayName: 'Art Enthusiast',
      bio: 'Exploring the world of AR art',
      avatar: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Helper: Generate username from wallet
  String _generateUsername(String walletAddress) {
    return 'user_${walletAddress.substring(0, 8)}';
  }

  /// Helper: Shorten wallet address for immediate display (e.g. 0x1234...abcd)
  String _shortWallet(String wallet) {
    if (wallet.isEmpty) return '';
    try {
      if (wallet.length <= 16) return wallet;
      final head = wallet.substring(0, 8);
      final tail = wallet.substring(wallet.length - 6);
      return '$head...$tail';
    } catch (_) {
      return wallet;
    }
  }

  ProfilePreferences _cachedPreferencesFromPrefs() {
    try {
      final wallet = _prefs.getString(PreferenceKeys.walletAddress) ?? _prefs.getString('wallet_address') ?? '';
      final bool isPrivate = _prefs.getBool('private_profile') ?? false;
      final bool showActivityStatus = _prefs.getBool('show_activity_status') ?? true;
      final bool shareLastVisitedLocation = _prefs.getBool('share_last_visited_location') ?? false;
      final bool showCollection = _prefs.getBool('show_collection') ?? true;
      final bool allowMessages = _prefs.getBool('allow_messages') ?? true;
      final String? persona = wallet.isNotEmpty ? _prefs.getString(_personaKeyForWallet(wallet)) : null;
      return ProfilePreferences(
        privacy: isPrivate ? 'private' : 'public',
        notifications: true,
        theme: 'auto',
        showActivityStatus: showActivityStatus,
        shareLastVisitedLocation: shareLastVisitedLocation,
        showCollection: showCollection,
        allowMessages: allowMessages,
        persona: persona,
      );
    } catch (_) {
      return _currentUser?.preferences ?? ProfilePreferences();
    }
  }

  ProfilePreferences _mergePreferencesWithLocalPersona(String walletAddress) {
    final existing = _currentUser?.preferences ?? _cachedPreferencesFromPrefs();
    final currentPersona = (existing.persona ?? '').trim();
    if (currentPersona.isNotEmpty) {
      // Ensure local keys are kept in sync so onboarding doesn't reappear.
      try {
        _prefs.setString(_personaKeyForWallet(walletAddress), currentPersona);
        _prefs.setBool(_personaOnboardedKeyForWallet(walletAddress), true);
      } catch (_) {}
      return existing;
    }

    final persisted = (_prefs.getString(_personaKeyForWallet(walletAddress)) ?? '').trim();
    if (persisted.isEmpty) return existing;

    // Mark onboarding complete when we have a persisted persona.
    try {
      _prefs.setBool(_personaOnboardedKeyForWallet(walletAddress), true);
    } catch (_) {}
    return existing.copyWith(persona: persisted);
  }

  Future<void> _applyDaoReviewRoles(String walletAddress) async {
    try {
      final reviewPayload = await _apiService.getDAOReview(idOrWallet: walletAddress);
      if (reviewPayload == null) return;
      final daoReview = DAOReview.fromJson(reviewPayload);
      if (!daoReview.isApproved) return;

      final isArtistReview = daoReview.isArtistApplication;
      final isInstitutionReview = daoReview.isInstitutionApplication;

      final nextArtist = (_currentUser?.isArtist ?? false) || isArtistReview;
      final nextInstitution = (_currentUser?.isInstitution ?? false) || isInstitutionReview;

      final previousArtist = _currentUser?.isArtist ?? false;
      final previousInstitution = _currentUser?.isInstitution ?? false;

      if (nextArtist != previousArtist || nextInstitution != previousInstitution) {
        _currentUser = _currentUser?.copyWith(
          isArtist: nextArtist,
          isInstitution: nextInstitution,
        );
        notifyListeners();
        try { EventBus().emitProfileUpdated(_currentUser); } catch (_) {}
      }
    } catch (e) {
      debugPrint('ProfileProvider._applyDaoReviewRoles failed: $e');
    }
  }

  Future<void> _persistPreferences(ProfilePreferences preferences) async {
    try {
      await _prefs.setBool('private_profile', preferences.privacy.toLowerCase() == 'private');
      await _prefs.setBool('show_activity_status', preferences.showActivityStatus);
      await _prefs.setBool('share_last_visited_location', preferences.shareLastVisitedLocation);
      await _prefs.setBool('show_collection', preferences.showCollection);
      await _prefs.setBool('allow_messages', preferences.allowMessages);
      final wallet = _currentWalletAddress;
      final persona = (preferences.persona ?? '').trim();
      if (wallet != null && wallet.isNotEmpty && persona.isNotEmpty) {
        await _prefs.setString(_personaKeyForWallet(wallet), persona);
        await _prefs.setBool(_personaOnboardedKeyForWallet(wallet), true);
      }
      _cachedPreferences = preferences;
    } catch (_) {}
  }
  
  // Refresh stats from backend
  Future<void> refreshStats() async {
    if (_currentUser?.walletAddress != null) {
      await _loadBackendStats(_currentUser!.walletAddress);
      notifyListeners();
    }
  }

  /// Update privacy/display preferences locally and attempt to persist to backend.
  Future<void> updatePreferences({
    bool? privateProfile,
    bool? showActivityStatus,
    bool? shareLastVisitedLocation,
    bool? showCollection,
    bool? allowMessages,
  }) async {
    try {
      final existing = _currentUser?.preferences ?? _cachedPreferencesFromPrefs();
      final next = existing.copyWith(
        privacy: (privateProfile ?? (existing.privacy.toLowerCase() == 'private')) ? 'private' : 'public',
        showActivityStatus: showActivityStatus ?? existing.showActivityStatus,
        shareLastVisitedLocation: shareLastVisitedLocation ?? existing.shareLastVisitedLocation,
        showCollection: showCollection ?? existing.showCollection,
        allowMessages: allowMessages ?? existing.allowMessages,
      );

      _cachedPreferences = next;
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(preferences: next);
      }
      await _persistPreferences(next);
      notifyListeners();

      // Best-effort backend persistence
      if (_currentUser != null) {
        try {
          await _apiService.updateProfile(
            _currentUser!.walletAddress,
            {'preferences': next.toJson()},
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('ProfileProvider.updatePreferences: backend update failed: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfileProvider.updatePreferences failed: $e');
      }
    }
  }
  
  // Helper method to format large numbers
  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  int _parseCount(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }
  
  void signOut() {
    _currentUser = null;
    _followingUsers.clear();
    _followers.clear();
    _isSignedIn = false;
    notifyListeners();
  }
  
  Future<void> followUser(UserProfile user) async {
    try {
      await _apiService.followUser(user.walletAddress);
      if (!_followingUsers.any((u) => u.id == user.id)) {
        _followingUsers.add(user);
        _realFollowingCount++;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error following user: $e');
      rethrow;
    }
  }
  
  Future<void> unfollowUser(String walletAddress) async {
    try {
      await _apiService.unfollowUser(walletAddress);
      _followingUsers.removeWhere((user) => user.id == walletAddress || user.walletAddress == walletAddress);
      _realFollowingCount = _followingUsers.length;
      notifyListeners();
    } catch (e) {
      debugPrint('Error unfollowing user: $e');
      rethrow;
    }
  }
  
  bool isFollowing(String userId) {
    return _followingUsers.any((user) => user.id == userId || user.walletAddress == userId);
  }
  
  Future<bool> checkIsFollowing(String walletAddress) async {
    try {
      return await _apiService.isFollowing(walletAddress);
    } catch (e) {
      debugPrint('Error checking follow status: $e');
      return isFollowing(walletAddress);
    }
  }
  
  void addFollower(UserProfile user) {
    if (!_followers.any((u) => u.id == user.id)) {
      _followers.add(user);
      notifyListeners();
    }
  }
  
  void removeFollower(String userId) {
    _followers.removeWhere((user) => user.id == userId);
    notifyListeners();
  }
  
  // Initialize with sample data (deprecated - use loadProfile instead)
  void initializeSampleData() {
    // Create a sample current user with new model
    _currentUser = UserProfile(
      id: 'current_user',
      walletAddress: '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
      username: 'current_user',
      displayName: 'Current User',
      bio: 'Digital artist exploring the intersection of AR, blockchain, and creativity.',
      avatar: '${_apiService.baseUrl.replaceAll(RegExp(r'/$'), '')}/api/avatar/current?style=avataaars&format=png&raw=true',
      stats: UserStats(
        followersCount: 1250,
        followingCount: 340,
        artworksDiscovered: 45,
        artworksCreated: 12,
      ),
      createdAt: DateTime.now().subtract(const Duration(days: 365)),
      updatedAt: DateTime.now(),
    );
    _isSignedIn = true;
    
    notifyListeners();
  }
}
