import 'package:shared_preferences/shared_preferences.dart';
import '../config/config.dart';

// Enhanced community interaction models
class CommunityPost {
  final String id;
  final String authorId;
  final String authorName;
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
  }) {
    return CommunityPost(
      id: id,
      authorId: authorId,
      authorName: authorName,
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
  String content; // Made mutable for editing
  final DateTime timestamp;
  int likeCount;
  bool isLiked;
  final List<Comment> replies;

  Comment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.timestamp,
    this.likeCount = 0,
    this.isLiked = false,
    this.replies = const [],
  });

  Comment copyWith({
    int? likeCount,
    bool? isLiked,
  }) {
    return Comment(
      id: id,
      authorId: authorId,
      authorName: authorName,
      content: content,
      timestamp: timestamp,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      replies: replies,
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

  // Like/Unlike post
  static Future<void> togglePostLike(CommunityPost post) async {
    if (!AppConfig.enableLiking) return;

    final prefs = await SharedPreferences.getInstance();
    final likedPosts = prefs.getStringList(_likesKey) ?? [];
    final likeCounts = prefs.getStringList(_likeCountsKey) ?? [];

    // The post object state has already been updated by the UI
    // We just need to persist the current state
    if (post.isLiked) {
      // Post is now liked, add to persistence
      if (!likedPosts.contains(post.id)) {
        likedPosts.add(post.id);
      }
    } else {
      // Post is now unliked, remove from persistence
      likedPosts.remove(post.id);
    }

    // Update like counts persistence
    likeCounts.removeWhere((item) => item.startsWith('${post.id}|'));
    likeCounts.add('${post.id}|${post.likeCount}');

    await prefs.setStringList(_likesKey, likedPosts);
    await prefs.setStringList(_likeCountsKey, likeCounts);
    
    if (AppConfig.enableDebugPrints) {
      print('Post ${post.id} ${post.isLiked ? "liked" : "unliked"}. Total likes: ${post.likeCount}');
    }
  }

  // Like/Unlike comment
  static Future<void> toggleCommentLike(Comment comment, String postId) async {
    if (!AppConfig.enableLiking) return;

    final prefs = await SharedPreferences.getInstance();
    final likedComments = prefs.getStringList('${_likesKey}_comments') ?? [];
    final commentKey = '${postId}_${comment.id}';

    if (comment.isLiked) {
      // Unlike
      likedComments.remove(commentKey);
      comment.likeCount = (comment.likeCount - 1).clamp(0, double.infinity).toInt();
      comment.isLiked = false;
    } else {
      // Like
      likedComments.add(commentKey);
      comment.likeCount++;
      comment.isLiked = true;
    }

    await prefs.setStringList('${_likesKey}_comments', likedComments);
  }

  // Add comment to post
  static Future<Comment> addComment(CommunityPost post, String content, String authorName) async {
    if (!AppConfig.enableCommenting) throw Exception('Commenting is disabled');

    final comment = Comment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      authorId: 'current_user', // In real app, get from auth
      authorName: authorName,
      content: content,
      timestamp: DateTime.now(),
    );

    post.comments = [...post.comments, comment];
    post.commentCount = post.comments.length;

    // Save to preferences for persistence
    final prefs = await SharedPreferences.getInstance();
    final commentsData = prefs.getStringList('${_commentsKey}_${post.id}') ?? [];
    commentsData.add('${comment.id}|${comment.authorName}|${comment.content}|${comment.timestamp.millisecondsSinceEpoch}');
    await prefs.setStringList('${_commentsKey}_${post.id}', commentsData);

    if (AppConfig.enableDebugPrints) {
      print('Comment added to post ${post.id}. Total comments: ${post.commentCount}');
    }

    return comment;
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
          final commentKey = '${post.id}_${comment.id}';
          comment.isLiked = likedComments.contains(commentKey);

          loadedComments.add(comment);
        }
      }

      post.comments = [...post.comments, ...loadedComments];
      post.commentCount = post.comments.length;
    }
  }

  // Generate mock posts with enhanced features
  static List<CommunityPost> getMockPosts() {
    if (!AppConfig.useMockData) return [];

    return [
      CommunityPost(
        id: 'post_1',
        authorId: 'artist_1',
        authorName: 'Elena Rodriguez',
        content: 'Just finished my latest NFT collection "Digital Dreams"! 🎨 The intersection of AI and traditional art continues to amaze me. What do you think about the future of AI-generated art?',
        imageUrl: 'https://picsum.photos/400/300?random=1',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        tags: ['#NFT', '#DigitalArt', '#AI'],
        likeCount: 42,
        commentCount: 8,
        shareCount: 15,
        viewCount: 324,
        comments: [
          Comment(
            id: 'comment_1_1',
            authorId: 'user_2',
            authorName: 'Marcus Chen',
            content: 'Absolutely stunning work! The blend of organic and digital elements is perfect.',
            timestamp: DateTime.now().subtract(const Duration(hours: 1)),
            likeCount: 5,
          ),
          Comment(
            id: 'comment_1_2',
            authorId: 'user_3',
            authorName: 'Sarah Kim',
            content: 'AI art is controversial but this shows real artistic vision. Love it!',
            timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
            likeCount: 3,
          ),
        ],
      ),
      CommunityPost(
        id: 'post_2',
        authorId: 'collector_1',
        authorName: 'James Wilson',
        content: 'Amazing AR experience at the Museum of Digital Arts today! Walking through virtual galleries and seeing how artworks transform in real space. The future is here! 🚀',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        tags: ['#AR', '#Museum', '#DigitalExperience'],
        likeCount: 67,
        commentCount: 12,
        shareCount: 28,
        viewCount: 456,
        comments: [
          Comment(
            id: 'comment_2_1',
            authorId: 'user_4',
            authorName: 'Maya Patel',
            content: 'I was there too! The holographic sculptures were mind-blowing.',
            timestamp: DateTime.now().subtract(const Duration(hours: 4)),
            likeCount: 8,
          ),
        ],
      ),
      CommunityPost(
        id: 'post_3',
        authorId: 'artist_2',
        authorName: 'Viktor Petrov',
        content: 'New drop alert! 🔥 "Cyber Renaissance" collection goes live tomorrow at 3 PM UTC. Only 100 pieces available. Each artwork tells a story of classical art meeting futuristic technology.',
        imageUrl: 'https://picsum.photos/400/300?random=2',
        timestamp: DateTime.now().subtract(const Duration(hours: 8)),
        tags: ['#NewDrop', '#CyberRenaissance', '#LimitedEdition'],
        likeCount: 89,
        commentCount: 15,
        shareCount: 34,
        viewCount: 623,
        comments: [
          Comment(
            id: 'comment_3_1',
            authorId: 'user_5',
            authorName: 'Lisa Park',
            content: 'Your art style is so unique! Definitely setting a reminder for tomorrow.',
            timestamp: DateTime.now().subtract(const Duration(hours: 7)),
            likeCount: 4,
          ),
          Comment(
            id: 'comment_3_2',
            authorId: 'user_6',
            authorName: 'David Thompson',
            content: 'Will there be any special utility for holders?',
            timestamp: DateTime.now().subtract(const Duration(hours: 6)),
            likeCount: 2,
          ),
        ],
      ),
      CommunityPost(
        id: 'post_4',
        authorId: 'community_manager',
        authorName: 'art.kubus Team',
        content: 'Community Update 📢 We\'re excited to announce the launch of our new Web3 marketplace! Trade, discover, and collect digital art with zero gas fees. Beta testing starts next week!',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        tags: ['#CommunityUpdate', '#Marketplace', '#Web3'],
        likeCount: 156,
        commentCount: 23,
        shareCount: 78,
        viewCount: 1205,
        comments: [
          Comment(
            id: 'comment_4_1',
            authorId: 'user_7',
            authorName: 'Alex Rodriguez',
            content: 'Finally! Been waiting for this feature. How do I sign up for beta?',
            timestamp: DateTime.now().subtract(const Duration(hours: 20)),
            likeCount: 12,
          ),
          Comment(
            id: 'comment_4_2',
            authorId: 'user_8',
            authorName: 'Emma Johnson',
            content: 'Zero gas fees? That\'s a game changer for small artists!',
            timestamp: DateTime.now().subtract(const Duration(hours: 18)),
            likeCount: 9,
          ),
        ],
      ),
      CommunityPost(
        id: 'post_5',
        authorId: 'artist_5',
        authorName: 'David Kim',
        content: 'Experimenting with AR sculptures in public spaces 🏛️ The way people interact with invisible art is fascinating. Check out this piece I installed at Central Park!',
        imageUrl: 'https://picsum.photos/400/300?random=5',
        timestamp: DateTime.now().subtract(const Duration(hours: 8)),
        tags: ['#AR', '#PublicArt', '#Sculpture'],
        likeCount: 73,
        commentCount: 12,
        shareCount: 31,
        viewCount: 892,
        comments: [
          Comment(
            id: 'comment_5_1',
            authorId: 'user_9',
            authorName: 'Sarah Wilson',
            content: 'I saw this yesterday! Amazing how it changes with the lighting.',
            timestamp: DateTime.now().subtract(const Duration(hours: 6)),
            likeCount: 8,
          ),
        ],
      ),
      CommunityPost(
        id: 'post_6',
        authorId: 'artist_6',
        authorName: 'Maya Patel',
        content: 'New NFT drop: "Digital Landscapes" 🌄 Inspired by climate change and our digital transformation. Each piece tells a story of adaptation.',
        imageUrl: 'https://picsum.photos/400/300?random=6',
        timestamp: DateTime.now().subtract(const Duration(hours: 12)),
        tags: ['#NFT', '#ClimateArt', '#Digital'],
        likeCount: 95,
        commentCount: 18,
        shareCount: 44,
        viewCount: 567,
        comments: [
          Comment(
            id: 'comment_6_1',
            authorId: 'user_10',
            authorName: 'Tom Anderson',
            content: 'Powerful message and beautiful execution. When is the drop?',
            timestamp: DateTime.now().subtract(const Duration(hours: 10)),
            likeCount: 6,
          ),
        ],
      ),
      CommunityPost(
        id: 'post_7',
        authorId: 'artist_7',
        authorName: 'Lisa Chen',
        content: 'Interactive art meets blockchain! 🎮 My latest piece responds to viewer emotions detected through AR. The more engagement, the more the artwork evolves.',
        imageUrl: 'https://picsum.photos/400/300?random=7',
        timestamp: DateTime.now().subtract(const Duration(hours: 16)),
        tags: ['#Interactive', '#AR', '#Blockchain'],
        likeCount: 128,
        commentCount: 24,
        shareCount: 67,
        viewCount: 1234,
        comments: [
          Comment(
            id: 'comment_7_1',
            authorId: 'user_11',
            authorName: 'Alex Johnson',
            content: 'This is the future of art! How does the emotion detection work?',
            timestamp: DateTime.now().subtract(const Duration(hours: 14)),
            likeCount: 11,
          ),
        ],
      ),
      CommunityPost(
        id: 'post_8',
        authorId: 'artist_8',
        authorName: 'Roberto Silva',
        content: 'Community collaboration project: "Digital Dreams" 🌟 Looking for 10 artists to contribute to this massive AR installation. DM me if interested!',
        imageUrl: 'https://picsum.photos/400/300?random=8',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        tags: ['#Collaboration', '#Community', '#AR'],
        likeCount: 187,
        commentCount: 45,
        shareCount: 93,
        viewCount: 2156,
        comments: [
          Comment(
            id: 'comment_8_1',
            authorId: 'user_12',
            authorName: 'Jennifer Lee',
            content: 'Count me in! This sounds amazing. Checking DMs now.',
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
            likeCount: 15,
          ),
        ],
      ),
    ];
  }

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
        print('Post ${post.id} reported for: $reason');
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
      print('Post ${post.id} ${post.isBookmarked ? "bookmarked" : "unbookmarked"}');
    }
  }

  // Follow/Unfollow user
  static Future<void> toggleFollow(String userId, CommunityPost? post) async {
    final prefs = await SharedPreferences.getInstance();
    final followedUsers = prefs.getStringList(_followsKey) ?? [];

    bool isFollowing = followedUsers.contains(userId);

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
      print('User $userId ${!isFollowing ? "followed" : "unfollowed"}');
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
        print('Post ${post.id} viewed. Total views: ${post.viewCount}');
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

  // Share post functionality (enhanced)
  static Future<void> sharePost(CommunityPost post) async {
    if (!AppConfig.enableSharing) return;

    // Track shares
    final prefs = await SharedPreferences.getInstance();
    final sharedPosts = prefs.getStringList(_sharesKey) ?? [];
    final shareKey = '${post.id}_${DateTime.now().millisecondsSinceEpoch}';
    
    sharedPosts.add(shareKey);
    post.shareCount++;
    await prefs.setStringList(_sharesKey, sharedPosts);

    // In a real app, this would integrate with platform sharing
    final shareText = '${post.content}\n\n- ${post.authorName} on art.kubus';
    
    if (AppConfig.enableDebugPrints) {
      print('Sharing post: $shareText');
      print('Post ${post.id} shared. Total shares: ${post.shareCount}');
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
      print('Comment $commentId deleted from post ${post.id}');
    }
  }

  // Edit comment
  static Future<void> editComment(Comment comment, String newContent) async {
    // Note: In a real app, you'd want to track edit history
    comment.content = newContent;
    
    if (AppConfig.enableDebugPrints) {
      print('Comment ${comment.id} edited');
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
