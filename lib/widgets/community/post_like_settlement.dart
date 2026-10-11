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

/// Shows [post] liked while its confirmed like is in flight. The server records
/// a like well before it answers (20 to 40 s on the rig), so the heart shows it
/// from the moment of confirmation. The answer then sets the count, or the
/// server's state comes back if the attempt failed.
void applyOptimisticPostLike(CommunityPost post) {
  if (post.isLiked) return;
  post.isLiked = true;
  post.likeCount = post.likeCount + 1;
}

/// Reports each like a continuation applies, once, to a feed or post screen.
///
/// Attaching starts from the provider's current revision, so settlements that
/// happened before the screen was shown are not applied to it. The screen
/// receives every later settlement that is a like on a post, and, while a like
/// is in flight, its start and an attempt that ended without a confirmed like.
class PostLikeSettlementWatcher {
  PostLikeSettlementWatcher(
    this.onLikeSettled, {
    this.onLikeStarted,
    this.onLikeAttemptEnded,
  });

  final void Function(String postId, PostLikeSnapshot snapshot) onLikeSettled;

  /// A like confirmed on a post has started and the answer is still out.
  final void Function(String postId)? onLikeStarted;

  /// A like attempt ended without a confirmed like (it failed).
  final void Function(String postId)? onLikeAttemptEnded;

  PendingActionProvider? _provider;
  int _seenRevision = 0;
  String? _inFlightPostId;

  /// True while a like confirmed on [postId] is in flight.
  bool isInFlight(String postId) => _inFlightPostId == postId;

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

    if (provider.isExecuting && _inFlightPostId == null) {
      final intent = provider.pending;
      if (intent != null &&
          intent.actionType == PendingActionType.like &&
          intent.targetType == PendingActionTargetType.post) {
        _inFlightPostId = intent.targetId;
        onLikeStarted?.call(intent.targetId);
      }
    }

    if (provider.settledRevision != _seenRevision) {
      _seenRevision = provider.settledRevision;
      final intent = provider.lastSettled;
      final snapshot = provider.lastSettledResult?.postLike;
      if (intent != null &&
          snapshot != null &&
          intent.actionType == PendingActionType.like &&
          intent.targetType == PendingActionTargetType.post) {
        _inFlightPostId = null;
        onLikeSettled(intent.targetId, snapshot);
      }
    }

    if (!provider.isExecuting && _inFlightPostId != null) {
      final postId = _inFlightPostId!;
      _inFlightPostId = null;
      onLikeAttemptEnded?.call(postId);
    }
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
