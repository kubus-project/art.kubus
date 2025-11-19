import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config.dart';
import '../services/backend_api_service.dart';

// Enhanced community interaction models
class CommunityPost {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String? authorUsername;
  final String content;
  final String? imageUrl;
  final DateTime timestamp;
  final List<String> tags;
  int likeCount;
  int commentCount;
  int shareCount;
  int viewCount;
  bool isLiked;
  bool isBookmarked;
  bool isFollowing;
  List<Comment> comments;

  CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.authorUsername,
    required this.content,
    this.imageUrl,
    required this.timestamp,
    this.tags = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.viewCount = 0,
    this.isLiked = false,
    this.isBookmarked = false,
    this.isFollowing = false,
    this.comments = const [],
  });

  CommunityPost copyWith({
    int? likeCount,
    int? shareCount,
    int? viewCount,
    bool? isLiked,
    bool? isBookmarked,
    bool? isFollowing,
    List<Comment>? comments,
    int? commentCount,
    String? authorAvatar,
    String? authorUsername,
  }) {
    return CommunityPost(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      authorUsername: authorUsername ?? this.authorUsername,
      content: content,
      imageUrl: imageUrl,
      timestamp: timestamp,
      tags: tags,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      viewCount: viewCount ?? this.viewCount,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isFollowing: isFollowing ?? this.isFollowing,
      comments: comments ?? this.comments,
    );
  }
}

class Comment {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String? authorUsername;
  final String? authorWallet;
  final String? parentCommentId;
  String content; // Made mutable for editing
  final DateTime timestamp;
  int likeCount;
  bool isLiked;
  List<Comment> replies;

  Comment({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.authorUsername,
    this.authorWallet,
    this.parentCommentId,
    required this.content,
    required this.timestamp,
    this.likeCount = 0,
    this.isLiked = false,
    List<Comment>? replies,
  }) : replies = replies ?? <Comment>[];

  Comment copyWith({
    int? likeCount,
    bool? isLiked,
    String? authorAvatar,
    String? authorUsername,
    String? content,
    List<Comment>? replies,
  }) {
    return Comment(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      authorUsername: authorUsername ?? this.authorUsername,
      authorWallet: authorWallet,
      parentCommentId: parentCommentId,
      content: content ?? this.content,
      timestamp: timestamp,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      replies: replies ?? List<Comment>.from(this.replies),
    );
  }
}

// Community interaction service
class CommunityService {
  static const String _likesKey = 'community_likes';
  static const String _commentsKey = 'community_comments';
  static const String _sharesKey = 'community_shares';
  static const String _bookmarksKey = 'community_bookmarks';
  static const String _followsKey = 'community_follows';
  static const String _viewsKey = 'community_views';
  static const String _likeCountsKey = 'community_like_counts';

  // Like/Unlike post (with backend sync)
  static Future<void> togglePostLike(CommunityPost post, {String? currentUserId, String? currentUserName, String? currentUserWallet}) async {
    if (!AppConfig.enableLiking) return;

    final prefs = await SharedPreferences.getInstance();
    final likedPosts = prefs.getStringList(_likesKey) ?? [];
    final likeCounts = prefs.getStringList(_likeCountsKey) ?? [];
    final backendApi = BackendApiService();
    // Local notification service removed for actor-side; server will notify recipients.

      // Store original state for rollback
      final originalIsLiked = post.isLiked;
      final originalLikeCount = post.likeCount;

      // If UI did not pre-toggle, toggle here: flip the like state and adjust count
      final toggledToLiked = !post.isLiked;
      post.isLiked = toggledToLiked;
      post.likeCount = (post.likeCount + (toggledToLiked ? 1 : -1)).clamp(0, 1 << 30);

      // Persist local liked posts list
      if (post.isLiked) {
        if (!likedPosts.contains(post.id)) likedPosts.add(post.id);
      } else {
        likedPosts.remove(post.id);
      }

      // Update like counts persistence
      likeCounts.removeWhere((item) => item.startsWith('${post.id}|'));
      likeCounts.add('${post.id}|${post.likeCount}');

      await prefs.setStringList(_likesKey, likedPosts);
      await prefs.setStringList(_likeCountsKey, likeCounts);

      if (AppConfig.enableDebugPrints) {
        debugPrint('Post ${post.id} ${post.isLiked ? "liked" : "unliked"}. Total likes: ${post.likeCount}');
      }

    // Sync with backend (optimistic update)
    try {
      // Accept either explicit id or wallet param passed from UI
      // Effective user ID not needed here; server-side notifications to recipients will be handled by backend.
      if (post.isLiked) {
        await backendApi.likePost(post.id);
        // Server will create and emit a notification to the post author. No local push is required here for the actor.
      } else {
        await backendApi.unlikePost(post.id);
      }
    } catch (e) {
      // Rollback on error
      if (AppConfig.enableDebugPrints) {
        debugPrint('Failed to sync like with backend: $e. Rolling back.');
      }
      
      post.isLiked = originalIsLiked;
      post.likeCount = originalLikeCount;
      
      // Rollback local storage
      if (originalIsLiked) {
        if (!likedPosts.contains(post.id)) likedPosts.add(post.id);
      } else {
        likedPosts.remove(post.id);
      }
      
      likeCounts.removeWhere((item) => item.startsWith('${post.id}|'));
      likeCounts.add('${post.id}|$originalLikeCount');
      
      await prefs.setStringList(_likesKey, likedPosts);
      await prefs.setStringList(_likeCountsKey, likeCounts);
    }
  }

