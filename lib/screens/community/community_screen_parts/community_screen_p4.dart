part of '../community_screen.dart';

// Extracted from community_screen.dart (godfile split). Same library:
// private state access is intact. setState is routed through
// the State's _applyState shim.
extension _CommunityScreenStatePart4 on _CommunityScreenState {
  Widget _buildSearchSuggestionsList({
    required List<Map<String, dynamic>> suggestions,
    required String searchType,
    required ThemeProvider themeProvider,
    required ColorScheme scheme,
    required void Function(Map<String, dynamic>) onSelect,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: suggestions.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              searchType == 'tags'
                  ? AppLocalizations.of(context)!.communityPopularTagsTitle
                  : AppLocalizations.of(context)!.communitySuggestionsTitle,
              style: KubusTypography.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          );
        }
        final suggestion = suggestions[index - 1];
        return _buildSearchResultTile(
          result: suggestion,
          searchType: searchType,
          themeProvider: themeProvider,
          scheme: scheme,
          onTap: () => onSelect(suggestion),
        );
      },
    );
  }

  Widget _buildSearchResultsList({
    required List<Map<String, dynamic>> results,
    required String searchType,
    required ThemeProvider themeProvider,
    required ColorScheme scheme,
    required void Function(Map<String, dynamic>) onSelect,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return _buildSearchResultTile(
          result: result,
          searchType: searchType,
          themeProvider: themeProvider,
          scheme: scheme,
          onTap: () => onSelect(result),
        );
      },
    );
  }

  Widget _buildSearchResultTile({
    required Map<String, dynamic> result,
    required String searchType,
    required ThemeProvider themeProvider,
    required ColorScheme scheme,
    required VoidCallback onTap,
  }) {
    if (searchType == 'tags') {
      final tag = result['tag'] ?? result['name'] ?? '';
      final rawCount = result['count'] ?? result['search_count'] ?? 0;
      final count =
          rawCount is num ? rawCount : num.tryParse(rawCount.toString()) ?? 0;
      final isCustom = result['isCustom'] == true;

      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: themeProvider.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.tag,
            color: themeProvider.accentColor,
            size: 20,
          ),
        ),
        title: Text(
          '#$tag',
          style: KubusTypography.inter(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        subtitle: isCustom
            ? Text(
                AppLocalizations.of(context)!.communitySearchAddNewTag,
                style: KubusTypography.inter(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              )
            : count > 0
                ? Text(
                    AppLocalizations.of(context)!.communitySearchTagUses(count),
                    style: KubusTypography.inter(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  )
                : null,
        trailing: Icon(
          Icons.add_circle_outline,
          size: 20,
          color: scheme.onSurface.withValues(alpha: 0.72),
        ),
        onTap: onTap,
      );
    } else if (searchType == 'profiles') {
      final identity = ProfileIdentityData.fromProfileMap(
        result,
        fallbackLabel: AppLocalizations.of(context)!.commonUnknownArtist,
      );

      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        title: ProfileIdentitySummary(
          identity: identity,
          layout: ProfileIdentityLayout.row,
          avatarRadius: 20,
          allowFabricatedFallback: true,
          onTap: onTap,
          titleStyle: KubusTypography.inter(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          subtitleStyle: KubusTypography.inter(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: Icon(
          Icons.add_circle_outline,
          size: 20,
          color: scheme.onSurface.withValues(alpha: 0.72),
        ),
        onTap: onTap,
      );
    } else if (searchType == 'artworks') {
      final title =
          result['title'] ?? AppLocalizations.of(context)!.commonUntitled;
      final artist = result['artist_name'] ??
          result['artistName'] ??
          AppLocalizations.of(context)!.commonUnknown;
      final image =
          result['image_url'] ?? result['imageUrl'] ?? result['thumbnailUrl'];

      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: themeProvider.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(KubusRadius.sm),
          ),
          child: image != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(KubusRadius.sm),
                  child: Image.network(
                    MediaUrlResolver.resolveDisplayUrl(image.toString()) ??
                        MediaUrlResolver.resolve(image.toString()) ??
                        image.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.image,
                      color: themeProvider.accentColor,
                    ),
                  ),
                )
              : Icon(
                  Icons.view_in_ar,
                  color: themeProvider.accentColor,
                ),
        ),
        title: Text(
          title,
          style: KubusTypography.inter(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          AppLocalizations.of(context)!.commonByArtist(artist.toString()),
          style: KubusTypography.inter(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: Icon(
          Icons.add_circle_outline,
          size: 20,
          color: scheme.onSurface.withValues(alpha: 0.72),
        ),
        onTap: onTap,
      );
    } else if (searchType == 'institutions') {
      final name = result['name'] ??
          result['title'] ??
          AppLocalizations.of(context)!.communitySearchFallbackInstitution;
      final type = result['type'] ?? '';
      final address = result['address'] ?? '';

      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: themeProvider.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.location_city,
            color: themeProvider.accentColor,
            size: 20,
          ),
        ),
        title: Text(
          name.toString(),
          style: KubusTypography.inter(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [type, address]
              .where((e) => e.toString().trim().isNotEmpty)
              .join(' - '),
          style: KubusTypography.inter(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          Icons.chevron_right,
          size: 20,
          color: scheme.onSurface.withValues(alpha: 0.68),
        ),
        onTap: onTap,
      );
    } else if (searchType == 'screens') {
      final name = result['name'] ??
          AppLocalizations.of(context)!.communitySearchFallbackScreen;
      final icon = result['icon'] as IconData? ?? Icons.open_in_new;

      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: themeProvider.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: themeProvider.accentColor, size: 20),
        ),
        title: Text(
          name.toString(),
          style: KubusTypography.inter(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          AppLocalizations.of(context)!.communityOpenScreenSubtitle,
          style: KubusTypography.inter(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      );
    } else if (searchType == 'posts') {
      final content =
          (result['content'] ?? result['text'] ?? result['message'] ?? '')
              .toString();
      final author = (result['authorName'] ??
              result['author_name'] ??
              result['author'] ??
              AppLocalizations.of(context)!.communityComposerCategoryPostLabel)
          .toString();
      final snippet = content.trim().isNotEmpty
          ? content.trim()
          : AppLocalizations.of(context)!.communityViewPostButton;

      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: themeProvider.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.article_outlined,
              color: themeProvider.accentColor, size: 20),
        ),
        title: Text(
          snippet,
          style: KubusTypography.inter(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          author,
          style: KubusTypography.inter(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      );
    }

    // Default tile
    return ListTile(
      title: Text(result.toString()),
      onTap: onTap,
    );
  }

  Future<CommunityGroupSummary?> _showGroupPicker() async {
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    await _ensureGroupsLoaded();
    if (!mounted) return null;
    final joined = hub.groups.where((g) => g.isMember || g.isOwner).toList();
    if (joined.isEmpty) {
      if (!mounted) return null;
      _showSnack(
        AppLocalizations.of(context)!.communityGroupPickerJoinFirstToast,
      );
      return null;
    }
    return showModalBottomSheet<CommunityGroupSummary>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(KubusRadius.xl),
          ),
        ),
        child: CommunityGroupPickerContent(
          title: AppLocalizations.of(context)!.communityGroupPickerTitle,
          groups: joined,
          showHandle: true,
          headerPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          listPadding: const EdgeInsets.symmetric(horizontal: 16),
          subtitleBuilder: (group) => group.description?.isNotEmpty == true
              ? group.description!
              : AppLocalizations.of(context)!.communityGroupNoDescription,
          onSelect: (group) => Navigator.of(ctx).pop(group),
          headerTrailing: const SizedBox.shrink(),
        ),
      ),
    );
  }

  Future<void> _captureDraftLocation(StateSetter setModalState) async {
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    final locationData = await _obtainCurrentLocation();
    if (locationData == null) return;
    final lat = locationData.latitude;
    final lng = locationData.longitude;
    final label = (lat != null && lng != null)
        ? l10n.communityComposerLocationDropLabel(
            lat.toStringAsFixed(3),
            lng.toStringAsFixed(3),
          )
        : l10n.communityComposerCurrentLocationLabel;
    hub.setDraftLocation(
      CommunityLocation(name: label, lat: lat, lng: lng),
      label: label,
    );
    setModalState(() {});
  }

  Future<void> _promptLocationLabelEdit(
    CommunityLocation? location, {
    String? initialLabel,
  }) async {
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    final controller = TextEditingController(text: initialLabel ?? '');
    final l10n = AppLocalizations.of(context)!;
    final result = await showKubusDialog<String>(
      context: context,
      builder: (ctx) => KubusAlertDialog(
        title: Text(l10n.communityNameThisPlaceTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.communityNamePlaceHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    hub.setDraftLocation(location, label: result);
  }

  Future<String?> _ensureWalletForPosting(BuildContext ctx) async {
    try {
      final walletProvider = ctx.read<WalletProvider?>();
      final prefs = await SharedPreferences.getInstance();
      final walletAddress = prefs.getString('wallet') ??
          prefs.getString('wallet_address') ??
          prefs.getString('walletAddress');
      if (walletAddress == null || walletAddress.isEmpty) {
        if (!mounted) return null;
        final l10n = AppLocalizations.of(context)!;
        _showSnack(l10n.communityConnectWalletFirstToast);
        return null;
      }
      final api = BackendApiService();
      await api.restoreExistingSession(allowRefresh: false);
      final currentAuthWallet =
          (api.getCurrentAuthWalletAddress() ?? '').trim();
      final hasMatchingSession = (api.getAuthToken() ?? '').trim().isNotEmpty &&
          WalletUtils.equals(currentAuthWallet, walletAddress);
      if (!hasMatchingSession) {
        final signerReady = walletProvider != null &&
            walletProvider.canTransact &&
            WalletUtils.equals(
              walletProvider.currentWalletAddress,
              walletAddress,
            );
        if (!signerReady ||
            !await walletProvider.ensureBackendSessionForActiveSigner(
              walletAddress: walletAddress,
            )) {
          throw StateError(
            'A ready signer is required to authenticate posting.',
          );
        }
      }
      return walletAddress;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CommunityScreen: wallet auth failed: $e');
      }
      if (!mounted) return null;
      final l10n = AppLocalizations.of(context)!;
      _showSnack(l10n.communityUnableToAuthenticateToast);
      return null;
    }
  }

  Future<List<String>> _uploadComposerMedia() async {
    final mediaUrls = <String>[];
    final api = BackendApiService();
    if (_selectedPostImage != null && _selectedPostImageBytes != null) {
      final fileName = _selectedPostImage!.name;
      final uploadResult = await api.uploadFile(
        fileBytes: _selectedPostImageBytes!,
        fileName: fileName,
        fileType: 'post-image',
      );
      final url = uploadResult['uploadedUrl'] as String?;
      if (url != null) {
        mediaUrls.add(url);
      } else {
        throw Exception('Image upload returned no URL');
      }
    }
    if (_selectedPostVideo != null) {
      final videoFile = File(_selectedPostVideo!.path);
      final uploadResult = await api.uploadFile(
        fileBytes: await videoFile.readAsBytes(),
        fileName: _selectedPostVideo!.name,
        fileType: 'post-video',
      );
      final url = uploadResult['uploadedUrl'] as String?;
      if (url != null) {
        mediaUrls.add(url);
      } else {
        throw Exception('Video upload returned no URL');
      }
    }
    return mediaUrls;
  }

  String _resolveComposerPostType() {
    return communityComposerPostType(
      hasImage: _selectedPostImage != null,
      hasVideo: _selectedPostVideo != null,
    );
  }

  Future<CommunityPost> _submitCommunityPost({
    required CommunityHubProvider hub,
    required String content,
    required List<String> mediaUrls,
  }) async {
    final draft = hub.draft;
    final location = draft.location;
    final locationLabel = draft.locationLabel ?? location?.name;
    final artworkId = draft.artwork?.id;
    final subjectType = draft.subjectType;
    final subjectId = draft.subjectId;
    final postType = _resolveComposerPostType();
    final tags = draft.tags;
    final mentions = draft.mentions;
    final category = draft.category.isNotEmpty ? draft.category : 'post';

    if (draft.targetGroup != null) {
      final created = await hub.submitGroupPost(
        draft.targetGroup!.id,
        content: content,
        mediaUrls: mediaUrls.isEmpty ? null : mediaUrls,
        artworkId: artworkId,
        subjectType: subjectType,
        subjectId: subjectId,
        subjects: draft.subjects,
        postType: postType,
        category: category,
        tags: tags,
        mentions: mentions,
        location: location,
        locationLabel: locationLabel,
      );
      if (created == null) {
        throw Exception('Group post creation failed');
      }
      return created;
    }

    return context.read<CommunityInteractionsProvider>().createCommunityPost(
          content: content,
          mediaUrls: mediaUrls.isEmpty ? null : mediaUrls,
          artworkId: artworkId,
          subjectType: subjectType,
          subjectId: subjectId,
          subjects: draft.subjects,
          postType: postType,
          category: category,
          tags: tags,
          mentions: mentions,
          location: location,
          locationName: locationLabel,
          locationLat: location?.lat,
          locationLng: location?.lng,
          normalizePost: (created) => _mergeDraftSubject(created, draft),
        );
  }

  Future<void> _submitComposer({
    required BuildContext sheetContext,
    required StateSetter setModalState,
    required CommunityHubProvider hub,
  }) async {
    final messenger = ScaffoldMessenger.of(sheetContext);
    final navigator = Navigator.of(sheetContext);
    final l10n = AppLocalizations.of(sheetContext)!;
    final appModeProvider =
        Provider.of<AppModeProvider?>(sheetContext, listen: false);
    var content = _newPostController.text.trim();
    if (content.isEmpty && !_hasSelectedMedia) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.communityComposerAddContentToast)),
      );
      return;
    }

    final walletAddress = await _ensureWalletForPosting(sheetContext);
    if (walletAddress == null) return;
    if (appModeProvider?.isIpfsFallbackMode ?? false) {
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            appModeProvider!.unavailableMessageFor(
              l10n.communityPostingFeatureLabel,
            ),
          ),
        ),
      );
      return;
    }

    setModalState(() => _isPostingNew = true);
    var loadingCleared = false;

    try {
      final mediaUrls = await _uploadComposerMedia();
      if (content.isEmpty) {
        content = _selectedPostVideo != null
            ? '🎥'
            : (_selectedPostImage != null ? '📷' : 'Shared via art.kubus');
      }

      final groupName = hub.draft.targetGroup?.name;
      final isGroupPost = hub.draft.targetGroup != null;

      final createdPost = await _submitCommunityPost(
        hub: hub,
        content: content,
        mediaUrls: mediaUrls,
      );

      setModalState(() => _isPostingNew = false);
      loadingCleared = true;
      if (!mounted) return;

      _handlePostSuccess(createdPost, isGroupPost: isGroupPost);
      navigator.pop();
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            isGroupPost
                ? l10n.communityComposerSharedInGroupToast(
                    groupName ?? l10n.communityGroupFallbackName)
                : l10n.communityComposerPostCreatedToast,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CommunityScreen: create post failed: $e');
      }
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.communityComposerCreatePostFailedToast)),
      );
    } finally {
      if (!loadingCleared) {
        setModalState(() => _isPostingNew = false);
      }
    }
  }

  CommunityPost _mergeDraftSubject(
    CommunityPost createdPost,
    CommunityPostDraft draft,
  ) {
    final createdType = (createdPost.subjectType ?? '').trim();
    final createdId = (createdPost.subjectId ?? '').trim();
    final draftType = (draft.subjectType ?? '').trim();
    final draftId = (draft.subjectId ?? '').trim();
    final draftSubjects = draft.subjects;

    var resolved = createdPost;
    final needsType = createdType.isEmpty;
    final needsId = createdId.isEmpty;
    if ((needsType || needsId) && draftType.isNotEmpty && draftId.isNotEmpty) {
      resolved = resolved.copyWith(
        subjectType: needsType ? draftType : createdType,
        subjectId: needsId ? draftId : createdId,
        subjects:
            createdPost.subjects.isEmpty ? draftSubjects : createdPost.subjects,
        artwork: (draftType == 'artwork' && draft.artwork != null)
            ? draft.artwork
            : resolved.artwork,
      );
    } else if (createdPost.subjects.isEmpty && draftSubjects.isNotEmpty) {
      resolved = resolved.copyWith(subjects: draftSubjects);
    } else if (createdType == 'artwork' &&
        resolved.artwork == null &&
        draft.artwork != null &&
        draft.artwork!.id == createdId) {
      resolved = resolved.copyWith(artwork: draft.artwork);
    }

    return resolved;
  }

  void _handlePostSuccess(CommunityPost createdPost,
      {required bool isGroupPost}) {
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    final subjectProvider =
        Provider.of<CommunitySubjectProvider>(context, listen: false);
    final draft = hub.draft;
    final resolvedPost = _mergeDraftSubject(createdPost, draft);
    final achievementResult = resolvedPost.achievementResult;
    if (achievementResult != null) {
      context.read<TaskProvider>().applyAchievementResult(achievementResult);
      if (achievementResult.unlocked.isNotEmpty) {
        final first = achievementResult.unlocked.first;
        final extra = achievementResult.unlocked.length > 1
            ? ' +${achievementResult.unlocked.length - 1}'
            : '';
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text(
              l10n.communityAchievementUnlockedToast(
                first.title,
                extra,
                first.kub8Reward.round(),
                first.rewardCurrency,
              ),
            ),
            action: SnackBarAction(
              label: l10n.communityViewAchievementsAction,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AchievementsPage(),
                  ),
                );
              },
            ),
          ),
        );
      }
    }
    hub.resetDraft();
    if (!mounted) return;
    subjectProvider.primeFromPosts([resolvedPost]);
    _applyState(() {
      _newPostController.clear();
      _selectedPostImage = null;
      _selectedPostImageBytes = null;
      _selectedPostVideo = null;
      if (!isGroupPost) {
        if (resolvedPost.id.isNotEmpty) {
          _recentlyCreatedPostIds.add(resolvedPost.id);
        }
        final updated = [resolvedPost, ..._communityPosts];
        _communityPosts = updated;
        if (_activeFeed == CommunityFeedType.following) {
          _followingFeedPosts = updated;
        } else {
          _discoverFeedPosts = updated;
        }
      }
    });
  }

  // Interaction methods
  void _toggleLike(int index) async {
    if (index >= _communityPosts.length) {
      return;
    }

    final post = _communityPosts[index];
    final wasLiked = post.isLiked;
    final l10n = AppLocalizations.of(context)!;
    final authenticated = await const ContextualAuthGate().ensureAuthenticated(
      context,
      actionLabel: l10n.commonLikes.toLowerCase(),
      returnRoute: '/p/${Uri.encodeComponent(post.id)}',
    );
    if (!authenticated || !mounted) return;

    try {
      await Provider.of<CommunityInteractionsProvider>(context, listen: false)
          .togglePostLike(post);

      if (!mounted) return;
      // Rebuild UI to reflect the updated post state
      _applyState(() {});

      // Show feedback message
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(!wasLiked
              ? l10n.postDetailPostLikedToast
              : l10n.postDetailLikeRemovedToast),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CommunityScreen: togglePostLike failed: $e');
      }
      // CommunityService performs rollback on error; ensure UI is refreshed
      _applyState(() {});
      if (!mounted) return;

      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.communityToggleLikeFailedToast),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showPostLikes(String postId) {
    final l10n = AppLocalizations.of(context)!;
    _showLikesDialog(
      title: l10n.communityPostLikesTitle,
      loader: () =>
          context.read<CommunityInteractionsProvider>().loadPostLikes(postId),
    );
  }

  void _showLikesDialog(
      {required String title,
      required Future<List<CommunityLikeUser>> Function() loader}) {
    showCommunityLikesSheet(
      context: context,
      title: title,
      loader: loader,
      formatTimeAgo: _getTimeAgo,
      errorMessage: 'Failed to load likes',
      unnamedUserLabel: 'Unnamed User',
      showDetailedError: true,
      allowFabricatedFallback: true,
    );
  }

  void _toggleBookmark(int index) async {
    if (index >= _communityPosts.length) return;

    final post = _communityPosts[index];
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

      _applyState(() {
        _bookmarkedPosts[index] = post.isBookmarked;
      });

      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(
            post.isBookmarked
                ? l10n.communityBookmarkAddedToast
                : l10n.communityBookmarkRemovedToast,
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('CommunityScreen: bookmark toggle failed: $error');
      }
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.communityBookmarkUpdateFailedToast),
          duration: const Duration(seconds: 2),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
