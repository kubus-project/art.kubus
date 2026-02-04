import 'package:flutter/foundation.dart';

import 'user_action_service.dart';
import '../utils/creator_display_format.dart';

/// Centralized helper for writing the current user's actions to the
/// [UserActionService] so they surface inside the unified recent activity feed.
class UserActionLogger {
  UserActionLogger._();

  static final UserActionService _service = UserActionService();

  /// Record that the current user liked a community post.
  static Future<void> logPostLike({
    required String postId,
    String? authorId,
    String? authorName,
    String? postContent,
  }) async {
    final title = 'You liked ${_safeDisplayName(authorName, fallback: 'a post')}';
    await _record(
      type: 'like',
      idPrefix: 'post_like',
      targetId: postId,
      title: title,
      description: _truncate(postContent),
      metadata: {
        'postId': postId,
        'targetId': postId,
        'targetType': 'post',
        if (postContent != null && postContent.trim().isNotEmpty) 'targetTitle': postContent,
        if (authorId != null) 'authorId': authorId,
        if (authorName != null) 'authorName': authorName,
        'actionUrl': 'app://community/posts/$postId',
      },
    );
  }

  /// Record that the current user published a new community post.
  static Future<void> logPostCreated({
    required String postId,
    required String content,
    List<String>? mediaUrls,
  }) async {
    final preview = _truncate(content, maxLength: 140);
    await _record(
      type: 'post_create',
      idPrefix: 'post_create',
      targetId: postId,
      title: 'You posted a new update',
      description: preview,
      metadata: {
        'postId': postId,
        'targetId': postId,
        'targetType': 'post',
        'actionUrl': 'app://community/posts/$postId',
        if (preview.isNotEmpty) 'contentPreview': preview,
        if (mediaUrls != null && mediaUrls.isNotEmpty) 'mediaUrls': mediaUrls,
      },
    );
  }

  /// Record that the current user commented on a community post.
  static Future<void> logPostComment({
    required String postId,
    required String commentId,
    required String commentContent,
    String? postAuthorName,
    bool isReply = false,
  }) async {
    final preview = _truncate(commentContent, maxLength: 140);
    final title = isReply
        ? 'You replied to a comment'
        : 'You commented on ${postAuthorName != null ? _safeDisplayName(postAuthorName, fallback: 'a post') : 'a post'}';
    await _record(
      type: 'comment',
      idPrefix: 'comment_create',
      targetId: commentId,
      title: title,
      description: preview,
      metadata: {
        'postId': postId,
        'targetId': postId,
        'targetType': 'post',
        'commentId': commentId,
        'actionUrl': 'app://community/posts/$postId?commentId=$commentId',
        if (preview.isNotEmpty) 'commentPreview': preview,
        if (postAuthorName != null) 'postAuthorName': postAuthorName,
        if (isReply) 'isReply': true,
      },
    );
  }

  /// Record that the current user saved/bookmarked a community post (or
  /// converted artwork) for later.
  static Future<void> logPostSave({
    required String postId,
    String? postContent,
    String? authorName,
  }) async {
    final targetTitle = _safeDisplayName(postContent, fallback: 'this post');
    await _record(
      type: 'save',
      idPrefix: 'post_save',
      targetId: postId,
      title: 'Saved $targetTitle',
      description: _truncate(authorName),
      metadata: {
        'postId': postId,
        'targetId': postId,
        'targetType': 'post',
        if (postContent != null && postContent.trim().isNotEmpty) 'targetTitle': postContent,
        if (authorName != null) 'authorName': authorName,
        'actionUrl': 'app://community/posts/$postId',
      },
    );
  }

  /// Record that the current user liked an artwork in AR or gallery contexts.
  static Future<void> logArtworkLike({
    required String artworkId,
    required String artworkTitle,
    String? artistName,
  }) async {
    final title = 'You liked ${_quoteIfNeeded(artworkTitle)}';
    await _record(
      type: 'like',
      idPrefix: 'artwork_like',
      targetId: artworkId,
      title: title,
      description: _truncate(artistName),
      metadata: {
        'artworkId': artworkId,
        'targetId': artworkId,
        'targetType': 'artwork',
        'artworkTitle': artworkTitle,
        if (artistName != null && artistName.trim().isNotEmpty) 'artistName': artistName,
        'actionUrl': 'app://artworks/$artworkId',
      },
    );
  }

