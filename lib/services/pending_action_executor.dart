import '../config/config.dart';
import '../models/pending_action_intent.dart';
import '../providers/artwork_provider.dart';
import '../providers/saved_items_provider.dart';
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

class PendingActionExecutionResult {
  const PendingActionExecutionResult(this.outcome);

  final PendingActionOutcome outcome;

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
  const PendingActionExecutor();

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
