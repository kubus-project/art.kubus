import '../config/config.dart';
import '../models/pending_action_intent.dart';
import '../providers/artwork_provider.dart';
import '../providers/saved_items_provider.dart';
import 'backend_api_service.dart';
import 'user_service.dart';

/// Why a confirmed pending action did or did not complete.
enum PendingActionOutcome {
  /// The mutation ran (or was already in the requested state).
  completed,

  /// The intent only needed the visitor returned to a composer surface; no
  /// mutation is replayed because none was ever captured.
  entryRestored,

  /// The entity is gone, unpublished or no longer public.
  targetUnavailable,

  /// The backend rejected the caller. Authorization stays server-side.
  unauthorized,

  /// Network or unexpected failure. Safe to retry.
  failed,
}

/// The account's like on a post as the backend confirmed it.
typedef PostLikeSnapshot = ({bool isLiked, int? likeCount});

class PendingActionExecutionResult {
  const PendingActionExecutionResult(this.outcome, {this.postLike});

  final PendingActionOutcome outcome;

  /// For a confirmed post like: the like state the backend holds now, so a
  /// screen showing the post can reflect it without reloading.
  final PostLikeSnapshot? postLike;

  bool get didSucceed =>
      outcome == PendingActionOutcome.completed ||
      outcome == PendingActionOutcome.entryRestored;

  /// Coarse machine label for telemetry. Never carries an error message.
  String get failureStage => switch (outcome) {
        PendingActionOutcome.completed => 'none',
        PendingActionOutcome.entryRestored => 'none',
        PendingActionOutcome.targetUnavailable => 'target_unavailable',
        PendingActionOutcome.unauthorized => 'unauthorized',
        PendingActionOutcome.failed => 'execution',
      };
}

/// Reads the account's like state on [postId]. Resolves to `null` when the
/// post is no longer available.
typedef PostLikedLoader = Future<PostLikeSnapshot?> Function(String postId);

/// Records a like on [postId] and resolves to the new like count when the
/// backend reports one. The backend treats a repeated like as a no-op.
typedef PostLiker = Future<int?> Function(String postId);

/// Applies a confirmed [PendingActionIntent].
///
/// Two invariants matter here:
///
/// * **Idempotence.** Every branch drives the target to an explicit desired
///   state rather than toggling, so a double confirmation or a state the
///   visitor changed elsewhere cannot invert the result.
/// * **Server authority.** Nothing here grants access. The intent only names a
///   target; the backend still authenticates and authorizes the mutation, and a
///   rejection surfaces as [PendingActionOutcome.unauthorized].
class PendingActionExecutor {
  const PendingActionExecutor({
    PostLikedLoader? loadPostLiked,
    PostLiker? likePost,
  })  : _loadPostLiked = loadPostLiked,
        _likePost = likePost;

  final PostLikedLoader? _loadPostLiked;
  final PostLiker? _likePost;

  Future<PostLikeSnapshot?> _readPostLiked(String postId) async {
    final override = _loadPostLiked;
    if (override != null) return override(postId);
    final batch = await BackendApiService()
        .getCommunityInteractionStates(postIds: <String>[postId]);
    final state = batch.posts[postId];
    if (state == null) return null;
    return (isLiked: state.isLiked, likeCount: state.likeCount);
  }

  Future<int?> _sendPostLike(String postId) {
    final override = _likePost;
    if (override != null) return override(postId);
    return BackendApiService().likePost(postId);
  }

  Future<PendingActionExecutionResult> execute({
    required PendingActionIntent intent,
    required ArtworkProvider artworkProvider,
    required SavedItemsProvider savedItemsProvider,
  }) async {
    try {
      return switch (intent.actionType) {
        PendingActionType.save => await _executeSave(
            intent: intent,
            artworkProvider: artworkProvider,
            savedItemsProvider: savedItemsProvider,
          ),
        PendingActionType.like => await _executeLike(
            intent: intent,
            artworkProvider: artworkProvider,
          ),
        PendingActionType.follow => await _executeFollow(intent),
        // Comment and contribution intents intentionally carry no payload —
        // the visitor's text was never stored, so there is nothing to replay.
        // Restoring them means landing back on the composer.
        PendingActionType.comment ||
        PendingActionType.contribute =>
          const PendingActionExecutionResult(
            PendingActionOutcome.entryRestored,
          ),
      };
    } on SavedItemsAuthenticationRequired {
      return const PendingActionExecutionResult(
        PendingActionOutcome.unauthorized,
      );
    } catch (e) {
      AppConfig.debugPrint('PendingActionExecutor: execution failed: $e');
      return PendingActionExecutionResult(_classify(e));
    }
  }

