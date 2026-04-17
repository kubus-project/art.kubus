import 'dart:async';

import 'package:flutter/foundation.dart';

import '../community/community_interactions.dart';
import '../services/backend_api_service.dart';
import 'community_comments_provider.dart';
import 'wallet_provider.dart';

class CommunityInteractionsProvider extends ChangeNotifier {
  CommunityInteractionsProvider({BackendApiService? api})
      : _api = api ?? BackendApiService();

  static const Duration _interactionStateTtl = Duration(minutes: 2);
  static const Duration _likeListTtl = Duration(minutes: 2);

  final BackendApiService _api;

  WalletProvider? _walletProvider;
  String? _boundWallet;
  Timer? _walletDebounce;
  int _authEpoch = 0;

  final Map<String, CommunityEntityInteractionState> _postStates = {};
  final Map<String, DateTime> _postStateFetchedAt = {};
  final Map<String, bool> _postStateInflight = {};

  final Map<String, Future<List<CommunityLikeUser>>> _postLikeFutures = {};
  final Map<String, List<CommunityLikeUser>> _postLikeUsers = {};
  final Map<String, DateTime> _postLikeFetchedAt = {};

  final Map<String, Future<List<CommunityLikeUser>>> _commentLikeFutures = {};
  final Map<String, List<CommunityLikeUser>> _commentLikeUsers = {};
  final Map<String, DateTime> _commentLikeFetchedAt = {};

  List<CommunityLikeUser>? cachedPostLikes(String postId) =>
      _postLikeUsers[postId];

  List<CommunityLikeUser>? cachedCommentLikes(String commentId) =>
      _commentLikeUsers[commentId];

  void bindWalletProvider(WalletProvider? walletProvider) {
    if (_walletProvider == walletProvider) {
      _handleWalletMaybeChanged();
      return;
    }
    _walletProvider?.removeListener(_handleWalletMaybeChanged);
    _walletProvider = walletProvider;
    _boundWallet = _normalizedWallet(walletProvider?.currentWalletAddress);
    walletProvider?.addListener(_handleWalletMaybeChanged);
  }

  @override
  void dispose() {
    _walletDebounce?.cancel();
    _walletProvider?.removeListener(_handleWalletMaybeChanged);
    super.dispose();
  }

  void applyServerPostState(CommunityPost post) {
    _postStates[post.id] = CommunityEntityInteractionState(
      id: post.id,
      isLiked: post.isLiked,
      likeCount: post.likeCount,
      commentCount: post.commentCount,
      isBookmarked: post.isBookmarked,
    );
    _postStateFetchedAt[post.id] = DateTime.now();
  }

  void hydratePostsFromServer(List<CommunityPost> posts) {
    if (posts.isEmpty) return;
    for (final post in posts) {
      applyServerPostState(post);
    }
  }

