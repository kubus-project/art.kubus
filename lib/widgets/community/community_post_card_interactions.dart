part of 'community_post_card.dart';

/// The spoken label of a post action: its name plus its count or state, e.g.
/// "Like, 4 likes, not liked". Empty parts are dropped.
String _actionLabel(Iterable<String?> parts) =>
    parts.where((part) => part != null && part.isNotEmpty).join(', ');

/// One post action (like, comment, repost, share, save).
///
/// An icon-only button with a text label for assistive technology and a
/// 48 px square hit area (the mobile minimum; a 44 px target missed it on a
/// phone). Persistent relationship actions (like, save) pass
/// [toggled]; one-shot actions (comment, repost, share) leave it `null` so
/// they never announce a toggle state. Counts live in [_PostStatsLine], so an
/// action never has to share its hit area with a count.
class _InteractionButton extends StatefulWidget {
  const _InteractionButton({
    required this.icon,
    required this.semanticLabel,
    required this.accentColor,
    this.onTap,
    this.isActive = false,
    this.toggled,
    this.color,
    this.focusReturnKey,
  });

  final IconData icon;
  final String semanticLabel;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool isActive;
  final bool? toggled;
  final Color? color;
  // Identifies a control a sign-in journey must hand focus back to; see
  // PendingActionProvider.rememberFocusReturn.
  final String? focusReturnKey;

  @override
  State<_InteractionButton> createState() => _InteractionButtonState();
}

class _InteractionButtonState extends State<_InteractionButton> {
  // The action's focus node, handed to its InkWell. The InkWell's own focus
  // node is excluded from semantics (below), so the web engine can only focus
  // the action through the labelled node, which passes focus on to this one.
  final FocusNode _focusNode = FocusNode(debugLabel: 'community post action');

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
    if (widget.focusReturnKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final pending = readPendingActionsOrNull(context);
        if (pending == null) return;
        _pendingActions = pending;
        _settledSeen = pending.settledRevision;
        pending.addListener(_handleSettled);
        // A rebuilt control (the screen was replaced by sign-in) takes focus
        // once, when the journey remembered it.
        final key = widget.focusReturnKey;
        if (key != null && pending.takeFocusReturn(key)) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  PendingActionProvider? _pendingActions;
  int _settledSeen = 0;

  // A like on this control's post was confirmed. The confirmation sheet has
  // closed by then, so focus can stay here. Only the current route takes it:
  // a feed card under a pushed post must not pull focus back.
  void _handleSettled() {
    final pending = _pendingActions;
    final key = widget.focusReturnKey;
    if (pending == null || key == null || !mounted) return;
    if (pending.settledRevision == _settledSeen) return;
    _settledSeen = pending.settledRevision;
    final settled = pending.lastSettled;
    if (settled == null || settled.actionType != PendingActionType.like) return;
    if (key != 'like:${settled.targetId}') return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _pendingActions?.removeListener(_handleSettled);
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    final semanticLabel = widget.semanticLabel;
    final toggled = widget.toggled;
    final icon = widget.icon;
    final roles = KubusColorRoles.of(context);
    final finalColor = widget.color ??
        (widget.isActive ? widget.accentColor : roles.foregroundMuted);
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      toggled: toggled,
      label: semanticLabel,
      onTap: onTap,
      focusable: onTap != null,
      focused: _focusNode.hasPrimaryFocus,
      onFocus: onTap == null ? null : _focusNode.requestFocus,
      child: ExcludeSemantics(
        child: Tooltip(
          message: semanticLabel,
          child: InkWell(
            focusNode: _focusNode,
            onTap: onTap,
            borderRadius: BorderRadius.circular(KubusRadius.surface),
            focusColor: roles.focus.withValues(alpha: 0.16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              child: Center(child: Icon(icon, color: finalColor, size: 20)),
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
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KubusRadius.control),
          focusColor: roles.focus.withValues(alpha: 0.16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.xxs),
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
    );
  }
}
