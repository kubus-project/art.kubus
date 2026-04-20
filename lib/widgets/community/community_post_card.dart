import 'dart:async';

import 'package:art_kubus/models/community_group.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../../community/community_interactions.dart';
import '../../models/community_subject.dart';
import '../../providers/community_subject_provider.dart';
import '../../utils/app_animations.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/media_url_resolver.dart';
import '../../utils/user_profile_navigation.dart';
import '../inline_loading.dart';
import '../glass_components.dart';
import '../profile_identity_summary.dart';
import 'community_author_role_badges.dart';

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
    this.inlineComments,
  });

  final CommunityPost post;
  final Color accentColor;

  final ValueChanged<CommunityPost> onOpenPostDetail;
  final VoidCallback? onOpenAuthorProfile;

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
  final Widget? inlineComments;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 375;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final radius = BorderRadius.circular(KubusRadius.lg);
        final glassTint =
            scheme.surface.withValues(alpha: isDark ? 0.16 : 0.10);

        return Container(
          margin: const EdgeInsets.only(bottom: KubusChromeMetrics.cardPadding),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.18),
              ),
            ),
            child: LiquidGlassPanel(
              padding: const EdgeInsets.all(KubusChromeMetrics.cardPadding),
              margin: EdgeInsets.zero,
              borderRadius: radius,
              showBorder: false,
              backgroundColor: glassTint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                      Row(
                        children: [
                          Expanded(
                            child: ProfileIdentitySummary(
                              identity: ProfileIdentityData.fromValues(
                                fallbackLabel:
                                    l10n?.commonUnknownArtist ?? 'Unknown artist',
                                displayName: post.authorName,
                                username: post.authorUsername,
                                userId: post.authorWallet ?? post.authorId,
                                wallet: post.authorWallet ?? post.authorId,
                                avatarUrl: post.authorAvatar,
                              ),
                              layout: ProfileIdentityLayout.row,
                              avatarRadius: 20,
                              allowFabricatedFallback: true,
                              onTap: onOpenAuthorProfile,
                              titleStyle:
                                  KubusTextStyles.sectionTitle.copyWith(
                                fontSize: isSmallScreen
                                    ? KubusChromeMetrics.navLabel
                                    : KubusHeaderMetrics.sectionTitle,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                              subtitleStyle:
                                  KubusTextStyles.sectionSubtitle.copyWith(
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
                      if (post.feedPin.isPinned ||
                          post.promotion.isPromoted) ...[
                        const SizedBox(
                            height: KubusSpacing.sm + KubusSpacing.xxs),
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
                      if (post.postType == 'repost' &&
                          post.content.isNotEmpty) ...[
                        const SizedBox(
                            height: KubusSpacing.xs + KubusSpacing.xxs),
                        _OpenPostSurface(
                          onTap: () => onOpenPostDetail(post),
                          child: Text(
                            post.content,
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
                      if (post.category.isNotEmpty &&
                          post.category != 'post') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KubusSpacing.sm + KubusSpacing.xxs,
                            vertical: KubusSpacing.xs,
                          ),
                          margin:
                              const EdgeInsets.only(bottom: KubusSpacing.sm),
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
                      if (post.postType == 'repost' &&
                          post.originalPost != null) ...[
                        _RepostInnerCard(
                          post: post.originalPost!,
                          accentColor: accentColor,
                          onOpenPostDetail: onOpenPostDetail,
                        ),
                      ] else ...[
                        _OpenPostSurface(
                          onTap: () => onOpenPostDetail(post),
                          child: Text(
                            post.content,
                            style: KubusTextStyles.detailBody.copyWith(
                              fontSize: isSmallScreen ? 13 : 15,
                              height: 1.5,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                      if (_hasPrimaryImage(post)) ...[
                        const SizedBox(height: KubusSpacing.md),
                        _OpenPostSurface(
                          onTap: () =>
                              onOpenPostDetail(_primaryImagePost(post)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(KubusRadius.md),
                            child: Image.network(
                              _primaryImageUrl(post),
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        accentColor.withValues(alpha: 0.3),
                                        accentColor.withValues(alpha: 0.1),
                                      ],
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(KubusRadius.md),
                                  ),
                                  child: Center(
                                    child: SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: InlineLoading(
                                        expand: true,
                                        shape: BoxShape.circle,
                                        tileSize: 4.0,
                                        progress: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? (loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!)
                                            : null,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        accentColor.withValues(alpha: 0.3),
                                        accentColor.withValues(alpha: 0.1),
                                      ],
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(KubusRadius.md),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: scheme.onPrimary,
                                      size: 60,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
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
                      const SizedBox(height: KubusSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: _InteractionButton(
                              icon: post.isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              label: '${post.likeCount}',
                              onTap: onToggleLike,
                              onCountTap: onShowLikes,
                              isActive: post.isLiked,
                              color: post.isLiked
                                  ? KubusColorRoles.of(context).likeAction
                                  : scheme.onSurface.withValues(alpha: 0.6),
                              accentColor: accentColor,
                            ),
                          ),
                          Expanded(
                            child: _InteractionButton(
                              icon: Icons.comment_outlined,
                              label: '${post.commentCount}',
                              onTap: onOpenComments,
                              isActive: commentsExpanded,
                              accentColor: accentColor,
                            ),
                          ),
                          Expanded(
                            child: _InteractionButton(
                              icon: Icons.repeat,
                              label: '${post.shareCount}',
                              onTap: onRepost,
                              onCountTap:
                                  post.shareCount > 0 ? onShowReposts : null,
                              accentColor: accentColor,
                            ),
                          ),
                          Expanded(
                            child: _InteractionButton(
                              icon: Icons.share_outlined,
                              label: '',
                              onTap: onShare,
                              accentColor: accentColor,
                            ),
                          ),
                          const SizedBox(width: KubusSpacing.sm),
                          IconButton(
                            onPressed: onToggleBookmark,
                            icon: Icon(
                              post.isBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: post.isBookmarked
                                  ? scheme.primary
                                  : scheme.onSurface.withValues(alpha: 0.6),
                              size: 20,
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

bool _hasPrimaryImage(CommunityPost post) {
  return (post.postType == 'repost' && post.originalPost?.imageUrl != null) ||
      (post.postType != 'repost' && post.imageUrl != null);
}

String _primaryImageUrl(CommunityPost post) {
  final raw = (post.postType == 'repost' && post.originalPost != null)
      ? post.originalPost!.imageUrl
      : post.imageUrl;
  final resolved = MediaUrlResolver.resolveDisplayUrl(raw);
  return resolved ?? raw!;
}

CommunityPost _primaryImagePost(CommunityPost post) {
  return (post.postType == 'repost' && post.originalPost != null)
      ? post.originalPost!
      : post;
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

CommunitySubjectRef? _resolveSubjectRef(CommunityPost post) {
  final type = (post.subjectType ?? '').trim();
  final id = (post.subjectId ?? '').trim();
  if (type.isNotEmpty && id.isNotEmpty) {
    return CommunitySubjectRef(type: type, id: id);
  }
  if (post.artwork != null) {
    return CommunitySubjectRef(type: 'artwork', id: post.artwork!.id);
  }
  return null;
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
      return Icons.event_outlined;
    case 'collection':
      return Icons.collections_bookmark_outlined;
    case 'institution':
      return Icons.apartment_outlined;
    default:
      return Icons.info_outline;
  }
}