  // Like/Unlike comment
  static Future<void> toggleCommentLike(Comment comment, String postId) async {
    if (!AppConfig.enableLiking) return;

    final prefs = await SharedPreferences.getInstance();
    final likesKey = '${_likesKey}_comments';
    final likedComments = prefs.getStringList(likesKey) ?? [];
    final commentKey = '${postId}|${comment.id}';
    final backendApi = BackendApiService();

    final wasLiked = comment.isLiked;
    final originalCount = comment.likeCount;

    if (wasLiked) {
      likedComments.remove(commentKey);
      comment.likeCount = (comment.likeCount - 1).clamp(0, double.infinity).toInt();
      comment.isLiked = false;
    } else {
      if (!likedComments.contains(commentKey)) likedComments.add(commentKey);
      comment.likeCount++;
      comment.isLiked = true;
    }

    await prefs.setStringList(likesKey, likedComments);

    try {
      if (comment.isLiked) {
        await backendApi.likeComment(comment.id);
      } else {
        await backendApi.unlikeComment(comment.id);
      }
    } catch (e) {
      // Roll back state and persistence on failure
      if (comment.isLiked) {
        comment.likeCount = (comment.likeCount - 1).clamp(0, double.infinity).toInt();
        likedComments.remove(commentKey);
      } else {
        comment.likeCount = originalCount;
        if (!likedComments.contains(commentKey)) likedComments.add(commentKey);
      }
      comment.isLiked = wasLiked;
      comment.likeCount = originalCount;
      await prefs.setStringList(likesKey, likedComments);
      rethrow;
    }
  }

  // Add comment to post (with backend sync)
  static Future<Comment> addComment(
    CommunityPost post,
    String content,
    String authorName, {
    String? currentUserId,
    String? parentCommentId,
  }) async {
    if (!AppConfig.enableCommenting) throw Exception('Commenting is disabled');

    final backendApi = BackendApiService();

    // Optimistic UI update
    final tempComment = Comment(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      authorId: currentUserId ?? 'current_user',
      authorName: authorName,
      parentCommentId: parentCommentId,
      content: content,
      timestamp: DateTime.now(),
      replies: <Comment>[],
    );

    if (parentCommentId == null || parentCommentId.isEmpty) {
      post.comments = [...post.comments, tempComment];
    } else {
      final inserted = _appendReply(post.comments, parentCommentId, tempComment);
      if (!inserted) {
        // Fallback to root insertion if parent isn't present locally yet
        post.comments = [...post.comments, tempComment];
      }
    }
    post.commentCount = _countComments(post.comments);

    try {
      // Create comment on backend
      final backendComment = await backendApi.createComment(
        postId: post.id,
        content: content,
        parentCommentId: parentCommentId,
      );

      final replaced = _replaceComment(post.comments, tempComment.id, backendComment);
      if (!replaced) {
        // If we somehow lost the temp comment reference, append freshly fetched one
        if (parentCommentId == null || parentCommentId.isEmpty) {
          post.comments = [...post.comments.where((c) => c.id != backendComment.id), backendComment];
        } else {
          final inserted = _appendReply(post.comments, parentCommentId, backendComment);
          if (!inserted) post.comments = [...post.comments, backendComment];
        }
      }
      post.commentCount = _countComments(post.comments);

      // Save to local preferences for persistence
      final prefs = await SharedPreferences.getInstance();
      final commentsData = prefs.getStringList('${_commentsKey}_${post.id}') ?? [];
      commentsData.add('${backendComment.id}|${backendComment.authorName}|${backendComment.content}|${backendComment.timestamp.millisecondsSinceEpoch}');
      await prefs.setStringList('${_commentsKey}_${post.id}', commentsData);

      if (AppConfig.enableDebugPrints) {
        debugPrint('Comment added to post ${post.id}. Total comments: ${post.commentCount}');
      }

      // Server will create notification for the post author; client-side push is not shown for actor.

      return backendComment;
    } catch (e) {
      // Rollback on error
      if (AppConfig.enableDebugPrints) {
        debugPrint('Failed to create comment on backend: $e. Rolling back.');
      }
      
      _removeComment(post.comments, tempComment.id);
      post.commentCount = _countComments(post.comments);
      
      rethrow;
    }
  }

