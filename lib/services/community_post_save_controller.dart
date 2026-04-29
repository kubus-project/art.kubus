import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../community/community_interactions.dart';
import '../providers/saved_items_provider.dart';
import 'user_action_logger.dart';

class CommunityPostSaveController {
  const CommunityPostSaveController._();

  static Future<bool> toggle(
    BuildContext context,
    CommunityPost post, {
    bool trackUserAction = true,
  }) async {
    final savedItems = context.read<SavedItemsProvider>();
    final wasSaved = post.isBookmarked;
    final nextSaved = !wasSaved;
    post.isBookmarked = nextSaved;

    try {
      await savedItems.setPostSaved(
        post.id,
        nextSaved,
        title: _titleFor(post),
        subtitle: post.authorName,
        imageUrl: _imageFor(post),
        authorId: post.authorWallet ?? post.authorId,
        authorName: post.authorName,
        metadata: _metadataFor(post),
      );
      if (nextSaved && trackUserAction) {
        UserActionLogger.logPostSave(
          postId: post.id,
          postContent: post.content,
          authorName: post.authorName,
        );
      }
      return nextSaved;
    } catch (error) {
      post.isBookmarked = wasSaved;
      if (kDebugMode) {
        debugPrint('CommunityPostSaveController.toggle failed: $error');
      }
      rethrow;
    }
  }

  static String _titleFor(CommunityPost post) {
    final content = post.content.trim();
    if (content.isEmpty) return post.authorName;
    if (content.length <= 120) return content;
    return '${content.substring(0, 117).trimRight()}...';
  }

  static String? _imageFor(CommunityPost post) {
    final image = post.imageUrl?.trim();
    if (image != null && image.isNotEmpty) return image;
    for (final media in post.mediaUrls) {
      final candidate = media.trim();
      if (candidate.isNotEmpty) return candidate;
    }
    return post.artwork?.imageUrl;
  }

  static Map<String, dynamic> _metadataFor(CommunityPost post) {
    return <String, dynamic>{
      if (post.category.trim().isNotEmpty) 'category': post.category.trim(),
      if (post.tags.isNotEmpty) 'tags': post.tags,
      if (post.mentions.isNotEmpty) 'mentions': post.mentions,
      if (post.subjects.isNotEmpty)
        'subjects': post.subjects.map((subject) => subject.toJson()).toList(),
      if (post.groupId != null && post.groupId!.trim().isNotEmpty)
        'groupId': post.groupId!.trim(),
    };
  }
}
