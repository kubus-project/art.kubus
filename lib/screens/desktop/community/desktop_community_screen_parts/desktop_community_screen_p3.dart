part of '../desktop_community_screen.dart';

// Extracted from desktop_community_screen.dart (godfile split). Same library:
// private state access is intact. setState is routed through
// the State's _applyState shim.
extension _DesktopCommunityScreenStatePart3 on _DesktopCommunityScreenState {
  Widget _buildPostCard(CommunityPost post, ThemeProvider themeProvider) {
    final commentsExpanded = _expandedCommentPostIds.contains(post.id);
    return CommunityPostCard(
      post: post,
      accentColor: themeProvider.accentColor,
      onOpenPostDetail: _openPostDetail,
      onOpenProfileIdentity: (identity) =>
          openProfileIdentity(context, identity),
      onToggleLike: () => _togglePostLike(post),
      onOpenComments: () => _toggleInlineComments(post),
      onRepost: () => _handleRepostTap(post),
      onShare: () => _showShareDialog(post),
      onToggleBookmark: () => _toggleBookmark(post),
      onMoreOptions: () => _showPostOptionsForPost(post),
      onShowLikes: () => _showPostLikes(post.id),
      onShowReposts: () => _viewRepostsList(post),
      onTagTap: (tag) => unawaited(_openTagFeed(tag)),
      onMentionTap: (mention) => unawaited(
        _openUserProfileModal(
          userId: mention,
          username: mention,
        ),
      ),
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

  Future<void> _togglePostLike(CommunityPost post) async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final authenticated = await const ContextualAuthGate().ensureAuthenticated(
      context,
      actionLabel: l10n.commonLikes.toLowerCase(),
      returnRoute: '/p/${Uri.encodeComponent(post.id)}',
    );
    if (!authenticated || !mounted) return;
    final wasLiked = post.isLiked;
    try {
      await CommunityService.togglePostLike(
        post,
        currentUserWallet: walletProvider.currentWalletAddress,
      );
      if (!mounted) return;
      _applyState(() {});
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            wasLiked
                ? l10n.postDetailPostUnlikedToast
                : l10n.postDetailPostLikedToast,
          ),
          duration: const Duration(milliseconds: 1300),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _applyState(() {});
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.communityToggleLikeFailedToast),
        ),
      );
    }
  }

  Future<void> _toggleBookmark(CommunityPost post) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final authenticated = await const ContextualAuthGate().ensureAuthenticated(
      context,
      actionLabel: l10n.commonSave.toLowerCase(),
      returnRoute: '/p/${Uri.encodeComponent(post.id)}',
    );
    if (!authenticated || !mounted) return;
    try {
      await CommunityPostSaveController.toggle(context, post);
      if (!mounted) return;
      _applyState(() {});
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(post.isBookmarked
              ? l10n.communityBookmarkAddedToast
              : l10n.communityBookmarkRemovedToast),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.communityBookmarkUpdateFailedToast)),
      );
    }
  }

  void _toggleInlineComments(CommunityPost post) {
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
          debugPrint('DesktopCommunityScreen: inline comment failed: $e');
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
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l10n.postDetailWriteCommentHint,
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

  Future<void> _showShareDialog(CommunityPost post) async {
    await ShareService().showShareSheet(
      context,
      target: share_types.ShareTarget.post(
        postId: post.id,
        title: post.content,
      ),
      sourceScreen: 'desktop_community_feed',
      onCreatePostRequested: () async {
        if (!mounted) return;
        await _showRepostOptions(post);
      },
    );
  }

  void _maybeHandleComposerOpenRequest(CommunityHubProvider hub) {
    final nonce = hub.composerOpenNonce;
    if (nonce == 0) return;
    if (nonce == _lastHandledComposerOpenNonce) return;
    _lastHandledComposerOpenNonce = nonce;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isComposerExpanded) return;
      _applyState(() {
        _isComposerExpanded = true;
        _selectedCategory = hub.draft.category.isNotEmpty
            ? hub.draft.category
            : _selectedCategory;
      });
    });
  }

  Future<void> _showRepostOptions(CommunityPost post) async {
    await showKubusDialog(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        Widget optionTile({
          required IconData icon,
          required String label,
          Color? iconColor,
          required Future<void> Function() onTap,
        }) {
          final scheme = Theme.of(dialogContext).colorScheme;
          return LiquidGlassPanel(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            showBorder: false,
            borderRadius: BorderRadius.circular(KubusRadius.md),
            backgroundColor: scheme.surface.withValues(alpha: 0.06),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(KubusRadius.md),
                onTap: () async {
                  Navigator.of(dialogContext).pop();
                  await onTap();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.lg,
                    vertical: KubusSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Icon(icon,
                          size: 18, color: iconColor ?? scheme.onSurface),
                      const SizedBox(width: KubusSpacing.md),
                      Expanded(
                        child: Text(
                          label,
                          style: KubusTextStyles.navLabel.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return KubusAlertDialog(
          title: Text(l10n.postDetailSharePostTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              optionTile(
                icon: Icons.repeat,
                label: l10n.communityQuickRepostAction,
                onTap: () => _createRepost(post),
              ),
              const SizedBox(height: KubusSpacing.md),
              optionTile(
                icon: Icons.edit_note,
                label: l10n.communityRepostWithCommentAction,
                onTap: () => _showQuoteRepostDialog(post),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showQuoteRepostDialog(CommunityPost post) async {
    final controller = TextEditingController();
    bool isSubmitting = false;

    await showKubusDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return KubusAlertDialog(
              title: Text(l10n.communityRepostWithCommentAction),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: l10n.communityRepostWithCommentHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    _buildRepostPreview(post),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(AppLocalizations.of(context)!.commonCancel),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final navigator = Navigator.of(dialogContext);
                          setDialogState(() => isSubmitting = true);
                          final success = await _createRepost(post,
                              comment: controller.text.trim());
                          if (!mounted) return;
                          setDialogState(() => isSubmitting = false);
                          if (success) {
                            navigator.pop();
                          }
                        },
                  child: isSubmitting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: InlineLoading(
                              tileSize: 4,
                              color: Theme.of(context).colorScheme.onPrimary),
                        )
                      : Text(l10n.communityRepostButtonLabel),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
  }

  Future<bool> _createRepost(CommunityPost post, {String? comment}) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      final createdRepost =
          await context.read<CommunityInteractionsProvider>().createRepost(
                originalPost: post,
                content: comment != null && comment.trim().isNotEmpty
                    ? comment.trim()
                    : null,
              );
      if (!mounted) return false;
      _applyState(() {
        _discoverPosts = _prependUniquePost(_discoverPosts, createdRepost);
        _followingPosts = _prependUniquePost(_followingPosts, createdRepost);
      });
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(comment != null && comment.trim().isNotEmpty
              ? l10n.communityRepostedWithCommentToast
              : l10n.communityRepostedToast),
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.postDetailRepostFailedToast)),
      );
      return false;
    }
  }

  Widget _buildRepostPreview(CommunityPost post) {
    final scheme = Theme.of(context).colorScheme;
    final originalPost = post.originalPost;
    final displayPost = originalPost ?? post;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ProfileIdentitySummary(
                  identity: displayPost.authorIdentityData,
                  avatarRadius: 14,
                  allowFabricatedFallback: true,
                  fetchMissingAvatar: false,
                  onTap: () => openProfileIdentity(
                    context,
                    displayPost.authorIdentityData,
                  ),
                  titleStyle: KubusTextStyles.actionTileTitle.copyWith(
                    color: scheme.onSurface,
                  ),
                  subtitleStyle: KubusTextStyles.navMetaLabel.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.62),
                  ),
                  titleSuffix: CommunityAuthorRoleBadges(
                    post: displayPost,
                    fontSize: 8,
                    iconOnly: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            displayPost.content,
            style: KubusTextStyles.detailBody.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.8),
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
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
    final summary = communityGroupSummaryFromReference(group);
    final shellScope = DesktopShellScope.of(context);
    if (shellScope != null) {
      shellScope.pushScreen(
        DesktopSubScreen(
          title: summary.name,
          child: GroupFeedScreen(group: summary, embedded: true),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupFeedScreen(group: summary)),
    );
  }

  void _handleRepostTap(CommunityPost post) {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final currentWallet = walletProvider.currentWalletAddress;
    final authorWallet = post.authorWallet ?? post.authorId;
    if (post.postType == 'repost' &&
        WalletUtils.equals(authorWallet, currentWallet)) {
      unawaited(_showUnrepostOptions(post));
      return;
    }
    unawaited(_showRepostOptions(post));
  }

  Future<void> _showUnrepostOptions(CommunityPost post) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldUnrepost = await showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool selectionMade = false;
        Widget optionTile({
          required IconData icon,
          required String label,
          Color? iconColor,
          TextStyle? textStyle,
          required bool result,
        }) {
          final scheme = Theme.of(dialogContext).colorScheme;
          return LiquidGlassPanel(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            showBorder: false,
            borderRadius: BorderRadius.circular(KubusRadius.md),
            backgroundColor: scheme.surface.withValues(alpha: 0.06),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(KubusRadius.md),
                onTap: () {
                  if (selectionMade) return;
                  selectionMade = true;
                  Navigator.of(dialogContext).pop(result);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.lg,
                    vertical: KubusSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Icon(icon,
                          size: 18, color: iconColor ?? scheme.onSurface),
                      const SizedBox(width: KubusSpacing.md),
                      Expanded(
                        child: Text(
                          label,
                          style: textStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final scheme = Theme.of(dialogContext).colorScheme;

        return KubusAlertDialog(
          title: Text(l10n.communityUnrepostTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              optionTile(
                icon: Icons.delete_outline,
                label: l10n.communityUnrepostAction,
                iconColor: scheme.error,
                textStyle:
                    KubusTextStyles.navLabel.copyWith(color: scheme.error),
                result: true,
              ),
              const SizedBox(height: KubusSpacing.md),
              optionTile(
                icon: Icons.cancel,
                label: l10n.commonCancel,
                iconColor: scheme.onSurface.withValues(alpha: 0.65),
                result: false,
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || shouldUnrepost != true) return;
    await _unrepostPost(post);
  }

  Future<void> _unrepostPost(CommunityPost post) async {
    if (!mounted) return;
    if (_deleteDialogOpenPostIds.contains(post.id) ||
        _deleteInFlightPostIds.contains(post.id)) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    _deleteDialogOpenPostIds.add(post.id);

    final confirmed = await showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        title: Text(
          l10n.communityUnrepostTitle,
          style: KubusTextStyles.sectionTitle,
        ),
        content: Text(
          l10n.communityUnrepostConfirmBody,
          style: KubusTextStyles.sectionSubtitle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel, style: KubusTextStyles.navLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(
              l10n.communityUnrepostAction,
              style: KubusTextStyles.navLabel.copyWith(
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
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
          SnackBar(content: Text(l10n.communityRepostRemovedToast)));
    } catch (e) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.communityUnrepostFailedToast)));
    } finally {
      _deleteInFlightPostIds.remove(post.id);
    }
  }

  void _showPostLikes(String postId) {
    final l10n = AppLocalizations.of(context)!;
    _showLikesDialog(
      title: l10n.communityPostLikesTitle,
      loader: () => BackendApiService().getPostLikes(postId),
    );
  }

  void _showLikesDialog({
    required String title,
    required Future<List<CommunityLikeUser>> Function() loader,
  }) {
    final l10n = AppLocalizations.of(context)!;
    showCommunityLikesSheet(
      context: context,
      title: title,
      loader: loader,
      formatTimeAgo: (likedAt) => _formatTimeAgo(likedAt),
      errorMessage: l10n.postDetailLoadLikesFailedMessage,
      unnamedUserLabel: l10n.commonUnnamed,
      isScrollControlled: true,
    );
  }

  void _viewRepostsList(CommunityPost post) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final future = BackendApiService().getPostReposts(postId: post.id);

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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.communityRepostedByTitle,
                    style: KubusTextStyles.sectionTitle
                        .copyWith(color: theme.colorScheme.onSurface),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: InlineLoading(width: 40, height: 40));
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        l10n.communityRepostsLoadFailedMessage,
                        style: KubusTextStyles.sectionSubtitle,
                      ),
                    );
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
                          enableProfileNavigation: false,
                          allowFabricatedFallback: false,
                        ),
                        title: Text(
                          identity.label,
                          style: KubusTextStyles.sectionTitle,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (subtitle != null)
                              Text(
                                subtitle,
                                style: KubusTextStyles.navMetaLabel,
                              ),
                            if (comment != null && comment.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                comment,
                                style: KubusTextStyles.navMetaLabel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                        trailing: createdAt != null
                            ? Text(
                                _formatTimeAgo(createdAt),
                                style: KubusTextStyles.compactBadge.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              )
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

  List<CommunityPost> _prependUniquePost(
      List<CommunityPost> source, CommunityPost post) {
    final filtered =
        source.where((existing) => existing.id != post.id).toList();
    return [post, ...filtered];
  }

  void _handleSidebarTabChange(bool showMessages) {
    _applyState(() {
      _showMessagesPanel = showMessages;
      if (!showMessages) {
        _paneStack
            .removeWhere((route) => route.type == _PaneViewType.conversation);
        _activeConversationId = null;
      }
    });
  }

  Widget _buildRightSidebar(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    const sidebarTabHorizontalPadding = KubusSpacing.md;
    const sidebarTabVerticalPadding = KubusSpacing.sm + KubusSpacing.xs;
    final currentTab = _tabs[_tabController.index];
    final showTrending = currentTab == 'discover' || currentTab == 'art';
    final showWhoToFollow =
        currentTab == 'discover' || currentTab == 'following';
    final showActiveCommunities = true;
    return Column(
      children: [
        // Sidebar tabs
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: sidebarTabHorizontalPadding,
            vertical: sidebarTabVerticalPadding,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.1),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildSidebarTab(
                  l10n.commonFeed,
                  Icons.dynamic_feed,
                  !_showMessagesPanel,
                  () => _handleSidebarTabChange(false),
                  themeProvider,
                ),
              ),
              const SizedBox(width: KubusSpacing.sm),
              Expanded(
                child: _buildSidebarTab(
                  l10n.messagesTitle,
                  Icons.mail_outline,
                  _showMessagesPanel,
                  () => _handleSidebarTabChange(true),
                  themeProvider,
                ),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _showMessagesPanel
              ? _buildMessagesPanel(themeProvider)
              : ListView(
                  padding: const EdgeInsets.all(KubusSpacing.lg),
                  children: [
                    _buildCreatePostPrompt(themeProvider),
                    if (showTrending) ...[
                      const SizedBox(height: KubusSpacing.lg),
                      _buildTrendingSection(themeProvider),
                    ],
                    if (showWhoToFollow) ...[
                      const SizedBox(height: KubusSpacing.lg),
                      _buildWhoToFollowSection(themeProvider),
                    ],
                    if (showActiveCommunities) ...[
                      const SizedBox(height: KubusSpacing.lg),
                      _buildActiveCommunitiesSection(themeProvider),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSidebarTab(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
    ThemeProvider themeProvider,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KubusRadius.md),
        splashColor: themeProvider.accentColor.withValues(alpha: 0.1),
        highlightColor: themeProvider.accentColor.withValues(alpha: 0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      themeProvider.accentColor.withValues(alpha: 0.15),
                      themeProvider.accentColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            borderRadius: BorderRadius.circular(KubusRadius.md),
            border: Border.all(
              color: isSelected
                  ? themeProvider.accentColor.withValues(alpha: 0.4)
                  : scheme.outline.withValues(alpha: 0.2),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: themeProvider.accentColor.withValues(alpha: 0.15),
                      blurRadius: KubusSpacing.sm + KubusSpacing.xs,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: KubusSpacing.sm,
                      offset: const Offset(0, 1),
                      spreadRadius: 0,
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? scheme.onSurface
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: KubusTextStyles.navMetaLabel.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? scheme.onSurface
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMessageSearchChanged() {
    if (!mounted) return;
    final next = _messageSearchController.text;
    if (next == _messageSearchQuery) return;
    _applyState(() {
      _messageSearchQuery = next;
    });
  }

  Widget _buildMessagesPanel(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final conversations = chatProvider.conversations;
        final trimmedQuery = _messageSearchQuery.trim();
        final queryVariants = _buildMessageSearchVariants(_messageSearchQuery);
        final isSearching = queryVariants.isNotEmpty;
        final highlightMap = <String, String>{};
        final filteredConversations = isSearching
            ? _applyMessageSearchFilters(
                conversations, chatProvider, queryVariants, highlightMap)
            : conversations;

        return Column(
          children: [
            // Search and new message
            Padding(
              padding: const EdgeInsets.all(KubusSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(KubusRadius.md),
                          border: Border.all(
                            color: scheme.outline.withValues(alpha: 0.18),
                          ),
                        ),
                        child: LiquidGlassPanel(
                          // Keep the glass background full-bleed; spacing belongs to the input.
                          padding: EdgeInsets.zero,
                          margin: EdgeInsets.zero,
                          borderRadius: BorderRadius.circular(KubusRadius.md),
                          showBorder: false,
                          backgroundColor: scheme.surface.withValues(
                            alpha: isDark ? 0.22 : 0.26,
                          ),
                          child: TextField(
                            controller: _messageSearchController,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              hintText: l10n.desktopCommunitySearchMessagesHint,
                              hintStyle:
                                  KubusTextStyles.screenSubtitle.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.5),
                              ),
                              border: InputBorder.none,
                              prefixIcon: Icon(
                                Icons.search,
                                size: 20,
                                color: scheme.onSurface.withValues(alpha: 0.45),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              suffixIcon: trimmedQuery.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: l10n.commonClear,
                                      icon: const Icon(Icons.close),
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.5),
                                      onPressed: () =>
                                          _messageSearchController.clear(),
                                    ),
                              suffixIconConstraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                            ),
                            style: KubusTextStyles.navLabel.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      onPressed: _startNewConversation,
                      icon: Icon(
                        Icons.edit_square,
                        color: AppColorUtils.tealAccent,
                      ),
                      tooltip: l10n.messagesEmptyStartChatAction,
                    ),
                  ),
                ],
              ),
            ),
            if (isSearching && filteredConversations.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    AppLocalizations.of(context)!
                        .desktopCommunityMessagesSearchResultsLabel(
                      filteredConversations.length,
                      trimmedQuery,
                    ),
                    style: KubusTextStyles.navMetaLabel.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.secondary,
                    ),
                  ),
                ),
              ),
            // Conversations list
            Expanded(
              child: conversations.isEmpty
                  ? _buildEmptyMessagesState(themeProvider)
                  : filteredConversations.isEmpty && isSearching
                      ? _buildNoConversationMatchesState(
                          themeProvider, trimmedQuery)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: filteredConversations.length,
                          itemBuilder: (context, index) {
                            final conversation = filteredConversations[index];
                            return _buildConversationItem(
                              conversation,
                              themeProvider,
                              chatProvider,
                              searchHighlight: highlightMap[conversation.id],
                              showSearchContext: isSearching,
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}
