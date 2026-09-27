part of 'community_post_card.dart';

/// One post action (like, comment, repost, share, save).
///
/// Exposes a button with a text label to assistive technology. Persistent
/// relationship actions (like, save) pass [toggled]; one-shot actions
/// (comment, repost, share) leave it `null` so they never announce a toggle
/// state. The hit area is at least 44 px square.
class _InteractionButton extends StatelessWidget {
  const _InteractionButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.accentColor,
    this.onTap,
    this.onCountTap,
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
  final bool isActive;
  final bool? toggled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final animationTheme = context.animationTheme;
    final finalColor =
        color ?? (isActive ? accentColor : roles.foregroundMuted);
    final countLabel = label.isEmpty ? semanticLabel : '$semanticLabel, $label';

    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      toggled: toggled,
      label: countLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KubusRadius.surface),
          focusColor: roles.focus.withValues(alpha: 0.16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: finalColor, size: 20),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: KubusSpacing.xs + KubusSpacing.xxs),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onCountTap ?? onTap,
                    child: AnimatedDefaultTextStyle(
                      duration: animationTheme.short,
                      style: KubusTextStyles.navMetaLabel.copyWith(
                        color: finalColor,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                      ),
                      child: Text(label, textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
