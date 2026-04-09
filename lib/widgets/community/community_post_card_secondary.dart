part of 'community_post_card.dart';

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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final originalHandle = (post.authorUsername ?? '').trim();

    final radius = BorderRadius.circular(KubusRadius.md);
    final glassTint = scheme.surface.withValues(alpha: isDark ? 0.14 : 0.09);

    return GestureDetector(
      onTap: () => onOpenPostDetail(post),
      child: Container(
        margin: const EdgeInsets.only(top: KubusSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: scheme.outline.withValues(alpha: 0.18),
          ),
        ),
        child: LiquidGlassPanel(
          padding: const EdgeInsets.all(KubusSpacing.md),
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
                        username: originalHandle,
                        userId: post.authorWallet ?? post.authorId,
                        wallet: post.authorWallet ?? post.authorId,
                        avatarUrl: post.authorAvatar,
                      ),
                      layout: ProfileIdentityLayout.row,
                      avatarRadius: 16,
                      allowFabricatedFallback: true,
                      onTap: () {
                        final userId =
                            (post.authorWallet ?? post.authorId).trim();
                        if (userId.isEmpty) return;
                        unawaited(
                          UserProfileNavigation.open(
                            context,
                            userId: userId,
                            username:
                                originalHandle.isEmpty ? null : originalHandle,
                          ),
                        );
                      },
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
                        iconOnly: false,
                      ),
                    ),
                  ),
                  Text(
                    _timeAgo(context, post.timestamp, AppLocalizations.of(context)),
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
      ),
    );
  }
}
