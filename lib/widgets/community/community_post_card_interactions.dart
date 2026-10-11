part of 'community_post_card.dart';

/// One post action (like, comment, repost, share, save).
///
/// An icon-only button with a text label for assistive technology and a
/// 44 px square hit area. Persistent relationship actions (like, save) pass
/// [toggled]; one-shot actions (comment, repost, share) leave it `null` so
/// they never announce a toggle state. Counts live in [_PostStatsLine], so an
/// action never has to share its hit area with a count.
class _InteractionButton extends StatelessWidget {
  const _InteractionButton({
    required this.icon,
    required this.semanticLabel,
    required this.accentColor,
    this.onTap,
    this.isActive = false,
    this.toggled,
    this.color,
  });

  final IconData icon;
  final String semanticLabel;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool isActive;
  final bool? toggled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final finalColor =
        color ?? (isActive ? accentColor : roles.foregroundMuted);
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      toggled: toggled,
      label: semanticLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Tooltip(
          message: semanticLabel,
          child: KubusFocusRing(
            borderRadius: BorderRadius.circular(KubusRadius.surface),
            enabled: onTap != null,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(KubusRadius.surface),
              focusColor: roles.focus.withValues(alpha: 0.16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                child: Center(child: Icon(icon, color: finalColor, size: 20)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Social proof above the action row: "24 likes · 3 comments · 2 reposts".
///
/// A count that opens its own list (who liked, who reposted) is an ordinary
/// button with its own label and a 44 px tall hit area; other counts are
/// plain text. Nothing here is a toggle.
class _PostStatsLine extends StatelessWidget {
  const _PostStatsLine({
    required this.post,
    this.onShowLikes,
    this.onShowReposts,
  });

  final CommunityPost post;
  final VoidCallback? onShowLikes;
  final VoidCallback? onShowReposts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();
    final roles = KubusColorRoles.of(context);
    final style = KubusTextStyles.navMetaLabel.copyWith(
      color: roles.foregroundMuted,
    );
    final parts = <Widget>[];

    void add(String text, VoidCallback? onTap) {
      if (parts.isNotEmpty) {
        parts.add(ExcludeSemantics(child: Text('·', style: style)));
      }
      parts.add(onTap == null
          ? Text(text, style: style)
          : _PostCountLink(label: text, onTap: onTap, style: style));
    }

    if (post.likeCount > 0) {
      add(l10n.communityPostLikesCount(post.likeCount), onShowLikes);
    }
    if (post.commentCount > 0) {
      add(l10n.commonCommentsCount(post.commentCount), null);
    }
    if (post.shareCount > 0) {
      add(l10n.communityPostRepostsCount(post.shareCount), onShowReposts);
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: KubusSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts,
    );
  }
}

class _PostCountLink extends StatelessWidget {
  const _PostCountLink({
    required this.label,
    required this.onTap,
    required this.style,
  });

  final String label;
  final VoidCallback onTap;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: KubusFocusRing(
          borderRadius: BorderRadius.circular(KubusRadius.control),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(KubusRadius.control),
            focusColor: roles.focus.withValues(alpha: 0.16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: KubusSpacing.xxs),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: style.copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: roles.ruleStrong,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
