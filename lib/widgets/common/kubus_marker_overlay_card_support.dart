part of 'kubus_marker_overlay_card.dart';

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

class _OverlayMetaBadge extends StatelessWidget {
  const _OverlayMetaBadge({
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final fg = accent;

    return buildKubusMapGlassSurface(
      context: context,
      kind: KubusMapGlassSurfaceKind.button,
      borderRadius: BorderRadius.circular(999),
      tintBase: accent.withValues(alpha: 0.09),
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.sm - KubusSpacing.xxs,
        vertical: KubusSpacing.xxs + 1,
      ),
      border: Border.all(color: accent.withValues(alpha: 0.24)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg.withValues(alpha: 0.9)),
          const SizedBox(width: KubusSpacing.xxs),
          Text(
            label,
            style: KubusTypography.textTheme.labelSmall?.copyWith(
              fontSize: KubusHeaderMetrics.sectionSubtitle - 3,
              fontWeight: FontWeight.w600,
              color: fg.withValues(alpha: 0.95),
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
        ? spec.activeColor.withValues(alpha: 0.30)
        : scheme.outlineVariant.withValues(alpha: 0.26);
    final fg = spec.isActive ? spec.activeColor : scheme.onSurfaceVariant;

    final content = MouseRegion(
      cursor: spec.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: buildKubusMapGlassSurface(
        context: context,
        kind: KubusMapGlassSurfaceKind.button,
        borderRadius: BorderRadius.circular(KubusRadius.sm),
        tintBase: spec.isActive
            ? spec.activeColor.withValues(alpha: 0.14)
            : scheme.surface.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.sm - KubusSpacing.xxs,
          vertical: KubusSpacing.sm - KubusSpacing.xxs,
        ),
        border: Border.all(color: border),
        onTap: spec.onTap,
        child: SizedBox(
          height: 40,
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
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ],
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
    final effectiveArrowColor = arrowColor.withValues(alpha: 0.74);
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
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Icon(
                Icons.chevron_left,
                size: 17,
                color: effectiveArrowColor,
              ),
            ),
          ),
        ),
        ...List.generate(
          count,
          (dotIndex) {
            final isActive = index == dotIndex;
            final dot = AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 11 : 5,
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: isActive
                    ? accent.withValues(alpha: 0.92)
                    : inactiveColor.withValues(alpha: 0.8),
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
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Icon(
                Icons.chevron_right,
                size: 17,
                color: effectiveArrowColor,
              ),
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
            color: accent.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        onTap: onPressed,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: foregroundColor),
              const SizedBox(width: KubusSpacing.sm - KubusSpacing.xxs),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
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
      ),
    );
  }
}
