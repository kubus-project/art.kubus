import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/art_marker.dart';
import '../../../models/artwork.dart';
import '../../../models/event.dart';
import '../../../models/exhibition.dart';
import '../../../config/config.dart';
import '../../../providers/artwork_provider.dart';
import '../../../providers/saved_items_provider.dart';
import '../../../services/contextual_auth_gate.dart';
import '../../../services/share/share_service.dart';
import '../../../services/share/share_types.dart';
import '../../../utils/map_destination_actions.dart';
import '../../../widgets/common/kubus_marker_overlay_card.dart';
import 'map_marker_overlay_presentation.dart';

/// The quick card offers directions exactly when the marker has a coordinate
/// a person could be sent to.
bool markerOverlayHasDirections(ArtMarker marker) =>
    MapDestination.isValidCoordinate(marker.position);

/// Whether [buildMarkerOverlayActions] would produce at least one secondary
/// action for this marker.
///
/// Mirrors the builder's branches exactly so the quick card's height estimator
/// reserves the footer's action row if and only if the card renders one. Kept
/// free of [BuildContext] so it is callable from a layout resolver.
bool markerOverlayHasSecondaryActions({
  required ArtMarker marker,
  required Artwork? artwork,
  required KubusEvent? event,
  required Exhibition? exhibition,
  required bool canPresentExhibition,
  bool canClaimStreetArt = false,
}) {
  if (markerOverlayHasDirections(marker)) return true;
  if (canClaimStreetArt &&
      AppConfig.isFeatureEnabled('streetArtClaims') &&
      marker.type == ArtMarkerType.streetArt &&
      marker.isPublic) {
    return true;
  }
  if (event != null || exhibition != null) return true;
  if (artwork == null || canPresentExhibition) return false;
  return true;
}

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
        id: 'marker_claim',
        label: l10n.mapMarkerClaimButton,
        isActive: false,
        activeColor: baseColor,
        tooltip: l10n.mapMarkerClaimButton,
        semanticsLabel: l10n.mapMarkerClaimButton,
        onTap: onClaimTap,
      ),
    );
  }

  // Directions come before the engagement actions: where to go is the next
  // thing a person at a place wants, and it exists for every subject kind
  // (artwork, event, exhibition, institution) that has a coordinate.
  if (markerOverlayHasDirections(marker)) {
    final title = resolveMarkerOverlayPresentation(
      marker: marker,
      artwork: artwork,
      event: event,
      exhibition: exhibition,
    ).title;
    final destination = MapDestination(
      id: artwork?.id ?? marker.id,
      title: title,
      position: marker.position,
    );
    actions.add(
      MarkerOverlayActionSpec(
        id: 'marker_directions',
        icon: Icons.navigation_outlined,
        label: l10n.commonNavigate,
        isActive: false,
        activeColor: baseColor,
        tooltip: l10n.commonGetDirections,
        semanticsLabel: l10n.artDetailNavigateToTitle(title),
        onTap: () => unawaited(destination.showNavigationOptions(context)),
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
        id: 'marker_event_save',
        semanticsLabel: isSaved ? l10n.commonSavedToast : l10n.commonSave,
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
        id: 'marker_event_share',
        semanticsLabel: l10n.commonShare,
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
        id: 'marker_exhibition_save',
        semanticsLabel: isSaved ? l10n.commonSavedToast : l10n.commonSave,
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
        id: 'marker_exhibition_share',
        semanticsLabel: l10n.commonShare,
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
      id: 'marker_save',
      semanticsLabel: l10n.commonSave,
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
      id: 'marker_share',
      semanticsLabel: l10n.commonShare,
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
      id: 'marker_like',
      semanticsLabel: '${l10n.commonLikes} ${artwork.likesCount}',
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
