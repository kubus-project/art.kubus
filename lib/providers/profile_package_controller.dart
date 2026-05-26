import 'dart:async';

import 'package:flutter/foundation.dart';

import '../community/community_interactions.dart';
import '../models/achievement_preview_data_state.dart';
import '../models/profile_package.dart';
import '../models/user.dart';
import '../services/backend_api_service.dart';
import '../services/profile_package_service.dart';
import '../services/user_service.dart';
import '../utils/wallet_utils.dart';
import 'community_interactions_provider.dart';
import 'saved_items_provider.dart';
import 'stats_provider.dart';

class ProfilePackageController extends ChangeNotifier {
  ProfilePackageController({
    required String walletAddress,
    String? username,
    ProfileCriticalPackage? initialCriticalPackage,
    Future<ProfileCriticalPackage?>? initialCriticalPackageFuture,
    Future<ProfileExtendedPackage?>? initialExtendedPackageFuture,
    ProfilePackage? initialPackage,
    Future<ProfilePackage?>? initialPackageFuture,
  })  : _walletAddress = walletAddress.trim(),
        _username = username?.trim(),
        _initialCriticalPackage =
            initialCriticalPackage ?? initialPackage?.critical,
        _initialCriticalPackageFuture = initialCriticalPackageFuture ??
            initialPackageFuture?.then((package) => package?.critical),
        _initialExtendedPackageFuture = initialExtendedPackageFuture ??
            initialPackageFuture?.then((package) => package?.extended) {
    final package = initialPackage;
    if (package != null && package.isComplete) {
      _package = package;
      _publicStreetArtAddedCount =
          package.publicStats['publicStreetArtAdded'] ?? 0;
      _hydrateExtendedState(package.extended);
      _isLoadingCritical = false;
    }
  }

  final String _walletAddress;
  final String? _username;
  final ProfileCriticalPackage? _initialCriticalPackage;
  final Future<ProfileCriticalPackage?>? _initialCriticalPackageFuture;
  final Future<ProfileExtendedPackage?>? _initialExtendedPackageFuture;

  ProfilePackage? _package;
  bool _isLoadingCritical = true;
  bool _isLoadingExtended = false;
  Object? _error;
  List<CommunityPost> _posts = <CommunityPost>[];
  bool _postsLoading = true;
  int _currentPage = 1;
  bool _isLastPage = false;
  bool _loadingMore = false;
  String? _postsError;
  int _publicStreetArtAddedCount = 0;
  bool _artistDataLoaded = false;
  bool _artistDataLoading = false;
  List<Map<String, dynamic>> _artistArtworks = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _artistCollections = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _artistEvents = <Map<String, dynamic>>[];
  int _loadEpoch = 0;
  int _extendedLoadEpoch = 0;
  bool _disposed = false;

  ProfilePackage? get package => _package;
  User? get user => _package?.user;
  bool get isLoadingCritical => _isLoadingCritical;
  bool get isLoadingExtended => _isLoadingExtended;
  Object? get error => _error;
  List<CommunityPost> get posts => List<CommunityPost>.unmodifiable(_posts);
  bool get postsLoading => _postsLoading;
  bool get loadingMore => _loadingMore;
  bool get isLastPage => _isLastPage;
  String? get postsError => _postsError;
  int get currentPage => _currentPage;
  int get publicStreetArtAddedCount => _publicStreetArtAddedCount;
  bool get artistDataLoaded => _artistDataLoaded;
  bool get artistDataLoading => _artistDataLoading;
  List<Map<String, dynamic>> get artistArtworks =>
      List<Map<String, dynamic>>.unmodifiable(_artistArtworks);
  List<Map<String, dynamic>> get artistCollections =>
      List<Map<String, dynamic>>.unmodifiable(_artistCollections);
  List<Map<String, dynamic>> get artistEvents =>
      List<Map<String, dynamic>>.unmodifiable(_artistEvents);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  AchievementPreviewDataState get achievementPreviewDataState {
    final critical = _package?.critical;
    if (critical == null || !critical.isComplete) {
      return AchievementPreviewDataState.loading;
    }
    if (critical.achievementsUnavailable) {
      return AchievementPreviewDataState.unavailable;
    }
    if (critical.achievementDefinitions.isNotEmpty ||
        critical.achievementProgress.isEmpty) {
      return AchievementPreviewDataState.ready;
    }
    return AchievementPreviewDataState.fallback;
  }

