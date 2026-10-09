import 'package:art_kubus/models/community_group.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../../community/community_interactions.dart';
import '../../community/community_post_media.dart';
import '../../models/community_subject.dart';
import '../../providers/community_subject_provider.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/media_url_resolver.dart';
import '../../utils/profile_identity_navigation.dart';
import '../profile_identity_summary.dart';
import 'community_author_role_badges.dart';
import 'community_post_caption.dart';
import 'community_post_media_carousel.dart';

part 'community_post_card_interactions.dart';
part 'community_post_card_metadata.dart';
part 'community_post_card_secondary.dart';

class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    required this.accentColor,
    required this.onOpenPostDetail,
    this.onOpenAuthorProfile,
    this.onOpenProfileIdentity,
    this.onToggleLike,
    this.onOpenComments,
    this.onRepost,
    this.onShare,
    this.onToggleBookmark,
    this.onMoreOptions,
    this.onShowLikes,
    this.onShowReposts,
    this.onTagTap,
    this.onMentionTap,
    this.onOpenLocation,
    this.onOpenGroup,
    this.onOpenSubject,
    this.commentsExpanded = false,
    this.expandCaption = false,
    this.inlineComments,
  });

  final CommunityPost post;
  final Color accentColor;

  final ValueChanged<CommunityPost> onOpenPostDetail;
  final VoidCallback? onOpenAuthorProfile;
  final ValueChanged<ProfileIdentityData>? onOpenProfileIdentity;

  final VoidCallback? onToggleLike;
  final VoidCallback? onOpenComments;
  final VoidCallback? onRepost;
  final VoidCallback? onShare;
  final VoidCallback? onToggleBookmark;

  final VoidCallback? onMoreOptions;

  final VoidCallback? onShowLikes;
  final VoidCallback? onShowReposts;

  final ValueChanged<String>? onTagTap;
  final ValueChanged<String>? onMentionTap;
  final ValueChanged<CommunityLocation>? onOpenLocation;
  final ValueChanged<CommunityGroupReference>? onOpenGroup;
  final ValueChanged<CommunitySubjectPreview>? onOpenSubject;
  final bool commentsExpanded;

  /// Shows the complete caption by default. The post detail screen sets this so
  /// feed truncation never applies to the full post.
  final bool expandCaption;
  final Widget? inlineComments;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 375;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final roles = KubusColorRoles.of(context);
        final radius = BorderRadius.circular(KubusRadius.surface);
        final openAuthorProfile = onOpenProfileIdentity == null
            ? (onOpenAuthorProfile ??
                () => openProfileIdentity(context, post.authorIdentityData))
            : () => onOpenProfileIdentity!(post.authorIdentityData);

        return Container(
          margin: const EdgeInsets.only(bottom: KubusChromeMetrics.cardPadding),
          child: Container(
            // Flat reading surface: posts are content, not glass overlays.
            padding: const EdgeInsets.all(KubusChromeMetrics.cardPadding),
            decoration: BoxDecoration(
              color: roles.surface,
              borderRadius: radius,
              border: Border.all(color: roles.rule, width: KubusSizes.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ProfileIdentitySummary(
                        identity: post.authorIdentityData,
                        layout: ProfileIdentityLayout.row,
                        avatarRadius: 20,
                        allowFabricatedFallback: true,
                        fetchMissingAvatar: false,
                        onTap: openAuthorProfile,
                        titleStyle: KubusTextStyles.sectionTitle.copyWith(
                          fontSize: isSmallScreen
                              ? KubusChromeMetrics.navLabel
                              : KubusHeaderMetrics.sectionTitle,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                        subtitleStyle: KubusTextStyles.sectionSubtitle.copyWith(
                          fontSize: isSmallScreen
                              ? KubusChromeMetrics.navMetaLabel
                              : KubusHeaderMetrics.screenSubtitle,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                        titleSuffix: CommunityAuthorRoleBadges(
                          post: post,
                          fontSize: isSmallScreen ? 8.5 : 9.5,
                          iconOnly: true,
                          // ProfileIdentitySummary already inserts a
                          // small gap between the title and suffix.
                          spacing: 0,
                        ),
                      ),
                    ),
                    Text(
                      _timeAgo(context, post.timestamp, l10n),
                      style: KubusTextStyles.navMetaLabel.copyWith(
                        fontSize: isSmallScreen
                            ? KubusChromeMetrics.navBadgeLabel
                            : KubusChromeMetrics.navMetaLabel,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (onMoreOptions != null) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onMoreOptions,
                        icon: Icon(
                          Icons.more_vert,
                          size: 18,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
                if (post.feedPin.isPinned || post.promotion.isPromoted) ...[
                  const SizedBox(height: KubusSpacing.sm + KubusSpacing.xxs),
                  Wrap(
                    spacing: KubusSpacing.sm,
                    runSpacing: KubusSpacing.sm,
                    children: [
                      if (post.feedPin.isPinned)
                        _buildMetaBadge(
                          context,
                          icon: Icons.push_pin_outlined,
                          label: post.feedPin.surface == null
                              ? 'Pinned'
                              : 'Pinned ${post.feedPin.surface}',
                          color: scheme.tertiary,
                        ),
                      if (post.promotion.isPromoted)
                        _buildMetaBadge(
                          context,
                          icon: Icons.auto_awesome,
                          label: 'Promoted',
                          color: accentColor,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: KubusSpacing.md),
                if (post.postType == 'repost' && post.content.isNotEmpty) ...[
                  const SizedBox(height: KubusSpacing.xs + KubusSpacing.xxs),
                  _OpenPostSurface(
                    onTap: () => onOpenPostDetail(post),
                    child: CommunityPostCaption(
                      text: post.content,
                      initiallyExpanded: expandCaption,
                      style: KubusTextStyles.detailBody.copyWith(
                        fontSize: isSmallScreen ? 13 : 15,
                        height: 1.5,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  Divider(color: scheme.outline.withValues(alpha: 0.5)),
                  const SizedBox(height: KubusSpacing.sm),
                ],
                if (post.category.isNotEmpty && post.category != 'post') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KubusSpacing.sm + KubusSpacing.xxs,
                      vertical: KubusSpacing.xs,
                    ),
                    margin: const EdgeInsets.only(bottom: KubusSpacing.sm),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(KubusRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getCategoryIcon(post.category),
                          size: 14,
                          color: accentColor,
                        ),
                        const SizedBox(
                            width: KubusSpacing.xs + KubusSpacing.xxs),
                        Text(
                          _formatCategoryLabel(post.category),
                          style: KubusTextStyles.navMetaLabel.copyWith(
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (post.postType == 'repost' && post.originalPost != null) ...[
                  _RepostInnerCard(
                    post: post.originalPost!,
                    accentColor: accentColor,
                    onOpenPostDetail: onOpenPostDetail,
                    onOpenProfileIdentity: onOpenProfileIdentity,
                  ),
                ] else ...[
                  _OpenPostSurface(
                    onTap: () => onOpenPostDetail(post),
                    child: CommunityPostCaption(
                      text: post.content,
                      hasMedia: communityPostMediaUrls(post).isNotEmpty,
                      initiallyExpanded: expandCaption,
                      style: KubusTextStyles.detailBody.copyWith(
                        fontSize: isSmallScreen ? 13 : 15,
                        height: 1.5,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
                if (post.postType != 'repost' &&
                    communityPostMediaUrls(post).isNotEmpty) ...[
                  const SizedBox(height: KubusSpacing.md),
                  CommunityPostMediaCarousel(
                    key: ValueKey<String>('media-${post.id}'),
                    mediaUrls: communityPostMediaUrls(post),
                    onOpenMedia: () => onOpenPostDetail(post),
                  ),
                ],
                if (post.postType != 'repost') ...[
                  _PostMetadataSection(
                    post: post,
                    accentColor: accentColor,
                    onTagTap: onTagTap,
                    onMentionTap: onMentionTap,
                    onOpenLocation: onOpenLocation,
                    onOpenGroup: onOpenGroup,
                    onOpenSubject: onOpenSubject,
                  ),
                ],
                const SizedBox(height: KubusSpacing.sm),
                _PostStatsLine(
                  post: post,
                  onShowLikes: onShowLikes,
                  onShowReposts: onShowReposts,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _InteractionButton(
                        icon: post.isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        semanticLabel: l10n?.communityPostActionLike ?? '',
                        toggled: post.isLiked,
                        onTap: onToggleLike,
                        isActive: post.isLiked,
                        color: post.isLiked
                            ? roles.likeAction
                            : roles.foregroundMuted,
                        accentColor: accentColor,
                      ),
                    ),
                    Expanded(
                      child: _InteractionButton(
                        icon: Icons.comment_outlined,
                        semanticLabel: l10n?.communityPostActionComment ?? '',
                        onTap: onOpenComments,
                        isActive: commentsExpanded,
                        accentColor: accentColor,
                      ),
                    ),
                    Expanded(
                      child: _InteractionButton(
                        icon: Icons.repeat,
                        semanticLabel: l10n?.communityRepostButtonLabel ?? '',
                        onTap: onRepost,
                        accentColor: accentColor,
                      ),
                    ),
                    Expanded(
                      child: _InteractionButton(
                        icon: Icons.share_outlined,
                        semanticLabel: l10n?.commonShare ?? '',
                        onTap: onShare,
                        accentColor: accentColor,
                      ),
                    ),
                    Expanded(
                      child: _InteractionButton(
                        icon: post.isBookmarked
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        semanticLabel: l10n?.commonSave ?? '',
                        toggled: post.isBookmarked,
                        onTap: onToggleBookmark,
                        isActive: post.isBookmarked,
                        color: post.isBookmarked
                            ? roles.active
                            : roles.foregroundMuted,
                        accentColor: accentColor,
                      ),
                    ),
                  ],
                ),
                if (inlineComments != null) ...[
                  const SizedBox(height: KubusSpacing.sm),
                  inlineComments!,
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetaBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: KubusSpacing.xs + KubusSpacing.xxs),
          Text(
            label,
            style: KubusTextStyles.compactBadge.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenPostSurface extends StatelessWidget {
  const _OpenPostSurface({
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

String _timeAgo(
    BuildContext context, DateTime timestamp, AppLocalizations? l10n) {
  // Prefer localizations when available (tests or minimal wrappers may omit).
  final localizations = l10n ?? AppLocalizations.of(context);
  final now = DateTime.now();
  final difference = now.difference(timestamp);

  if (localizations != null) {
    if (difference.inDays > 7) {
      return localizations.commonTimeAgoWeeks((difference.inDays / 7).floor());
    }
    if (difference.inDays > 0) {
      return localizations.commonTimeAgoDays(difference.inDays);
    }
    if (difference.inHours > 0) {
      return localizations.commonTimeAgoHours(difference.inHours);
    }
    if (difference.inMinutes > 0) {
      return localizations.commonTimeAgoMinutes(difference.inMinutes);
    }
    return localizations.commonTimeAgoJustNow;
  }

  // Fallback: English relative time.
  if (difference.inDays > 7) return '${(difference.inDays / 7).floor()}w ago';
  if (difference.inDays > 0) return '${difference.inDays}d ago';
  if (difference.inHours > 0) return '${difference.inHours}h ago';
  if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
  return 'Just now';
}

IconData _getCategoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'ar_drop':
    case 'art_drop':
      return Icons.place_outlined;
    case 'art_review':
      return Icons.rate_review_outlined;
    case 'event':
      return Icons.event_outlined;
    case 'poll':
      return Icons.poll_outlined;
    case 'question':
      return Icons.help_outline;
    case 'announcement':
      return Icons.campaign_outlined;
    case 'review':
      return Icons.rate_review_outlined;
    default:
      return Icons.article_outlined;
  }
}

String _formatCategoryLabel(String category) {
  switch (category.toLowerCase()) {
    case 'ar_drop':
    case 'art_drop':
      return 'AR Drop';
    case 'art_review':
      return 'Art Review';
    case 'event':
      return 'Event';
    case 'poll':
      return 'Poll';
    case 'question':
      return 'Question';
    case 'announcement':
      return 'Announcement';
    case 'review':
      return 'Review';
    default:
      return category
          .replaceAll('_', ' ')
          .split(' ')
          .map((w) =>
              w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
          .join(' ');
  }
}

List<CommunitySubjectRef> _resolveSubjectRefs(CommunityPost post) {
  if (post.subjects.isNotEmpty) {
    return post.subjects
        .where((ref) => ref.normalizedType.isNotEmpty && ref.id.isNotEmpty)
        .toList(growable: false);
  }
  final type = (post.subjectType ?? '').trim();
  final id = (post.subjectId ?? '').trim();
  if (type.isNotEmpty && id.isNotEmpty) {
    return <CommunitySubjectRef>[CommunitySubjectRef(type: type, id: id)];
  }
  if (post.artwork != null) {
    return <CommunitySubjectRef>[
      CommunitySubjectRef(type: 'artwork', id: post.artwork!.id),
    ];
  }
  return const <CommunitySubjectRef>[];
}

String _subjectTypeLabel(
    BuildContext context, String type, AppLocalizations? l10n) {
  final localized = l10n ?? AppLocalizations.of(context);
  if (localized == null) return type;
  switch (type.toLowerCase()) {
    case 'artwork':
      return localized.commonArtwork;
    case 'exhibition':
      return localized.commonExhibition;
    case 'collection':
      return localized.commonCollection;
    case 'institution':
      return localized.commonInstitution;
    default:
      return localized.commonDetails;
  }
}

IconData _subjectTypeIcon(String type) {
  switch (type.toLowerCase()) {
    case 'artwork':
      return Icons.view_in_ar;
    case 'exhibition':
      return AppColorUtils.exhibitionIcon;
    case 'collection':
      return Icons.collections_bookmark_outlined;
    case 'institution':
      return Icons.apartment_outlined;
    case 'artist':
      return Icons.palette_outlined;
    case 'group':
      return Icons.groups_2_outlined;
    case 'event':
      return Icons.event_outlined;
    case 'marker':
      return Icons.place_outlined;
    default:
      return Icons.info_outline;
  }
}
