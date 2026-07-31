import 'package:flutter/material.dart';

import '../../../features/map/detail/marker_info_detail_presentation.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/artwork.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/media_url_resolver.dart';
import '../../common/kubus_cached_image.dart';
import '../../common/kubus_reading_surface.dart';
import '../../common/marker_attribution_section.dart';
// `DetailHeader` is hidden: the map panel shell defines its own header widget of
// the same name, and that is the one this panel uses.
import '../../detail/detail_shell_components.dart' hide DetailHeader;
import '../kubus_map_glass_surface.dart';
import 'kubus_detail_panel.dart';

/// One secondary action on the generic marker-detail surface.
@immutable
class MarkerInfoDetailAction {
  const MarkerInfoDetailAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tooltip,
    this.isActive = false,
    this.activeColor,
    this.semanticsLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? tooltip;
  final bool isActive;
  final Color? activeColor;
  final String? semanticsLabel;
}

/// Body sections of the generic marker-detail surface.
///
/// Shared verbatim by [MarkerInfoDetailPanel] (desktop side panel) and
/// `MarkerInfoDetailScreen` (mobile full detail) so there is exactly one marker
/// detail implementation, not a second one competing with the event/exhibition
/// detail surfaces.
class MarkerInfoDetailSections extends StatelessWidget {
  const MarkerInfoDetailSections({
    super.key,
    required this.detail,
    required this.actions,
    this.artwork,
    this.padding = const EdgeInsets.all(KubusSpacing.lg),
  });

  final MarkerInfoDetail detail;
  final List<MarkerInfoDetailAction> actions;
  final Artwork? artwork;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final marker = detail.marker;

    final metaItems = <DetailMetaItem>[
      if ((detail.dateRangeLabel ?? '').isNotEmpty)
        DetailMetaItem(icon: Icons.schedule, label: detail.dateRangeLabel!),
      if ((detail.locationLabel ?? '').isNotEmpty)
        DetailMetaItem(
          icon: Icons.place_outlined,
          label: detail.locationLabel!,
        ),
      if ((detail.categoryLabel ?? '').isNotEmpty)
        DetailMetaItem(
          icon: Icons.category_outlined,
          label: detail.categoryLabel!,
        ),
      if ((detail.distanceLabel ?? '').isNotEmpty)
        DetailMetaItem(icon: Icons.near_me, label: detail.distanceLabel!),
    ];

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailIdentityBlock(
            key: const ValueKey<String>('marker_info_detail_identity'),
            title: detail.title,
            kicker: detail.kicker,
            subtitle: detail.subjectTypeLabel,
          ),
          if (detail.linkedSubjectUnavailable) ...[
            const SizedBox(height: KubusSpacing.md),
            _UnlinkedSubjectNotice(
              subjectTypeLabel: detail.subjectTypeLabel,
            ),
          ],
          if (metaItems.isNotEmpty) ...[
            const SizedBox(height: KubusSpacing.md),
            DetailMetadataBlock(compact: true, items: metaItems),
          ],
          const SizedBox(height: KubusSpacing.md),
          KubusReadingSurface(
            child: Text(
              detail.hasDescription
                  ? detail.description
                  : l10n.markerInfoDetailNoDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: detail.hasDescription
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
          ),
          MarkerAttributionSection.fromMarkerAndArtwork(marker, artwork),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: KubusSpacing.lg),
            DetailSecondaryActionCluster(
              maxVisible: 5,
              actions: <DetailSecondaryAction>[
                for (final action in actions)
                  DetailSecondaryAction(
                    icon: action.icon,
                    label: action.label,
                    onTap: action.onTap,
                    isActive: action.isActive,
                    activeColor: action.activeColor,
                    tooltip: action.tooltip ?? action.label,
                    semanticsLabel: action.semanticsLabel,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _UnlinkedSubjectNotice extends StatelessWidget {
  const _UnlinkedSubjectNotice({required this.subjectTypeLabel});

  final String? subjectTypeLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final label = (subjectTypeLabel ?? '').trim();
    final message = label.isEmpty
        ? l10n.markerInfoDetailUnlinkedNotice
        : l10n.markerInfoDetailUnlinkedTypedNotice(label.toLowerCase());

    return Container(
      key: const ValueKey<String>('marker_info_detail_unlinked_notice'),
      padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xxs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(KubusRadius.sm),
        border: KubusBorders.hairline(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: KubusSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Desktop side-panel shell for the generic marker-detail surface.
///
/// Uses the same [KubusDetailPanel] architecture as the artwork, event, and
/// exhibition panels so marker information docks into the map's left panel with
/// identical chrome, glass, and close behavior.
class MarkerInfoDetailPanel extends StatelessWidget {
  const MarkerInfoDetailPanel({
    super.key,
    required this.detail,
    required this.accentColor,
    required this.closeAccentColor,
    required this.onClose,
    this.actions = const <MarkerInfoDetailAction>[],
    this.artwork,
    this.margin = const EdgeInsets.only(left: 24),
  });

  final MarkerInfoDetail detail;
  final Color accentColor;
  final Color closeAccentColor;
  final VoidCallback onClose;
  final List<MarkerInfoDetailAction> actions;
  final Artwork? artwork;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: isDark ? 0.88 : 0.92),
        borderRadius: BorderRadius.circular(KubusRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 16, color: accentColor),
          const SizedBox(width: 6),
          Text(
            detail.kicker,
            style: KubusTextStyles.navMetaLabel.copyWith(
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );

    return KubusDetailPanel(
      key: const ValueKey<String>('marker_info_detail_panel'),
      kind: DetailPanelKind.markerInfo,
      presentation: PanelPresentation.sidePanel,
      margin: margin,
      blurPolicy: KubusMapBlurPolicy.forceMapChromeWhenCapable,
      overMapPlatformView: true,
      enablePlatformBackdropRegion: true,
      backdropRegionId: 'desktop-map-marker-info-detail-panel',
      header: DetailHeader(
        imageUrl: MediaUrlResolver.resolve(detail.coverUrl),
        imageVersion: KubusCachedImage.versionTokenFromDate(
          detail.coverUpdatedAt,
        ),
        height: 248,
        accentColor: accentColor,
        closeTooltip: l10n.commonClose,
        onClose: onClose,
        badge: badge,
        closeAccentColor: closeAccentColor,
        fallbackIcon: AppColorUtils.markerSubjectIcon(detail.marker.type.name),
      ),
      sections: [
        MarkerInfoDetailSections(
          detail: detail,
          actions: actions,
          artwork: artwork,
        ),
      ],
    );
  }
}