  Future<void> load({
    bool forceRefresh = false,
    bool includeExtended = true,
  }) async {
    final epoch = ++_loadEpoch;
    _error = null;
    if (_package == null) {
      _isLoadingCritical = true;
      _notifyListenersSafe();
    }

    if (!forceRefresh) {
      final cached = _initialCriticalPackage ??
          ProfilePackageService.getCachedCriticalPackage(
            _walletAddress,
            allowStale: true,
          );
      if (cached != null && cached.isComplete) {
        applyCritical(cached);
        if (includeExtended) {
          unawaited(loadExtended(forceRefresh: false));
        }
        unawaited(_refreshCriticalInBackground(epoch));
        return;
      }
    }

    try {
      final critical = !forceRefresh && _initialCriticalPackageFuture != null
          ? await _initialCriticalPackageFuture
          : await ProfilePackageService.loadPublicProfileCriticalPackage(
              _walletAddress,
              forceRefresh: forceRefresh,
              username: _username,
            );
      if (epoch != _loadEpoch) return;
      if (critical == null || !critical.isComplete) {
        _package = null;
        _isLoadingCritical = false;
        _error = StateError('Profile package critical load failed');
        _notifyListenersSafe();
        return;
      }
      applyCritical(critical);
      if (includeExtended) {
        unawaited(loadExtended(forceRefresh: forceRefresh));
      }
    } catch (e) {
      if (epoch != _loadEpoch) return;
      _error = e;
      _isLoadingCritical = false;
      if (_package == null) {
        _postsLoading = false;
      }
      _notifyListenersSafe();
    }
  }

  Future<void> refresh() async {
    final epoch = ++_loadEpoch;
    final critical =
        await ProfilePackageService.loadPublicProfileCriticalPackage(
      _walletAddress,
      forceRefresh: true,
      username: _username,
    );
    if (epoch != _loadEpoch || _disposed) return;
    if (critical != null && critical.isComplete) {
      applyCritical(critical);
    }
    await loadExtended(forceRefresh: true);
  }

  Future<void> loadExtended({bool forceRefresh = false}) async {
    final epoch = ++_extendedLoadEpoch;
    final currentUser = user;
    final wallet = currentUser?.id ?? _walletAddress;
    if (wallet.trim().isEmpty) return;

    final cached = !forceRefresh
        ? ProfilePackageService.getCachedExtendedPackage(
            wallet,
            allowStale: true,
          )
        : null;
    if (cached != null) {
      applyExtended(cached);
      return;
    }

    _isLoadingExtended = true;
    _artistDataLoading = true;
    if (_posts.isEmpty) _postsLoading = true;
    _notifyListenersSafe();

    try {
      final extended = !forceRefresh && _initialExtendedPackageFuture != null
          ? await _initialExtendedPackageFuture
          : await ProfilePackageService.loadPublicProfileExtendedPackage(
              wallet,
              forceRefresh: forceRefresh,
              includePosts: true,
              includeShowcase: true,
              user: currentUser,
            );
      if (epoch != _extendedLoadEpoch || _disposed) return;
      if (extended != null) {
        applyExtended(extended);
      } else {
        _isLoadingExtended = false;
        _artistDataLoading = false;
        _postsLoading = false;
        _notifyListenersSafe();
      }
    } catch (e) {
      if (epoch != _extendedLoadEpoch || _disposed) return;
      _error = e;
      _isLoadingExtended = false;
      _artistDataLoading = false;
      _postsLoading = false;
      _notifyListenersSafe();
    }
  }

  void applyCritical(ProfileCriticalPackage critical) {
    final current = _package;
    _package = ProfilePackage.fromParts(
      critical: critical,
      extended: current?.extended,
    );
    _isLoadingCritical = false;
    _error = null;
    _publicStreetArtAddedCount = critical.publicStats['publicStreetArtAdded'] ??
        _publicStreetArtAddedCount;
    _notifyListenersSafe();
  }

  void applyExtended(ProfileExtendedPackage extended) {
    final critical = _package?.critical;
    if (critical == null) return;
    _package = ProfilePackage.fromParts(
      critical: critical,
      extended: extended,
    );
    _hydrateExtendedState(extended);
    _isLoadingExtended = false;
    _notifyListenersSafe();
  }

  void applyPackage(ProfilePackage package) {
    _package = package;
    _isLoadingCritical = false;
    _error = null;
    _publicStreetArtAddedCount = package.publicStats['publicStreetArtAdded'] ??
        _publicStreetArtAddedCount;
    _hydrateExtendedState(package.extended);
    _notifyListenersSafe();
  }

