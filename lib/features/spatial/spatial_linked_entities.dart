import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/art_marker.dart';
import '../../models/artwork.dart';
import '../../utils/artwork_navigation.dart';
import '../../utils/map_navigation.dart';
import '../../widgets/kubus_kit.dart';
import 'spatial_artwork_thumbnail.dart';
import 'spatial_marker_directory.dart';
import 'spatial_record_presentation.dart';

/// The "Linked to" section of a capture's detail screen.
///
/// The association is the point of the record, so it is shown as a
/// relationship the user can follow — not as two ids in a metadata table. A
/// reference that no longer resolves says so plainly and keeps the stored id,
/// because silently relinking a capture to something else destroys the only
/// evidence of what it was actually a scan of.
class SpatialLinkedEntities extends StatelessWidget {
  const SpatialLinkedEntities({
    super.key,
    required this.display,
    required this.artworkId,
    this.artwork,
    this.marker,
    this.onOpenArtwork,
    this.onOpenMarker,
  });

  final SpatialRecordDisplay display;
  final String artworkId;
  final Artwork? artwork;
  final ArtMarker? marker;

  /// Injectable for tests. Null uses the app's shared navigation helpers.
  final VoidCallback? onOpenArtwork;
  final VoidCallback? onOpenMarker;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final markerLabel = display.markerLabel;
    final canOpenMarker = marker != null &&
        markerHasMapLocation(marker!) &&
        display.markerResolved;

    return KubusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.spatialLibraryLinkedTo,
            style: KubusTextStyles.detailSectionTitle,
          ),
          const SizedBox(height: KubusSpacing.sm),
          _LinkRow(
            label: l10n.spatialLibraryArtworkLabel,
            leading: SpatialArtworkThumbnail(
              artwork: artwork,
              size: KubusSizes.compactThumbnail,
              semanticLabel: display.artworkLabel,
            ),
            title: display.artworkLabel,
            subtitle: display.subtitle,
            resolved: display.artworkResolved,
            onTap: display.artworkResolved
                ? (onOpenArtwork ??
                    () => unawaited(
                          openArtwork(
                            context,
                            artworkId,
                            source: 'spatial_library',
                          ),
                        ))
                : null,
          ),
          if (markerLabel != null) ...<Widget>[
            const SizedBox(height: KubusSpacing.sm),
            _LinkRow(
              label: l10n.spatialLibraryMarkerLabel,
              leading: Icon(
                display.markerResolved
                    ? (canOpenMarker
                        ? Icons.place_outlined
                        : Icons.qr_code_2_rounded)
                    : Icons.link_off_rounded,
                color: scheme.onSurfaceVariant,
              ),
              title: markerLabel,
              subtitle: display.markerResolved
                  ? (canOpenMarker
                      ? l10n.spatialMarkerKindLocation
                      : l10n.spatialMarkerKindConfiguration)
                  : null,
              resolved: display.markerResolved,
              trailingLabel: canOpenMarker ? l10n.spatialViewOnMap : null,
              onTap: canOpenMarker
                  ? (onOpenMarker ??
                      () => MapNavigation.open(
                            context,
                            center: marker!.position,
                            initialMarkerId: marker!.id,
                            initialArtworkId: artworkId,
                            initialTargetLabel: marker!.name,
                          ))
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.label,
    required this.leading,
    required this.title,
    required this.resolved,
    this.subtitle,
    this.trailingLabel,
    this.onTap,
  });

  final String label;
  final Widget leading;
  final String title;
  final String? subtitle;
  final bool resolved;
  final String? trailingLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: KubusSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: KubusTextStyles.detailLabel.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Row(
            children: <Widget>[
              leading,
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: KubusTextStyles.detailCardTitle.copyWith(
                        color:
                            resolved ? scheme.onSurface : roles.warningAction,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: KubusSpacing.xxs),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KubusTextStyles.detailCaption.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingLabel != null) ...<Widget>[
                const SizedBox(width: KubusSpacing.sm),
                Flexible(
                  child: Text(
                    trailingLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: KubusTextStyles.detailCaption.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: KubusSizes.trailingChevron,
                ),
            ],
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KubusRadius.sm),
      child: row,
    );
  }
}
