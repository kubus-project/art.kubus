import '../l10n/app_localizations.dart';
import '../models/pending_action_intent.dart';

/// Resolves value-first copy for the activation surfaces.
///
/// The wording always names the concrete benefit of the action the visitor
/// just attempted ("Save this artwork to your collection"), never a generic
/// "sign-in required" demand. Actions we cannot describe specifically fall back
/// to a benefit-framed generic line rather than a requirement.
class ActivationCopy {
  const ActivationCopy._();

  /// Headline for the pre-authentication activation sheet.
  static String gateTitle(
    AppLocalizations l10n, {
    required PendingActionType? actionType,
    required PendingActionTargetType? targetType,
    required String fallbackActionLabel,
  }) {
    switch (actionType) {
      case PendingActionType.save:
        switch (targetType) {
          case PendingActionTargetType.event:
            return l10n.activationGateSaveEventTitle;
          case PendingActionTargetType.exhibition:
            return l10n.activationGateSaveExhibitionTitle;
          case PendingActionTargetType.post:
            return l10n.activationGateSavePostTitle;
          case PendingActionTargetType.artwork:
          case PendingActionTargetType.user:
          case PendingActionTargetType.marker:
          case null:
            return l10n.activationGateSaveArtworkTitle;
        }
      case PendingActionType.like:
        return l10n.activationGateLikeArtworkTitle;
      case PendingActionType.follow:
        return l10n.activationGateFollowTitle;
      case PendingActionType.comment:
        return l10n.activationGateCommentTitle;
      case PendingActionType.contribute:
        return l10n.activationGateContributeTitle;
      case null:
        return l10n.activationGateGenericTitle(fallbackActionLabel);
    }
  }

  static String gateBody(AppLocalizations l10n) => l10n.activationGateBody;

  /// Question shown after authentication, before the action is replayed.
  static String confirmationQuestion(
    AppLocalizations l10n,
    PendingActionIntent intent,
  ) {
    switch (intent.actionType) {
      case PendingActionType.save:
        switch (intent.targetType) {
          case PendingActionTargetType.event:
            return l10n.activationConfirmSaveEvent;
          case PendingActionTargetType.exhibition:
            return l10n.activationConfirmSaveExhibition;
          case PendingActionTargetType.post:
            return l10n.activationConfirmSavePost;
          case PendingActionTargetType.artwork:
          case PendingActionTargetType.user:
          case PendingActionTargetType.marker:
            return l10n.activationConfirmSaveArtwork;
        }
      case PendingActionType.like:
        return l10n.activationConfirmLikeArtwork;
      case PendingActionType.follow:
        return l10n.activationConfirmFollow;
      case PendingActionType.comment:
        return l10n.activationConfirmComment;
      case PendingActionType.contribute:
        return l10n.activationConfirmContribute;
    }
  }

  /// Label of the button that actually performs the action.
  static String confirmationCta(
    AppLocalizations l10n,
    PendingActionIntent intent,
  ) {
    switch (intent.actionType) {
      case PendingActionType.save:
        return l10n.commonSave;
      case PendingActionType.like:
        return l10n.activationConfirmLikeCta;
      case PendingActionType.follow:
        return l10n.commonFollow;
      case PendingActionType.comment:
      case PendingActionType.contribute:
        return l10n.activationConfirmContinueCta;
    }
  }

  /// Confirmation feedback after the action succeeded.
  static String successToast(
    AppLocalizations l10n,
    PendingActionIntent intent,
  ) {
    switch (intent.actionType) {
      case PendingActionType.save:
        return l10n.activationActionSavedToast;
      case PendingActionType.like:
        return l10n.activationActionLikedToast;
      case PendingActionType.follow:
        return l10n.activationActionFollowedToast;
      case PendingActionType.comment:
      case PendingActionType.contribute:
        return l10n.activationConfirmHeading;
    }
  }
}