  void patchUser(User Function(User current) patch) {
    final current = _package;
    if (current == null) return;
    final nextUser = patch(current.user);
    _package = current.copyWith(user: nextUser);
    UserService.setUsersInCache([nextUser]);
    ProfilePackageService.patchUser(nextUser.id, (_) => nextUser);
    _notifyListenersSafe();
  }

  void patchStats(Map<String, int> patch) {
    if (patch.isEmpty) return;
    final current = _package;
    if (current == null) return;
    final nextStats = <String, int>{...current.publicStats, ...patch};
    final nextUser = current.user.copyWith(
      postsCount: nextStats['posts'] ?? current.user.postsCount,
      followersCount: nextStats['followers'] ?? current.user.followersCount,
      followingCount: nextStats['following'] ?? current.user.followingCount,
    );
    _package = current.copyWith(
      user: nextUser,
      publicStats: nextStats,
    );
    _publicStreetArtAddedCount =
        nextStats['publicStreetArtAdded'] ?? _publicStreetArtAddedCount;
    ProfilePackageService.patchStats(nextUser.id, patch);
    UserService.setUsersInCache([nextUser]);
    _notifyListenersSafe();
  }

  void patchPosts(List<CommunityPost> posts) {
    _posts = List<CommunityPost>.from(posts);
    _postsLoading = false;
    _postsError = null;
    _currentPage = 1;
    _isLastPage = posts.length < 20;
    _loadingMore = false;
    final current = _package;
    if (current != null) {
      _package = current.copyWith(initialPosts: _posts);
      ProfilePackageService.patchPosts(current.user.id, _posts);
    }
    _notifyListenersSafe();
  }