  static bool _appendReply(List<Comment> comments, String parentId, Comment reply) {
    for (final comment in comments) {
      if (comment.id == parentId) {
        comment.replies = [...comment.replies, reply];
        return true;
      }
      if (comment.replies.isNotEmpty) {
        final inserted = _appendReply(comment.replies, parentId, reply);
        if (inserted) return true;
      }
    }
    return false;
  }

  static bool _replaceComment(List<Comment> comments, String targetId, Comment replacement) {
    for (var i = 0; i < comments.length; i++) {
      if (comments[i].id == targetId) {
        comments[i] = replacement;
        return true;
      }
      if (comments[i].replies.isNotEmpty) {
        final replaced = _replaceComment(comments[i].replies, targetId, replacement);
        if (replaced) return true;
      }
    }
    return false;
  }

  static bool _removeComment(List<Comment> comments, String targetId) {
    for (var i = 0; i < comments.length; i++) {
      if (comments[i].id == targetId) {
        comments.removeAt(i);
        return true;
      }
      if (comments[i].replies.isNotEmpty) {
        final removed = _removeComment(comments[i].replies, targetId);
        if (removed) return true;
      }
    }
    return false;
  }

  static int _countComments(List<Comment> comments) {
    int total = comments.length;
    for (final comment in comments) {
      if (comment.replies.isNotEmpty) total += _countComments(comment.replies);
    }
    return total;
  }

  // Load saved interactions
  static Future<void> loadSavedInteractions(List<CommunityPost> posts) async {
    final prefs = await SharedPreferences.getInstance();
    final likedPosts = prefs.getStringList(_likesKey) ?? [];
    final likedComments = prefs.getStringList('${_likesKey}_comments') ?? [];
    final bookmarkedPosts = prefs.getStringList(_bookmarksKey) ?? [];
    final followedUsers = prefs.getStringList(_followsKey) ?? [];
    final likeCounts = prefs.getStringList(_likeCountsKey) ?? [];

    // Create a map for quick like count lookup
    final likeCountMap = <String, int>{};
    for (final countString in likeCounts) {
      final parts = countString.split('|');
      if (parts.length == 2) {
        likeCountMap[parts[0]] = int.tryParse(parts[1]) ?? 0;
      }
    }

    for (final post in posts) {
      // Load likes
      post.isLiked = likedPosts.contains(post.id);
      
      // Load like counts (override original mock data with saved counts)
      if (likeCountMap.containsKey(post.id)) {
        post.likeCount = likeCountMap[post.id]!;
      }
      
      // Load bookmarks
      post.isBookmarked = bookmarkedPosts.contains(post.id);
      
      // Load follows
      post.isFollowing = followedUsers.contains(post.authorId);

      // Load comments
      final commentsData = prefs.getStringList('${_commentsKey}_${post.id}') ?? [];
      final loadedComments = <Comment>[];

      for (final commentString in commentsData) {
        final parts = commentString.split('|');
        if (parts.length >= 4) {
          final comment = Comment(
            id: parts[0],
            authorId: 'saved_user',
            authorName: parts[1],
            content: parts[2],
            timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[3])),
          );

          // Check if comment is liked
          final commentKey = '${post.id}|${comment.id}';
          comment.isLiked = likedComments.contains(commentKey);

          loadedComments.add(comment);
        }
      }

