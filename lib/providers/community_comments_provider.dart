import 'dart:async';

import 'package:flutter/foundation.dart';

import '../community/community_interactions.dart' show Comment;
import '../services/account_identity.dart';
import '../services/backend_api_service.dart';
import 'wallet_provider.dart';

class CommunityCommentsProvider extends ChangeNotifier {
  CommunityCommentsProvider({BackendApiService? api})
      : _api = api ?? BackendApiService() {
    AccountIdentity.addListener(_handleAccountIdentityChanged);
  }

  final BackendApiService _api;
  WalletProvider? _walletProvider;
  String? _boundWallet;
  Timer? _walletDebounce;
  int _authEpoch = 0;
  String _heldAccountKey = AccountIdentity.accountKey;

  final Map<String, List<Comment>> _commentsByPostId =
      <String, List<Comment>>{};
  final Map<String, bool> _loadingByPostId = <String, bool>{};
  final Map<String, String?> _errorByPostId = <String, String?>{};

  bool isLoading(String postId) => _loadingByPostId[postId] ?? false;
  String? errorForPost(String postId) => _errorByPostId[postId];
  bool hasLoadedComments(String postId) =>
      _commentsByPostId.containsKey(postId);

  List<Comment> commentsForPost(String postId) =>
      List.unmodifiable(_commentsByPostId[postId] ?? const <Comment>[]);

  int totalCountForPost(String postId) {
    final roots = _commentsByPostId[postId];
    if (roots == null || roots.isEmpty) return 0;
    return _countWithReplies(roots);
  }

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
    AccountIdentity.removeListener(_handleAccountIdentityChanged);
    super.dispose();
  }

  Future<void> loadComments(
    String postId, {
    bool force = false,
    int page = 1,
    int limit = 200,
  }) async {
    if (postId.trim().isEmpty) return;
    if (!force && isLoading(postId)) return;
    if (!force && _commentsByPostId.containsKey(postId)) return;

    if (kDebugMode) {
      debugPrint(
          'CommunityCommentsProvider: load comments postId=$postId page=$page limit=$limit force=$force');
    }

    _loadingByPostId[postId] = true;
    _errorByPostId[postId] = null;
    notifyListeners();

    final requestEpoch = _captureAuthEpoch();
    try {
      final comments =
          await _api.getComments(postId: postId, page: page, limit: limit);
      if (requestEpoch != _authEpoch) return;
      _commentsByPostId[postId] = comments;
    } catch (e) {
      if (requestEpoch != _authEpoch) return;
      _errorByPostId[postId] = e.toString();
    } finally {
      if (requestEpoch == _authEpoch) {
        _loadingByPostId[postId] = false;
        notifyListeners();
      }
    }
  }

  Future<void> addComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    if (postId.trim().isEmpty) return;
    if (content.trim().isEmpty) return;

    try {
      await _api.createComment(
        postId: postId,
        content: content.trim(),
        parentCommentId:
            (parentCommentId != null && parentCommentId.trim().isNotEmpty)
                ? parentCommentId.trim()
                : null,
      );
    } finally {
      // Always reload to ensure nested structure + avatar/name enrichment.
      await loadComments(postId, force: true);
    }
  }

  Future<void> editComment({
    required String postId,
    required String commentId,
    required String content,
  }) async {
    if (postId.trim().isEmpty) return;
    if (commentId.trim().isEmpty) return;
    if (content.trim().isEmpty) return;

    try {
      await _api.editComment(commentId: commentId, content: content.trim());
    } finally {
      await loadComments(postId, force: true);
    }
  }

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    if (postId.trim().isEmpty) return;
    if (commentId.trim().isEmpty) return;

    try {
      await _api.deleteComment(commentId);
    } finally {
      await loadComments(postId, force: true);
    }
  }

  int _countWithReplies(List<Comment> roots) {
    int total = 0;
    for (final c in roots) {
      total++;
      if (c.replies.isNotEmpty) {
        total += _countWithReplies(c.replies);
      }
    }
    return total;
  }

  void _handleWalletMaybeChanged() {
    _walletDebounce?.cancel();
    _walletDebounce = Timer(const Duration(milliseconds: 120), () {
      final nextWallet =
          _normalizedWallet(_walletProvider?.currentWalletAddress);
      if (nextWallet == _boundWallet) return;
      _boundWallet = nextWallet;
      _clearAccountState();
    });
  }

  void _handleAccountIdentityChanged() {
    _walletDebounce?.cancel();
    _boundWallet = _normalizedWallet(_walletProvider?.currentWalletAddress);
    // A same-account change (wallet link, re-issued token) keeps the comments.
    final key = AccountIdentity.accountKey;
    if (key.isNotEmpty && key == _heldAccountKey) return;
    _clearAccountState();
  }

  /// Starts a request under the current account. Its response is applied only
  /// while the account is unchanged, so the held account is recorded here.
  int _captureAuthEpoch() {
    _heldAccountKey = AccountIdentity.accountKey;
    return _authEpoch;
  }

  void _clearAccountState() {
    _authEpoch += 1;
    _commentsByPostId.clear();
    _loadingByPostId.clear();
    _errorByPostId.clear();
    notifyListeners();
  }

  String? _normalizedWallet(String? wallet) {
    final trimmed = wallet?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.toLowerCase();
  }
}
