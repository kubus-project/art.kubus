import 'package:art_kubus/models/community_group.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../../community/community_interactions.dart';
import '../../models/community_subject.dart';
import '../../providers/community_subject_provider.dart';
import '../../utils/app_animations.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/media_url_resolver.dart';
import '../avatar_widget.dart';
import '../inline_loading.dart';
import '../glass_components.dart';
import 'community_author_role_badges.dart';

class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    required this.accentColor,
    required this.onOpenPostDetail,
    required this.onOpenAuthorProfile,
    required this.onToggleLike,
    required this.onOpenComments,
    required this.onRepost,
    required this.onShare,
    required this.onToggleBookmark,
    this.onMoreOptions,
    this.onShowLikes,
    this.onShowReposts,
    this.onTagTap,
    this.onMentionTap,
    this.onOpenLocation,
    this.onOpenGroup,
    this.onOpenSubject,
  });

  final CommunityPost post;
  final Color accentColor;

  final ValueChanged<CommunityPost> onOpenPostDetail;
  final VoidCallback onOpenAuthorProfile;

  final VoidCallback onToggleLike;
  final VoidCallback onOpenComments;
  final VoidCallback onRepost;
  final VoidCallback onShare;
  final VoidCallback onToggleBookmark;

  final VoidCallback? onMoreOptions;

  final VoidCallback? onShowLikes;
  final VoidCallback? onShowReposts;

  final ValueChanged<String>? onTagTap;
  final ValueChanged<String>? onMentionTap;
  final ValueChanged<CommunityLocation>? onOpenLocation;
  final ValueChanged<CommunityGroupReference>? onOpenGroup;
  final ValueChanged<CommunitySubjectPreview>? onOpenSubject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 375;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final radius = BorderRadius.circular(16);
        final glassTint = scheme.surface.withValues(alpha: isDark ? 0.16 : 0.10);

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onTap: () => onOpenPostDetail(post),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.18),
                  ),
                ),
                child: LiquidGlassPanel(
                  padding: const EdgeInsets.all(20),
                  margin: EdgeInsets.zero,
                  borderRadius: radius,
                  showBorder: false,
                  backgroundColor: glassTint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Row(
                      children: [
                        AvatarWidget(
                          wallet: (post.authorWallet ?? post.authorId),
                          avatarUrl: post.authorAvatar,
                          radius: 20,
                          allowFabricatedFallback: true,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onOpenAuthorProfile,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      fit: FlexFit.loose,
                                      child: Text(
                                        post.authorName,
                                        style: GoogleFonts.inter(
                                          fontSize: isSmallScreen ? 14 : 16,
                                          fontWeight: FontWeight.bold,
                                          color: scheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    CommunityAuthorRoleBadges(
                                      post: post,
                                      fontSize: isSmallScreen ? 8.5 : 9.5,
                                      iconOnly: false,
                                    ),
                                  ],
                                ),
                                if ((post.authorUsername ?? '').trim().isNotEmpty)
                                  Text(
                                    '@${post.authorUsername!.trim()}',
                                    style: GoogleFonts.inter(
                                      fontSize: isSmallScreen ? 12 : 14,
                                      color: scheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          _timeAgo(context, post.timestamp, l10n),
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 10 : 12,
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
                    const SizedBox(height: 16),
                    if (post.postType == 'repost' && post.content.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        post.content,
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 13 : 15,
                          height: 1.5,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Divider(color: scheme.outline.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                    ],
                    if (post.category.isNotEmpty && post.category != 'post') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getCategoryIcon(post.category),
                              size: 14,
                              color: accentColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatCategoryLabel(post.category),
                              style: GoogleFonts.inter(
                                fontSize: 12,
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
                      ),
                    ] else ...[
                      Text(
                        post.content,
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 13 : 15,
                          height: 1.5,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                    if (_hasPrimaryImage(post)) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => onOpenPostDetail(_primaryImagePost(post)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _primaryImageUrl(post),
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
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
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: InlineLoading(
                                      expand: true,
                                      shape: BoxShape.circle,
                                      tileSize: 4.0,
                                      progress: loadingProgress.expectedTotalBytes != null
                                          ? (loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!)
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
                                  borderRadius: BorderRadius.circular(12),
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _InteractionButton(
                            icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
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
                            accentColor: accentColor,
                          ),
                        ),
                        Expanded(
                          child: _InteractionButton(
                            icon: Icons.repeat,
                            label: '${post.shareCount}',
                            onTap: onRepost,
                            onCountTap: post.shareCount > 0 ? onShowReposts : null,
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
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: onToggleBookmark,
                          icon: Icon(
                            post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            color: post.isBookmarked
                                ? scheme.primary
                                : scheme.onSurface.withValues(alpha: 0.6),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

String _timeAgo(BuildContext context, DateTime timestamp, AppLocalizations? l10n) {
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
          .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
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

String _subjectTypeLabel(BuildContext context, String type, AppLocalizations? l10n) {
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
        padding: const EdgeInsets.symmetric(vertical: 6),
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
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onCountTap ?? onTap,
                child: AnimatedDefaultTextStyle(
                  duration: animationTheme.short,
                  style: GoogleFonts.inter(
                    fontSize: 13,
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

class _RepostInnerCard extends StatelessWidget {
  const _RepostInnerCard({
    required this.post,
    required this.accentColor,
    required this.onOpenPostDetail,
  });

  final CommunityPost post;
  final Color accentColor;
  final ValueChanged<CommunityPost> onOpenPostDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final originalHandle = (post.authorUsername ?? '').trim();

    final radius = BorderRadius.circular(12);
    final glassTint = scheme.surface.withValues(alpha: isDark ? 0.14 : 0.09);

    return GestureDetector(
      onTap: () => onOpenPostDetail(post),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: scheme.outline.withValues(alpha: 0.18),
          ),
        ),
        child: LiquidGlassPanel(
          padding: const EdgeInsets.all(12),
          margin: EdgeInsets.zero,
          borderRadius: radius,
          showBorder: false,
          backgroundColor: glassTint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                AvatarWidget(
                  wallet: post.authorWallet ?? post.authorId,
                  avatarUrl: post.authorAvatar,
                  radius: 16,
                  allowFabricatedFallback: true,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              post.authorName,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: scheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          CommunityAuthorRoleBadges(
                            post: post,
                            fontSize: 8,
                            iconOnly: false,
                          ),
                        ],
                      ),
                      if (originalHandle.isNotEmpty)
                        Text(
                          '@$originalHandle',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Text(
                  _timeAgo(context, post.timestamp, AppLocalizations.of(context)),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              post.content,
              style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurface),
            ),
            if (post.imageUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  MediaUrlResolver.resolveDisplayUrl(post.imageUrl) ??
                      post.imageUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 140,
                    color: accentColor.withValues(alpha: 0.1),
                    child: Icon(Icons.image_not_supported, color: accentColor),
                  ),
                ),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PostMetadataSection extends StatelessWidget {
  const _PostMetadataSection({
    required this.post,
    required this.accentColor,
    this.onTagTap,
    this.onMentionTap,
    this.onOpenLocation,
    this.onOpenGroup,
    this.onOpenSubject,
  });

  final CommunityPost post;
  final Color accentColor;
  final ValueChanged<String>? onTagTap;
  final ValueChanged<String>? onMentionTap;
  final ValueChanged<CommunityLocation>? onOpenLocation;
  final ValueChanged<CommunityGroupReference>? onOpenGroup;
  final ValueChanged<CommunitySubjectPreview>? onOpenSubject;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final subjectProvider = context.watch<CommunitySubjectProvider>();
    final subjectRef = _resolveSubjectRef(post);
    CommunitySubjectPreview? subjectPreview;
    if (subjectRef != null) {
      subjectPreview = subjectProvider.previewFor(subjectRef);
      if (subjectPreview == null && post.artwork != null) {
        subjectPreview = CommunitySubjectPreview(
          ref: subjectRef,
          title: post.artwork!.title,
          imageUrl: MediaUrlResolver.resolve(post.artwork!.imageUrl) ?? post.artwork!.imageUrl,
        );
      }
    }
    final resolvedPreview = subjectPreview;
    final subjectTypeLabel = resolvedPreview != null
        ? _subjectTypeLabel(context, resolvedPreview.ref.normalizedType, l10n)
        : null;
    final hasMetadata = post.tags.isNotEmpty ||
        post.mentions.isNotEmpty ||
        post.location != null ||
        resolvedPreview != null ||
        post.group != null;
    if (!hasMetadata) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.tags.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: post.tags.map((tag) {
              final roles = KubusColorRoles.of(context);
              return GestureDetector(
                onTap: onTagTap == null ? null : () => onTagTap!(tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: roles.tagChipBackground.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '#$tag',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: roles.tagChipBackground,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        if (post.mentions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: post.mentions.map((mention) {
              return GestureDetector(
                onTap: onMentionTap == null ? null : () => onMentionTap!(mention),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '@$mention',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        if (post.location != null &&
            (post.location!.name?.isNotEmpty == true ||
                post.location!.lat != null)) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onOpenLocation == null ||
                    post.location!.lat == null ||
                    post.location!.lng == null
                ? null
                : () => onOpenLocation!(post.location!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: scheme.tertiary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      post.location!.name ??
                          '${post.location!.lat!.toStringAsFixed(4)}, ${post.location!.lng!.toStringAsFixed(4)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: scheme.onTertiaryContainer,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (post.distanceKm != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '• ${post.distanceKm!.toStringAsFixed(1)} km',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: scheme.onTertiaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
          if (resolvedPreview != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap:
                  onOpenSubject == null ? null : () => onOpenSubject!(resolvedPreview),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: resolvedPreview.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                MediaUrlResolver.resolveDisplayUrl(
                                      resolvedPreview.imageUrl,
                                    ) ??
                                    resolvedPreview.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  _subjectTypeIcon(resolvedPreview.ref.normalizedType),
                                  color: accentColor,
                                  size: 22,
                                ),
                              ),
                            )
                          : Icon(
                              _subjectTypeIcon(resolvedPreview.ref.normalizedType),
                              color: accentColor,
                              size: 22,
                            ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resolvedPreview.title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          l10n?.communitySubjectLinkedLabel(subjectTypeLabel ?? '') ?? 'Linked',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: scheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (post.group != null) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onOpenGroup == null ? null : () => onOpenGroup!(post.group!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.groups_2,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      post.group!.name,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
