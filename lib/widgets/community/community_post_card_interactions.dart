part of 'community_post_card.dart';

class _InteractionButton extends StatelessWidget {
  const _InteractionButton({
    required this.icon,
    required this.label,
    required this.accentColor,
    this.onTap,
    this.onCountTap,
    this.isActive = false,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onCountTap;
  final bool isActive;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final animationTheme = context.animationTheme;
    final finalColor = color ??
        (isActive
            ? accentColor
            : scheme.onSurface.withValues(alpha: label.isEmpty ? 0.5 : 0.65));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: KubusSpacing.xs + KubusSpacing.xxs,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isActive ? 1.18 : 1.0,
              duration: animationTheme.short,
              curve: animationTheme.emphasisCurve,
              child: Icon(icon, color: finalColor, size: 20),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: KubusSpacing.sm),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onCountTap ?? onTap,
                child: AnimatedDefaultTextStyle(
                  duration: animationTheme.short,
                  style: KubusTextStyles.navMetaLabel.copyWith(
                    color: finalColor,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(label, textAlign: TextAlign.center),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
