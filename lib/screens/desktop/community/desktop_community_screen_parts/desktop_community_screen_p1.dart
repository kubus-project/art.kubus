part of '../desktop_community_screen.dart';

// Extracted from desktop_community_screen.dart (godfile split). Same library:
// private state access is intact. setState is routed through
// the State's _applyState shim.
extension _DesktopCommunityScreenStatePart1 on _DesktopCommunityScreenState {
  String _tabLabel(AppLocalizations l10n, String tabKey) {
    switch (tabKey) {
      case 'discover':
        return l10n.desktopCommunityTabDiscover;
      case 'following':
        return l10n.desktopCommunityTabFollowing;
      case 'groups':
        return l10n.desktopCommunityTabGroups;
      case 'art':
        return l10n.desktopCommunityTabArt;
      default:
        return tabKey;
    }
  }

  void _startInitialCommunityLoad() {
    unawaited(() async {
      await _loadFeed();
      if (!mounted) return;
      _schedulePostFeedStartupWork();
    }());
  }

  void _schedulePostFeedStartupWork() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(Future<void>.delayed(
        const Duration(milliseconds: 250),
        () async {
          if (!mounted) return;
          if (kDebugMode) {
            debugPrint('DesktopCommunityScreen: post-feed startup work');
          }
          await _loadSidebarData();
          if (!mounted) return;
          unawaited(_syncFollowingWallets());
        },
      ));
    });
  }

  void _handleSearchControllerChanged() {
    if (!mounted) return;
    _applyState(() {});
  }

  void _onAppRefreshTriggered() {
    if (!mounted || _appRefreshProvider == null) return;
    final communityVersion = _appRefreshProvider!.communityVersion;
    final globalVersion = _appRefreshProvider!.globalVersion;
    if (communityVersion == _lastCommunityRefreshVersion &&
        globalVersion == _lastGlobalRefreshVersion) {
      return;
    }
    _lastCommunityRefreshVersion = communityVersion;
    _lastGlobalRefreshVersion = globalVersion;

    if (_refreshInFlight) return;
    _refreshInFlight = true;
    unawaited(() async {
      try {
        await _loadFeed();
        await _syncFollowingWallets();
      } finally {
        _refreshInFlight = false;
      }
    }());
  }

  Future<void> _syncFollowingWallets() async {
    try {
      final wallets = await UserService.getFollowingUsers();
      if (!mounted) return;
      _applyState(() {
        _followingWallets = wallets
            .map(WalletUtils.canonical)
            .where((w) => w.isNotEmpty)
            .toSet();
      });
    } catch (_) {}
  }

  Future<void> _toggleSuggestedFollow({
    required String walletAddress,
    required String displayName,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final profileProvider = context.read<ProfileProvider>();
    if (!profileProvider.isSignedIn) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.userProfileSignInToFollowToast),
          action: SnackBarAction(
            label: l10n.commonSignIn,
            onPressed: () => Navigator.of(context).pushNamed('/sign-in'),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final wallet = WalletUtils.canonical(walletAddress);
    if (wallet.isEmpty) return;
    if (_followRequestsInFlight.contains(wallet)) return;

    final wasFollowing = _followingWallets.contains(wallet);
    final shouldFollow = !wasFollowing;

    _applyState(() {
      _followRequestsInFlight.add(wallet);
      if (shouldFollow) {
        _followingWallets.add(wallet);
      } else {
        _followingWallets.remove(wallet);
      }
    });

    // Optimistically persist local follow state so it survives reloads.
    try {
      if (shouldFollow) {
        await UserService.followUser(wallet);
      } else {
        await UserService.unfollowUser(wallet);
      }
    } catch (_) {}

    final backend = BackendApiService();
    try {
      if (shouldFollow) {
        await backend.followUser(wallet);
      } else {
        await backend.unfollowUser(wallet);
      }

      if (!mounted) return;
      _applyState(() => _followRequestsInFlight.remove(wallet));
      _appRefreshProvider?.triggerCommunity();
      _appRefreshProvider?.triggerProfile();

      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(
            shouldFollow
                ? l10n.userProfileNowFollowingToast(displayName)
                : l10n.userProfileUnfollowedToast(displayName),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      // Roll back optimistic state on failure.
      try {
        if (shouldFollow) {
          await UserService.unfollowUser(wallet);
        } else {
          await UserService.followUser(wallet);
        }
      } catch (_) {}

      if (!mounted) return;
      _applyState(() {
        _followRequestsInFlight.remove(wallet);
        if (shouldFollow) {
          _followingWallets.remove(wallet);
        } else {
          _followingWallets.add(wallet);
        }
      });

      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.userProfileFollowUpdateFailedToast),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _loadFeed() async {
    await _loadActiveFeed();

    // Trending topics are loaded in parallel with the feeds. When the trending
    // request finishes before the feed data is available, we end up with
    // "0 tagged posts" because the backend trending endpoint does not include
    // community tag counts. Once feeds are loaded, enrich (or seed) trending
    // counts from the local posts so the desktop sidebar stays informative.
    if (!mounted) return;
    _enrichTrendingTopicsFromFeedCounts();
  }

  Future<void> _loadActiveFeed() async {
    final currentTab = _tabs[_tabController.index];
    switch (currentTab) {
      case 'following':
        await _loadFollowingFeed();
        break;
      case 'groups':
        final communityProvider = context.read<CommunityHubProvider>();
        if (!communityProvider.groupsInitialized) {
          await communityProvider.loadGroups();
        }
        break;
      case 'art':
        await _loadArtFeed();
        break;
      case 'discover':
      default:
        await _loadDiscoverFeed();
        break;
    }
  }

  void _ensureActiveTabLoaded() {
    final currentTab = _tabs[_tabController.index];
    switch (currentTab) {
      case 'following':
        if (!_followingFeedLoaded && !_isLoadingFollowing) {
          unawaited(_loadFollowingFeed());
        }
        break;
      case 'groups':
        final communityProvider = context.read<CommunityHubProvider>();
        if (!communityProvider.groupsInitialized &&
            !communityProvider.groupsLoading) {
          unawaited(communityProvider.loadGroups());
        }
        break;
      case 'art':
        final communityProvider = context.read<CommunityHubProvider>();
        if (communityProvider.artFeedPosts.isEmpty &&
            !communityProvider.artFeedLoading) {
          unawaited(_loadArtFeed());
        }
        break;
      case 'discover':
      default:
        if (!_discoverFeedLoaded && !_isLoadingDiscover) {
          unawaited(_loadDiscoverFeed());
        }
        break;
    }
  }

  Future<void> _loadArtFeed() {
    return context.read<CommunityHubProvider>().loadArtFeed(
          latitude: 46.05,
          longitude: 14.50,
          radiusKm: 50,
          limit: 24,
          refresh: true,
          sort: _artSortMode,
        );
  }

  void _enrichTrendingTopicsFromFeedCounts() {
    if (!mounted) return;
    final fallback = _buildFallbackTrendingTopics();
    if (fallback.isEmpty) return;

    // If trending wasn't loaded yet (or failed), seed from feed-derived counts.
    if (_trendingTopics.isEmpty) {
      _applyState(() {
        _trendingTopics = fallback.length > 12
            ? fallback.sublist(0, 12)
            : List<Map<String, dynamic>>.from(fallback);
        _trendingFromFeed = true;
      });
      return;
    }

    final fallbackCounts = <String, int>{
      for (final item in fallback)
        (item['tag'] as String).toLowerCase(): (item['count'] as int),
    };

    var changed = false;
    final updated = <Map<String, dynamic>>[];
    for (final entry in _trendingTopics) {
      final rawTag = entry['tag'];
      final normalizedTag = _sanitizeTagValue(rawTag)?.toLowerCase();
      if (normalizedTag == null) {
        updated.add(Map<String, dynamic>.from(entry));
        continue;
      }

      final currentValue = entry['count'];
      final currentCount = currentValue is num
          ? currentValue
          : num.tryParse(currentValue?.toString() ?? '') ?? 0;

      if (currentCount == 0 && fallbackCounts.containsKey(normalizedTag)) {
        updated.add({
          ...entry,
          'tag': _sanitizeTagValue(rawTag) ?? rawTag,
          'count': fallbackCounts[normalizedTag]!,
        });
        changed = true;
      } else {
        // Ensure count is consistently numeric.
        updated.add({
          ...entry,
          'tag': _sanitizeTagValue(rawTag) ?? rawTag,
          'count': currentCount,
        });
      }
    }

    if (!changed) return;
    _applyState(() {
      _trendingTopics = updated;
      _trendingFromFeed = true;
    });
  }

  Future<List<CommunityPost>> _filterBlockedPosts(
      List<CommunityPost> posts) async {
    final blocked = await BlockListService().loadBlockedWallets();
    if (blocked.isEmpty) return posts;
    return posts.where((post) {
      final author = WalletUtils.canonical(post.authorWallet);
      if (author.isEmpty) return true;
      return !blocked.contains(author);
    }).toList();
  }

  Future<void> _loadDiscoverFeed({String? sortOverride}) async {
    if (_isLoadingDiscover) return;
    final sort = sortOverride ?? _discoverSortMode;
    if (sortOverride != null) {
      _discoverSortMode = sortOverride;
    }
    _applyState(() {
      _isLoadingDiscover = true;
      _discoverError = null;
    });
    try {
      if (kDebugMode) {
        debugPrint(
            'DesktopCommunityScreen: active feed fetch discover limit=24');
      }
      final posts = await BackendApiService().getCommunityPosts(
        page: 1,
        limit: 24,
        followingOnly: false,
        surface: 'discover',
        sort: sort,
      );
      final filtered = await _filterBlockedPosts(posts);
      if (mounted) {
        _primeSubjectPreviews(filtered);
        context
            .read<CommunityInteractionsProvider>()
            .hydratePostsFromServer(filtered);
      }
      if (mounted) {
        _applyState(() {
          _discoverPosts = filtered;
          _discoverFeedLoaded = true;
          _isLoadingDiscover = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _applyState(() {
          _discoverError = e.toString();
          _discoverFeedLoaded = true;
          _isLoadingDiscover = false;
        });
      }
    }
  }

  Future<void> _loadSidebarData() async {
    if (kDebugMode) {
      debugPrint('DesktopCommunityScreen: sidebar/suggestions fetch');
    }
    await Future.wait([
      _loadTrendingTopics(),
      _loadSuggestions(),
    ]);
  }

  Future<void> _loadTrendingTopics() async {
    if (!mounted) return;
    _applyState(() {
      _isLoadingTrending = true;
      _trendingError = null;
    });
    try {
      final backend = BackendApiService();
      // Prefer real community tag counts from the community API.
      // This endpoint returns { tag, count }.
      final tagResults = await backend.getTrendingCommunityTags(
        limit: 24,
        timeframeDays: 30,
      );

      // Fallback to the search trending endpoint only if the community tag
      // endpoint is empty/unavailable.
      final searchResults = tagResults.isEmpty
          ? await backend.getTrendingSearches(limit: 24)
          : const <Map<String, dynamic>>[];

      var normalized = _normalizeTrendingTopics(
          tagResults.isNotEmpty ? tagResults : searchResults);
      var usedFallback = false;
      final fallback = _buildFallbackTrendingTopics();
      final fallbackCounts = {
        for (final item in fallback)
          (item['tag'] as String).toLowerCase(): item['count'] as int
      };

      if (normalized.isEmpty && fallback.isNotEmpty) {
        normalized = List<Map<String, dynamic>>.from(fallback);
        usedFallback = true;
      } else if (normalized.length < 6 && fallback.isNotEmpty) {
        final seen = normalized
            .map((entry) => entry['tag']?.toString().toLowerCase())
            .whereType<String>()
            .toSet();
        for (final entry in fallback) {
          final key = entry['tag']?.toString().toLowerCase();
          if (key == null || seen.contains(key)) continue;
          normalized.add(entry);
          seen.add(key);
          usedFallback = true;
          if (normalized.length >= 12) break;
        }
      }

      // If backend provided tags but without counts, enrich from fallback map
      for (final entry in normalized) {
        final tag = entry['tag']?.toString().toLowerCase();
        if (tag == null) continue;
        final count = (entry['count'] ?? 0) as num;
        if (count == 0 && fallbackCounts.containsKey(tag)) {
          entry['count'] = fallbackCounts[tag]!;
        }
      }

      if (normalized.length > 12) {
        normalized = normalized.sublist(0, 12);
      }
      if (mounted) {
        _applyState(() {
          _trendingTopics = normalized;
          _isLoadingTrending = false;
          _trendingFromFeed = usedFallback;
        });
      }
    } catch (e) {
      if (mounted) {
        _applyState(() {
          _trendingError = e.toString();
          _isLoadingTrending = false;
          _trendingFromFeed = false;
        });
      }
    }
  }

  Future<void> _loadSuggestions() async {
    if (!mounted) return;
    final locale = Localizations.localeOf(context).languageCode;
    _applyState(() {
      _isLoadingSuggestions = true;
      _suggestionsError = null;
    });
    try {
      final backend = BackendApiService();
      final aggregated = <Map<String, dynamic>>[];

      try {
        final featured = await backend.getPublicHomeRails(locale: locale);
        final suggestionItems = featured.rails
            .where((rail) =>
                rail.entityType == PromotionEntityType.profile ||
                rail.entityType == PromotionEntityType.institution)
            .expand((rail) => rail.items)
            .toList(growable: false);
        aggregated.addAll(
          suggestionItems
              .map(_promotionRailItemToSuggestion)
              .whereType<Map<String, dynamic>>(),
        );
      } catch (e) {
        debugPrint('Featured artists fetch failed: $e');
      }

      if (aggregated.length < 8) {
        try {
          final general = await backend.listArtists(limit: 20, offset: 0);
          aggregated.addAll(general);
        } catch (e) {
          debugPrint('General artists fetch failed: $e');
        }
      }

      if (aggregated.length < 8) {
        try {
          final response =
              await backend.search(query: 'art', type: 'profiles', limit: 20);
          aggregated.addAll(_parseProfileSearchResults(response));
        } catch (e) {
          debugPrint('Profile search fallback failed: $e');
        }
      }

      final artists = _dedupeSuggestedProfiles(aggregated, take: 8);
      if (mounted) {
        _applyState(() {
          _suggestedArtists = artists;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _applyState(() {
          _suggestionsError = e.toString();
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  Future<void> _loadFollowingFeed({String? sortOverride}) async {
    if (_isLoadingFollowing) return;
    final sort = sortOverride ?? _followingSortMode;
    if (sortOverride != null) {
      _followingSortMode = sortOverride;
    }
    _applyState(() {
      _isLoadingFollowing = true;
      _followingError = null;
    });
    try {
      if (kDebugMode) {
        debugPrint(
            'DesktopCommunityScreen: active feed fetch following limit=24');
      }
      final posts = await BackendApiService().getCommunityPosts(
        page: 1,
        limit: 24,
        followingOnly: true,
        surface: 'following',
        sort: sort,
      );
      final filtered = await _filterBlockedPosts(posts);
      if (mounted) {
        _primeSubjectPreviews(filtered);
        context
            .read<CommunityInteractionsProvider>()
            .hydratePostsFromServer(filtered);
      }
      if (mounted) {
        _applyState(() {
          _followingPosts = filtered;
          _followingFeedLoaded = true;
          _isLoadingFollowing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _applyState(() {
          _followingError = e.toString();
          _followingFeedLoaded = true;
          _isLoadingFollowing = false;
        });
      }
    }
  }

  Widget _buildMainFeed(
      ThemeProvider themeProvider, AppAnimationTheme animationTheme) {
    final bool hasPane = _paneStack.isNotEmpty;
    final _PaneRoute? activePane = hasPane ? _paneStack.last : null;
    final Widget homePane = _buildHomeContent(themeProvider);
    final Widget overlayPane = hasPane
        ? _buildPaneView(activePane!, themeProvider)
        : const SizedBox.shrink(key: ValueKey('community-pane-empty'));

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animationController,
        curve: animationTheme.fadeCurve,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: hasPane,
            child: homePane,
          ),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: animationTheme.medium,
              switchInCurve: animationTheme.emphasisCurve,
              switchOutCurve: animationTheme.fadeCurve,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: StackFit.expand,
                children: [
                  ...previousChildren
                      .map((child) => Positioned.fill(child: child)),
                  if (currentChild != null)
                    Positioned.fill(child: currentChild),
                ],
              ),
              child: overlayPane,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(ThemeProvider themeProvider) {
    return Stack(
      key: const ValueKey('community-home-pane'),
      children: [
        NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildHeader(themeProvider),
                    _buildSortControls(themeProvider),
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children:
                _tabs.map((tab) => _buildFeedList(tab, themeProvider)).toList(),
          ),
        ),

        // Floating actions
        Positioned(
          bottom: KubusSpacing.lg,
          right: KubusSpacing.lg,
          child: _buildFloatingActions(themeProvider),
        ),
      ],
    );
  }

  Widget _buildPaneView(_PaneRoute route, ThemeProvider themeProvider) {
    Widget child;
    switch (route.type) {
      case _PaneViewType.tagFeed:
        final tag = route.tag ?? '';
        child = _buildTagFeedPane(tag, themeProvider);
        break;
      case _PaneViewType.postDetail:
        final post = route.post;
        child = post == null
            ? const SizedBox.shrink()
            : _buildPostDetailPane(
                post,
                themeProvider: themeProvider,
                initialAction: route.initialAction,
              );
        break;
      case _PaneViewType.conversation:
        final conversation = route.conversation;
        child = conversation == null
            ? const SizedBox.shrink()
            : _buildConversationPane(conversation, themeProvider);
        break;
    }
    return KeyedSubtree(
      key: ValueKey(route.viewKey),
      child: child,
    );
  }

  void _popPane() {
    if (_paneStack.isEmpty) return;
    _applyState(() {
      final removed = _paneStack.removeLast();
      if (removed.type == _PaneViewType.conversation) {
        _activeConversationId = null;
      }
    });
  }

  Color _paneBackdropColor(ThemeProvider themeProvider) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final tintedSurface = Color.lerp(
          scheme.surface,
          themeProvider.accentColor,
          isDark ? 0.05 : 0.025,
        ) ??
        scheme.surface;
    return tintedSurface.withValues(alpha: isDark ? 0.96 : 0.92);
  }

  Widget _buildTagFeedPane(String tag, ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final sanitized = _sanitizeTagValue(tag);
    if (sanitized == null) {
      return Container(
        key: const ValueKey('tag-pane-invalid'),
        color: _paneBackdropColor(themeProvider),
        child: Column(
          children: [
            _buildTagFeedHeader(
              displayTag: '#$tag',
              tagValue: tag,
              themeProvider: themeProvider,
              isLoading: false,
              tagCount: null,
            ),
            Expanded(
              child: _buildScrollablePlaceholder(
                _buildEmptyState(
                  themeProvider,
                  Icons.local_offer_outlined,
                  l10n.desktopCommunityTagUnavailableTitle,
                  l10n.desktopCommunityTagUnavailableBody,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final tagKey = sanitized.toLowerCase();
    final tagState = _tagFeeds[tagKey] ?? const _TagFeedState();
    final posts = tagState.posts;
    final isLoading = tagState.isLoading;
    final error = tagState.error;
    final sortMode = tagState.sortMode;
    final followingOnly = tagState.followingOnly;
    final arOnly = tagState.arOnly;
    final Map<String, dynamic> trendEntry = _trendingTopics.firstWhere(
      (topic) => (topic['tag'] ?? '').toString().toLowerCase() == tagKey,
      orElse: () => <String, dynamic>{},
    );
    num? taggedCount;
    final rawCount = trendEntry['count'] ??
        trendEntry['post_count'] ??
        trendEntry['search_count'] ??
        trendEntry['frequency'];
    if (rawCount is num) {
      taggedCount = rawCount;
    } else if (rawCount != null) {
      taggedCount = num.tryParse(rawCount.toString());
    }

    if (!isLoading && posts.isEmpty && error == null) {
      Future.microtask(() => _loadTagFeed(sanitized));
    }

    Widget buildBody() {
      if (isLoading && posts.isEmpty) {
        return _buildScrollablePlaceholder(
          _buildLoadingState(
            themeProvider,
            l10n.desktopCommunityTagFeedLoadingPostsLabel(sanitized),
          ),
        );
      }
      if (error != null && posts.isEmpty) {
        return _buildScrollablePlaceholder(
          _buildErrorState(
            themeProvider,
            error,
            () => _loadTagFeed(sanitized, forceRefresh: true),
          ),
        );
      }
      if (posts.isEmpty) {
        return _buildScrollablePlaceholder(
          _buildEmptyState(
            themeProvider,
            Icons.local_offer_outlined,
            l10n.desktopCommunityTagFeedEmptyTitle(sanitized),
            l10n.desktopCommunityTagFeedEmptyBody(sanitized),
          ),
        );
      }

      return ListView.separated(
        key: ValueKey('tag-feed-$tagKey'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        itemCount: posts.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.desktopCommunityTagFeedTopPostsTitle(sanitized),
                  style: KubusTextStyles.sectionTitle
                      .copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.desktopCommunityTagFeedSortedByPopularityDescription,
                  style: KubusTextStyles.sectionSubtitle.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                if (taggedCount != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.desktopCommunityTagFeedTaggedPostsAcrossCommunityLabel(
                      taggedCount.toInt(),
                    ),
                    style: KubusTextStyles.navMetaLabel.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ],
            );
          }
          final post = posts[index - 1];
          final rank = index;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: themeProvider.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(KubusRadius.md),
                    ),
                    child: Text(
                      '#$rank',
                      style: KubusTextStyles.compactBadge.copyWith(
                        color: themeProvider.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.desktopCommunityPopularForTagTitle(sanitized),
                    style: KubusTextStyles.navMetaLabel.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildPostCard(post, themeProvider),
            ],
          );
        },
      );
    }

    return Container(
      key: ValueKey('tag-pane-$tagKey'),
      color: _paneBackdropColor(themeProvider),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTagFeedHeader(
            displayTag: '#$sanitized',
            tagValue: sanitized,
            themeProvider: themeProvider,
            isLoading: isLoading,
            tagCount: taggedCount,
            sortMode: sortMode,
            followingOnly: followingOnly,
            arOnly: arOnly,
          ),
          _buildTagFilters(
            themeProvider: themeProvider,
            tagValue: sanitized,
            followingOnly: followingOnly,
            arOnly: arOnly,
            sortMode: sortMode,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadTagFeed(sanitized, forceRefresh: true),
              color: themeProvider.accentColor,
              child: buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagFeedHeader({
    required String displayTag,
    required String tagValue,
    required ThemeProvider themeProvider,
    required bool isLoading,
    num? tagCount,
    String sortMode = 'popularity',
    bool followingOnly = false,
    bool arOnly = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isPopularity = sortMode == 'popularity';
    final sortLabel = isPopularity
        ? l10n.desktopCommunitySortPopularity
        : l10n.desktopCommunitySortRecent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          IconButton(
            tooltip:
                AppLocalizations.of(context)!.desktopCommunityBackToFeedTooltip,
            onPressed: _popPane,
            icon: Icon(
              Icons.arrow_back,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTag,
                  style: KubusTextStyles.sectionTitle.copyWith(
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      sortLabel,
                      style: KubusTextStyles.navMetaLabel.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (tagCount != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.circle,
                          size: 4,
                          color: scheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                      Text(
                        l10n.desktopCommunityTaggedPostsLabel(
                            tagCount.toInt().toString()),
                        style: KubusTextStyles.navMetaLabel.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isPopularity
                ? l10n.desktopCommunitySortedByPopularityTooltip
                : l10n.desktopCommunitySortedByRecentTooltip,
            onPressed: isLoading
                ? null
                : () => _updateTagFeedFilters(
                      tagValue,
                      sortMode:
                          sortMode == 'popularity' ? 'recent' : 'popularity',
                    ),
            icon: Icon(
              sortMode == 'popularity' ? Icons.bar_chart : Icons.schedule,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          IconButton(
            tooltip: isLoading ? l10n.commonLoading : l10n.commonRefresh,
            onPressed: isLoading
                ? null
                : () => _loadTagFeed(tagValue, forceRefresh: true),
            icon: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: InlineLoading(tileSize: 4, color: themeProvider.accentColor),
                  )
                : Icon(
                    Icons.refresh,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollablePlaceholder(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [child],
    );
  }

  Widget _buildPostDetailPane(
    CommunityPost post, {
    required ThemeProvider themeProvider,
    PostDetailInitialAction? initialAction,
  }) {
    return Container(
      key: ValueKey('post-pane-${post.id}'),
      color: _paneBackdropColor(themeProvider),
      child: PostDetailScreen(
        post: post,
        initialAction: initialAction,
        onClose: _popPane,
      ),
    );
  }

  Widget _buildConversationPane(
    Conversation conversation,
    ThemeProvider themeProvider,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Full-height, full-width conversation panel
    return Container(
      key: ValueKey('conversation-pane-${conversation.id}'),
      color: scheme.surface,
      child: ConversationScreen(
        conversation: conversation,
        onClose: _popPane,
      ),
    );
  }

  Future<void> _openTagFeed(String rawTag) async {
    final sanitized = _sanitizeTagValue(rawTag);
    if (sanitized == null) return;
    final tagKey = sanitized.toLowerCase();
    _applyState(() {
      _paneStack.removeWhere(
        (route) =>
            route.type == _PaneViewType.tagFeed &&
            (route.tag?.toLowerCase() == tagKey),
      );
      _paneStack.add(_PaneRoute.tag(sanitized));
      _activeConversationId = null;
    });
    await _loadTagFeed(sanitized);
  }

  Future<void> _updateTagFeedFilters(
    String tag, {
    bool? followingOnly,
    bool? arOnly,
    String? sortMode,
  }) async {
    final sanitized = _sanitizeTagValue(tag);
    if (sanitized == null) return;
    final key = sanitized.toLowerCase();
    final previous = _tagFeeds[key] ?? const _TagFeedState();
    final nextState = previous.copyWith(
      followingOnly: followingOnly ?? previous.followingOnly,
      arOnly: arOnly ?? previous.arOnly,
      sortMode: sortMode ?? previous.sortMode,
    );
    _applyState(() {
      _tagFeeds[key] = nextState;
    });
    await _loadTagFeed(sanitized, forceRefresh: true);
  }

  Future<void> _loadTagFeed(String tag, {bool forceRefresh = false}) async {
    final sanitized = _sanitizeTagValue(tag);
    if (sanitized == null) return;
    final key = sanitized.toLowerCase();
    final previous = _tagFeeds[key] ?? const _TagFeedState();
    final sortMode = previous.sortMode;
    final followingOnly = previous.followingOnly;
    final arOnly = previous.arOnly;
    final isFresh = previous.lastFetched != null &&
        DateTime.now().difference(previous.lastFetched!) <
            const Duration(minutes: 5);
    if (!forceRefresh && previous.isLoading) return;
    if (!forceRefresh &&
        isFresh &&
        previous.error == null &&
        previous.posts.isNotEmpty) {
      return;
    }

    if (!mounted) return;
    _applyState(() {
      _tagFeeds[key] = previous.copyWith(isLoading: true, error: null);
    });

    try {
      final posts = await _backendApi.getCommunityPosts(
        page: 1,
        limit: 50,
        tag: sanitized,
        sort: sortMode,
        followingOnly: followingOnly,
        arOnly: arOnly,
      );
      final chosenPosts =
          posts.isNotEmpty ? posts : _filterLocalPostsByTag(sanitized);
      final filtered = await _filterBlockedPosts(chosenPosts);
      if (mounted) {
        _primeSubjectPreviews(filtered);
      }
      if (!mounted) return;
      _applyState(() {
        _tagFeeds[key] = previous.copyWith(
          posts: _sortPosts(filtered, sortMode),
          isLoading: false,
          error: filtered.isEmpty
              ? AppLocalizations.of(context)!
                  .desktopCommunityTagFeedNoPostsFoundError(sanitized)
              : null,
          lastFetched: DateTime.now(),
        );
      });
    } catch (e) {
      final fallback = _filterLocalPostsByTag(sanitized);
      final filtered = await _filterBlockedPosts(fallback);
      if (mounted) {
        _primeSubjectPreviews(filtered);
      }
      if (!mounted) return;
      _applyState(() {
        _tagFeeds[key] = previous.copyWith(
          posts: _sortPosts(filtered, sortMode),
          isLoading: false,
          error: filtered.isEmpty ? e.toString() : null,
        );
      });
    }
  }

  Widget _buildHeader(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final accent = themeProvider.accentColor;
    final headerStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.header,
      tintBase: accent,
    );
    final radius = BorderRadius.circular(KubusRadius.lg + KubusRadius.xs);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.md,
        KubusSpacing.md,
        KubusSpacing.md,
        KubusSpacing.sm,
      ),
      child: Column(
        children: [
          LiquidGlassCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(KubusSpacing.md + KubusSpacing.xs),
            borderRadius: radius,
            blurSigma: headerStyle.blurSigma,
            fallbackMinOpacity: headerStyle.fallbackMinOpacity,
            showBorder: false,
            backgroundColor: headerStyle.tintColor,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: accent.withValues(alpha: 0.20),
                  width: KubusSizes.hairline,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.16),
                    accent.withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(KubusSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: KubusSpacing.xxl + KubusSpacing.sm,
                      height: KubusSpacing.xxl + KubusSpacing.sm,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(KubusRadius.lg),
                      ),
                      child: Icon(
                        Icons.groups_2_outlined,
                        color: accent,
                        size: KubusHeaderMetrics.actionIcon + KubusSpacing.xs,
                      ),
                    ),
                    const SizedBox(width: KubusSpacing.md),
                    Expanded(
                      child: KubusHeaderText(
                        title: l10n.navigationScreenCommunity,
                        subtitle: l10n.desktopCommunityHeaderSubtitle,
                        titleStyle: KubusTextStyles.heroTitle.copyWith(
                          color: scheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                        subtitleStyle: KubusTextStyles.sectionSubtitle.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.76),
                        ),
                        maxTitleLines: 1,
                      ),
                    ),
                    const SizedBox(width: KubusSpacing.lg),
                    CommunitySearchBar(
                      controller: _communitySearchController,
                      hintText: l10n.desktopCommunitySearchHint,
                      semanticsLabel: 'desktop_community_search_input',
                      onSubmitted: _handleSearchSubmit,
                      width: 300,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          _buildTabBar(themeProvider),
        ],
      ),
    );
  }
}
