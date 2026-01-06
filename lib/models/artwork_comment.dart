class ArtworkComment {
  final String id;
  final String artworkId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String content;
  /// Original content before the first edit.
  ///
  /// Set by the backend on first edit; remains unchanged for subsequent edits.
  final String? originalContent;
  final DateTime createdAt;
  final DateTime? updatedAt;
  /// Timestamp when the comment was edited (if ever).
  final DateTime? editedAt;
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
    this.originalContent,
    required this.createdAt,
    this.updatedAt,
    this.editedAt,
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
      'originalContent': originalContent,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'editedAt': editedAt?.toIso8601String(),
      'likesCount': likesCount,
      'isLikedByCurrentUser': isLikedByCurrentUser,
      'isEdited': isEdited,
      'parentCommentId': parentCommentId,
      'replies': replies.map((reply) => reply.toMap()).toList(),
    };
  }

  /// Create from Map (from storage/API)
  factory ArtworkComment.fromMap(Map<String, dynamic> map) {
    DateTime? tryParseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    String? normalizeOptionalString(dynamic value) {
      final s = value?.toString();
      if (s == null) return null;
      final trimmed = s.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final createdAt = tryParseDateTime(map['createdAt'] ?? map['created_at']) ?? DateTime.now();
    final updatedAt = tryParseDateTime(map['updatedAt'] ?? map['updated_at']);
    final editedAt = tryParseDateTime(map['editedAt'] ?? map['edited_at'] ?? map['editedAtUtc']);
    final explicitIsEdited = map['isEdited'];
    final isEdited = (explicitIsEdited is bool)
        ? explicitIsEdited
        : (editedAt != null);

    return ArtworkComment(
      id: map['id']?.toString() ?? '',
      artworkId: map['artworkId']?.toString() ?? map['artwork_id']?.toString() ?? '',
      // Prefer wallet identifiers when available, as the UI expects a wallet-like
      // key for profile navigation + permission checks.
      userId: map['userId']?.toString() ??
          map['authorWallet']?.toString() ??
          map['author_wallet']?.toString() ??
          map['walletAddress']?.toString() ??
          map['wallet_address']?.toString() ??
          map['authorId']?.toString() ??
          map['author_id']?.toString() ??
          '',
      userName: map['userName']?.toString() ?? '',
      userAvatarUrl: map['userAvatarUrl'],
      content: map['content'] ?? '',
      originalContent: normalizeOptionalString(
        map['originalContent'] ?? map['original_content'] ?? map['originalText'],
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
      editedAt: editedAt,
      likesCount: map['likesCount']?.toInt() ?? 0,
      isLikedByCurrentUser: map['isLikedByCurrentUser'] ?? false,
      isEdited: isEdited,
      parentCommentId: normalizeOptionalString(map['parentCommentId'] ?? map['parent_comment_id']),
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
    String? originalContent,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? editedAt,
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
      originalContent: originalContent ?? this.originalContent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      editedAt: editedAt ?? this.editedAt,
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
