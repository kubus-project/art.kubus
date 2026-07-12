part of '../community_screen.dart';

// Extracted from community_screen.dart (godfile split). Same library:
// private state access is intact. setState is routed through
// the State's _applyState shim.
extension _CommunityScreenStatePart2 on _CommunityScreenState {
  Widget _buildGroupDirectoryHeader() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: KubusRadius.circular(KubusRadius.lg),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.16),
          width: KubusSizes.hairline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.groups_2_outlined,
            color: scheme.primary,
            size: KubusHeaderMetrics.actionIcon,
          ),
          const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.communityGroupsDirectoryTitle,
                  style: KubusTextStyles.sectionTitle.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: KubusSpacing.xs),
                Text(
                  l10n.communityGroupsDirectoryDescription,
                  style: KubusTextStyles.sectionSubtitle.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSearchField(CommunityHubProvider hub) {
    final l10n = AppLocalizations.of(context)!;
    final query = hub.currentGroupSearchQuery;
    final scheme = Theme.of(context).colorScheme;

    if (_groupSearchController.text != query) {
      _groupSearchController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }

    return TextField(
      controller: _groupSearchController,
      onChanged: _onGroupSearchChanged,
      style: KubusTypography.inter(
        color: scheme.onSurface,
      ),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        suffixIcon: query.isNotEmpty
            ? IconButton(
                tooltip: l10n.communityClearSearchTooltip,
                onPressed: () {
                  _groupSearchController.clear();
                  _onGroupSearchChanged('');
                },
                icon: const Icon(Icons.clear),
              )
            : null,
        hintText: l10n.communityGroupsSearchHint,
        hintStyle: KubusTypography.inter(
          color: scheme.onSurface.withValues(alpha: 0.56),
        ),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: KubusRadius.circular(KubusRadius.lg),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.md,
          vertical: 0,
        ),
      ),
    );
  }

  Widget _buildGroupErrorBanner(String message) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.md),
      margin: const EdgeInsets.only(bottom: KubusSpacing.sm + 4),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: KubusRadius.circular(KubusRadius.lg),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: KubusTypography.textTheme.bodyMedium?.copyWith(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _ensureGroupsLoaded(force: true),
            child: Text(l10n.commonRetry),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(CommunityGroupSummary group) {
    return CommunityGroupCard(
      group: group,
      accentColor:
          Provider.of<ThemeProvider>(context, listen: false).accentColor,
      variant: CommunityGroupCardVariant.mobile,
      onOpenGroupFeed: () => _openGroupFeed(group),
      onToggleMembership:
          group.isOwner ? null : () => _handleGroupMembershipToggle(group),
      isMembershipActionInFlight: _groupActionsInFlight.contains(group.id),
      timeAgoBuilder: _getTimeAgo,
    );
  }

  Widget _buildArtTab() {
    final l10n = AppLocalizations.of(context)!;
    final filteredPosts = _filterPostsForQuery(_artFeedPosts);
    final hasQuery = _communitySearchQuery.isNotEmpty;

    if (_isLoadingArtFeed && _artFeedPosts.isEmpty) {
      return const AppLoading();
    }

    return RefreshIndicator(
      onRefresh: () => _ensureArtFeedLoaded(force: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleArtFeedScrollNotification,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            KubusSpacing.lg,
            KubusSpacing.lg,
            KubusSpacing.lg,
            KubusSpacing.lg + KubusLayout.mainBottomNavBarHeight,
          ),
          children: [
            _buildArtFeedHeader(),
            const SizedBox(height: KubusSpacing.md),
            if (_artFeedError != null && filteredPosts.isEmpty && !hasQuery)
              _buildArtStatusCard(
                icon: Icons.location_off_outlined,
                title: l10n.communityArtFeedLocationNeededTitle,
                description: l10n.communityArtFeedLocationNeededDescription,
                actionLabel: l10n.commonRetry,
                onAction: () => _ensureArtFeedLoaded(force: true),
              )
            else if (filteredPosts.isEmpty)
              _buildArtStatusCard(
                icon: hasQuery ? Icons.search_off : Icons.brush_outlined,
                title: hasQuery
                    ? l10n.commonNoResultsFound
                    : l10n.communityArtFeedNoNearbyActivationsTitle,
                description: hasQuery
                    ? l10n.communitySearchEmptyNoResults
                    : l10n.communityArtFeedNoNearbyActivationsDescription,
                actionLabel: hasQuery
                    ? l10n.communityClearSearchTooltip
                    : l10n.commonRefresh,
                onAction: hasQuery
                    ? () => _communitySearchController.clearQueryWithContext(
                          context,
                        )
                    : () => _ensureArtFeedLoaded(force: true),
              ),
            ...filteredPosts.map(_buildArtPostCard),
            if (_isLoadingArtFeed && filteredPosts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: KubusSpacing.xl,
                ),
                child: Center(
                  child: InlineLoading(
                    expand: false,
                    shape: BoxShape.circle,
                    tileSize: 4,
                    progress: null,
                    color: Provider.of<ThemeProvider>(context, listen: false)
                        .accentColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<CommunityPost> _filterPostsForQuery(List<CommunityPost> posts) {
    final rawQuery = _communitySearchQuery.toLowerCase();
    if (rawQuery.isEmpty) return posts;
    final normalizedTagQuery = _normalizedCommunityFeedQuery;

    return posts.where((post) {
      final contentMatch = post.content.toLowerCase().contains(rawQuery);
      final authorMatch = post.authorName.toLowerCase().contains(rawQuery) ||
          (post.authorUsername?.toLowerCase().contains(rawQuery) ?? false);
      final tagMatch = post.tags
          .any((tag) => tag.toLowerCase().contains(normalizedTagQuery));
      final mentionMatch = post.mentions
          .any((mention) => mention.toLowerCase().contains(rawQuery));
      final groupMatch =
          post.group?.name.toLowerCase().contains(rawQuery) ?? false;
      return contentMatch ||
          authorMatch ||
          tagMatch ||
          mentionMatch ||
          groupMatch;
    }).toList(growable: false);
  }

  Widget _buildArtFeedHeader() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final radiusKm = Provider.of<CommunityHubProvider>(context, listen: false)
        .artFeedRadiusKm;
    String subtitle;
    if (_artFeedLatitude != null && _artFeedLongitude != null) {
      subtitle = l10n.communityArtFeedCenterSubtitle(
        _artFeedLatitude!.toStringAsFixed(3),
        _artFeedLongitude!.toStringAsFixed(3),
      );
    } else {
      subtitle = l10n.communityArtFeedEnablePreciseLocationHint;
    }

    return Container(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: KubusRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.communityArtFeedHeaderTitle,
            style: KubusTypography.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.communityArtFeedRadiusSubtitle(
              l10n.commonDistanceKm(radiusKm.toStringAsFixed(1)),
            ),
            style: KubusTypography.textTheme.bodySmall?.copyWith(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: KubusTypography.textTheme.labelSmall?.copyWith(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () => _ensureArtFeedLoaded(force: true),
                icon: const Icon(Icons.near_me_outlined, size: 18),
                label: Text(l10n.communityArtFeedRefreshLocationButton),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final l10n = AppLocalizations.of(context)!;
                  await showModalBottomSheet(
                    context: context,
                    builder: (ctx) => Padding(
                      padding: const EdgeInsets.all(KubusSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.communityArtFeedAboutTitle,
                            style: KubusTypography.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.communityArtFeedAboutBody,
                            style: KubusTypography.inter(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline, size: 18),
                label: Text(l10n.communityArtFeedAboutButton),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArtStatusCard({
    required IconData icon,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: KubusSpacing.xl),
      padding: const EdgeInsets.all(KubusSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: KubusRadius.circular(18),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(height: 12),
          Text(
            title,
            style: KubusTypography.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: KubusTypography.textTheme.bodySmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onPrimaryContainer
                  .withValues(alpha: 0.78),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArtPostCard(CommunityPost post) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final rawImageUrl = post.imageUrl ??
        (post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null);
    final imageUrl = MediaUrlResolver.resolveDisplayUrl(rawImageUrl) ??
        MediaUrlResolver.resolve(rawImageUrl) ??
        rawImageUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: KubusSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: ProfileIdentitySummary(
              identity: post.authorIdentityData,
              avatarRadius: 22,
              allowFabricatedFallback: true,
              fetchMissingAvatar: false,
              onTap: () =>
                  openProfileIdentity(context, post.authorIdentityData),
              titleStyle: KubusTypography.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
              ),
              subtitleStyle: KubusTypography.textTheme.labelSmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.72),
              ),
            ),
            subtitle: Text(
              '${_getTimeAgo(post.timestamp)} - ${post.category}',
              style: KubusTypography.textTheme.labelSmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.72),
              ),
            ),
            trailing: IconButton(
              tooltip: l10n.commonShare,
              onPressed: () {
                ShareService().showShareSheet(
                  context,
                  target: share_types.ShareTarget.post(
                    postId: post.id,
                    title: post.content,
                  ),
                  sourceScreen: 'community_art_feed',
                );
              },
              icon: const Icon(Icons.share_outlined),
            ),
          ),
          if (imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(KubusRadius.md),
                topRight: Radius.circular(KubusRadius.md),
              ),
              child: Image.network(
                imageUrl,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 220,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          themeProvider.accentColor.withValues(alpha: 0.3),
                          themeProvider.accentColor.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                    child: InlineLoading(
                      expand: false,
                      progress: null,
                      shape: BoxShape.circle,
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 220,
                  color: themeProvider.accentColor.withValues(alpha: 0.15),
                  child:
                      Icon(Icons.image_not_supported, color: scheme.onPrimary),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.content,
                  style: KubusTypography.textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                if (post.location != null || post.distanceKm != null)
                  Row(
                    children: [
                      Icon(Icons.place,
                          size: 18,
                          color:
                              themeProvider.accentColor.withValues(alpha: 0.9)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [
                            post.location?.name,
                            post.distanceKm != null
                                ? l10n.commonDistanceKmAway(
                                    post.distanceKm!.toStringAsFixed(1))
                                : null,
                          ].whereType<String>().join(' - '),
                          style: KubusTypography.textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimaryContainer
                                .withValues(alpha: 0.68),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (post.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: post.tags.map((tag) {
                      final roles = KubusColorRoles.of(context);
                      return Chip(
                        backgroundColor:
                            roles.tagChipBackground.withValues(alpha: 0.1),
                        side: BorderSide.none,
                        label: Text(
                          '#$tag',
                          style: KubusTypography.inter(
                            color: roles.tagChipBackground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(post: post),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(l10n.communityViewPostButton),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: post.group != null
                          ? () => _openGroupFeed(
                                CommunityGroupSummary(
                                  id: post.group!.id,
                                  name: post.group!.name,
                                  slug: post.group!.slug,
                                  coverImage: post.group!.coverImage,
                                  description: post.group!.description,
                                  isPublic: true,
                                  ownerWallet: post.authorWallet ?? '',
                                  memberCount: 0,
                                  isMember: false,
                                  isOwner: false,
                                ),
                              )
                          : null,
                      icon: const Icon(Icons.groups_2_outlined, size: 18),
                      label: Text(l10n.commonGroup),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCardForPost(CommunityPost post) {
    final sourceIndex =
        _communityPosts.indexWhere((item) => item.id == post.id);
    if (sourceIndex == -1) {
      return const SizedBox.shrink();
    }
    return _buildPostCard(sourceIndex);
  }

  Widget _buildPostCard(int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    Provider.of<CommunityInteractionsProvider>(context);
    final commentsProvider = Provider.of<CommunityCommentsProvider>(context);
    if (index >= _communityPosts.length) {
      return const SizedBox.shrink();
    }
    final post = _communityPosts[index];
    final hydratedCommentCount = commentsProvider.totalCountForPost(post.id);
    if (commentsProvider.hasLoadedComments(post.id) &&
        post.commentCount != hydratedCommentCount) {
      post.commentCount = hydratedCommentCount;
    }
    final commentsExpanded = _expandedCommentPostIds.contains(post.id);
    return CommunityPostCard(
      post: post,
      accentColor: themeProvider.accentColor,
      onOpenPostDetail: (target) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => PostDetailScreen(post: target)),
        );
      },
      onOpenProfileIdentity: (identity) =>
          openProfileIdentity(context, identity),
      onToggleLike: () => _toggleLike(index),
      onOpenComments: () => _toggleInlineComments(index),
      onRepost: () {
        final walletProvider =
            Provider.of<WalletProvider>(context, listen: false);
        final currentWallet = walletProvider.currentWalletAddress;
        if (post.postType == 'repost' && post.authorWallet == currentWallet) {
          _showRepostOptions(post);
        } else {
          _showRepostModal(post);
        }
      },
      onShare: () => _sharePost(index),
      onToggleBookmark: () => _toggleBookmark(index),
      onMoreOptions: () => _showPostOptionsForPost(post),
      onShowLikes: () => _showPostLikes(post.id),
      onShowReposts: () => _viewRepostsList(post),
      onTagTap: _filterByTag,
      onMentionTap: _searchMention,
      onOpenLocation: _openLocationOnMap,
      onOpenGroup: _openGroupFromPost,
      onOpenSubject: (preview) => CommunitySubjectNavigation.open(
        context,
        subject: preview.ref,
        titleOverride: preview.title,
      ),
      commentsExpanded: commentsExpanded,
      inlineComments: commentsExpanded ? _buildInlineComments(post) : null,
    );
  }

  void _toggleInlineComments(int index) {
    if (index >= _communityPosts.length) return;
    final post = _communityPosts[index];
    final willExpand = !_expandedCommentPostIds.contains(post.id);
    _applyState(() {
      if (willExpand) {
        _expandedCommentPostIds.add(post.id);
      } else {
        _expandedCommentPostIds.remove(post.id);
      }
    });
    if (willExpand) {
      unawaited(
          context.read<CommunityCommentsProvider>().loadComments(post.id));
    }
  }

  Widget _buildInlineComments(CommunityPost post) {
    final l10n = AppLocalizations.of(context)!;
    final controller = _inlineCommentControllers.putIfAbsent(
      post.id,
      () => TextEditingController(),
    );
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Future<void> submitInlineComment() async {
      final text = controller.text.trim();
      if (text.isEmpty) return;
      final messenger = ScaffoldMessenger.of(context);
      final commentsProvider = context.read<CommunityCommentsProvider>();
      final parentId = _inlineReplyToCommentIds[post.id];
      try {
        await commentsProvider.addComment(
          postId: post.id,
          content: text,
          parentCommentId:
              parentId != null && parentId.isNotEmpty ? parentId : null,
        );
        post.commentCount = commentsProvider.totalCountForPost(post.id);
        ProfilePackageMutationTracker.postUpdated(post: post);
        controller.clear();
        if (!mounted) return;
        _applyState(() {
          _inlineReplyToCommentIds.remove(post.id);
        });
      } catch (e) {
        if (kDebugMode) {
          debugPrint('CommunityScreen: inline comment failed: $e');
        }
        if (!mounted) return;
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.postDetailAddCommentFailedToast)),
        );
      }
    }

    Widget buildComment(Comment comment, {required int depth}) {
      final isReply = depth > 0;
      final leftInset = (depth * 22.0).clamp(0.0, 44.0);
      return Padding(
        padding: EdgeInsets.only(left: leftInset, bottom: KubusSpacing.sm),
        child: LiquidGlassCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(KubusSpacing.sm),
          borderRadius: BorderRadius.circular(KubusRadius.md),
          backgroundColor:
              scheme.surface.withValues(alpha: isReply ? 0.08 : 0.12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileIdentitySummary(
                      identity: comment.authorIdentityData,
                      avatarRadius: isReply ? 12 : 14,
                      allowFabricatedFallback: true,
                      fetchMissingAvatar: false,
                      onTap: () => openProfileIdentity(
                        context,
                        comment.authorIdentityData,
                      ),
                      titleStyle: KubusTextStyles.actionTileTitle.copyWith(
                        fontSize: isReply ? 12 : 13,
                        color: scheme.onSurface,
                      ),
                      subtitleStyle: KubusTextStyles.sectionSubtitle.copyWith(
                        fontSize: isReply ? 11 : 12,
                        color: scheme.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.xxs),
                    Text(
                      comment.content,
                      style: KubusTextStyles.sectionSubtitle.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(KubusRadius.sm),
                          onTap: () async {
                            try {
                              await context
                                  .read<CommunityInteractionsProvider>()
                                  .toggleCommentLike(
                                    postId: post.id,
                                    comment: comment,
                                  );
                              if (mounted) _applyState(() {});
                            } catch (_) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showKubusSnackBar(
                                SnackBar(
                                  content: Text(l10n
                                      .postDetailUpdateCommentLikeFailedToast),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: KubusSpacing.xs,
                              vertical: KubusSpacing.xxs,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  comment.isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 15,
                                  color: comment.isLiked
                                      ? KubusColorRoles.of(context).likeAction
                                      : scheme.onSurface
                                          .withValues(alpha: 0.56),
                                ),
                                const SizedBox(width: KubusSpacing.xs),
                                Text(
                                  '${comment.likeCount}',
                                  style: KubusTextStyles.compactBadge.copyWith(
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.66),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: KubusSpacing.sm),
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: KubusSpacing.sm,
                            ),
                          ),
                          onPressed: () {
                            _applyState(() {
                              _inlineReplyToCommentIds[post.id] = comment.id;
                              controller.text = '@${comment.authorName} ';
                              controller.selection = TextSelection.collapsed(
                                offset: controller.text.length,
                              );
                            });
                          },
                          child: Text(l10n.commonReply),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    List<Widget> buildTree(Comment comment, {required int depth}) {
      return <Widget>[
        buildComment(comment, depth: depth),
        for (final reply in comment.replies)
          ...buildTree(reply, depth: depth + 1),
      ];
    }

    return Consumer<CommunityCommentsProvider>(
      builder: (context, commentsProvider, _) {
        final comments = commentsProvider.commentsForPost(post.id);
        final loading = commentsProvider.isLoading(post.id);
        final error = commentsProvider.errorForPost(post.id);
        final replyTarget = _inlineReplyToCommentIds[post.id];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: scheme.outline.withValues(alpha: 0.18)),
            if (loading && comments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: KubusSpacing.md),
                child: Center(child: InlineLoading(width: 40, height: 40)),
              )
            else if (error != null && comments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: KubusSpacing.sm),
                child: Text(
                  error,
                  style: KubusTextStyles.sectionSubtitle.copyWith(
                    color: scheme.error,
                  ),
                ),
              )
            else if (comments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: KubusSpacing.sm),
                child: Text(
                  l10n.postDetailNoCommentsDescription,
                  style: KubusTextStyles.sectionSubtitle.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              )
            else
              ...comments.expand((comment) => buildTree(comment, depth: 0)),
            if (replyTarget != null) ...[
              const SizedBox(height: KubusSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.communityReplyingToCommentLabel,
                      style: KubusTextStyles.compactBadge.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _applyState(() {
                        _inlineReplyToCommentIds.remove(post.id);
                        controller.clear();
                      });
                    },
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ],
            const SizedBox(height: KubusSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => submitInlineComment(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l10n.postDetailWriteCommentHint,
                      hintStyle: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.56),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(KubusRadius.md),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: KubusSpacing.sm),
                IconButton.filledTonal(
                  onPressed: submitInlineComment,
                  icon: const Icon(Icons.send_outlined, size: 18),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildFloatingActionButton() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scheme = Theme.of(context).colorScheme;
    final animationTheme = context.animationTheme;
    final l10n = AppLocalizations.of(context)!;
    final int tabIndex = _tabController.index;

    // Groups tab (index 2) and Art tab (index 3) get expandable FABs
    if (tabIndex == 2) {
      return _buildExpandableFab(
        themeProvider: themeProvider,
        scheme: scheme,
        animationTheme: animationTheme,
        mainIcon: Icons.add,
        mainLabel: l10n.commonCreate,
        options: [
          CommunityFabOption(
            icon: Icons.group_add_outlined,
            label: l10n.communityFabCreateGroup,
            onTap: () => _showCreateGroupSheet(),
          ),
          CommunityFabOption(
            icon: Icons.post_add_outlined,
            label: l10n.communityFabGroupPost,
            onTap: () {
              _handleGroupFabPressed();
            },
          ),
        ],
      );
    } else if (tabIndex == 3) {
      return _buildExpandableFab(
        themeProvider: themeProvider,
        scheme: scheme,
        animationTheme: animationTheme,
        mainIcon: Icons.add,
        mainLabel: l10n.commonCreate,
        options: [
          CommunityFabOption(
            icon: Icons.place_outlined,
            label: l10n.communityFabArtDrop,
            onTap: () => _handleArtFabPressed(),
          ),
          CommunityFabOption(
            icon: Icons.rate_review_outlined,
            label: l10n.communityFabPostReview,
            onTap: () =>
                _createNewPost(presetCategory: 'review', artContext: true),
          ),
        ],
      );
    }

    // Following/Discover tabs get simple FAB
    final fab = FloatingActionButton.extended(
      key: ValueKey('fab_$tabIndex'),
      heroTag: 'community_fab_$tabIndex',
      onPressed: _handleFeedFabPressed,
      backgroundColor: themeProvider.accentColor,
      icon: Icon(Icons.edit_outlined, color: scheme.onPrimary),
      label: Text(
        l10n.communityFabNewPost,
        style: KubusTypography.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onPrimary,
        ),
      ),
    );

    return AnimatedSwitcher(
      duration: animationTheme.medium,
      reverseDuration: animationTheme.short,
      switchInCurve: animationTheme.emphasisCurve,
      switchOutCurve: animationTheme.fadeCurve,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: animationTheme.emphasisCurve,
        );
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: animationTheme.fadeCurve,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      child: fab,
    );
  }

  Widget _buildExpandableFab({
    required ThemeProvider themeProvider,
    required ColorScheme scheme,
    required AppAnimationTheme animationTheme,
    required IconData mainIcon,
    required String mainLabel,
    required List<CommunityFabOption> options,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return CommunityExpandableFab(
      isExpanded: _isFabExpanded,
      accentColor: themeProvider.accentColor,
      scheme: scheme,
      animationTheme: animationTheme,
      mainIcon: mainIcon,
      mainLabel: mainLabel,
      closeLabel: l10n.commonClose,
      mainHeroTag: 'community_fab_expandable',
      optionHeroTagPrefix: 'fab_option_',
      options: options,
      variant: CommunityExpandableFabVariant.mobile,
      onExpandedChanged: (expanded) {
        _applyState(() => _isFabExpanded = expanded);
      },
    );
  }

  void _showCreateGroupSheet() {
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isPublic = true;
    bool isCreating = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final scheme = Theme.of(context).colorScheme;
          final themeProvider =
              Provider.of<ThemeProvider>(context, listen: false);
          final l10n = AppLocalizations.of(context)!;

          return KeyboardInsetPadding(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(KubusRadius.xl)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: scheme.outline.withValues(alpha: 0.4),
                      borderRadius: KubusRadius.circular(3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Row(
                      children: [
                        Text(
                          l10n.communityCreateGroupTitle,
                          style:
                              KubusTypography.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          color: scheme.onSurface,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: nameController,
                            style: TextStyle(
                              color: scheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n.communityCreateGroupNameLabel,
                              hintText: l10n.communityCreateGroupNameHint,
                              hintStyle: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.56),
                              ),
                              border: OutlineInputBorder(
                                borderRadius:
                                    KubusRadius.circular(KubusRadius.md),
                              ),
                              filled: true,
                              fillColor: scheme.primaryContainer
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: descriptionController,
                            maxLines: 3,
                            style: TextStyle(
                              color: scheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  l10n.communityCreateGroupDescriptionLabel,
                              hintText:
                                  l10n.communityCreateGroupDescriptionHint,
                              hintStyle: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.56),
                              ),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(KubusRadius.md),
                              ),
                              filled: true,
                              fillColor: scheme.primaryContainer
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              l10n.communityCreateGroupPublicLabel,
                              style: KubusTypography.inter(
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              isPublic
                                  ? l10n.communityCreateGroupPublicHint
                                  : l10n.communityCreateGroupPrivateHint,
                              style: KubusTypography.inter(fontSize: 13),
                            ),
                            value: isPublic,
                            onChanged: (val) =>
                                setModalState(() => isPublic = val),
                            activeThumbColor: themeProvider.accentColor,
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isCreating ||
                                  nameController.text.trim().isEmpty
                              ? null
                              : () async {
                                  final sheetNavigator =
                                      Navigator.of(sheetContext);
                                  final l10n = AppLocalizations.of(context)!;
                                  setModalState(() => isCreating = true);
                                  try {
                                    final created = await hub.createGroup(
                                      name: nameController.text.trim(),
                                      description: descriptionController.text
                                              .trim()
                                              .isEmpty
                                          ? null
                                          : descriptionController.text.trim(),
                                      isPublic: isPublic,
                                    );
                                    if (!mounted) return;
                                    sheetNavigator.pop();
                                    if (created != null) {
                                      _showSnack(
                                          l10n.communityGroupCreatedToast(
                                              created.name));
                                      _openGroupFeed(created);
                                    }
                                  } catch (e) {
                                    setModalState(() => isCreating = false);
                                    if (kDebugMode) {
                                      debugPrint(
                                          'CommunityScreen: failed to create group: $e');
                                    }
                                    _showSnack(
                                        l10n.communityCreateGroupFailedToast);
                                  }
                                },
                          child: isCreating
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: InlineLoading(
                                    expand: true,
                                    shape: BoxShape.circle,
                                    tileSize: 3.5,
                                  ),
                                )
                              : Text(l10n.communityCreateGroupButton),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
