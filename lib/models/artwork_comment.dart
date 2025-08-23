class ArtworkComment {
  final String id;
  final String artworkId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int likesCount;
  final bool isLikedByCurrentUser;
  final bool isEdited;
  final String? parentCommentId; // For replies
  final List<ArtworkComment> replies;

  const ArtworkComment({
    required this.id,
    required this.artworkId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.likesCount = 0,
    this.isLikedByCurrentUser = false,
    this.isEdited = false,
    this.parentCommentId,
    this.replies = const [],
  });

  /// Check if this is a reply to another comment
  bool get isReply => parentCommentId != null;

  /// Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  /// Convert to Map for storage/API
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'artworkId': artworkId,
      'userId': userId,
      'userName': userName,
      'userAvatarUrl': userAvatarUrl,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'likesCount': likesCount,
      'isLikedByCurrentUser': isLikedByCurrentUser,
      'isEdited': isEdited,
      'parentCommentId': parentCommentId,
      'replies': replies.map((reply) => reply.toMap()).toList(),
    };
  }

  /// Create from Map (from storage/API)
  factory ArtworkComment.fromMap(Map<String, dynamic> map) {
    return ArtworkComment(
      id: map['id'] ?? '',
      artworkId: map['artworkId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userAvatarUrl: map['userAvatarUrl'],
      content: map['content'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? DateTime.tryParse(map['updatedAt']) 
          : null,
      likesCount: map['likesCount']?.toInt() ?? 0,
      isLikedByCurrentUser: map['isLikedByCurrentUser'] ?? false,
      isEdited: map['isEdited'] ?? false,
      parentCommentId: map['parentCommentId'],
      replies: (map['replies'] as List<dynamic>?)
          ?.map((replyMap) => ArtworkComment.fromMap(replyMap))
          .toList() ?? [],
    );
  }

  /// Create a copy with updated fields
  ArtworkComment copyWith({
    String? id,
    String? artworkId,
    String? userId,
    String? userName,
    String? userAvatarUrl,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likesCount,
    bool? isLikedByCurrentUser,
    bool? isEdited,
    String? parentCommentId,
    List<ArtworkComment>? replies,
  }) {
    return ArtworkComment(
      id: id ?? this.id,
      artworkId: artworkId ?? this.artworkId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likesCount: likesCount ?? this.likesCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      isEdited: isEdited ?? this.isEdited,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replies: replies ?? this.replies,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ArtworkComment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ArtworkComment(id: $id, userId: $userId, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content})';
  }
}
