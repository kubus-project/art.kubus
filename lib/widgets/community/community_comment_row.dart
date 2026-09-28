import 'package:flutter/material.dart';

import '../../community/community_interactions.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../profile_identity_summary.dart';

/// One comment in a discussion thread (PRODUCT v5).
///
/// Conversational, not a record: author, time, text, then a quiet action
/// line. Replies are marked by a short structural rule and a fixed offset
/// instead of cumulative indentation, so deep threads stay readable at
/// 320 px. Like exposes toggle state; the likes count (when it opens a list)
/// and Reply are ordinary buttons; every control has a 44 px hit area.
class CommunityCommentRow extends StatelessWidget {
  const CommunityCommentRow({
    super.key,
    required this.comment,
    required this.isReply,
    required this.timeLabel,
    this.onOpenAuthor,
    this.onShowHistory,
    this.onToggleLike,
    this.onShowLikes,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });

  final Comment comment;
  final bool isReply;
  final String timeLabel;
  final VoidCallback? onOpenAuthor;
  final VoidCallback? onShowHistory;
  final VoidCallback? onToggleLike;
  final VoidCallback? onShowLikes;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final textTheme = Theme.of(context).textTheme;
    final metaStyle = textTheme.labelSmall?.copyWith(
      color: roles.foregroundSubtle,
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: ProfileIdentitySummary(
                identity: comment.authorIdentityData,
                avatarRadius: isReply ? 12 : 16,
                allowFabricatedFallback: true,
                fetchMissingAvatar: false,
                onTap: onOpenAuthor,
                titleStyle: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: roles.foreground,
                ),
                subtitleStyle: metaStyle,
              ),
            ),
            if (onEdit != null || onDelete != null)
              PopupMenuButton<String>(
                tooltip: l10n.commonMore,
                icon: Icon(Icons.more_horiz, color: roles.foregroundMuted),
                constraints: const BoxConstraints(minWidth: 140),
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    PopupMenuItem(value: 'edit', child: Text(l10n.commonEdit)),
                  if (onDelete != null)
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        l10n.commonDelete,
                        style: TextStyle(color: roles.destructive),
                      ),
                    ),
                ],
              ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(left: isReply ? 32 : 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: timeLabel),
                    if (comment.isEdited)
                      TextSpan(text: '  ·  ${l10n.commonEditedTag}'),
                  ],
                ),
                style: metaStyle,
              ),
              const SizedBox(height: KubusSpacing.xs),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onShowHistory,
                child: Text(
                  comment.content,
                  style: textTheme.bodyMedium?.copyWith(
                    color: roles.foreground,
                    height: 1.4,
                  ),
                ),
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _CommentAction(
                    icon: comment.isLiked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    iconColor: comment.isLiked
                        ? roles.likeAction
                        : roles.foregroundMuted,
                    label: l10n.communityPostActionLike,
                    toggled: comment.isLiked,
                    onTap: onToggleLike,
                  ),
                  if (comment.likeCount > 0)
                    _CommentAction(
                      label: l10n.communityPostLikesCount(comment.likeCount),
                      onTap: onShowLikes,
                    ),
                  if (onReply != null)
                    _CommentAction(label: l10n.commonReply, onTap: onReply),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    if (!isReply) {
      return Padding(
        padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
        child: body,
      );
    }
    // A reply keeps one fixed offset and a short structural rule, however
    // deep the thread goes.
    return Padding(
      padding:
          const EdgeInsets.only(left: KubusSpacing.md, bottom: KubusSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: roles.rule, width: 2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: KubusSpacing.sm + 4),
          child: body,
        ),
      ),
    );
  }
}

class _CommentAction extends StatelessWidget {
  const _CommentAction({
    required this.label,
    this.icon,
    this.iconColor,
    this.toggled,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;
  final bool? toggled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: roles.foregroundMuted,
          fontWeight: FontWeight.w600,
        );
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      toggled: toggled,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KubusRadius.control),
          focusColor: roles.focus.withValues(alpha: 0.16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null)
                    Icon(icon, size: 18, color: iconColor)
                  else
                    Text(label, style: textStyle),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
