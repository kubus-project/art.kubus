part of 'kubus_marker_overlay_card.dart';

extension _KubusMarkerOverlayCardHeaderParts on KubusMarkerOverlayCard {
  Widget _buildHeader({
    required BuildContext context,
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required Color baseColor,
    required String displayTitle,
    required Artwork? artwork,
    required String? distanceText,
    required bool isPromoted,
    required bool canPresentExhibition,
    required VoidCallback? onTitleTap,
    required String? linkedSubjectTypeLabel,
    required String? linkedSubjectTitle,
    required String? linkedSubjectSubtitle,
  }) {
    final normalizedLinkedTypeLabel = linkedSubjectTypeLabel?.trim();
    final normalizedLinkedTitle = linkedSubjectTitle?.trim();
    final normalizedLinkedSubtitle = linkedSubjectSubtitle?.trim();
    final displayTitleNormalized = displayTitle.trim();
    final showLinkedTitle = normalizedLinkedTitle != null &&
        normalizedLinkedTitle.isNotEmpty &&
        normalizedLinkedTitle != displayTitleNormalized;
    final showLinkedSubtitle =
        normalizedLinkedSubtitle != null && normalizedLinkedSubtitle.isNotEmpty;
    final showLinkedContext = showLinkedTitle || showLinkedSubtitle;

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
              if ((normalizedLinkedTypeLabel ?? '').isNotEmpty) ...[
                Text(
                  normalizedLinkedTypeLabel!,
                  style: KubusTypography.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: baseColor,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: KubusSpacing.xxs),
              ] else if (canPresentExhibition) ...[
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
              if (showLinkedContext) ...[
                const SizedBox(height: KubusSpacing.xxs),
                if (showLinkedTitle)
                  Text(
                    normalizedLinkedTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KubusTypography.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: KubusHeaderMetrics.sectionSubtitle - 1,
                      height: 1.15,
                    ),
                  ),
                if (showLinkedSubtitle) ...[
                  if (showLinkedTitle) const SizedBox(height: 2),
                  Text(
                    normalizedLinkedSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KubusTypography.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                      fontSize: KubusHeaderMetrics.sectionSubtitle - 2,
                      height: 1.15,
                    ),
                  ),
                ],
              ],
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
}