  Future<void> loadStats({
    StatsProvider? statsProvider,
    bool skipFollowersOverwrite = false,
    bool forceRefresh = false,
  }) async {
    final currentUser = user;
    if (currentUser == null || statsProvider == null) return;
    try {
      final snapshot = await statsProvider.ensureSnapshot(
        entityType: 'user',
        entityId: currentUser.id,
        metrics: const <String>[
          'posts',
          'followers',
          'following',
          'publicStreetArtAdded',
        ],
        scope: 'public',
        forceRefresh: forceRefresh,
      );
      final counters = snapshot?.counters ?? const <String, int>{};
      final patch = <String, int>{};
      if (counters.containsKey('posts')) {
        patch['posts'] = counters['posts'] ?? 0;
      }
      if (!skipFollowersOverwrite && counters.containsKey('followers')) {
        patch['followers'] = counters['followers'] ?? 0;
      }
      if (!skipFollowersOverwrite && counters.containsKey('following')) {
        patch['following'] = counters['following'] ?? 0;
      }
      if (counters.containsKey('publicStreetArtAdded')) {
        patch['publicStreetArtAdded'] = counters['publicStreetArtAdded'] ?? 0;
      }
      patchStats(patch);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePackageController.loadStats: $e');
      }
    }
  }

  Future<void> loadPosts({
    SavedItemsProvider? savedItemsProvider,
    CommunityInteractionsProvider? interactionsProvider,
    String? errorMessage,
  }) async {
    final currentUser = user;
    if (currentUser == null) return;
    _postsLoading = true;
    _postsError = null;
    _currentPage = 1;
    _isLastPage = false;
    _notifyListenersSafe();

    try {
      const pageSize = 20;
      final posts = await BackendApiService().getCommunityPosts(
        page: _currentPage,
        limit: pageSize,
        authorWallet: currentUser.id,
      );
      await _hydratePostInteractions(
        posts,
        savedItemsProvider: savedItemsProvider,
        interactionsProvider: interactionsProvider,
      );
      _posts = posts;
      _postsLoading = false;
      _isLastPage = posts.length < pageSize;
      _postsError = null;
      patchStats(<String, int>{'posts': posts.length});
      ProfilePackageService.patchPosts(currentUser.id, _posts);
      _notifyListenersSafe();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePackageController.loadPosts: $e');
      }
      _posts = <CommunityPost>[];
      _postsLoading = false;
      _postsError = errorMessage ?? e.toString();
      _notifyListenersSafe();
    }
  }

  Future<void> loadMorePosts({
    SavedItemsProvider? savedItemsProvider,
    CommunityInteractionsProvider? interactionsProvider,
    String? errorMessage,
  }) async {
    final currentUser = user;
    if (currentUser == null || _isLastPage || _loadingMore) return;
    _loadingMore = true;
    _currentPage += 1;
    _notifyListenersSafe();

    try {
      const pageSize = 20;
      final more = await BackendApiService().getCommunityPosts(
        page: _currentPage,
        limit: pageSize,
        authorWallet: currentUser.id,
      );
      await _hydratePostInteractions(
        more,
        savedItemsProvider: savedItemsProvider,
        interactionsProvider: interactionsProvider,
      );
      _posts.addAll(more);
      _isLastPage = more.length < pageSize;
      _loadingMore = false;
      ProfilePackageService.patchPosts(
        currentUser.id,
        _posts,
        updateCount: false,
      );
      _notifyListenersSafe();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePackageController.loadMorePosts: $e');
      }
      _loadingMore = false;
      _postsError = errorMessage ?? e.toString();
      if (_currentPage > 1) _currentPage -= 1;
      _notifyListenersSafe();
    }
  }

  Future<void> refreshPostInteractions({
    SavedItemsProvider? savedItemsProvider,
    CommunityInteractionsProvider? interactionsProvider,
  }) async {
    if (_posts.isEmpty) return;
    await _hydratePostInteractions(
      _posts,
      savedItemsProvider: savedItemsProvider,
      interactionsProvider: interactionsProvider,
      refresh: true,
    );
    _notifyListenersSafe();
  }

  Future<void> handleIncomingPostData(Map<String, dynamic> data) async {
    final currentUser = user;
    if (currentUser == null) return;
    final incomingAuthor =
        (data['walletAddress'] ?? data['author'] ?? data['authorWallet'])
            ?.toString();
    if (incomingAuthor == null ||
        !WalletUtils.equals(incomingAuthor, currentUser.id)) {
      return;
    }
    final id = (data['id'] ?? data['postId'] ?? data['post_id'])?.toString();
    if (id == null || id.trim().isEmpty) return;
    if (_posts.any((post) => post.id == id)) return;

    try {
      final post = await BackendApiService().getCommunityPostById(id);
      _posts.insert(0, post);
      final nextPostsCount = currentUser.postsCount + 1;
      patchStats(<String, int>{'posts': nextPostsCount});
      ProfilePackageService.invalidatePosts(currentUser.id);
      ProfilePackageService.patchPosts(currentUser.id, _posts);
      _notifyListenersSafe();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePackageController.handleIncomingPostData: $e');
      }
    }
  }

  Future<void> refreshFollowStateFromServer() async {
    final current = user;
    if (current == null) return;
    try {
      final fresh = await UserService.getUserById(
        current.id,
        forceRefresh: true,
        includeAchievements: false,
      );
      if (fresh == null) return;
      patchUser((latest) => latest.copyWith(isFollowing: fresh.isFollowing));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePackageController.refreshFollowStateFromServer: $e');
      }
    }
  }

  Future<void> _refreshCriticalInBackground(int epoch) async {
    try {
      final fresh =
          await ProfilePackageService.loadPublicProfileCriticalPackage(
        _walletAddress,
        forceRefresh: true,
        username: _username,
      );
      if (fresh == null || !fresh.isComplete || epoch != _loadEpoch) return;
      final current = user;
      if (current != null && !WalletUtils.equals(current.id, fresh.user.id)) {
        return;
      }
      applyCritical(fresh);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePackageController._refreshCriticalInBackground: $e');
      }
    }
  }

  Future<void> _hydratePostInteractions(
    List<CommunityPost> posts, {
    SavedItemsProvider? savedItemsProvider,
    CommunityInteractionsProvider? interactionsProvider,
    bool refresh = false,
  }) async {
    try {
      await CommunityService.loadSavedInteractions(
        posts,
        savedItemsProvider: savedItemsProvider,
      );
      if (refresh) {
        await interactionsProvider?.refreshPostStates(posts, force: true);
      } else {
        interactionsProvider?.hydratePostsFromServer(posts);
      }
    } catch (_) {}
  }

  void _hydrateExtendedState(ProfileExtendedPackage? extended) {
    if (extended == null) return;
    final posts = extended.initialPosts;
    if (posts != null) {
      _posts = List<CommunityPost>.from(posts);
      _postsLoading = false;
      _postsError = null;
      _currentPage = 1;
      _isLastPage = posts.length < 20;
      _loadingMore = false;
    }
    _artistArtworks = extended.artistArtworks
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    _artistCollections = extended.artistCollections
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    _artistEvents = extended.artistEvents
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    _artistDataLoaded = true;
    _artistDataLoading = false;
    _isLoadingExtended = false;
  }

  void _notifyListenersSafe() {
    if (_disposed) return;
    notifyListeners();
  }
}
