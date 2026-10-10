import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../community/community_interactions.dart';
import '../../models/pending_action_intent.dart';
import '../../providers/pending_action_provider.dart';
import '../../services/pending_action_executor.dart';

/// Makes [post] show the like the backend confirmed for it.
///
/// A like that is already on the account stays liked and its count is left as
/// it is. A fresh like takes the count the backend reported, or adds one when
/// it reported none. Applying the same snapshot twice changes nothing more.
void applyConfirmedPostLike(CommunityPost post, PostLikeSnapshot snapshot) {
  final wasLiked = post.isLiked;
  post.isLiked = snapshot.isLiked;
  if (!snapshot.isLiked) return;
  final count = snapshot.likeCount;
  if (count != null) {
    post.likeCount = count;
  } else if (!wasLiked) {
    post.likeCount = post.likeCount + 1;
  }
}

/// Reports each like a continuation applies, once, to a feed or post screen.
///
/// Attaching starts from the provider's current revision, so settlements that
/// happened before the screen was shown are not applied to it. The screen
/// receives every later settlement that is a like on a post.
class PostLikeSettlementWatcher {
  PostLikeSettlementWatcher(this.onLikeSettled);

  final void Function(String postId, PostLikeSnapshot snapshot) onLikeSettled;

  PendingActionProvider? _provider;
  int _seenRevision = 0;

  /// Follows [provider]. Calling again with the same instance changes nothing.
  void attach(PendingActionProvider? provider) {
    if (identical(provider, _provider)) return;
    _provider?.removeListener(_handle);
    _provider = provider;
    _seenRevision = provider?.settledRevision ?? 0;
    provider?.addListener(_handle);
  }

  void detach() {
    _provider?.removeListener(_handle);
    _provider = null;
  }

  void _handle() {
    final provider = _provider;
    if (provider == null) return;
    if (provider.settledRevision == _seenRevision) return;
    _seenRevision = provider.settledRevision;

    final intent = provider.lastSettled;
    final snapshot = provider.lastSettledResult?.postLike;
    if (intent == null || snapshot == null) return;
    if (intent.actionType != PendingActionType.like ||
        intent.targetType != PendingActionTargetType.post) {
      return;
    }
    onLikeSettled(intent.targetId, snapshot);
  }
}

/// The app's pending-action provider, or null where the tree has none.
PendingActionProvider? readPendingActionsOrNull(BuildContext context) {
  try {
    return Provider.of<PendingActionProvider>(context, listen: false);
  } catch (_) {
    return null;
  }
}
