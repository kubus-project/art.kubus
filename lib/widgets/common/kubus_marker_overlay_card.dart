import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/map/shared/marker_overlay_card_metrics.dart';
import '../../l10n/app_localizations.dart';
import '../../models/art_marker.dart';
import '../../models/artwork.dart';
import '../../utils/app_animations.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/artwork_media_resolver.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/media_url_resolver.dart';
import '../artwork_creator_byline.dart';
import '../inline_loading.dart';
import '../map/kubus_map_glass_surface.dart';
import 'kubus_cached_image.dart';
import 'marker_attribution_section.dart';

part 'kubus_marker_overlay_card_support.dart';
part 'kubus_marker_overlay_card_header.dart';
part 'kubus_marker_overlay_card_media.dart';
part 'kubus_marker_overlay_card_body.dart';
part 'kubus_marker_overlay_card_footer.dart';

class MarkerOverlayActionSpec {
  const MarkerOverlayActionSpec({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    this.onTap,
    this.tooltip,
    this.semanticsLabel,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback? onTap;
  final String? tooltip;
  final String? semanticsLabel;
}

/// Shared map marker overlay card used by both mobile and desktop map screens.
///
/// Notes:
/// - Does not position itself; it is intended to be placed inside a `Positioned`.
/// - Uses design tokens (`KubusSpacing`, `KubusRadius`, `KubusSizes`) and theme
///   colors, avoiding hardcoded UI colors.
class KubusMarkerOverlayCard extends StatelessWidget {
  const KubusMarkerOverlayCard({
    super.key,
    required this.marker,
    required this.baseColor,
    required this.displayTitle,
    required this.canPresentExhibition,
    required this.onClose,
    required this.onPrimaryAction,
    required this.primaryActionIcon,
    required this.primaryActionLabel,
    this.onCardTap,
    this.onTitleTap,
    this.artwork,
    this.subjectImageUrl,
    this.subjectImageUpdatedAt,
    this.distanceText,
    this.description,
    this.linkedSubjectTypeLabel,
    this.linkedSubjectTitle,
    this.linkedSubjectSubtitle,
    this.maxPreviewChars = MarkerOverlayCardMetrics.maxPreviewChars,
    this.maxPreviewWords = MarkerOverlayCardMetrics.maxPreviewWords,
    this.actions = const <MarkerOverlayActionSpec>[],
    this.stackCount = 1,
    this.stackIndex = 0,
    this.onNextStacked,
    this.onPreviousStacked,
    this.onSelectStackIndex,
    this.onHorizontalDragEnd,
    this.maxWidth,
    this.maxHeight,
  });

  final ArtMarker marker;
  final Artwork? artwork;
  final String? subjectImageUrl;
  final DateTime? subjectImageUpdatedAt;

  final Color baseColor;
  final String displayTitle;
  final bool canPresentExhibition;
  final String? distanceText;

  /// Optional description override. If null, uses marker/linked artwork.
  final String? description;
  final String? linkedSubjectTypeLabel;
  final String? linkedSubjectTitle;
  final String? linkedSubjectSubtitle;

  final int maxPreviewChars;
  final int maxPreviewWords;

  final VoidCallback onClose;

  final VoidCallback onPrimaryAction;
  final IconData primaryActionIcon;
  final String primaryActionLabel;
  final VoidCallback? onCardTap;
  final VoidCallback? onTitleTap;

  final List<MarkerOverlayActionSpec> actions;

  /// Stacked markers paging (optional).
  final int stackCount;
  final int stackIndex;
  final VoidCallback? onNextStacked;
  final VoidCallback? onPreviousStacked;
  final ValueChanged<int>? onSelectStackIndex;
  final ValueChanged<DragEndDetails>? onHorizontalDragEnd;

  /// Optional sizing hints.
  final double? maxWidth;
  final double? maxHeight;

  /// Resolves the vertical composition for this card inside [availableHeight].
  ///
  /// Delegates to [MarkerOverlayCardMetrics] so the rendered layout and the map
  /// overlay's reserved height are always derived from the same model.
  MarkerOverlayCardComposition resolveComposition({
    required double availableHeight,
    required bool isCompactWidth,
    required double textScale,
  }) {
    return MarkerOverlayCardMetrics.resolveComposition(
      spec: contentSpec(),
      availableHeight: availableHeight,
      isCompactWidth: isCompactWidth,
      textScale: textScale,
    );
  }

  /// The height-relevant content this card renders.
  MarkerOverlayCardContentSpec contentSpec() {
    final rawDescriptionCandidate = (description ??
            (marker.description.isNotEmpty
                ? marker.description
                : (artwork?.description ?? '')))
        .trim();
    final rawDescription = rawDescriptionCandidate.isNotEmpty
        ? rawDescriptionCandidate
        : (linkedSubjectSubtitle ?? '').trim();
    final linkedTitle = (linkedSubjectTitle ?? '').trim();

    return MarkerOverlayCardContentSpec(
      description: truncateMarkerOverlayDescription(
        normalizeMarkerOverlayDescription(rawDescription),
        maxWords: maxPreviewWords,
        maxChars: maxPreviewChars,
      ),
      badgeCount: _badgeCount(),
      attributionRows: MarkerAttributionSection.rowCountForMarkerAndArtwork(
        marker,
        artwork,
      ),
      hasKicker: (linkedSubjectTypeLabel ?? '').trim().isNotEmpty ||
          canPresentExhibition,
      hasLinkedTitle:
          linkedTitle.isNotEmpty && linkedTitle != displayTitle.trim(),
      hasLinkedSubtitle: (linkedSubjectSubtitle ?? '').trim().isNotEmpty,
      hasByline: artwork != null,
      secondaryActionRows: actions.isEmpty ? 0 : 1,
      hasPager: stackCount > 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    const cardPadding = MarkerOverlayCardMetrics.cardPadding;

    final spec = contentSpec();
    final visibleDescription = spec.description;

    final linkedSubjectImageUrl = (subjectImageUrl ?? '').trim();
    final rawImageUrl = linkedSubjectImageUrl.isNotEmpty
        ? linkedSubjectImageUrl
        : ArtworkMediaResolver.resolveCover(
            artwork: artwork,
            metadata: marker.metadata,
          );
    final imageUrl = MediaUrlResolver.resolveDisplayUrl(
      rawImageUrl,
      maxWidth: 960,
    );
    final imageVersion = KubusCachedImage.versionTokenFromDate(
      subjectImageUpdatedAt ?? artwork?.updatedAt ?? marker.updatedAt,
    );
    final media = MediaQuery.maybeOf(context);
    final dpr = (media?.devicePixelRatio ?? 1.0).clamp(1.0, 2.0);
    final cacheWidth = (304 * dpr).clamp(128.0, 960.0).round();
    final textScale = media?.textScaler.scale(100) != null
        ? media!.textScaler.scale(100) / 100
        : 1.0;

    final isPromoted =
        marker.isPromoted || (artwork?.promotion.isPromoted ?? false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actionFg = isDark ? Colors.white : Colors.black;

    final resolvedCardTap = onCardTap ?? onPrimaryAction;
    final resolvedTitleTap = onTitleTap ?? onPrimaryAction;

    // `Flexible` may only be used when the incoming height is bounded; an
    // unbounded column with a flex child throws. Callers that place the card in
    // an unbounded slot get the natural (non-absorbing) composition instead.
    Widget buildCardSurface(
      MarkerOverlayCardComposition composition, {
      required bool hasBoundedHeight,
    }) {
      final imageHeight = composition.mediaHeight;
      final cacheHeight =
          (math.max(imageHeight, 1.0) * dpr).clamp(96.0, 720.0).round();
      final showDescription =
          composition.showDescription && visibleDescription.isNotEmpty;
      final previewChildren = <Widget>[
        if (composition.showMedia)
          _buildImage(
            baseColor: baseColor,
            scheme: scheme,
            marker: marker,
            imageUrl: imageUrl,
            imageVersion: imageVersion,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            imageHeight: imageHeight,
          ),
        if (spec.badgeCount > 0) ...[
          if (composition.showMedia)
            const SizedBox(height: MarkerOverlayCardMetrics.innerGap),
          _buildMetadataTier(
            context: context,
            scheme: scheme,
            baseColor: baseColor,
            artwork: artwork,
            marker: marker,
            canPresentExhibition: canPresentExhibition,
            isPromoted: isPromoted,
            distanceText: distanceText,
          ),
        ],
        if (showDescription) ...[
          if (composition.showMedia || spec.badgeCount > 0)
            const SizedBox(height: MarkerOverlayCardMetrics.innerGap),
          // Flexible, not scrollable: the description block absorbs whatever
          // slack the reserved height leaves and clips with an ellipsis when the
          // viewport is tighter than the estimate. Full text stays reachable
          // through the card's primary action.
          if (hasBoundedHeight)
            Flexible(
              fit: FlexFit.loose,
              child: _buildBody(
                context: context,
                scheme: scheme,
                visibleDescription: visibleDescription,
                maxLines: composition.descriptionMaxLines,
              ),
            )
          else
            _buildBody(
              context: context,
              scheme: scheme,
              visibleDescription: visibleDescription,
              maxLines: composition.descriptionMaxLines,
            ),
        ],
        if (composition.showAttribution)
          MarkerAttributionSection.fromMarkerAndArtwork(
            marker,
            artwork,
          ),
      ];

      final previewContent = _CardTapArea(
        onTap: resolvedCardTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: previewChildren,
        ),
      );

      return Semantics(
        key: const ValueKey<String>('marker_overlay_card_surface'),
        label: displayTitle,
        container: true,
        child: Material(
          color: Colors.transparent,
          child: buildKubusMapGlassSurface(
            context: context,
            kind: KubusMapGlassSurfaceKind.panel,
            overlayName: 'marker-overlay-card',
            borderRadius: BorderRadius.circular(KubusRadius.lg),
            tintBase: scheme.surface,
            padding: const EdgeInsets.all(cardPadding),
            border: Border.all(
              color: baseColor.withValues(alpha: 0.35),
              width: KubusSizes.hairline,
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(
                  context: context,
                  l10n: l10n,
                  scheme: scheme,
                  baseColor: baseColor,
                  displayTitle: displayTitle,
                  artwork: artwork,
                  canPresentExhibition: canPresentExhibition,
                  onTitleTap: resolvedTitleTap,
                  linkedSubjectTypeLabel: linkedSubjectTypeLabel,
                  linkedSubjectTitle: linkedSubjectTitle,
                  linkedSubjectSubtitle: linkedSubjectSubtitle,
                ),
                const SizedBox(height: MarkerOverlayCardMetrics.sectionGap),
                if (previewChildren.isNotEmpty)
                  if (hasBoundedHeight)
                    Flexible(fit: FlexFit.loose, child: previewContent)
                  else
                    previewContent,
                const SizedBox(height: MarkerOverlayCardMetrics.sectionGap),
                _buildFooter(
                  baseColor: baseColor,
                  actionFg: actionFg,
                  scheme: scheme,
                  stackCount: stackCount,
                  stackIndex: stackIndex,
                  actions: actions,
                  onPrimaryAction: onPrimaryAction,
                  onNextStacked: onNextStacked,
                  onPreviousStacked: onPreviousStacked,
                  onSelectStackIndex: onSelectStackIndex,
                  primaryActionIcon: primaryActionIcon,
                  primaryActionLabel: primaryActionLabel,
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget wrapped = LayoutBuilder(
      builder: (context, constraints) {
        final double? resolvedMaxWidth = maxWidth ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : null);
        final double? resolvedMaxHeight = maxHeight ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : null);
        final isCompactWidth =
            MarkerOverlayCardMetrics.isCompactCard(resolvedMaxWidth);
        final composition = resolveComposition(
          availableHeight: resolvedMaxHeight ?? double.infinity,
          isCompactWidth: isCompactWidth,
          textScale: textScale,
        );

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: resolvedMaxWidth ?? double.infinity,
            maxHeight: resolvedMaxHeight ?? double.infinity,
          ),
          child: buildCardSurface(
            composition,
            hasBoundedHeight: resolvedMaxHeight != null,
          ),
        );
      },
    );

    if (onHorizontalDragEnd != null) {
      wrapped = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: onHorizontalDragEnd,
        child: wrapped,
      );
    }

    return wrapped;
  }
}
