import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/art_marker.dart';
import '../../models/artwork.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/artwork_media_resolver.dart';
import '../../utils/design_tokens.dart';
import '../../utils/media_url_resolver.dart';
import '../glass_components.dart';

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
    this.artwork,
    this.distanceText,
    this.description,
    this.maxPreviewChars = 300,
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

  final VoidCallback onClose;

  final VoidCallback onPrimaryAction;
  final IconData primaryActionIcon;
  final String primaryActionLabel;

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

    final rawDescription = (description ??
            (marker.description.isNotEmpty
                ? marker.description
                : (artwork?.description ?? '')))
        .trim();
    final visibleDescription = rawDescription.isEmpty
        ? ''
        : (rawDescription.length <= maxPreviewChars
            ? rawDescription
            : '${rawDescription.substring(0, maxPreviewChars)}...');

    final rawImageUrl = ArtworkMediaResolver.resolveCover(
      artwork: artwork,
      metadata: marker.metadata,
    );
    final imageUrl = MediaUrlResolver.resolveDisplayUrl(
      rawImageUrl,
      maxWidth: 960,
    );
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final cacheWidth = (320 * dpr).clamp(128.0, 960.0).round();
    final cacheHeight = (120 * dpr).clamp(96.0, 720.0).round();

    final showChips = _hasChips(marker: marker, artwork: artwork) ||
        canPresentExhibition;

    final actionFg = AppColorUtils.contrastText(baseColor);

    final card = Semantics(
      label: 'marker_floating_card',
      container: true,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KubusRadius.lg),
            border: Border.all(
              color: baseColor.withValues(alpha: 0.35),
              width: KubusSizes.hairline,
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: LiquidGlassPanel(
            padding: const EdgeInsets.all(KubusSpacing.md),
            borderRadius: BorderRadius.circular(KubusRadius.lg),
            showBorder: false,
            backgroundColor: scheme.surface.withValues(alpha: 0.45),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (canPresentExhibition) ...[
                            Text(
                              l10n.commonExhibition,
                              style: KubusTypography.textTheme.labelSmall
                                  ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: baseColor,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: KubusTypography.textTheme.titleSmall
                                ?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (distanceText != null && distanceText!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: baseColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.near_me, size: 12, color: baseColor),
                            const SizedBox(width: 4),
                            Text(
                              distanceText!,
                              style: KubusTypography.textTheme.labelSmall
                                  ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: baseColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 6),
                    _OverlayIconButton(
                      icon: Icons.close,
                      tooltip: l10n.commonClose,
                      onTap: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.low,
                            cacheWidth: cacheWidth,
                            cacheHeight: cacheHeight,
                            errorBuilder: (_, __, ___) => _imageFallback(
                              baseColor,
                              scheme,
                              marker,
                            ),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: baseColor.withValues(alpha: 0.12),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          )
                        : _imageFallback(
                            baseColor,
                            scheme,
                            marker,
                          ),
                  ),
                ),
                if (visibleDescription.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    visibleDescription,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: KubusTypography.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (showChips) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (canPresentExhibition)
                        _OverlayChip(
                          label: 'POAP',
                          icon: Icons.verified_outlined,
                          accent: baseColor,
                          selected: true,
                        ),
                      if (artwork != null &&
                          artwork!.category.isNotEmpty &&
                          artwork!.category != 'General')
                        _OverlayChip(
                          label: artwork!.category,
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
                      if (artwork != null && artwork!.rewards > 0)
                        _OverlayChip(
                          label: '+${artwork!.rewards}',
                          icon: Icons.card_giftcard,
                          accent: baseColor,
                          selected: false,
                        ),
                    ],
                  ),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (int i = 0; i < actions.length; i++) ...[
                        Expanded(
                          child: _OverlayActionButton(
                            spec: actions[i],
                          ),
                        ),
                        if (i != actions.length - 1)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ],
                if (stackCount > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Center(
                      child: _OverlayPager(
                        count: stackCount,
                        index: stackIndex,
                        accent: baseColor,
                        onPrevious: onPreviousStacked,
                        onNext: onNextStacked,
                        onSelectIndex: onSelectStackIndex,
                        inactiveColor:
                            scheme.onSurfaceVariant.withValues(alpha: 0.4),
                        arrowColor: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Semantics(
                    label: 'marker_more_info',
                    button: true,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: baseColor,
                        foregroundColor: actionFg,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onPressed: onPrimaryAction,
                      icon: Icon(primaryActionIcon, size: 18),
                      label: Text(
                        primaryActionLabel,
                        style: KubusTypography.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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

        // If we have a bounded height, scale down the whole card (instead of
        // scrolling) so it always fits vertically across devices.
        if (resolvedMaxHeight != null && resolvedMaxHeight.isFinite) {
          return SizedBox(
            width: resolvedMaxWidth,
            height: resolvedMaxHeight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: resolvedMaxWidth,
                child: card,
              ),
            ),
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

  static bool _hasChips({required ArtMarker marker, required Artwork? artwork}) {
    return (artwork != null &&
            artwork.category.isNotEmpty &&
            artwork.category != 'General') ||
        marker.metadata?['subjectCategory'] != null ||
        marker.metadata?['subject_category'] != null ||
        marker.metadata?['locationName'] != null ||
        marker.metadata?['location'] != null ||
        (artwork != null && artwork.rewards > 0);
  }

  static Widget _imageFallback(
    Color baseColor,
    ColorScheme scheme,
    ArtMarker marker,
  ) {
    final hasExhibitions =
        marker.isExhibitionMarker || marker.exhibitionSummaries.isNotEmpty;
    final icon = hasExhibitions
        ? AppColorUtils.exhibitionIcon
        : Icons.auto_awesome;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = scheme.surface.withValues(alpha: isDark ? 0.46 : 0.52);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          mouseCursor: onTap == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: isDark ? 0.22 : 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: LiquidGlassPanel(
              padding: EdgeInsets.zero,
              margin: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(999),
              showBorder: false,
              backgroundColor: bg,
              child: Center(
                child: Icon(icon, size: 18, color: scheme.onSurface),
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = selected
        ? accent.withValues(alpha: isDark ? 0.24 : 0.18)
        : scheme.surface.withValues(alpha: isDark ? 0.34 : 0.42);
    final border = selected
        ? accent.withValues(alpha: 0.35)
        : scheme.outlineVariant.withValues(alpha: 0.30);
    final fg = selected ? accent : scheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: LiquidGlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(999),
        showBorder: false,
        backgroundColor: bg,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: KubusTypography.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = spec.isActive
        ? spec.activeColor.withValues(alpha: isDark ? 0.24 : 0.18)
        : scheme.surface.withValues(alpha: isDark ? 0.34 : 0.42);
    final border = spec.isActive
        ? spec.activeColor.withValues(alpha: 0.35)
        : scheme.outlineVariant.withValues(alpha: 0.30);
    final fg = spec.isActive ? spec.activeColor : scheme.onSurfaceVariant;

    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: spec.onTap,
        mouseCursor: spec.onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(KubusRadius.sm),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KubusRadius.sm),
            border: Border.all(color: border),
          ),
          child: LiquidGlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            margin: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(KubusRadius.sm),
            showBorder: false,
            backgroundColor: bg,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(spec.icon, size: 16, color: fg),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    spec.label,
                    style: KubusTypography.textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
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
          cursor:
              onNext == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
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