  /// Record that the current user saved/favorited an artwork.
  static Future<void> logArtworkSave({
    required String artworkId,
    required String artworkTitle,
    String? artistName,
  }) async {
    final title = 'Saved ${_quoteIfNeeded(artworkTitle)}';
    await _record(
      type: 'save',
      idPrefix: 'artwork_save',
      targetId: artworkId,
      title: title,
      description: _truncate(artistName),
      metadata: {
        'artworkId': artworkId,
        'targetId': artworkId,
        'targetType': 'artwork',
        'artworkTitle': artworkTitle,
        if (artistName != null && artistName.trim().isNotEmpty) 'artistName': artistName,
        'actionUrl': 'app://artworks/$artworkId',
      },
    );
  }

  /// Record that the current user viewed an artwork (used for history/analytics).
  static Future<void> logArtworkView({
    required String artworkId,
    String? artworkTitle,
    String? markerId,
  }) async {
    final title = 'Viewed ${_quoteIfNeeded(artworkTitle ?? 'an artwork')}';
    await _record(
      type: 'view',
      idPrefix: 'artwork_view',
      targetId: artworkId,
      title: title,
      description: artworkTitle,
      metadata: {
        'artworkId': artworkId,
        'targetId': artworkId,
        'targetType': 'artwork',
        if (artworkTitle != null && artworkTitle.trim().isNotEmpty) 'artworkTitle': artworkTitle,
        if (markerId != null && markerId.isNotEmpty) 'markerId': markerId,
        'actionUrl': 'app://artworks/$artworkId',
      },
    );
  }

  /// Record that the current user followed another profile.
  static Future<void> logFollow({
    required String walletAddress,
    String? displayName,
    String? username,
    String? avatarUrl,
  }) async {
    final formatted = CreatorDisplayFormat.format(
      fallbackLabel: _shortWallet(walletAddress),
      displayName: displayName,
      username: username,
      wallet: walletAddress,
    );
    final targetName = formatted.primary;
    await _record(
      type: 'follow',
      idPrefix: 'follow',
      targetId: walletAddress,
      title: 'You followed $targetName',
      description: formatted.secondary,
      metadata: {
        'userId': walletAddress,
        'targetWallet': walletAddress,
        'targetType': 'profile',
        'targetTitle': targetName,
        if (displayName != null) 'displayName': displayName,
        if (username != null) 'username': username,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'actionUrl': 'app://profile/$walletAddress',
      },
    );
  }

  static Future<void> _record({
    required String type,
    required String idPrefix,
    required String targetId,
    required String title,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final entry = UserActionEntry(
      id: _buildId(idPrefix, targetId),
      type: type,
      title: title,
      description: description,
      timestamp: DateTime.now(),
      metadata: metadata,
      isRead: true,
    );

    try {
      await _service.recordAction(entry);
    } catch (e, st) {
      debugPrint('UserActionLogger failed to record $type: $e\n$st');
    }
  }

  static String _buildId(String prefix, String targetId) {
    final sanitizedTarget = targetId.isEmpty ? 'unknown' : targetId;
    return '${prefix}_${sanitizedTarget}_${DateTime.now().microsecondsSinceEpoch}';
  }

  static String _safeDisplayName(String? value, {required String fallback}) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return fallback;
    }
    return trimmed;
  }

  static String _truncate(String? value, {int maxLength = 80}) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '';
    }
    if (trimmed.length <= maxLength) {
      return trimmed;
    }
    return '${trimmed.substring(0, maxLength - 1)}…';
  }

  static String _quoteIfNeeded(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'this item';
    }
    if (trimmed.startsWith('"') || trimmed.startsWith('\'')) {
      return trimmed;
    }
    return '"$trimmed"';
  }

  static String _shortWallet(String value) {
    if (value.length <= 8) {
      return value;
    }
    return '${value.substring(0, 4)}…${value.substring(value.length - 4)}';
  }
}
