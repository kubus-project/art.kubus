import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/artwork.dart';
import '../../../providers/artwork_provider.dart';
import '../../../services/share/share_service.dart';
import '../../../services/share/share_types.dart';
import '../../../widgets/common/kubus_marker_overlay_card.dart';

List<MarkerOverlayActionSpec> buildMarkerOverlayActions({
  required BuildContext context,
  required Artwork? artwork,
  required bool canPresentExhibition,
  required Color baseColor,
  required String sourceScreen,
}) {
  if (artwork == null || canPresentExhibition) {
    return const <MarkerOverlayActionSpec>[];
  }

  final l10n = AppLocalizations.of(context)!;
  final scheme = Theme.of(context).colorScheme;
  final artworkProvider = context.read<ArtworkProvider>();

  return <MarkerOverlayActionSpec>[
    MarkerOverlayActionSpec(
      icon: artwork.isLikedByCurrentUser
          ? Icons.favorite
          : Icons.favorite_border,
      label: '${artwork.likesCount}',
      isActive: artwork.isLikedByCurrentUser,
      activeColor: scheme.error,
      tooltip: l10n.commonLikes,
      semanticsLabel: 'marker_like',
      onTap: () {
        unawaited(artworkProvider.toggleLike(artwork.id));
      },
    ),
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
        unawaited(artworkProvider.toggleFavorite(artwork.id));
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
  ];
}
