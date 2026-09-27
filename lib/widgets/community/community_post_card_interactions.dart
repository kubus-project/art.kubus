part of 'community_post_card.dart';

/// One post action (like, comment, repost, share, save).
///
/// Exposes a button with a text label to assistive technology. Persistent
/// relationship actions (like, save) pass [toggled]; one-shot actions
/// (comment, repost, share) leave it `null` so they never announce a toggle
/// state. The hit area is at least 44 px square. When the count opens its
/// own list ([onCountTap], e.g. who liked or reposted), the count is a
/// second, separately labeled button so assistive technology can reach it.
class _InteractionButton extends StatelessWidget {
  const _InteractionButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.accentColor,
    this.onTap,
    this.onCountTap,
    this.countSemanticLabel,
    this.isActive = false,
    this.toggled,
    this.color,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final Color accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onCountTap;
  final String? countSemanticLabel;
  final bool isActive;
  final bool? toggled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final animationTheme = context.animationTheme;
    final finalColor =
        color ?? (isActive ? accentColor : roles.foregroundMuted);
    final countStyle = KubusTextStyles.navMetaLabel.copyWith(
      color: finalColor,
      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
    );
    final hasSeparateCount = label.isNotEmpty &&
        onCountTap != null &&
        (countSemanticLabel ?? '').isNotEmpty;

    Widget target({
      required String semantics,
      required VoidCallback? action,
      required Widget child,
      bool? toggledState,
    }) {
      return Semantics(
        container: true,
        button: true,
        enabled: action != null,
        toggled: toggledState,
        label: semantics,
        onTap: action,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: action,
            borderRadius: BorderRadius.circular(KubusRadius.surface),
            focusColor: roles.focus.withValues(alpha: 0.16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Center(widthFactor: 1, child: child),
            ),
          ),
        ),
      );
    }

    final icon = Icon(this.icon, color: finalColor, size: 20);
    if (hasSeparateCount) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          target(
            semantics: semanticLabel,
            action: onTap,
            toggledState: toggled,
            child: icon,
          ),
          target(
            semantics: '$countSemanticLabel, $label',
            action: onCountTap,
            child: AnimatedDefaultTextStyle(
              duration: animationTheme.short,
              style: countStyle,
              child: Text(label, textAlign: TextAlign.center),
            ),
          ),
        ],
      );
    }

    return target(
      semantics: label.isEmpty ? semanticLabel : '$semanticLabel, $label',
      action: onTap,
      toggledState: toggled,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          if (label.isNotEmpty) ...[
            const SizedBox(width: KubusSpacing.xs + KubusSpacing.xxs),
            AnimatedDefaultTextStyle(
              duration: animationTheme.short,
              style: countStyle,
              child: Text(label, textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }
}
