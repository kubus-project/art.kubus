import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/art_marker.dart';
import '../../models/artwork.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/artwork_media_resolver.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/media_url_resolver.dart';
import '../artwork_creator_byline.dart';
import '../map/kubus_map_glass_surface.dart';
import 'kubus_cached_image.dart';

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
    this.distanceText,
    this.description,
    this.linkedSubjectTypeLabel,
    this.linkedSubjectTitle,
    this.linkedSubjectSubtitle,
    this.maxPreviewChars = 1800,
    this.maxPreviewWords = 220,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    const cardPadding = KubusSpacing.md - KubusSpacing.xs;

    final rawDescriptionCandidate = (description ??
        (marker.description.isNotEmpty
          ? marker.description
          : (artwork?.description ?? '')))
      .trim();
    final rawDescription = rawDescriptionCandidate.isNotEmpty
      ? rawDescriptionCandidate
      : (linkedSubjectSubtitle ?? '').trim();
    final normalizedDescription = _normalizeDescription(rawDescription);
    final visibleDescription = _truncateDescription(
      normalizedDescription,
      maxWords: maxPreviewWords,
      maxChars: maxPreviewChars,
    );

    final rawImageUrl = ArtworkMediaResolver.resolveCover(
      artwork: artwork,
      metadata: marker.metadata,
    );
    final imageUrl = MediaUrlResolver.resolveDisplayUrl(
      rawImageUrl,
      maxWidth: 960,
    );
    final imageVersion = KubusCachedImage.versionTokenFromDate(
      artwork?.updatedAt ?? marker.updatedAt,
    );
    final dpr = (MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0)
      .clamp(1.0, 2.0);
    final cacheWidth = (304 * dpr).clamp(128.0, 960.0).round();
    final hasConstrainedHeight = maxHeight != null && maxHeight!.isFinite;
    final constrainedImageHeight = KubusSpacing.xl * 4 + KubusSpacing.xs;
    final unconstrainedImageHeight = KubusSpacing.xl * 5 + KubusSpacing.xs;
    final imageHeight = hasConstrainedHeight
        ? constrainedImageHeight
        : unconstrainedImageHeight;
    final cacheHeight = (imageHeight * dpr).clamp(160.0, 720.0).round();

    final isPromoted =
        marker.isPromoted || (artwork?.promotion.isPromoted ?? false);
    final actionFg = AppColorUtils.contrastText(baseColor);

    final resolvedCardTap = onCardTap ?? onPrimaryAction;
    final resolvedTitleTap = onTitleTap ?? onPrimaryAction;

    Widget card = Semantics(
      label: 'marker_floating_card',
      container: true,
      child: Material(
        color: Colors.transparent,
        child: buildKubusMapGlassSurface(
          context: context,
          kind: KubusMapGlassSurfaceKind.panel,
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
            mainAxisSize:
                hasConstrainedHeight ? MainAxisSize.max : MainAxisSize.min,
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
              const SizedBox(height: KubusSpacing.sm),
              Flexible(
                fit: hasConstrainedHeight ? FlexFit.tight : FlexFit.loose,
                child: LayoutBuilder(
                  builder: (context, previewConstraints) {
                    final previewHeight = previewConstraints.maxHeight;
                    final constrainedImageHeight =
                        hasConstrainedHeight && previewHeight.isFinite
                            ? math.min(
                                imageHeight,
                                math.max(
                                  112.0,
                                  previewHeight * 0.42,
                                ),
                              )
                            : imageHeight;
                    final showImage = constrainedImageHeight >= 132.0;

                    return _CardTapArea(
                      onTap: resolvedCardTap,
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildImage(
                            baseColor: baseColor,
                            scheme: scheme,
                            marker: marker,
                            imageUrl: imageUrl,
                            imageVersion: imageVersion,
                            cacheWidth: cacheWidth,
                            cacheHeight: cacheHeight,
                            imageHeight: constrainedImageHeight,
                          ),
                          if (showImage) ...[
                            const SizedBox(
                              height: KubusSpacing.sm + KubusSpacing.xxs,
                            ),
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
                            const SizedBox(height: KubusSpacing.sm),
                          ],
                          if (visibleDescription.isNotEmpty)
                            Expanded(
                              child: _buildBody(
                                context: context,
                                scheme: scheme,
                                visibleDescription: visibleDescription,
                                isConstrained: hasConstrainedHeight,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: KubusSpacing.sm),
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

    Widget wrapped = LayoutBuilder(
      builder: (context, constraints) {
        final double? resolvedMaxWidth = maxWidth ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : null);
        final double? resolvedMaxHeight = maxHeight ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : null);

        if (resolvedMaxHeight != null && resolvedMaxHeight.isFinite) {
          return SizedBox(
            width: resolvedMaxWidth,
            height: resolvedMaxHeight,
            child: card,
          );
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: resolvedMaxWidth ?? double.infinity,
          ),
          child: card,
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