  Future<void> refreshPostStates(
    Iterable<CommunityPost> posts, {
    bool force = false,
  }) async {
    final targets = <CommunityPost>[];
    final now = DateTime.now();
    for (final post in posts) {
      if (post.id.trim().isEmpty) continue;
      if (!force) {
        final fetchedAt = _postStateFetchedAt[post.id];
        final inFlight = _postStateInflight[post.id] == true;
        if (inFlight) continue;
        if (fetchedAt != null &&
            now.difference(fetchedAt) <= _interactionStateTtl) {
          continue;
        }
      }
      targets.add(post);
      if (targets.length >= 100) break;
    }
    if (targets.isEmpty) return;

    for (final post in targets) {
      _postStateInflight[post.id] = true;
    }
    final requestEpoch = _authEpoch;
    try {
      final batch = await _api.getCommunityInteractionStates(
        postIds: targets.map((post) => post.id).toList(growable: false),
      );
      if (requestEpoch != _authEpoch) return;
      final fetchedAt = DateTime.now();
      var changed = false;
      for (final post in targets) {
        final state = batch.posts[post.id];
        if (state == null) continue;
        _postStates[post.id] = state;
        _postStateFetchedAt[post.id] = fetchedAt;
        final nextLikeCount = state.likeCount ?? post.likeCount;
        final nextCommentCount = state.commentCount ?? post.commentCount;
        final nextBookmark = state.isBookmarked ?? post.isBookmarked;
        if (post.isLiked != state.isLiked ||
            post.likeCount != nextLikeCount ||
            post.commentCount != nextCommentCount ||
            post.isBookmarked != nextBookmark) {
          post.isLiked = state.isLiked;
          post.likeCount = nextLikeCount;
          post.commentCount = nextCommentCount;
          post.isBookmarked = nextBookmark;
          changed = true;
        }
      }
      if (changed) notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CommunityInteractionsProvider.refreshPostStates: $e');
      }
    } finally {
      for (final post in targets) {
        _postStateInflight.remove(post.id);
      }
    }
  }

  Future<void> prefetchForPosts(
    Iterable<CommunityPost> posts, {
    CommunityCommentsProvider? commentsProvider,
    int commentsLimit = 8,
    int likesLimit = 25,
  }) async {
    final list = posts.where((post) => post.id.trim().isNotEmpty).toList();
    if (list.isEmpty) return;

    hydratePostsFromServer(list);
    unawaited(refreshPostStates(list));

    if (commentsProvider != null) {
      for (final post in list.take(commentsLimit)) {
        unawaited(commentsProvider.loadComments(post.id));
      }
    }

    for (final post
        in list.where((post) => post.likeCount > 0).take(likesLimit)) {
      unawaited(loadPostLikes(post.id));
    }
  }

  Future<void> togglePostLike(CommunityPost post) async {
    final previousLiked = post.isLiked;
    final previousCount = post.likeCount;

    post.isLiked = !previousLiked;
    post.likeCount =
        (post.likeCount + (post.isLiked ? 1 : -1)).clamp(0, 1 << 30).toInt();
    applyServerPostState(post);
    notifyListeners();

    try {
      final updatedCount = post.isLiked
          ? await _api.likePost(post.id)
          : await _api.unlikePost(post.id);
      if (updatedCount != null && post.likeCount != updatedCount) {
        post.likeCount = updatedCount;
      }
      applyServerPostState(post);
      _postLikeFetchedAt.remove(post.id);
      _postLikeUsers.remove(post.id);
      notifyListeners();
    } catch (e) {
      post.isLiked = previousLiked;
      post.likeCount = previousCount;
      applyServerPostState(post);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleCommentLike({
    required String postId,
    required Comment comment,
  }) async {
    if (postId.trim().isEmpty) return;
    final previousLiked = comment.isLiked;
    final previousCount = comment.likeCount;

    comment.isLiked = !previousLiked;
    comment.likeCount = (comment.likeCount + (comment.isLiked ? 1 : -1))
        .clamp(0, 1 << 30)
        .toInt();
    notifyListeners();

    try {
      final updatedCount = comment.isLiked
          ? await _api.likeComment(comment.id)
          : await _api.unlikeComment(comment.id);
      if (updatedCount != null) {
        comment.likeCount = updatedCount;
      }
      _commentLikeFetchedAt.remove(comment.id);
      _commentLikeUsers.remove(comment.id);
      notifyListeners();
    } catch (e) {
      comment.isLiked = previousLiked;
      comment.likeCount = previousCount;
      notifyListeners();
      rethrow;
    }
  }

  Future<List<CommunityLikeUser>> loadPostLikes(
    String postId, {
    bool force = false,
  }) {
    final cached = _postLikeUsers[postId];
    final fetchedAt = _postLikeFetchedAt[postId];
    if (!force &&
        cached != null &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) <= _likeListTtl) {
      return Future.value(cached);
    }

    final inFlight = _postLikeFutures[postId];
    if (!force && inFlight != null) return inFlight;

    final requestEpoch = _authEpoch;
    final future = _api.getPostLikes(postId).then((users) {
      if (requestEpoch == _authEpoch) {
        _postLikeUsers[postId] = users;
        _postLikeFetchedAt[postId] = DateTime.now();
        notifyListeners();
      }
      return users;
    }).whenComplete(() {
      _postLikeFutures.remove(postId);
    });
    _postLikeFutures[postId] = future;
    return future;
  }

  Future<List<CommunityLikeUser>> loadCommentLikes(
    String commentId, {
    bool force = false,
  }) {
    final cached = _commentLikeUsers[commentId];
    final fetchedAt = _commentLikeFetchedAt[commentId];
    if (!force &&
        cached != null &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) <= _likeListTtl) {
      return Future.value(cached);
    }

    final inFlight = _commentLikeFutures[commentId];
    if (!force && inFlight != null) return inFlight;

    final requestEpoch = _authEpoch;
    final future = _api.getCommentLikes(commentId).then((users) {
      if (requestEpoch == _authEpoch) {
        _commentLikeUsers[commentId] = users;
        _commentLikeFetchedAt[commentId] = DateTime.now();
        notifyListeners();
      }
      return users;
    }).whenComplete(() {
      _commentLikeFutures.remove(commentId);
    });
    _commentLikeFutures[commentId] = future;
    return future;
  }

  void _handleWalletMaybeChanged() {
    _walletDebounce?.cancel();
    _walletDebounce = Timer(const Duration(milliseconds: 120), () {
      final nextWallet =
          _normalizedWallet(_walletProvider?.currentWalletAddress);
      if (nextWallet == _boundWallet) return;
      _boundWallet = nextWallet;
      _authEpoch += 1;
      _clearHydratedInteractionState();
      notifyListeners();
    });
  }

  void _clearHydratedInteractionState() {
    _postStates.clear();
    _postStateFetchedAt.clear();
    _postStateInflight.clear();
    _postLikeFutures.clear();
    _postLikeUsers.clear();
    _postLikeFetchedAt.clear();
    _commentLikeFutures.clear();
    _commentLikeUsers.clear();
    _commentLikeFetchedAt.clear();
  }

  String? _normalizedWallet(String? wallet) {
    final trimmed = wallet?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.toLowerCase();
  }
}
