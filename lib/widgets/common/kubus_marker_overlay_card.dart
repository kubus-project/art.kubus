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

    final rawDescription = (description ??
            (marker.description.isNotEmpty
                ? marker.description
                : (artwork?.description ?? '')))
        .trim();
    final normalizedDescription = _normalizeDescription(rawDescription);
    final visibleDescription = _truncateDescription(
      normalizedDescription,
      maxWords: maxPreviewWords,
      maxChars: maxPreviewChars,
    );
    final descriptionWordCount = _wordCount(visibleDescription);

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
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final cacheWidth = (304 * dpr).clamp(128.0, 960.0).round();
    final hasConstrainedHeight = maxHeight != null && maxHeight!.isFinite;
    final constrainedImageHeight = KubusSpacing.xl * 3 + KubusSpacing.xxs;
    final unconstrainedImageHeight = KubusSpacing.xl * 3 + KubusSpacing.sm;
    final imageHeight = hasConstrainedHeight
        ? constrainedImageHeight
        : unconstrainedImageHeight;
    final cacheHeight = (imageHeight * dpr).clamp(96.0, 720.0).round();

    final showChips =
        _hasChips(marker: marker, artwork: artwork) || canPresentExhibition;
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
                distanceText: distanceText,
                isPromoted: isPromoted,
                onTitleTap: resolvedTitleTap,
              ),
              const SizedBox(height: KubusSpacing.sm),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, previewConstraints) {
                    final previewHeight = previewConstraints.maxHeight;
                    final constrainedImageHeight =
                        hasConstrainedHeight && previewHeight.isFinite
                            ? math.min(
                                imageHeight,
                                math.max(
                                  KubusSpacing.xl * 2.5,
                                  previewHeight * 0.62,
                                ),
                              )
                            : imageHeight;
                    final showImage = constrainedImageHeight >= 72.0;

                    return _CardTapArea(
                      onTap: resolvedCardTap,
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showImage) ...[
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
                            const SizedBox(
                              height: KubusSpacing.sm + KubusSpacing.xxs,
                            ),
                          ],
                          Expanded(
                            child: _buildBody(
                              baseColor: baseColor,
                              scheme: scheme,
                              artwork: artwork,
                              marker: marker,
                              visibleDescription: visibleDescription,
                              descriptionWordCount: descriptionWordCount,
                              showChips: showChips,
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

  Widget _buildHeader({
    required BuildContext context,
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required Color baseColor,
    required String displayTitle,
    required Artwork? artwork,
    required String? distanceText,
    required bool isPromoted,
    required VoidCallback? onTitleTap,
  }) {
    final titleWidget = Text(
      displayTitle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: KubusTypography.textTheme.titleLarge?.copyWith(
            fontSize: KubusHeaderMetrics.sectionTitle - 1,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: scheme.onSurface,
          ) ??
          KubusTextStyles.sectionTitle.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: scheme.onSurface,
          ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canPresentExhibition) ...[
                Text(
                  l10n.commonExhibition,
                  style: KubusTypography.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: baseColor,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: KubusSpacing.xxs),
              ],
              if (onTitleTap != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTitleTap,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: titleWidget,
                  ),
                )
              else
                titleWidget,
              if (artwork != null) ...[
                const SizedBox(height: KubusSpacing.xxs),
                ArtworkCreatorByline(
                  artwork: artwork,
                  maxLines: 1,
                  style: KubusTypography.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: KubusHeaderMetrics.sectionSubtitle - 2,
                    height: 1.15,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: KubusSpacing.sm),
        if (distanceText != null && distanceText.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KubusSpacing.sm - KubusSpacing.xxs,
              vertical: KubusSpacing.xxs + 1,
            ),
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.near_me, size: 10, color: baseColor),
                const SizedBox(width: KubusSpacing.xs),
                Text(
                  distanceText,
                  style: KubusTypography.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: baseColor,
                  ),
                ),
              ],
            ),
          ),
        if (isPromoted) ...[
          const SizedBox(width: KubusSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KubusSpacing.sm - KubusSpacing.xxs,
              vertical: KubusSpacing.xxs + 1,
            ),
            decoration: BoxDecoration(
              color: KubusColorRoles.of(context)
                  .achievementGold
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star,
                  size: KubusTypography.textTheme.labelSmall?.fontSize,
                  color: KubusColorRoles.of(context).achievementGold,
                ),
                const SizedBox(width: KubusSpacing.xs),
                Text(
                  'Promoted',
                  style: TextStyle(
                    fontSize: KubusSizes.badgeCountFontSize,
                    fontWeight: FontWeight.w700,
                    color: KubusColorRoles.of(context).achievementGold,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(width: KubusSpacing.xs),
        _OverlayIconButton(
          icon: Icons.close,
          tooltip: l10n.commonClose,
          onTap: onClose,
        ),
      ],
    );
  }

  Widget _buildImage({
    required Color baseColor,
    required ColorScheme scheme,
    required ArtMarker marker,
    required String? imageUrl,
    required String? imageVersion,
    required int cacheWidth,
    required int cacheHeight,
    required double imageHeight,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedHeight = constraints.maxWidth.isFinite
            ? math.min(imageHeight, constraints.maxWidth / 1.68)
            : imageHeight;
        return ClipRRect(
          borderRadius: BorderRadius.circular(KubusRadius.md),
          child: SizedBox(
            height: resolvedHeight,
            width: double.infinity,
            child: imageUrl != null
                ? KubusCachedImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    cacheWidth: cacheWidth,
                    cacheHeight: cacheHeight,
                    maxDisplayWidth: cacheWidth,
                    cacheVersion: imageVersion,
                    placeholderBuilder: (context) => Container(
                      color: baseColor.withValues(alpha: 0.12),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorBuilder: (_, __, ___) => _imageFallback(
                      baseColor,
                      scheme,
                      marker,
                    ),
                  )
                : _imageFallback(
                    baseColor,
                    scheme,
                    marker,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildBody({
    required Color baseColor,
    required ColorScheme scheme,
    required Artwork? artwork,
    required ArtMarker marker,
    required String visibleDescription,
    required int descriptionWordCount,
    required bool showChips,
    required bool isConstrained,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : double.infinity;

        int maxDescriptionLines = isConstrained ? 10 : 14;
        var showChipsResolved = showChips;

        if (isConstrained && descriptionWordCount >= 130) {
          showChipsResolved = false;
        }

        if (isConstrained && availableHeight.isFinite) {
          if (availableHeight < 82) {
            maxDescriptionLines = 2;
            showChipsResolved = false;
          } else if (availableHeight < 120) {
            maxDescriptionLines = 4;
            showChipsResolved = false;
          } else if (availableHeight < 158) {
            maxDescriptionLines = 6;
            showChipsResolved = false;
          } else if (availableHeight < 196) {
            maxDescriptionLines = 8;
            showChipsResolved = false;
          } else if (availableHeight < 238) {
            maxDescriptionLines = 9;
            showChipsResolved = false;
          }
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (visibleDescription.isNotEmpty) ...[
              Text(
                visibleDescription,
                maxLines: maxDescriptionLines,
                overflow: TextOverflow.ellipsis,
                style: KubusTextStyles.detailBody.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.32,
                  fontSize: KubusHeaderMetrics.sectionSubtitle - 2,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
            if (showChipsResolved) ...[
              const SizedBox(height: KubusSpacing.xs),
              Wrap(
                spacing: KubusSpacing.sm - KubusSpacing.xxs,
                runSpacing: KubusSpacing.sm - KubusSpacing.xxs,
                children: [
                  if (canPresentExhibition)
                    _OverlayChip(
                      label: 'POAP',
                      icon: Icons.verified_outlined,
                      accent: baseColor,
                      selected: true,
                    ),
                  if (artwork != null &&
                      artwork.category.isNotEmpty &&
                      artwork.category != 'General')
                    _OverlayChip(
                      label: artwork.category,
                      icon: Icons.palette,
                      accent: baseColor,
                      selected: false,
                    ),
                  if (marker.metadata?['subjectCategory'] != null ||
                      marker.metadata?['subject_category'] != null)
                    _OverlayChip(
                      label: (marker.metadata!['subjectCategory'] ??
                              marker.metadata!['subject_category'])
                          .toString(),
                      icon: Icons.category_outlined,
                      accent: baseColor,
                      selected: false,
                    ),
                  if (marker.metadata?['locationName'] != null ||
                      marker.metadata?['location'] != null)
                    _OverlayChip(
                      label: (marker.metadata!['locationName'] ??
                              marker.metadata!['location'])
                          .toString(),
                      icon: Icons.place_outlined,
                      accent: baseColor,
                      selected: false,
                    ),
                  if (artwork != null && artwork.rewards > 0)
                    _OverlayChip(
                      label: '+${artwork.rewards}',
                      icon: Icons.card_giftcard,
                      accent: baseColor,
                      selected: false,
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildFooter({
    required Color baseColor,
    required Color actionFg,
    required ColorScheme scheme,
    required int stackCount,
    required int stackIndex,
    required List<MarkerOverlayActionSpec> actions,
    required VoidCallback onPrimaryAction,
    required VoidCallback? onNextStacked,
    required VoidCallback? onPreviousStacked,
    required ValueChanged<int>? onSelectStackIndex,
    required IconData primaryActionIcon,
    required String primaryActionLabel,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (actions.isNotEmpty) ...[
          Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: KubusSpacing.sm),
                Expanded(child: _OverlayActionButton(spec: actions[i])),
              ],
            ],
          ),
          const SizedBox(height: KubusSpacing.xs),
        ],
        if (stackCount > 1) ...[
          Center(
            child: _OverlayPager(
              count: stackCount,
              index: stackIndex,
              accent: baseColor,
              inactiveColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
              arrowColor: scheme.onSurfaceVariant,
              onPrevious: onPreviousStacked,
              onNext: onNextStacked,
              onSelectIndex: onSelectStackIndex,
            ),
          ),
          const SizedBox(height: KubusSpacing.xs),
        ],
        SizedBox(
          width: double.infinity,
          child: Semantics(
            label: 'marker_more_info',
            button: true,
            child: _OverlayPrimaryButton(
              accent: baseColor,
              foregroundColor: actionFg,
              onPressed: onPrimaryAction,
              icon: primaryActionIcon,
              label: primaryActionLabel,
            ),
          ),
        ),
      ],
    );
  }

  static bool _hasChips(
      {required ArtMarker marker, required Artwork? artwork}) {
    return (artwork != null &&
            artwork.category.isNotEmpty &&
            artwork.category != 'General') ||
        marker.metadata?['subjectCategory'] != null ||
        marker.metadata?['subject_category'] != null ||
        marker.metadata?['locationName'] != null ||
        marker.metadata?['location'] != null ||
        (artwork != null && artwork.rewards > 0);
  }

  static String _normalizeDescription(String input) {
    if (input.isEmpty) return '';
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _truncateDescription(
    String input, {
    required int maxWords,
    required int maxChars,
  }) {
    if (input.isEmpty) return '';

    final words = input.split(' ');
    final cappedByWords = words.length > maxWords
        ? '${words.take(maxWords).join(' ')}...'
        : input;

    if (cappedByWords.length <= maxChars) return cappedByWords;

    final safeIndex = cappedByWords.lastIndexOf(' ', maxChars);
    if (safeIndex <= 0) {
      return '${cappedByWords.substring(0, maxChars)}...';
    }
    return '${cappedByWords.substring(0, safeIndex)}...';
  }

  static int _wordCount(String input) {
    if (input.trim().isEmpty) return 0;
    return input
        .trim()
        .split(RegExp(r'\s+'))
        .where((segment) => segment.trim().isNotEmpty)
        .length;
  }

  static Widget _imageFallback(
    Color baseColor,
    ColorScheme scheme,
    ArtMarker marker,
  ) {
    final hasExhibitions =
        marker.isExhibitionMarker || marker.exhibitionSummaries.isNotEmpty;
    final icon =
        hasExhibitions ? AppColorUtils.exhibitionIcon : Icons.auto_awesome;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            baseColor.withValues(alpha: 0.25),
            baseColor.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        icon,
        color: scheme.onPrimary,
        size: 42,
      ),
    );
  }
}

class _CardTapArea extends StatelessWidget {
  const _CardTapArea({
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(KubusRadius.sm);

    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor:
            onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: buildKubusMapGlassSurface(
          context: context,
          kind: KubusMapGlassSurfaceKind.button,
          borderRadius: radius,
          tintBase: scheme.surface,
          padding: EdgeInsets.zero,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: Icon(icon, size: 16, color: scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayChip extends StatelessWidget {
  const _OverlayChip({
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = selected
        ? accent.withValues(alpha: 0.35)
        : scheme.outlineVariant.withValues(alpha: 0.30);
    final fg = selected ? accent : scheme.onSurfaceVariant;

    return buildKubusMapGlassSurface(
      context: context,
      kind: KubusMapGlassSurfaceKind.button,
      borderRadius: BorderRadius.circular(999),
      tintBase: selected ? accent : scheme.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.sm,
        vertical: KubusSpacing.xs,
      ),
      border: Border.all(color: border),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: KubusSpacing.xs),
          Text(
            label,
            style: KubusTypography.textTheme.labelSmall?.copyWith(
              fontSize: KubusSizes.badgeCountFontSize,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayActionButton extends StatelessWidget {
  const _OverlayActionButton({required this.spec});

  final MarkerOverlayActionSpec spec;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = spec.isActive
        ? spec.activeColor.withValues(alpha: 0.35)
        : scheme.outlineVariant.withValues(alpha: 0.30);
    final fg = spec.isActive ? spec.activeColor : scheme.onSurfaceVariant;

    final content = MouseRegion(
      cursor: spec.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: buildKubusMapGlassSurface(
        context: context,
        kind: KubusMapGlassSurfaceKind.button,
        borderRadius: BorderRadius.circular(KubusRadius.sm),
        tintBase: spec.isActive ? spec.activeColor : scheme.surface,
        padding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.sm - KubusSpacing.xxs,
          vertical: KubusSpacing.sm - KubusSpacing.xxs,
        ),
        border: Border.all(color: border),
        onTap: spec.onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon, size: 15, color: fg),
            const SizedBox(width: KubusSpacing.xs),
            Flexible(
              child: Text(
                spec.label,
                style: KubusTypography.textTheme.bodyMedium?.copyWith(
                  fontSize: KubusHeaderMetrics.sectionSubtitle - 2.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    if ((spec.tooltip ?? '').isEmpty && (spec.semanticsLabel ?? '').isEmpty) {
      return content;
    }

    Widget wrapped = content;
    if ((spec.semanticsLabel ?? '').isNotEmpty) {
      wrapped = Semantics(
        label: spec.semanticsLabel,
        button: true,
        child: wrapped,
      );
    }
    if ((spec.tooltip ?? '').isNotEmpty) {
      wrapped = Tooltip(message: spec.tooltip!, child: wrapped);
    }
    return wrapped;
  }
}

class _OverlayPager extends StatelessWidget {
  const _OverlayPager({
    required this.count,
    required this.index,
    required this.accent,
    required this.inactiveColor,
    required this.arrowColor,
    required this.onPrevious,
    required this.onNext,
    required this.onSelectIndex,
  });

  final int count;
  final int index;
  final Color accent;
  final Color inactiveColor;
  final Color arrowColor;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int>? onSelectIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: onPrevious == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onPrevious,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(Icons.chevron_left, size: 20, color: arrowColor),
            ),
          ),
        ),
        ...List.generate(
          count,
          (dotIndex) {
            final isActive = index == dotIndex;
            final dot = AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 12 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: isActive ? accent : inactiveColor,
              ),
            );

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: onSelectIndex == null
                  ? dot
                  : MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelectIndex!(dotIndex),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: Center(child: dot),
                        ),
                      ),
                    ),
            );
          },
        ),
        MouseRegion(
          cursor: onNext == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onNext,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(Icons.chevron_right, size: 20, color: arrowColor),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlayPrimaryButton extends StatelessWidget {
  const _OverlayPrimaryButton({
    required this.accent,
    required this.foregroundColor,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final Color accent;
  final Color foregroundColor;
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cursor =
        onPressed == null ? SystemMouseCursors.basic : SystemMouseCursors.click;

    return MouseRegion(
      cursor: cursor,
      child: buildKubusMapGlassSurface(
        context: context,
        kind: KubusMapGlassSurfaceKind.button,
        borderRadius: BorderRadius.circular(KubusRadius.sm),
        tintBase: accent,
        padding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.sm + KubusSpacing.xxs,
          vertical: KubusSpacing.sm,
        ),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        onTap: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: foregroundColor),
            const SizedBox(width: KubusSpacing.sm - KubusSpacing.xxs),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: KubusTypography.textTheme.labelLarge?.copyWith(
                  fontSize: KubusHeaderMetrics.sectionSubtitle,
                  fontWeight: FontWeight.w700,
                  color: foregroundColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
