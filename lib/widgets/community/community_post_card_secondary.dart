part of 'community_post_card.dart';

class _RepostInnerCard extends StatelessWidget {
  const _RepostInnerCard({
    required this.post,
    required this.accentColor,
    required this.onOpenPostDetail,
    this.onOpenProfileIdentity,
  });

  final CommunityPost post;
  final Color accentColor;
  final ValueChanged<CommunityPost> onOpenPostDetail;
  final ValueChanged<ProfileIdentityData>? onOpenProfileIdentity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final roles = KubusColorRoles.of(context);
    final openAuthorProfile = onOpenProfileIdentity == null
        ? () => openProfileIdentity(context, post.authorIdentityData)
        : () => onOpenProfileIdentity!(post.authorIdentityData);

    return GestureDetector(
      onTap: () => onOpenPostDetail(post),
      child: Container(
        // A quoted reference inside the post, not a second card.
        margin: const EdgeInsets.only(top: KubusSpacing.sm),
        padding: const EdgeInsets.all(KubusSpacing.md),
        decoration: BoxDecoration(
          color: roles.ground,
          border: Border(
            left: BorderSide(color: roles.ruleStrong, width: 2),
          ),
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
                    avatarRadius: 16,
                    allowFabricatedFallback: true,
                    fetchMissingAvatar: false,
                    onTap: openAuthorProfile,
                    titleStyle: KubusTextStyles.navMetaLabel.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                    subtitleStyle: KubusTextStyles.navMetaLabel.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                    titleSuffix: CommunityAuthorRoleBadges(
                      post: post,
                      fontSize: 8,
                      iconOnly: true,
                      // ProfileIdentitySummary already adds spacing.
                      spacing: 0,
                    ),
                  ),
                ),
                Text(
                  _timeAgo(
                      context, post.timestamp, AppLocalizations.of(context)),
                  style: KubusTextStyles.compactBadge.copyWith(
                    fontSize: KubusChromeMetrics.navBadgeLabel + 2,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KubusSpacing.sm),
            Text(
              post.content,
              style: KubusTextStyles.navMetaLabel.copyWith(
                color: scheme.onSurface,
              ),
            ),
            if (post.imageUrl != null) ...[
              const SizedBox(height: KubusSpacing.sm + KubusSpacing.xxs),
              ClipRRect(
                borderRadius: BorderRadius.circular(KubusRadius.sm),
                child: Image.network(
                  MediaUrlResolver.resolveDisplayUrl(post.imageUrl) ??
                      post.imageUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 140,
                    color: accentColor.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.image_not_supported,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
