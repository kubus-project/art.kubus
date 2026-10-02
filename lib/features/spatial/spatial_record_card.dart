import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/art_marker.dart';
import '../../models/artwork.dart';
import '../../providers/artwork_provider.dart';
import '../../services/spatial_library_store.dart';
import '../../utils/node_state_presentation.dart';
import '../../widgets/kubus_kit.dart';
import 'spatial_artwork_thumbnail.dart';
import 'spatial_marker_directory.dart';
import 'spatial_record_presentation.dart';
import 'spatial_status_presentation.dart';

/// One capture in the Spatial Library list.
///
/// The card answers, in order: what is this a capture *of*, where, what state
/// is it in, and how much of the device is it using. The previous card led
/// with three identical neutral pills, which made every capture look the same
/// and buried the one fact that distinguishes them.
class SpatialRecordCard extends StatelessWidget {
  const SpatialRecordCard({
    super.key,
    required this.record,
    required this.onTap,
    this.artworkOverride,
    this.markerDirectory,
  });

  final SpatialLibraryRecord record;
  final VoidCallback onTap;

  /// Injectable for tests. Null resolves the live provider for *this record's*
  /// artwork id.
  final Artwork? artworkOverride;

  final SpatialMarkerDirectory? markerDirectory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    // Selected per record, by this record's own id. A `watch` here would
    // rebuild every card in the list — and, worse, invites reaching for one
    // shared "current artwork" instead of the one this record names.
    final artwork = artworkOverride ??
        context.select<ArtworkProvider, Artwork?>(
          (provider) => provider.getArtworkById(record.artworkId),
        );
    final ArtMarker? marker = (record.markerId ?? '').isEmpty
        ? null
        : (markerDirectory ?? SpatialMarkerDirectory())
            .resolve(record.markerId);

    final display = SpatialRecordDisplay.resolve(
      l10n,
      record,
      artwork: artwork,
      marker: marker,
    );
    final status = SpatialStatusPresentation.forRecord(l10n, record);

    return KubusCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SpatialArtworkThumbnail(
            capturePath: display.thumbnailPath,
            artwork: artwork,
            semanticLabel: display.artworkLabel,
          ),
          const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  display.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTextStyles.detailCardTitle.copyWith(
                    color: display.artworkResolved
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
                if (display.subtitle != null) ...<Widget>[
                  const SizedBox(height: KubusSpacing.xxs),
                  Text(
                    display.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KubusTextStyles.detailCaption.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (display.markerLabel != null) ...<Widget>[
                  const SizedBox(height: KubusSpacing.xxs),
                  Row(
                    children: <Widget>[
                      Icon(
                        display.markerResolved
                            ? Icons.place_outlined
                            : Icons.link_off_rounded,
                        size: KubusSizes.trailingChevron,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: KubusSpacing.xs),
                      Expanded(
                        child: Text(
                          display.markerLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KubusTextStyles.detailCaption.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: KubusSpacing.sm),
                // One accented status, then quiet metadata. Not three
                // interchangeable pills.
                Wrap(
                  spacing: KubusSpacing.xs,
                  runSpacing: KubusSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    KubusBadge(
                      text: status.label,
                      icon: status.icon,
                      variant: KubusBadgeVariant.status,
                      accent: status.accent(context),
                      compact: true,
                    ),
                    if (record.isPublished && record.version != null)
                      KubusBadge(
                        text: l10n.spatialLibraryVersionLabel(record.version!),
                        compact: true,
                      ),
                  ],
                ),
                const SizedBox(height: KubusSpacing.xs),
                Text(
                  _metaLine(context, l10n),
                  maxLines: 2,
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: KubusSizes.trailingChevron,
          ),
        ],
      ),
    );
  }

  String _metaLine(BuildContext context, AppLocalizations l10n) {
    final date =
        MaterialLocalizations.of(context).formatMediumDate(record.capturedAt);
    final parts = <String>[
      date,
      l10n.spatialLibraryTrackedViews(record.sampleCount),
      NodeStatePresentation.formatBytes(record.totalBytes),
    ];
    return parts.join(' · ');
  }
}
