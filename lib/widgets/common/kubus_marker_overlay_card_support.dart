part of 'kubus_marker_overlay_card.dart';

bool _hasChips({required ArtMarker marker, required Artwork? artwork}) {
  return (artwork != null &&
          artwork.category.isNotEmpty &&
          artwork.category != 'General') ||
      marker.metadata?['subjectCategory'] != null ||
      marker.metadata?['subject_category'] != null ||
      marker.metadata?['locationName'] != null ||
      marker.metadata?['location'] != null ||
      marker.isCommunityMarker ||
      (artwork != null && artwork.rewards > 0);
}

String _normalizeDescription(String input) {
  if (input.isEmpty) return '';
  return input.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _truncateDescription(
  String input, {
  required int maxWords,
  required int maxChars,
}) {
  if (input.isEmpty) return '';

  final words = input.split(' ');
  final cappedByWords =
      words.length > maxWords ? '${words.take(maxWords).join(' ')}...' : input;

  if (cappedByWords.length <= maxChars) return cappedByWords;

  final safeIndex = cappedByWords.lastIndexOf(' ', maxChars);
  if (safeIndex <= 0) {
    return '${cappedByWords.substring(0, maxChars)}...';
  }
  return '${cappedByWords.substring(0, safeIndex)}...';
}

int _wordCount(String input) {
  if (input.trim().isEmpty) return 0;
  return input
      .trim()
      .split(RegExp(r'\s+'))
      .where((segment) => segment.trim().isNotEmpty)
      .length;
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
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(spec.icon, size: 15, color: fg),
            const SizedBox(width: KubusSpacing.xs),
            Flexible(
              child: Text(
                spec.label,
                textAlign: TextAlign.center,
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
