part of '../desktop_community_screen.dart';

// Extracted from desktop_community_screen.dart (godfile split). Same library:
// private state access is intact. setState is routed through
// the State's _applyState shim.
extension _DesktopCommunityScreenStatePart2 on _DesktopCommunityScreenState {
  Widget _buildTagFilters({
    required ThemeProvider themeProvider,
    required String tagValue,
    required bool followingOnly,
    required bool arOnly,
    required String sortMode,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    Widget buildChip({
      required String label,
      required bool active,
      required VoidCallback onTap,
      IconData? icon,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? themeProvider.accentColor.withValues(alpha: 0.12)
                  : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? themeProvider.accentColor.withValues(alpha: 0.5)
                    : scheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      icon,
                      size: 16,
                      color: active
                          ? themeProvider.accentColor
                          : scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                Text(
                  label,
                  style: KubusTextStyles.navMetaLabel.copyWith(
                    fontWeight: FontWeight.w600,
                    color: active
                        ? themeProvider.accentColor
                        : scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Wrap(
        children: [
          buildChip(
            label: l10n.desktopCommunityFilterAllPosts,
            active: !followingOnly,
            onTap: () => _updateTagFeedFilters(tagValue, followingOnly: false),
            icon: Icons.public,
          ),
          buildChip(
            label: l10n.desktopCommunityFilterFollowing,
            active: followingOnly,
            onTap: () => _updateTagFeedFilters(tagValue, followingOnly: true),
            icon: Icons.people_alt,
          ),
          buildChip(
            label: l10n.desktopCommunityFilterArOnly,
            active: arOnly,
            onTap: () => _updateTagFeedFilters(tagValue, arOnly: !arOnly),
            icon: Icons.view_in_ar_outlined,
          ),
          buildChip(
            label: sortMode == 'popularity'
                ? l10n.desktopCommunitySortPopularity
                : l10n.desktopCommunitySortRecent,
            active: true,
            onTap: () => _updateTagFeedFilters(
              tagValue,
              sortMode: sortMode == 'popularity' ? 'recent' : 'popularity',
            ),
            icon: sortMode == 'popularity'
                ? Icons.trending_up
                : Icons.access_time,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final panelStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.panelBackground,
      tintBase: scheme.surface,
    );
    final radius = BorderRadius.circular(KubusRadius.md);
    final icons = <String, IconData>{
      'discover': Icons.explore_outlined,
      'following': Icons.people_alt_outlined,
      'groups': Icons.groups_outlined,
      'art': Icons.palette_outlined,
    };

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.20),
          width: KubusSizes.hairline,
        ),
      ),
      child: LiquidGlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(KubusSpacing.xs),
        borderRadius: radius,
        blurSigma: panelStyle.blurSigma,
        fallbackMinOpacity: panelStyle.fallbackMinOpacity,
        showBorder: false,
        backgroundColor: panelStyle.tintColor,
        child: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabAlignment: TabAlignment.fill,
          labelColor: scheme.onSurface,
          unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.68),
          labelStyle: KubusTypography.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: KubusTypography.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          indicator: BoxDecoration(
            color: themeProvider.accentColor.withValues(
              alpha: themeProvider.isDarkMode ? 0.28 : 0.18,
            ),
            borderRadius: BorderRadius.circular(KubusRadius.sm),
            border: Border.all(
              color: themeProvider.accentColor.withValues(alpha: 0.32),
              width: KubusSizes.hairline,
            ),
            boxShadow: [
              BoxShadow(
                color: themeProvider.accentColor.withValues(alpha: 0.14),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(KubusSpacing.xxs),
          dividerColor: Colors.transparent,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          padding: EdgeInsets.zero,
          labelPadding: EdgeInsets.zero,
          tabs: _tabs
              .map(
                (tab) => Tab(
                  height: 64,
                  iconMargin: const EdgeInsets.only(bottom: KubusSpacing.xxs),
                  icon: Icon(
                    icons[tab] ?? Icons.circle_outlined,
                    size: KubusHeaderMetrics.actionIcon,
                  ),
                  child: Text(
                    _tabLabel(l10n, tab),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildSortControls(ThemeProvider themeProvider) {
    if (_paneStack.isNotEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final currentTab = _tabs[_tabController.index];
    if (currentTab == 'groups') return const SizedBox.shrink();
    final sortMode = _sortModeForTab(currentTab);

    Widget buildChip(String label, String value, IconData icon) {
      final selected = sortMode == value;
      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected
                    ? scheme.onPrimary
                    : scheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
            Text(
              label,
              style: KubusTextStyles.navLabel.copyWith(
                color: selected
                    ? scheme.onPrimary
                    : scheme.onSurface.withValues(alpha: 0.72),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
        selected: selected,
        onSelected: (isSelected) {
          if (isSelected) _changeSortForTab(currentTab, value);
        },
        selectedColor: themeProvider.accentColor,
        backgroundColor: scheme.surfaceContainerHighest,
        labelStyle: KubusTextStyles.navMetaLabel.copyWith(
          color: selected ? scheme.onPrimary : scheme.onSurface,
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.sort,
              size: 18, color: scheme.onSurface.withValues(alpha: 0.65)),
          const SizedBox(width: 8),
          Text(
            l10n.desktopCommunitySortTitle,
            style: KubusTextStyles.sectionSubtitle.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 12),
          buildChip('Hybrid', 'hybrid', Icons.auto_awesome),
          const SizedBox(width: 8),
          buildChip(l10n.desktopCommunitySortRecent, 'recent', Icons.schedule),
          const SizedBox(width: 8),
          buildChip(
              l10n.desktopCommunitySortTop, 'popularity', Icons.trending_up),
        ],
      ),
    );
  }

  String _sortModeForTab(String tabName) {
    switch (tabName) {
      case 'following':
        return _followingSortMode;
      case 'art':
        return _artSortMode;
      default:
        return _discoverSortMode;
    }
  }

  void _changeSortForTab(String tabName, String mode) {
    switch (tabName) {
      case 'following':
        if (_followingSortMode == mode) return;
        _followingSortMode = mode;
        _loadFollowingFeed(sortOverride: mode);
        break;
      case 'art':
        if (_artSortMode == mode) return;
        _applyState(() {
          _artSortMode = mode;
        });
        break;
      default:
        if (_discoverSortMode == mode) return;
        _discoverSortMode = mode;
        _loadDiscoverFeed(sortOverride: mode);
        break;
    }
  }

  List<Map<String, dynamic>> _parseProfileSearchResults(
      Map<String, dynamic> payload) {
    final results = <Map<String, dynamic>>[];

    void addEntries(List<dynamic>? entries) {
      if (entries == null) return;
      for (final item in entries) {
        if (item is Map<String, dynamic>) {
          results.add(item);
        } else if (item is Map) {
          results.add(_toStringKeyedMap(item));
        }
      }
    }

    final dynamic resultsNode = payload['results'];
    if (resultsNode is Map<String, dynamic>) {
      addEntries((resultsNode['profiles'] as List?) ??
          (resultsNode['results'] as List?));
    } else if (resultsNode is List) {
      addEntries(resultsNode);
    }

    final dynamic dataNode = payload['data'];
    if (dataNode is Map<String, dynamic>) {
      addEntries(
          (dataNode['profiles'] as List?) ?? (dataNode['results'] as List?));
    } else if (dataNode is List) {
      addEntries(dataNode);
    }

    if (results.isEmpty) {
      final dynamic profilesRoot = payload['profiles'];
      if (profilesRoot is List) {
        addEntries(profilesRoot);
      }
      if (payload['data'] is Map<String, dynamic>) {
        final dynamic nestedProfiles =
            (payload['data'] as Map<String, dynamic>)['profiles'];
        if (nestedProfiles is List) {
          addEntries(nestedProfiles);
        }
      }
    }

    return results;
  }

  Map<String, dynamic> _toStringKeyedMap(Map<dynamic, dynamic> source) {
    final mapped = <String, dynamic>{};
    source.forEach((key, value) {
      mapped[key.toString()] = value;
    });
    return mapped;
  }

  void _handleSearchSubmit(String value) {
    final results = _communitySearchController.state.results;
    if (value.trim().isEmpty || results.isEmpty) return;
    unawaited(_handleSearchResultTap(results.first));
  }

  Future<void> _handleSearchResultTap(KubusSearchResult result) async {
    _communitySearchController.commitSelection(result.label);
    FocusScope.of(context).unfocus();
    await CommunitySearchActions.handle(
      context,
      result,
      onProfile: (userId) => _openUserProfileModal(userId: userId),
      onArtwork: (artworkId) => openArtwork(
        context,
        artworkId,
        source: 'desktop_community_search',
      ),
      onPost: (postId) async {
        final post = _findPostById(postId);
        if (post != null) {
          _openPostDetail(post);
        } else {
          await PostDetailScreen.openById(context, postId);
        }
      },
      onScreen: (screenKey) => unawaited(
        HomeQuickActionExecutor.execute(
          context,
          screenKey,
          source: HomeQuickActionSurface.desktopHome,
        ),
      ),
      onInstitution: ({
        required String institutionId,
        required String? profileTargetId,
        required Map<String, dynamic> data,
        required String title,
      }) {
        return InstitutionNavigation.open(
          context,
          institutionId: institutionId,
          profileTargetId: profileTargetId,
          data: data,
          title: title,
          openProfileTarget: (resolvedProfileTargetId) =>
              _openUserProfileModal(userId: resolvedProfileTargetId),
        );
      },
    );
  }

  Map<String, dynamic>? _promotionRailItemToSuggestion(
    HomeRailItem item,
  ) {
    if (item.entityType != PromotionEntityType.profile &&
        item.entityType != PromotionEntityType.institution) {
      return null;
    }

    final profileTargetId = item.profileTargetId;
    final institutionId = item.id.trim();
    if (item.entityType == PromotionEntityType.institution &&
        institutionId.isEmpty &&
        (profileTargetId == null || profileTargetId.isEmpty)) {
      return null;
    }
    if (item.entityType == PromotionEntityType.profile &&
        (profileTargetId == null || profileTargetId.isEmpty)) {
      return null;
    }

    final identity = ProfileIdentityData.fromHomeRailItem(
      item,
      fallbackLabel: 'Creator',
    );

    return <String, dynamic>{
      ...item.raw,
      'id': item.entityType == PromotionEntityType.institution
          ? institutionId
          : profileTargetId,
      'entityType': item.entityType.apiValue,
      if (institutionId.isNotEmpty) 'institutionId': institutionId,
      if (profileTargetId != null) 'profileTargetId': profileTargetId,
      'displayName': identity.label,
      'username':
          identity.username ?? item.raw['username'] ?? item.raw['handle'],
      if (profileTargetId != null) 'walletAddress': profileTargetId,
      if (profileTargetId != null) 'wallet': profileTargetId,
      if (identity.avatarUrl != null) 'avatarUrl': identity.avatarUrl,
      if (identity.avatarUrl != null) 'avatar': identity.avatarUrl,
      'verified': item.raw['verified'] ?? false,
    };
  }

  CommunityPost? _findPostById(String postId) {
    for (final post in <CommunityPost>[
      ..._discoverPosts,
      ..._followingPosts,
      ...context.read<CommunityHubProvider>().artFeedPosts,
    ]) {
      if (post.id == postId) {
        return post;
      }
    }
    return null;
  }

  Widget _buildFeedList(String tabName, ThemeProvider themeProvider) {
    // Route to appropriate tab content
    switch (tabName) {
      case 'following':
        return _buildFollowingFeed(themeProvider);
      case 'groups':
        return _buildGroupsTab(themeProvider);
      case 'art':
        return _buildArtFeed(themeProvider);
      default:
        return _buildDiscoverFeed(themeProvider);
    }
  }

  List<CommunityPost> _filterPostsForQuery(List<CommunityPost> posts) {
    final query = _communitySearchController.state.query.trim().toLowerCase();
    if (query.isEmpty) return posts;
    final normalizedTagQuery =
        query.startsWith('#') ? query.substring(1) : query;

    return posts.where((post) {
      final contentMatch = post.content.toLowerCase().contains(query);
      final authorMatch = post.authorName.toLowerCase().contains(query) ||
          (post.authorUsername?.toLowerCase().contains(query) ?? false);
      final tagMatch =
          post.tags.any((t) => t.toLowerCase().contains(normalizedTagQuery));
      final mentionMatch =
          post.mentions.any((m) => m.toLowerCase().contains(query));
      final groupMatch =
          post.group?.name.toLowerCase().contains(query) ?? false;
      return contentMatch ||
          authorMatch ||
          tagMatch ||
          mentionMatch ||
          groupMatch;
    }).toList();
  }

  void _primeSubjectPreviews(List<CommunityPost> posts) {
    try {
      context.read<CommunitySubjectProvider>().primeFromPosts(posts);
    } catch (_) {}
  }

  Widget _buildDiscoverFeed(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final posts =
        _sortPosts(_filterPostsForQuery(_discoverPosts), _discoverSortMode);

    if (_isLoadingDiscover && _discoverPosts.isEmpty) {
      return _buildLoadingState(
          themeProvider, l10n.desktopCommunityLoadingPostsLabel);
    }

    if (_discoverError != null && _discoverPosts.isEmpty) {
      return _buildErrorState(
          themeProvider, _discoverError!, _loadDiscoverFeed);
    }

    if (posts.isEmpty) {
      final hasQuery = _communitySearchController.state.query.trim().isNotEmpty;
      return _buildEmptyState(
        themeProvider,
        Icons.travel_explore,
        !hasQuery
            ? l10n.desktopCommunityEmptyDiscoverTitle
            : l10n.desktopCommunityEmptySearchTitle,
        !hasQuery
            ? l10n.desktopCommunityEmptyDiscoverBody
            : l10n.desktopCommunityEmptySearchBody,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDiscoverFeed,
      color: themeProvider.accentColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        itemCount:
            posts.length + (AppConfig.isFeatureEnabled('season0') ? 1 : 0),
        itemBuilder: (context, index) {
          if (AppConfig.isFeatureEnabled('season0') && index == 0) {
            return _buildSeason0Banner(themeProvider);
          }
          final postIndex =
              AppConfig.isFeatureEnabled('season0') ? index - 1 : index;
          return _buildPostCard(posts[postIndex], themeProvider);
        },
      ),
    );
  }

  Widget _buildSeason0Banner(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return CommunitySeason0Banner(
      title: l10n.season0BannerTitle,
      subtitle: l10n.season0BannerTap,
      accentColor: themeProvider.accentColor,
      variant: CommunitySeason0BannerVariant.desktop,
      onTap: () {
        final shellScope = DesktopShellScope.of(context);
        if (shellScope != null) {
          shellScope.pushScreen(
            DesktopSubScreen(
              title: l10n.season0ScreenTitle,
              child: const Season0Screen(embedded: true),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Season0Screen()),
          );
        }
      },
    );
  }

  Widget _buildFollowingFeed(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final posts =
        _sortPosts(_filterPostsForQuery(_followingPosts), _followingSortMode);

    if (_isLoadingFollowing && _followingPosts.isEmpty) {
      return _buildLoadingState(
          themeProvider, l10n.desktopCommunityLoadingPostsLabel);
    }

    if (_followingError != null && _followingPosts.isEmpty) {
      return _buildErrorState(
          themeProvider, _followingError!, _loadFollowingFeed);
    }

    if (posts.isEmpty) {
      final hasQuery = _communitySearchController.state.query.trim().isNotEmpty;
      return _buildEmptyState(
        themeProvider,
        Icons.people_outline,
        !hasQuery
            ? l10n.desktopCommunityEmptyFollowingTitle
            : l10n.desktopCommunityEmptySearchTitle,
        !hasQuery
            ? l10n.desktopCommunityEmptyFollowingBody
            : l10n.desktopCommunityEmptySearchBody,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFollowingFeed,
      color: themeProvider.accentColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        itemCount: posts.length,
        itemBuilder: (context, index) =>
            _buildPostCard(posts[index], themeProvider),
      ),
    );
  }

  Widget _buildArtFeed(ThemeProvider themeProvider) {
    return Consumer<CommunityHubProvider>(
      builder: (context, communityProvider, _) {
        final l10n = AppLocalizations.of(context)!;
        final allPosts = communityProvider.artFeedPosts;
        final isLoading = communityProvider.artFeedLoading;
        final error = communityProvider.artFeedError;

        if (isLoading && allPosts.isEmpty) {
          return _buildLoadingState(
              themeProvider, l10n.desktopCommunityLoadingNearbyArtLabel);
        }

        if (error != null && allPosts.isEmpty) {
          return _buildErrorState(themeProvider, error, () async {
            await communityProvider.loadArtFeed(
              latitude: 46.05,
              longitude: 14.50,
              radiusKm: 50,
              limit: 50,
              refresh: true,
            );
          });
        }

        if (allPosts.isEmpty) {
          return _buildEmptyState(
            themeProvider,
            Icons.view_in_ar_outlined,
            l10n.desktopCommunityEmptyNearbyArtTitle,
            l10n.desktopCommunityEmptyNearbyArtBody,
          );
        }

        final posts = _sortPosts(_filterPostsForQuery(allPosts), _artSortMode);
        if (posts.isEmpty) {
          return _buildEmptyState(
            themeProvider,
            Icons.search,
            l10n.desktopCommunityEmptySearchTitle,
            l10n.desktopCommunityEmptySearchSubtitle,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await communityProvider.loadArtFeed(
              latitude: 46.05,
              longitude: 14.50,
              radiusKm: 50,
              limit: 50,
              refresh: true,
            );
          },
          color: themeProvider.accentColor,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Infinite scroll: load next page when near the bottom.
              if (notification.metrics.extentAfter < 600 &&
                  communityProvider.artFeedHasMore &&
                  !communityProvider.artFeedLoading) {
                final center = communityProvider.artFeedCenter;
                unawaited(communityProvider.loadArtFeed(
                  latitude: center?.lat ?? 46.05,
                  longitude: center?.lng ?? 14.50,
                  radiusKm: communityProvider.artFeedRadiusKm,
                  limit: communityProvider.artFeedPageSize,
                  refresh: false,
                ));
              }
              return false;
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              itemCount: posts.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            await communityProvider.loadArtFeed(
                              latitude: 46.05,
                              longitude: 14.50,
                              radiusKm: 50,
                              limit: 50,
                              refresh: true,
                            );
                          },
                          icon: const Icon(Icons.my_location),
                          label: Text(
                              l10n.desktopCommunityArtUseCurrentAreaButton),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.accentColor,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(KubusRadius.md)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await communityProvider.loadArtFeed(
                              latitude: 46.05,
                              longitude: 14.50,
                              radiusKm: 200,
                              limit: 100,
                              refresh: true,
                            );
                          },
                          icon: const Icon(Icons.travel_explore),
                          label:
                              Text(l10n.desktopCommunityArtWiderRadiusButton),
                        ),
                      ],
                    ),
                  );
                }
                return _buildPostCard(posts[index - 1], themeProvider);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingActions(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final animationTheme = context.animationTheme;
    final tabIndex = _tabController.index;
    final options = _getFabOptions(tabIndex, l10n: l10n);

    if (options.length > 1) {
      return _buildExpandableFab(
        themeProvider: themeProvider,
        scheme: scheme,
        animationTheme: animationTheme,
        mainIcon: Icons.add,
        mainLabel: l10n.desktopCommunityCreateFabLabel,
        options: options,
      );
    }

    final single = options.first;
    return FloatingActionButton.extended(
      heroTag: 'desktop_comm_fab_$tabIndex',
      onPressed: single.onTap,
      backgroundColor: themeProvider.accentColor,
      foregroundColor: scheme.onPrimary,
      icon: Icon(
        single.icon,
        color: scheme.onPrimary,
      ),
      label: Text(
        single.label,
        style: KubusTextStyles.navLabel.copyWith(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<CommunityFabOption> _getFabOptions(
    int tabIndex, {
    required AppLocalizations l10n,
  }) {
    switch (tabIndex) {
      case 2: // Groups
        return [
          CommunityFabOption(
            icon: Icons.group_add_outlined,
            label: l10n.desktopCommunityCreateOptionCreateGroup,
            onTap: () {
              _applyState(() => _isFabExpanded = false);
              _showCreateGroupDialog(
                  Provider.of<ThemeProvider>(context, listen: false));
            },
          ),
          CommunityFabOption(
            icon: Icons.post_add_outlined,
            label: l10n.desktopCommunityCreateOptionGroupPost,
            onTap: () {
              _applyState(() {
                _isFabExpanded = false;
                _showComposeDialog = true;
              });
            },
          ),
        ];
      case 3: // Art
        return [
          CommunityFabOption(
            icon: Icons.place_outlined,
            label: l10n.desktopCommunityCreateOptionArtDrop,
            onTap: () {
              _applyState(() {
                _isFabExpanded = false;
                _showComposeDialog = true;
              });
              _showARAttachmentInfo();
            },
          ),
          CommunityFabOption(
            icon: Icons.rate_review_outlined,
            label: l10n.desktopCommunityCreateOptionPostReview,
            onTap: () {
              _applyState(() {
                _isFabExpanded = false;
                _showComposeDialog = true;
              });
            },
          ),
        ];
      default:
        return [
          CommunityFabOption(
            icon: Icons.edit_outlined,
            label: l10n.desktopCommunityCreateOptionPost,
            onTap: () {
              _applyState(() {
                _isFabExpanded = false;
                _showComposeDialog = true;
              });
            },
          ),
        ];
    }
  }

  Widget _buildExpandableFab({
    required ThemeProvider themeProvider,
    required ColorScheme scheme,
    required AppAnimationTheme animationTheme,
    required IconData mainIcon,
    required String mainLabel,
    required List<CommunityFabOption> options,
  }) {
    return CommunityExpandableFab(
      isExpanded: _isFabExpanded,
      accentColor: themeProvider.accentColor,
      scheme: scheme,
      animationTheme: animationTheme,
      mainIcon: mainIcon,
      mainLabel: mainLabel,
      closeLabel:
          AppLocalizations.of(context)!.desktopCommunityCreateFabCloseLabel,
      mainHeroTag: 'desktop_comm_fab_main',
      optionHeroTagPrefix: 'desktop_comm_fab_option_',
      options: options,
      variant: CommunityExpandableFabVariant.desktop,
      onExpandedChanged: (expanded) {
        _applyState(() => _isFabExpanded = expanded);
      },
    );
  }

  Widget _buildGroupsTab(ThemeProvider themeProvider) {
    return Consumer<CommunityHubProvider>(
      builder: (context, communityProvider, _) {
        final l10n = AppLocalizations.of(context)!;
        final currentQuery = communityProvider.currentGroupSearchQuery;
        if (_groupSearchController.text != currentQuery) {
          _groupSearchController.value = TextEditingValue(
            text: currentQuery,
            selection: TextSelection.collapsed(offset: currentQuery.length),
          );
        }
        final groups = communityProvider.groups;
        final isLoading = communityProvider.groupsLoading;
        final error = communityProvider.groupsError;

        if (isLoading && groups.isEmpty) {
          return _buildLoadingState(
              themeProvider, l10n.desktopCommunityLoadingGroupsLabel);
        }

        if (error != null && groups.isEmpty) {
          return _buildErrorState(themeProvider, error, () async {
            await communityProvider.loadGroups(refresh: true);
          });
        }

        if (groups.isEmpty) {
          return _buildEmptyState(
            themeProvider,
            Icons.groups_outlined,
            l10n.desktopCommunityEmptyGroupsTitle,
            l10n.desktopCommunityEmptyGroupsBody,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await communityProvider.loadGroups(
                refresh: true, search: _groupSearchController.text);
          },
          color: themeProvider.accentColor,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: groups.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: DesktopSearchBar(
                          controller: _groupSearchController,
                          hintText: l10n.desktopCommunityGroupsSearchHint,
                          onChanged: (value) {
                            _groupSearchDebounce?.cancel();
                            _groupSearchDebounce =
                                Timer(const Duration(milliseconds: 300), () {
                              communityProvider.loadGroups(
                                refresh: true,
                                search: value.trim(),
                              );
                            });
                          },
                          onSubmitted: (value) {
                            _groupSearchDebounce?.cancel();
                            communityProvider.loadGroups(
                              refresh: true,
                              search: value.trim(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showCreateGroupDialog(themeProvider),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.commonCreate),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeProvider.accentColor,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(KubusRadius.md)),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return _buildGroupCard(groups[index - 1], themeProvider);
            },
          ),
        );
      },
    );
  }

  Future<void> _showCreateGroupDialog(ThemeProvider themeProvider) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final communityProvider =
        Provider.of<CommunityHubProvider>(context, listen: false);

    await showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KubusRadius.lg),
        ),
        title: Text(
          l10n.desktopCommunityCreateOptionCreateGroup,
          style: KubusTextStyles.sectionTitle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n.desktopCommunityCreateGroupNameLabel,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: l10n.desktopCommunityCreateGroupDescriptionLabel,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final navigator = Navigator.of(context);
              await communityProvider.createGroup(
                  name: name, description: descController.text.trim());
              if (!navigator.mounted) return;
              navigator.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.accentColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: Text(AppLocalizations.of(context)!.commonCreate),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(
      CommunityGroupSummary group, ThemeProvider themeProvider) {
    return CommunityGroupCard(
      group: group,
      accentColor: themeProvider.accentColor,
      variant: CommunityGroupCardVariant.desktop,
      onOpenGroupFeed: () {
        final shellScope = DesktopShellScope.of(context);
        if (shellScope != null) {
          shellScope.pushScreen(
            DesktopSubScreen(
              title: group.name,
              child: GroupFeedScreen(group: group, embedded: true),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupFeedScreen(group: group),
            ),
          );
        }
      },
      timeAgoBuilder: (dateTime) => _formatTimeAgo(dateTime),
    );
  }

  String _formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays >= 365) {
      return l10n.commonTimeAgoYears((difference.inDays / 365).floor());
    }
    if (difference.inDays >= 30) {
      return l10n.commonTimeAgoMonths((difference.inDays / 30).floor());
    }
    if (difference.inDays >= 7) {
      return l10n.commonTimeAgoWeeks((difference.inDays / 7).floor());
    }
    if (difference.inDays > 0) {
      return l10n.commonTimeAgoDays(difference.inDays);
    }
    if (difference.inHours > 0) {
      return l10n.commonTimeAgoHours(difference.inHours);
    }
    if (difference.inMinutes > 0) {
      return l10n.commonTimeAgoMinutes(difference.inMinutes);
    }
    return l10n.commonTimeAgoJustNow;
  }

  Widget _buildLoadingState(ThemeProvider themeProvider, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: InlineLoading(tileSize: 4, color: themeProvider.accentColor),
          ),
          const SizedBox(height: KubusSpacing.lg - KubusSpacing.xs),
          Text(
            message,
            style: KubusTextStyles.sectionSubtitle.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
      ThemeProvider themeProvider, String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KubusRadius.xl),
            ),
            child: Icon(
              Icons.error_outline,
              size: 36,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.commonFailedToLoadLabel,
            style: KubusTextStyles.sectionTitle.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              error,
              style: KubusTextStyles.sectionSubtitle.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) => ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.commonRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.accentColor,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider themeProvider, IconData icon,
      String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: themeProvider.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KubusRadius.xl),
            ),
            child: Icon(
              icon,
              size: 36,
              color: themeProvider.accentColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: KubusSpacing.lg),
          Text(
            title,
            style: KubusTextStyles.sectionTitle.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              style: KubusTextStyles.sectionSubtitle.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
