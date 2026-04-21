import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/art_marker.dart';
import '../../../models/artwork.dart';
import '../../../config/config.dart';
import '../../../providers/artwork_provider.dart';
import '../../../services/share/share_service.dart';
import '../../../services/share/share_types.dart';
import '../../../widgets/common/kubus_marker_overlay_card.dart';

List<MarkerOverlayActionSpec> buildMarkerOverlayActions({
  required BuildContext context,
  required ArtMarker marker,
  required Artwork? artwork,
  required bool canPresentExhibition,
  required Color baseColor,
  required String sourceScreen,
  VoidCallback? onClaimTap,
}) {
  final l10n = AppLocalizations.of(context)!;
  final scheme = Theme.of(context).colorScheme;
  final artworkProvider = context.read<ArtworkProvider>();
  final actions = <MarkerOverlayActionSpec>[];

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
        unawaited(artworkProvider.toggleArtworkSaved(artwork.id));
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
        unawaited(artworkProvider.toggleLike(artwork.id));
      },
    ),
  ]);

  return actions;
}
