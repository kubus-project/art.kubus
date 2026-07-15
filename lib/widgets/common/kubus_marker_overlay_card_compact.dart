part of 'kubus_marker_overlay_card.dart';

extension _KubusMarkerOverlayCardCompactParts on KubusMarkerOverlayCard {
  Widget _buildCompactMobileCard({
    required BuildContext context,
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required String? imageUrl,
    required String? imageVersion,
    required int cacheWidth,
    required int cacheHeight,
    required String visibleDescription,
    required Color actionForeground,
    required String artistLabel,
  }) {
    final media = MediaQuery.of(context);
    final motion = KubusMapMotion.fromMediaQuery(
      animationTheme: context.animationTheme,
      mediaQuery: media,
    );
    final contentMotion = motion.overlayReposition;
    final resolvedCardTap = onCardTap ?? onPrimaryAction;
    final typeLabel = (linkedSubjectTypeLabel ?? marker.category).trim();
    final largeText = media.textScaler.scale(1.0) > 1.3;
    final mediaSize = largeText
        ? KubusMapMetrics.mobileMarkerPreviewLargeTextMediaSize
        : KubusMapMetrics.mobileMarkerPreviewMediaSize;

    final preview = Row(
      key: ValueKey<String>('marker_compact_content:${marker.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCompactImage(
          baseColor: baseColor,
          scheme: scheme,
          marker: marker,
          imageUrl: imageUrl,
          imageVersion: imageVersion,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          size: mediaSize,
        ),
        const SizedBox(width: KubusSpacing.sm),
        Expanded(
          child: _CardTapArea(
            onTap: resolvedCardTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: mediaSize),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (typeLabel.isNotEmpty || distanceText != null)
                    Text(
                      [
                        if (typeLabel.isNotEmpty) typeLabel,
                        if ((distanceText ?? '').isNotEmpty) distanceText!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KubusTypography.textTheme.labelSmall?.copyWith(
                        color: baseColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(
                    displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KubusTypography.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  if (artistLabel.isNotEmpty) ...[
                    const SizedBox(height: KubusSpacing.xxs),
                    Text(
                      artistLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KubusTypography.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ],
                  if (visibleDescription.isNotEmpty && !largeText) ...[
                    const SizedBox(height: KubusSpacing.xxs),
                    Text(
                      visibleDescription,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KubusTypography.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.15,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: KubusSpacing.xxs),
        _OverlayIconButton(
          icon: Icons.close,
          tooltip: l10n.commonClose,
          onTap: onClose,
        ),
      ],
    );

    Widget card = Semantics(
      key: const ValueKey<String>('marker_overlay_card_surface'),
      label: displayTitle,
      container: true,
      child: Material(
        color: Colors.transparent,
        child: buildKubusMapGlassSurface(
          context: context,
          kind: KubusMapGlassSurfaceKind.panel,
          overlayName: 'marker-overlay-card-compact',
          borderRadius: BorderRadius.circular(KubusRadius.lg),
          tintBase: scheme.surface,
          padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xxs),
          border: Border.all(
            color: baseColor.withValues(alpha: 0.35),
            width: KubusSizes.hairline,
          ),
          boxShadow: [
            BoxShadow(
              color: baseColor.withValues(alpha: 0.16),
              blurRadius: KubusSpacing.lg,
              offset: const Offset(0, KubusSpacing.sm),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: contentMotion.duration,
                switchInCurve: contentMotion.curve,
                switchOutCurve: contentMotion.curve,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: preview,
              ),
              const SizedBox(height: KubusSpacing.sm),
              Row(
                children: [
                  if (stackCount > 1) ...[
                    _CompactMarkerStackPager(
                      count: stackCount,
                      index: stackIndex,
                      accent: baseColor,
                      onPrevious: onPreviousStacked,
                      onNext: onNextStacked,
                    ),
                    const SizedBox(width: KubusSpacing.xs),
                  ],
                  if (actions.isNotEmpty) ...[
                    _CompactMarkerActionsMenu(actions: actions),
                    const SizedBox(width: KubusSpacing.xs),
                  ],
                  Expanded(
                    child: Semantics(
                      label: primaryActionLabel,
                      button: true,
                      child: _OverlayPrimaryButton(
                        accent: baseColor,
                        foregroundColor: actionForeground,
                        onPressed: onPrimaryAction,
                        icon: primaryActionIcon,
                        label: primaryActionLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    card = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? double.infinity,
        maxHeight: maxHeight ??
            KubusMapMetrics.resolveMobileMarkerPreviewMaxHeight(media),
      ),
      child: card,
    );

    if (onHorizontalDragEnd != null) {
      card = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: onHorizontalDragEnd,
        child: card,
      );
    }
    return card;
  }
}

class _CompactMarkerStackPager extends StatelessWidget {
  const _CompactMarkerStackPager({
    required this.count,
    required this.index,
    required this.accent,
    required this.onPrevious,
    required this.onNext,
  });

  final int count;
  final int index;
  final Color accent;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final materialL10n = MaterialLocalizations.of(context);
    return Semantics(
      label: '${index + 1}/$count',
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CompactPagerButton(
            icon: Icons.chevron_left,
            tooltip: materialL10n.previousPageTooltip,
            onTap: onPrevious,
          ),
          ExcludeSemantics(
            child: Text(
              '${index + 1}/$count',
              style: KubusTypography.textTheme.labelMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _CompactPagerButton(
            icon: Icons.chevron_right,
            tooltip: materialL10n.nextPageTooltip,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _CompactPagerButton extends StatelessWidget {
  const _CompactPagerButton({
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
    return Semantics(
      label: tooltip,
      button: true,
      child: Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: KubusMapMetrics.minimumTouchTarget / 2,
          child: SizedBox.square(
            dimension: KubusMapMetrics.minimumTouchTarget,
            child: Icon(
              icon,
              size: KubusHeaderMetrics.actionIcon,
              color: onTap == null
                  ? scheme.onSurfaceVariant.withValues(alpha: 0.38)
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactMarkerActionsMenu extends StatelessWidget {
  const _CompactMarkerActionsMenu({required this.actions});

  final List<MarkerOverlayActionSpec> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox.square(
      dimension: KubusMapMetrics.minimumTouchTarget,
      child: PopupMenuButton<int>(
        tooltip: l10n.exhibitionCreatorQuickActionsTitle,
        icon: const Icon(Icons.bolt_outlined),
        onSelected: (index) => actions[index].onTap?.call(),
        itemBuilder: (context) => [
          for (var index = 0; index < actions.length; index++)
            PopupMenuItem<int>(
              value: index,
              enabled: actions[index].onTap != null,
              child: Row(
                children: [
                  Icon(
                    actions[index].icon,
                    color: actions[index].isActive
                        ? actions[index].activeColor
                        : null,
                  ),
                  const SizedBox(width: KubusSpacing.sm),
                  Flexible(child: Text(actions[index].label)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
