import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/art_marker.dart';
import '../../../models/artwork.dart';
import '../../../models/event.dart';
import '../../../models/exhibition.dart';
import '../../../models/pending_action_intent.dart';
import '../../../config/config.dart';
import '../../../providers/artwork_provider.dart';
import '../../../providers/saved_items_provider.dart';
import '../../../services/contextual_auth_gate.dart';
import '../../../services/share/share_service.dart';
import '../../../services/share/share_types.dart';
import '../../../widgets/common/kubus_marker_overlay_card.dart';

List<MarkerOverlayActionSpec> buildMarkerOverlayActions({
  required BuildContext context,
  required ArtMarker marker,
  required Artwork? artwork,
  required KubusEvent? event,
  required Exhibition? exhibition,
  required bool canPresentExhibition,
  required Color baseColor,
  required String sourceScreen,
  VoidCallback? onClaimTap,
  VoidCallback? onEngagementChanged,
}) {
  final l10n = AppLocalizations.of(context)!;
  final scheme = Theme.of(context).colorScheme;
  final artworkProvider = context.read<ArtworkProvider>();
  final actions = <MarkerOverlayActionSpec>[];

  // Return to the exact marker, not the generic map. `/m/<id>` is the canonical
  // public marker route, so a visitor who authenticates mid-action lands back
  // on the overlay they were looking at.
  final markerReturnRoute = '/m/${Uri.encodeComponent(marker.id)}';

  final canShowClaimAction = AppConfig.isFeatureEnabled('streetArtClaims') &&
      marker.type == ArtMarkerType.streetArt &&
      marker.isPublic &&
      onClaimTap != null;

  if (canShowClaimAction) {
    actions.add(
      MarkerOverlayActionSpec(
        icon: Icons.gavel_outlined,
        label: l10n.mapMarkerClaimButton,
        isActive: false,
        activeColor: baseColor,
        tooltip: l10n.mapMarkerClaimButton,
        semanticsLabel: 'marker_claim',
        onTap: onClaimTap,
      ),
    );
  }

  // Watched, not read: the Save action's icon and label are derived from this
  // provider, so the overlay must rebuild when a toggle (or a save made
  // elsewhere) notifies listeners. `read` left the card showing stale state
  // until an unrelated map rebuild happened to arrive.
  final savedItemsProvider = context.watch<SavedItemsProvider>();

  if (event != null) {
    final isSaved = savedItemsProvider.isEventSaved(event.id);
    actions.addAll(<MarkerOverlayActionSpec>[
      MarkerOverlayActionSpec(
        icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
        label: isSaved ? l10n.commonSavedToast : l10n.commonSave,
        isActive: isSaved,
        activeColor: baseColor,
        tooltip: l10n.commonSave,
        semanticsLabel: 'marker_event_save',
        onTap: () {
          unawaited(() async {
            final authenticated =
                await const ContextualAuthGate().ensureAuthenticated(
              context,
              actionLabel: l10n.commonSave.toLowerCase(),
              returnRoute: markerReturnRoute,
              actionType: PendingActionType.save,
              targetType: PendingActionTargetType.event,
              targetId: event.id,
              targetLabel: event.title,
              markerId: marker.id,
              sourceScreen: sourceScreen,
            );
            if (!authenticated || !context.mounted) return;
            await savedItemsProvider.toggleEventSaved(event.id);
            onEngagementChanged?.call();
          }());
        },
      ),
      MarkerOverlayActionSpec(
        icon: Icons.share_outlined,
        label: l10n.commonShare,
        isActive: false,
        activeColor: baseColor,
        tooltip: l10n.commonShare,
        semanticsLabel: 'marker_event_share',
        onTap: () {
          ShareService().showShareSheet(
            context,
            target: ShareTarget.event(eventId: event.id, title: event.title),
            sourceScreen: sourceScreen,
          );
        },
      ),
    ]);
    return actions;
  }

  if (exhibition != null) {
    final isSaved = savedItemsProvider.isExhibitionSaved(exhibition.id);
    actions.addAll(<MarkerOverlayActionSpec>[
      MarkerOverlayActionSpec(
        icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
        label: isSaved ? l10n.commonSavedToast : l10n.commonSave,
        isActive: isSaved,
        activeColor: baseColor,
        tooltip: l10n.commonSave,
        semanticsLabel: 'marker_exhibition_save',
        onTap: () {
          unawaited(() async {
            final authenticated =
                await const ContextualAuthGate().ensureAuthenticated(
              context,
              actionLabel: l10n.commonSave.toLowerCase(),
              returnRoute: markerReturnRoute,
              actionType: PendingActionType.save,
              targetType: PendingActionTargetType.exhibition,
              targetId: exhibition.id,
              targetLabel: exhibition.title,
              markerId: marker.id,
              sourceScreen: sourceScreen,
            );
            if (!authenticated || !context.mounted) return;
            await savedItemsProvider.toggleExhibitionSaved(exhibition.id);
            onEngagementChanged?.call();
          }());
        },
      ),
      MarkerOverlayActionSpec(
        icon: Icons.share_outlined,
        label: l10n.commonShare,
        isActive: false,
        activeColor: baseColor,
        tooltip: l10n.commonShare,
        semanticsLabel: 'marker_exhibition_share',
        onTap: () {
          ShareService().showShareSheet(
            context,
            target: ShareTarget.exhibition(
              exhibitionId: exhibition.id,
              title: exhibition.title,
            ),
            sourceScreen: sourceScreen,
          );
        },
      ),
    ]);
    return actions;
  }

  if (artwork == null || canPresentExhibition) {
    return actions;
  }

  actions.addAll(<MarkerOverlayActionSpec>[
    MarkerOverlayActionSpec(
      icon: artwork.isFavoriteByCurrentUser || artwork.isFavorite
          ? Icons.bookmark
          : Icons.bookmark_border,
      label: l10n.commonSave,
      isActive: artwork.isFavoriteByCurrentUser || artwork.isFavorite,
      activeColor: baseColor,
      tooltip: l10n.commonSave,
      semanticsLabel: 'marker_save',
      onTap: () {
        unawaited(() async {
          final authenticated =
              await const ContextualAuthGate().ensureAuthenticated(
            context,
            actionLabel: l10n.commonSave.toLowerCase(),
            returnRoute: markerReturnRoute,
            actionType: PendingActionType.save,
            targetType: PendingActionTargetType.artwork,
            targetId: artwork.id,
            targetLabel: artwork.title,
            markerId: marker.id,
            sourceScreen: sourceScreen,
          );
          if (!authenticated || !context.mounted) return;
          await artworkProvider.toggleArtworkSaved(artwork.id);
          onEngagementChanged?.call();
        }());
      },
    ),
    MarkerOverlayActionSpec(
      icon: Icons.share_outlined,
      label: l10n.commonShare,
      isActive: false,
      activeColor: baseColor,
      tooltip: l10n.commonShare,
      semanticsLabel: 'marker_share',
      onTap: () {
        ShareService().showShareSheet(
          context,
          target: ShareTarget.artwork(
            artworkId: artwork.id,
            title: artwork.title,
          ),
          sourceScreen: sourceScreen,
        );
      },
    ),
    MarkerOverlayActionSpec(
      icon:
          artwork.isLikedByCurrentUser ? Icons.favorite : Icons.favorite_border,
      label: '${artwork.likesCount}',
      isActive: artwork.isLikedByCurrentUser,
      activeColor: scheme.error,
      tooltip: l10n.commonLikes,
      semanticsLabel: 'marker_like',
      onTap: () {
        unawaited(() async {
          final authenticated =
              await const ContextualAuthGate().ensureAuthenticated(
            context,
            actionLabel: l10n.commonLikes.toLowerCase(),
            returnRoute: markerReturnRoute,
            actionType: PendingActionType.like,
            targetType: PendingActionTargetType.artwork,
            targetId: artwork.id,
            targetLabel: artwork.title,
            markerId: marker.id,
            sourceScreen: sourceScreen,
          );
          if (!authenticated || !context.mounted) return;
          await artworkProvider.toggleLike(artwork.id);
          onEngagementChanged?.call();
        }());
      },
    ),
  ]);

  return actions;
}