  Future<PendingActionExecutionResult> _executeSave({
    required PendingActionIntent intent,
    required ArtworkProvider artworkProvider,
    required SavedItemsProvider savedItemsProvider,
  }) async {
    switch (intent.targetType) {
      case PendingActionTargetType.artwork:
        final artwork =
            await artworkProvider.fetchArtworkIfNeeded(intent.targetId);
        if (artwork == null) {
          return const PendingActionExecutionResult(
            PendingActionOutcome.targetUnavailable,
          );
        }
        final ok = await artworkProvider.setArtworkSavedState(
          intent.targetId,
          true,
        );
        return PendingActionExecutionResult(
          ok ? PendingActionOutcome.completed : PendingActionOutcome.failed,
        );
      case PendingActionTargetType.event:
        if (savedItemsProvider.isEventSaved(intent.targetId)) {
          return const PendingActionExecutionResult(
            PendingActionOutcome.completed,
          );
        }
        await savedItemsProvider.setEventSaved(intent.targetId, true);
        return const PendingActionExecutionResult(
          PendingActionOutcome.completed,
        );
      case PendingActionTargetType.exhibition:
        if (savedItemsProvider.isExhibitionSaved(intent.targetId)) {
          return const PendingActionExecutionResult(
            PendingActionOutcome.completed,
          );
        }
        await savedItemsProvider.setExhibitionSaved(intent.targetId, true);
        return const PendingActionExecutionResult(
          PendingActionOutcome.completed,
        );
      case PendingActionTargetType.collection:
        if (savedItemsProvider.isCollectionSaved(intent.targetId)) {
          return const PendingActionExecutionResult(
            PendingActionOutcome.completed,
          );
        }
        await savedItemsProvider.setCollectionSaved(intent.targetId, true);
        return const PendingActionExecutionResult(
          PendingActionOutcome.completed,
        );
      case PendingActionTargetType.post:
        if (savedItemsProvider.isPostSaved(intent.targetId)) {
          return const PendingActionExecutionResult(
            PendingActionOutcome.completed,
          );
        }
        await savedItemsProvider.setPostSaved(intent.targetId, true);
        return const PendingActionExecutionResult(
          PendingActionOutcome.completed,
        );
      case PendingActionTargetType.user:
      case PendingActionTargetType.marker:
        return const PendingActionExecutionResult(
          PendingActionOutcome.targetUnavailable,
        );
    }
  }

  Future<PendingActionExecutionResult> _executeLike({
    required PendingActionIntent intent,
    required ArtworkProvider artworkProvider,
  }) async {
    if (intent.targetType == PendingActionTargetType.post) {
      return _executePostLike(intent.targetId);
    }
    if (intent.targetType != PendingActionTargetType.artwork) {
      return const PendingActionExecutionResult(
        PendingActionOutcome.targetUnavailable,
      );
    }
    final artwork = await artworkProvider.fetchArtworkIfNeeded(intent.targetId);
    if (artwork == null) {
      return const PendingActionExecutionResult(
        PendingActionOutcome.targetUnavailable,
      );
    }
    final ok = await artworkProvider.setLiked(intent.targetId, true);
    return PendingActionExecutionResult(
      ok ? PendingActionOutcome.completed : PendingActionOutcome.failed,
    );
  }

  /// Drives the post to "liked" rather than toggling it. A post the account
  /// already likes is left alone, so a replayed or doubly confirmed like can
  /// never take the like back off.
  Future<PendingActionExecutionResult> _executePostLike(String postId) async {
    final current = await _readPostLiked(postId);
    if (current == null) {
      return const PendingActionExecutionResult(
        PendingActionOutcome.targetUnavailable,
      );
    }
    if (current.isLiked) {
      return PendingActionExecutionResult(
        PendingActionOutcome.completed,
        postLike: current,
      );
    }

    Object? sendFailure;
    int? reportedCount;
    try {
      reportedCount = await _sendPostLike(postId);
    } catch (error) {
      sendFailure = error;
    }

    // The like route records the like before a later step can fail, and a
    // response can be lost after the write. The server's state is what counts:
    // a like it holds is a success, whatever the response said.
    final after = await _readPostLikedOrNull(postId);
    if (after != null && after.isLiked) {
      return PendingActionExecutionResult(
        PendingActionOutcome.completed,
        postLike: (isLiked: true, likeCount: after.likeCount ?? reportedCount),
      );
    }
    if (sendFailure != null) {
      return PendingActionExecutionResult(_classify(sendFailure));
    }
    if (after == null) {
      // The request succeeded and the state could not be read to contradict it.
      return PendingActionExecutionResult(
        PendingActionOutcome.completed,
        postLike: (isLiked: true, likeCount: reportedCount),
      );
    }
    return const PendingActionExecutionResult(PendingActionOutcome.failed);
  }

  /// A state read that cannot fail the caller: null when it could not be read.
  Future<PostLikeSnapshot?> _readPostLikedOrNull(String postId) async {
    try {
      return await _readPostLiked(postId);
    } catch (_) {
      return null;
    }
  }

  Future<PendingActionExecutionResult> _executeFollow(
    PendingActionIntent intent,
  ) async {
    if (intent.targetType != PendingActionTargetType.user) {
      return const PendingActionExecutionResult(
        PendingActionOutcome.targetUnavailable,
      );
    }
    final result = await UserService.setFollowState(
      intent.targetId,
      shouldFollow: true,
    );
    return PendingActionExecutionResult(
      result.isFollowing
          ? PendingActionOutcome.completed
          : PendingActionOutcome.failed,
    );
  }

  PendingActionOutcome _classify(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('401') ||
        text.contains('403') ||
        text.contains('unauthor') ||
        text.contains('forbidden')) {
      return PendingActionOutcome.unauthorized;
    }
    if (text.contains('404') ||
        text.contains('not found') ||
        text.contains('gone')) {
      return PendingActionOutcome.targetUnavailable;
    }
    return PendingActionOutcome.failed;
  }
}