      post.comments = [...post.comments, ...loadedComments];
      for (final comment in post.comments) {
        final commentKey = '${post.id}|${comment.id}';
        if (likedComments.contains(commentKey)) {
          comment.isLiked = true;
        }
      }
      post.commentCount = post.comments.length;
    }
  }

  // Note: Mock post generator removed. Use BackendApiService.getCommunityPosts instead.

  // Report post (community moderation)
  static Future<void> reportPost(CommunityPost post, String reason) async {
    if (!AppConfig.enableReporting) return;

    final prefs = await SharedPreferences.getInstance();
    final reports = prefs.getStringList('reported_posts') ?? [];
    final reportData = '${post.id}|$reason|${DateTime.now().millisecondsSinceEpoch}';
    
    if (!reports.contains(reportData)) {
      reports.add(reportData);
      await prefs.setStringList('reported_posts', reports);
      
      if (AppConfig.enableDebugPrints) {
        debugPrint('Post ${post.id} reported for: $reason');
      }
    }
  }

  // Bookmark/Unbookmark post
  static Future<void> toggleBookmark(CommunityPost post) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarkedPosts = prefs.getStringList(_bookmarksKey) ?? [];

    if (post.isBookmarked) {
      // Remove bookmark
      bookmarkedPosts.remove(post.id);
      post.isBookmarked = false;
    } else {
      // Add bookmark
      bookmarkedPosts.add(post.id);
      post.isBookmarked = true;
    }

    await prefs.setStringList(_bookmarksKey, bookmarkedPosts);
    
    if (AppConfig.enableDebugPrints) {
      debugPrint('Post ${post.id} ${post.isBookmarked ? "bookmarked" : "unbookmarked"}');
    }
  }

  // Follow/Unfollow user (with backend sync)
  static Future<void> toggleFollow(
    String userId,
    CommunityPost? post, {
    String? currentUserName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final followedUsers = prefs.getStringList(_followsKey) ?? [];
    final backendApi = BackendApiService();

    bool isFollowing = followedUsers.contains(userId);
    bool originalFollowState = isFollowing;

    // Optimistic update
    if (isFollowing) {
      // Unfollow
      followedUsers.remove(userId);
      if (post != null) post.isFollowing = false;
    } else {
      // Follow
      followedUsers.add(userId);
      if (post != null) post.isFollowing = true;
    }

    await prefs.setStringList(_followsKey, followedUsers);
    
    if (AppConfig.enableDebugPrints) {
      debugPrint('User $userId ${!isFollowing ? "followed" : "unfollowed"}');
    }

    // Sync with backend
    try {
      if (!originalFollowState) {
        // Was unfollowed, now following
        await backendApi.followUser(userId);
        // Server will emit follower notification to the followed user; no local push for actor.
      } else {
        // Was following, now unfollowing
        await backendApi.unfollowUser(userId);
      }
    } catch (e) {
      // Rollback on error
      if (AppConfig.enableDebugPrints) {
        debugPrint('Failed to sync follow with backend: $e. Rolling back.');
      }
      
      if (originalFollowState) {
        // Restore to following
        if (!followedUsers.contains(userId)) followedUsers.add(userId);
        if (post != null) post.isFollowing = true;
      } else {
        // Restore to not following
        followedUsers.remove(userId);
        if (post != null) post.isFollowing = false;
      }
      
      await prefs.setStringList(_followsKey, followedUsers);
    }
  }

  // Check if user is followed
  static Future<bool> isUserFollowed(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final followedUsers = prefs.getStringList(_followsKey) ?? [];
    return followedUsers.contains(userId);
  }

  // Track post views
  static Future<void> trackPostView(CommunityPost post) async {
    final prefs = await SharedPreferences.getInstance();
    final viewedPosts = prefs.getStringList(_viewsKey) ?? [];
    final viewKey = '${post.id}_${DateTime.now().day}'; // Track daily views

    if (!viewedPosts.contains(viewKey)) {
      viewedPosts.add(viewKey);
      post.viewCount++;
      await prefs.setStringList(_viewsKey, viewedPosts);
      
      if (AppConfig.enableDebugPrints) {
        debugPrint('Post ${post.id} viewed. Total views: ${post.viewCount}');
      }
    }
  }

  // Get bookmarked posts
  static Future<List<String>> getBookmarkedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_bookmarksKey) ?? [];
  }

  // Get followed users
  static Future<List<String>> getFollowedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_followsKey) ?? [];
  }

  // Share post functionality (enhanced with backend sync)
  static Future<void> sharePost(CommunityPost post, {String? currentUserName}) async {
    if (!AppConfig.enableSharing) return;

    final prefs = await SharedPreferences.getInstance();
    final sharedPosts = prefs.getStringList(_sharesKey) ?? [];
    final shareKey = '${post.id}_${DateTime.now().millisecondsSinceEpoch}';
    final backendApi = BackendApiService();
    
    // Optimistic update
    sharedPosts.add(shareKey);
    final originalShareCount = post.shareCount;
    post.shareCount++;
    await prefs.setStringList(_sharesKey, sharedPosts);

    // In a real app, this would integrate with platform sharing
    final shareText = '${post.content}\n\n- ${post.authorName} on art.kubus';
    
    if (AppConfig.enableDebugPrints) {
      debugPrint('Sharing post: $shareText');
      debugPrint('Post ${post.id} shared. Total shares: ${post.shareCount}');
    }

    // Sync with backend
    try {
      await backendApi.sharePost(post.id);
      
      // Server will create and emit notification to the post author. No local push for actor.
    } catch (e) {
      // Rollback on error
      if (AppConfig.enableDebugPrints) {
        debugPrint('Failed to sync share with backend: $e. Rolling back.');
      }
      
      sharedPosts.remove(shareKey);
      post.shareCount = originalShareCount;
      await prefs.setStringList(_sharesKey, sharedPosts);
    }
    
    // Mock sharing action
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // Delete comment
  static Future<void> deleteComment(CommunityPost post, String commentId) async {
    post.comments.removeWhere((comment) => comment.id == commentId);
    post.commentCount = post.comments.length;

    // Update persistence
    final prefs = await SharedPreferences.getInstance();
    final commentsData = post.comments.map((comment) =>
        '${comment.id}|${comment.authorName}|${comment.content}|${comment.timestamp.millisecondsSinceEpoch}').toList();
    await prefs.setStringList('${_commentsKey}_${post.id}', commentsData);

    if (AppConfig.enableDebugPrints) {
      debugPrint('Comment $commentId deleted from post ${post.id}');
    }
  }

  // Edit comment
  static Future<void> editComment(Comment comment, String newContent) async {
    // Note: In a real app, you'd want to track edit history
    comment.content = newContent;
    
    if (AppConfig.enableDebugPrints) {
      debugPrint('Comment ${comment.id} edited');
    }
  }

  // Get post analytics
  static Map<String, dynamic> getPostAnalytics(CommunityPost post) {
    final engagementRate = post.viewCount > 0 
        ? ((post.likeCount + post.commentCount + post.shareCount) / post.viewCount * 100).toStringAsFixed(1)
        : '0.0';

    return {
      'likes': post.likeCount,
      'comments': post.commentCount,
      'shares': post.shareCount,
      'views': post.viewCount,
      'engagementRate': '$engagementRate%',
      'timestamp': post.timestamp.toIso8601String(),
    };
  }

  // Search posts by content or tags
  static List<CommunityPost> searchPosts(List<CommunityPost> posts, String query) {
    if (query.isEmpty) return posts;
    
    final lowercaseQuery = query.toLowerCase();
    return posts.where((post) {
      final matchesContent = post.content.toLowerCase().contains(lowercaseQuery);
      final matchesAuthor = post.authorName.toLowerCase().contains(lowercaseQuery);
      final matchesTags = post.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
      
      return matchesContent || matchesAuthor || matchesTags;
    }).toList();
  }

  // Filter posts by tag
  static List<CommunityPost> filterPostsByTag(List<CommunityPost> posts, String tag) {
    return posts.where((post) => post.tags.contains(tag)).toList();
  }

  // Get trending tags
  static List<String> getTrendingTags(List<CommunityPost> posts) {
    final tagCounts = <String, int>{};
    
    for (final post in posts) {
      for (final tag in post.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    
    final sortedTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedTags.take(10).map((entry) => entry.key).toList();
  }
}
