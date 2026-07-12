part of '../community_screen.dart';

// Extracted from community_screen.dart (godfile split). Same library:
// private state access is intact. setState is routed through
// the State's _applyState shim.
extension _CommunityScreenStatePart5 on _CommunityScreenState {
  void _sharePost(int index) async {
    if (index >= _communityPosts.length) return;
    final post = _communityPosts[index];
    _showShareModal(post);
  }

  void _showShareModal(CommunityPost post) {
    if (!mounted) return;
    ShareService().showShareSheet(
      context,
      target: share_types.ShareTarget.post(
        postId: post.id,
        title: post.content,
      ),
      sourceScreen: 'community_feed',
      onCreatePostRequested: () async {
        if (!mounted) return;
        _showRepostModal(post);
      },
    );
  }

  void _maybeHandleComposerOpenRequest(int nonce) {
    if (nonce == 0) return;
    if (nonce == _lastHandledComposerOpenNonce) return;
    _lastHandledComposerOpenNonce = nonce;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _createNewPost(resetDraft: false);
    });
  }

  void _showRepostModal(CommunityPost post) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final repostContentController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => KeyboardInsetPadding(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(KubusRadius.xl),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.postDetailRepostButton,
                      style: KubusTypography.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(
                            l10n.commonCancel,
                            style: KubusTypography.inter(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final content = repostContentController.text.trim();
                            Navigator.pop(sheetContext);
                            final messenger = ScaffoldMessenger.of(context);

                            try {
                              final createdRepost = await context
                                  .read<CommunityInteractionsProvider>()
                                  .createRepost(
                                    originalPost: post,
                                    content:
                                        content.isNotEmpty ? content : null,
                                  );

                              if (!mounted) return;
                              // Insert repost into feed immediately for instant feedback
                              _applyState(() {
                                _communityPosts.insert(0, createdRepost);
                              });
                              messenger.showKubusSnackBar(
                                SnackBar(
                                  content: Text(content.isEmpty
                                      ? l10n.postDetailRepostSuccessToast
                                      : l10n
                                          .postDetailRepostWithCommentSuccessToast),
                                ),
                              );
                            } catch (e) {
                              if (kDebugMode) {
                                debugPrint(
                                    'CommunityScreen: repost failed: $e');
                              }
                              if (!mounted) return;
                              messenger.showKubusSnackBar(
                                SnackBar(
                                  content:
                                      Text(l10n.postDetailRepostFailedToast),
                                ),
                              );
                            }
                          },
                          child: Text(l10n.postDetailRepostButton,
                              style: KubusTypography.inter()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(KubusSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: repostContentController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: l10n.postDetailRepostThoughtsHint,
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(KubusRadius.md)),
                          filled: true,
                          fillColor: theme.colorScheme.primaryContainer,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(l10n.postDetailRepostingLabel,
                          style: KubusTypography.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(KubusSpacing.md),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(KubusRadius.md),
                          color: theme.colorScheme.surface,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ProfileIdentitySummary(
                                    identity: post.authorIdentityData,
                                    avatarRadius: 16,
                                    allowFabricatedFallback: true,
                                    fetchMissingAvatar: false,
                                    onTap: () => openProfileIdentity(
                                      context,
                                      post.authorIdentityData,
                                    ),
                                    titleStyle: KubusTypography.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    subtitleStyle: KubusTypography.inter(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(_getTimeAgo(post.timestamp),
                                style: KubusTypography.inter(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5))),
                            const SizedBox(height: 8),
                            Text(post.content,
                                style: KubusTypography.inter(fontSize: 14),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis),
                            if (post.imageUrl != null &&
                                post.imageUrl!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(KubusRadius.sm),
                                child: Image.network(
                                  MediaUrlResolver.resolveDisplayUrl(
                                          post.imageUrl) ??
                                      post.imageUrl!,
                                  fit: BoxFit.cover,
                                  height: 120,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    final scheme =
                                        Theme.of(context).colorScheme;
                                    return Container(
                                      height: 120,
                                      width: double.infinity,
                                      color: scheme.surfaceContainerHighest,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewUserProfile(String userId) {
    unawaited(UserProfileNavigation.open(context, userId: userId));
  }

  void _viewRepostsList(CommunityPost post) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(KubusRadius.xl),
          ),
        ),
        child: Column(
          children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.communityRepostedByTitle,
                      style: KubusTypography.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface)),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: BackendApiService().getPostReposts(postId: post.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: InlineLoading(width: 40, height: 40));
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text(l10n.communityRepostsLoadFailedMessage,
                            style: KubusTypography.inter()));
                  }
                  final reposts = snapshot.data ?? [];
                  if (reposts.isEmpty) {
                    return Center(
                      child: EmptyStateCard(
                        icon: Icons.repeat,
                        title: l10n.communityNoRepostsTitle,
                        description: l10n.communityNoRepostsDescription,
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: reposts.length,
                    itemBuilder: (ctx, idx) {
                      final repost = reposts[idx];
                      final user = repost['user'] as Map<String, dynamic>?;
                      final wallet = WalletUtils.coalesce(
                        walletAddress: user?['walletAddress']?.toString(),
                        wallet: user?['wallet_address']?.toString() ??
                            user?['wallet']?.toString(),
                        userId: user?['id']?.toString(),
                        fallback: '',
                      );
                      final comment = repost['repostComment'] as String?;
                      final createdAt =
                          DateTime.tryParse(repost['createdAt'] ?? '');
                      final identity = communityRepostIdentityDataFromPayload(
                        user,
                        fallbackLabel: wallet.isNotEmpty
                            ? maskWallet(wallet)
                            : l10n.commonUnknown,
                      );
                      final subtitle = identity.handle ??
                          (wallet.isNotEmpty ? maskWallet(wallet) : null);

                      return ListTile(
                        onTap: () => openProfileIdentity(context, identity),
                        leading: AvatarWidget(
                            wallet: identity.walletSeed,
                            avatarUrl: identity.avatarUrl,
                            radius: 20,
                            allowFabricatedFallback: false,
                            enableProfileNavigation: false),
                        title: Text(identity.label,
                            style: KubusTypography.inter(
                                fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (subtitle != null)
                              Text(subtitle,
                                  style: KubusTypography.inter(fontSize: 12)),
                            if (comment != null && comment.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(comment,
                                  style: KubusTypography.inter(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                        trailing: createdAt != null
                            ? Text(_getTimeAgo(createdAt),
                                style: KubusTypography.inter(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5)))
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRepostOptions(CommunityPost post) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final shouldUnrepost = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(KubusRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading:
                  Icon(Icons.delete_outline, color: theme.colorScheme.error),
              title: Text(l10n.communityUnrepostAction,
                  style: KubusTypography.inter(color: theme.colorScheme.error)),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
            ListTile(
              leading: Icon(Icons.cancel,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              title: Text(l10n.commonCancel, style: KubusTypography.inter()),
              onTap: () => Navigator.pop(sheetContext, false),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (!mounted || shouldUnrepost != true) return;
    _unrepostPost(post);
  }

  void _unrepostPost(CommunityPost post) async {
    if (!mounted) return;
    if (_deleteDialogOpenPostIds.contains(post.id) ||
        _deleteInFlightPostIds.contains(post.id)) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    _deleteDialogOpenPostIds.add(post.id);

    // Show confirmation dialog
    final confirmed = await showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        title:
            Text(l10n.communityUnrepostTitle, style: KubusTypography.inter()),
        content: Text(l10n.communityUnrepostConfirmBody,
            style: KubusTypography.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel, style: KubusTypography.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error),
            child: Text(l10n.communityUnrepostAction,
                style: KubusTypography.inter()),
          ),
        ],
      ),
    ).whenComplete(() {
      _deleteDialogOpenPostIds.remove(post.id);
    });

    if (confirmed != true || !mounted) return;
    if (_deleteInFlightPostIds.contains(post.id)) return;
    _deleteInFlightPostIds.add(post.id);

    try {
      await context.read<CommunityInteractionsProvider>().deleteRepost(post);

      if (!mounted) return;
      _applyState(() => _removePostFromLocalFeeds(post.id));
      try {
        final hub = Provider.of<CommunityHubProvider>(context, listen: false);
        if (post.groupId != null) {
          hub.removeGroupPost(post.groupId!, post.id);
        }
        hub.removeArtFeedPost(post.id);
      } catch (_) {}
      _appRefreshProvider?.triggerCommunity();
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.communityRepostRemovedToast)),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CommunityScreen: unrepost failed: $e');
      }
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.communityUnrepostFailedToast)),
      );
    } finally {
      _deleteInFlightPostIds.remove(post.id);
    }
  }

  Future<void> _showPostOptionsForPost(CommunityPost post) async {
    if (!mounted) return;
    final currentWallet = _currentWalletAddress();
    final authorWallet = post.authorWallet ?? post.authorId;
    final isOwner = currentWallet != null &&
        WalletUtils.equals(authorWallet, currentWallet);

    final action = await showCommunityPostOptionsSheet(
      context: context,
      post: post,
      isOwner: isOwner,
    );
    if (!mounted || action == null) return;

    switch (action) {
      case CommunityPostOptionsAction.report:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(
              post: post,
              initialAction: PostDetailInitialAction.report,
            ),
          ),
        );
        break;
      case CommunityPostOptionsAction.edit:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(
              post: post,
              initialAction: PostDetailInitialAction.edit,
            ),
          ),
        );
        break;
      case CommunityPostOptionsAction.delete:
        await _confirmDeleteFeedPost(post);
        break;
    }
  }

  void _removePostFromLocalFeeds(String postId) {
    void removeFrom(List<CommunityPost> posts) {
      posts.removeWhere((item) => item.id == postId);
    }

    removeFrom(_communityPosts);
    removeFrom(_followingFeedPosts);
    removeFrom(_discoverFeedPosts);
    removeFrom(_artFeedPosts);
    removeFrom(_bufferedIncomingPosts);
    _expandedCommentPostIds.remove(postId);
    _inlineReplyToCommentIds.remove(postId);
    _inlineCommentControllers.remove(postId)?.dispose();
  }

  Future<void> _confirmDeleteFeedPost(CommunityPost post) async {
    if (!mounted) return;
    if (_deleteDialogOpenPostIds.contains(post.id) ||
        _deleteInFlightPostIds.contains(post.id)) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    _deleteDialogOpenPostIds.add(post.id);
    bool deleting = false;

    try {
      await showKubusDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => KubusAlertDialog(
            title: Text(
              l10n.postDetailDeletePostTitle,
              style: KubusTypography.inter(fontWeight: FontWeight.bold),
            ),
            content: Text(
              l10n.postDetailDeletePostBody,
              style: KubusTypography.inter(),
            ),
            actions: [
              TextButton(
                onPressed: deleting
                    ? null
                    : () => Navigator.of(dialogContext).maybePop(),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: deleting
                    ? null
                    : () async {
                        if (_deleteInFlightPostIds.contains(post.id)) return;
                        setDialogState(() => deleting = true);
                        _deleteInFlightPostIds.add(post.id);
                        final messenger = ScaffoldMessenger.of(context);
                        final appRefresh = _appRefreshProvider;

                        try {
                          await context
                              .read<CommunityInteractionsProvider>()
                              .deleteCommunityPost(post);
                          if (!mounted || !dialogContext.mounted) return;
                          _applyState(() => _removePostFromLocalFeeds(post.id));
                          try {
                            final hub = Provider.of<CommunityHubProvider>(
                              context,
                              listen: false,
                            );
                            if (post.groupId != null) {
                              hub.removeGroupPost(post.groupId!, post.id);
                            }
                            hub.removeArtFeedPost(post.id);
                          } catch (_) {}
                          appRefresh?.triggerCommunity();
                          Navigator.of(dialogContext).pop();
                          messenger.showKubusSnackBar(
                            SnackBar(
                                content: Text(l10n.postDetailPostDeletedToast)),
                          );
                        } catch (e) {
                          if (kDebugMode) {
                            debugPrint(
                                'CommunityScreen: delete post failed: $e');
                          }
                          if (!mounted || !dialogContext.mounted) return;
                          setDialogState(() => deleting = false);
                          messenger.showKubusSnackBar(
                            SnackBar(
                              content:
                                  Text(l10n.postDetailDeletePostFailedToast),
                            ),
                          );
                        } finally {
                          _deleteInFlightPostIds.remove(post.id);
                        }
                      },
                child: deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: InlineLoading(tileSize: 4),
                      )
                    : Text(l10n.commonDelete),
              ),
            ],
          ),
        ),
      );
    } finally {
      _deleteDialogOpenPostIds.remove(post.id);
    }
  }

  void _filterByTag(String tag) {
    final cleaned = tag.replaceAll('#', '').trim();
    if (cleaned.isEmpty) return;
    _communitySearchController.setQuery(context, '#$cleaned');
  }

  void _searchMention(String mention) {
    // Navigate to user profile search
    _viewUserProfile(mention);
  }

  void _openLocationOnMap(CommunityLocation location) {
    final target = communityLocationToLatLng(location);
    if (target == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          initialCenter: target,
          initialZoom: 15,
          autoFollow: false,
        ),
      ),
    );
  }

  void _openGroupFromPost(CommunityGroupReference group) {
    _openGroupFeed(communityGroupSummaryFromReference(group));
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    final l10n = AppLocalizations.of(context)!;

    if (difference.inDays > 7) {
      return l10n.commonTimeAgoWeeks((difference.inDays / 7).floor());
    } else if (difference.inDays > 0) {
      return l10n.commonTimeAgoDays(difference.inDays);
    } else if (difference.inHours > 0) {
      return l10n.commonTimeAgoHours(difference.inHours);
    } else if (difference.inMinutes > 0) {
      return l10n.commonTimeAgoMinutes(difference.inMinutes);
    } else {
      return l10n.commonTimeAgoJustNow;
    }
  }
}
