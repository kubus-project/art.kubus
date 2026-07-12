part of '../community_screen.dart';

// Extracted from community_screen.dart (godfile split). Same library:
// private state access is intact. setState is routed through
// the State's _applyState shim.
extension _CommunityScreenStatePart1 on _CommunityScreenState {
  void _onGroupSearchChanged(String value) {
    _groupSearchDebounce?.cancel();
    _groupSearchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final hub = Provider.of<CommunityHubProvider>(context, listen: false);
        await hub.loadGroups(refresh: true, search: value.trim());
      } catch (e) {
        if (kDebugMode) {
          debugPrint('CommunityScreen: failed to search community groups: $e');
        }
      }
    });
  }

  Future<void> _ensureGroupsLoaded({bool force = false}) async {
    try {
      final hub = Provider.of<CommunityHubProvider>(context, listen: false);
      if (!force && (hub.groupsInitialized || hub.groupsLoading)) {
        return;
      }
      await hub.loadGroups(refresh: force);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CommunityScreen: failed to load community groups: $e');
      }
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      _showSnack(l10n.communityGroupsRefreshFailedToast);
    }
  }

  Future<void> _handleGroupMembershipToggle(CommunityGroupSummary group) async {
    if (_groupActionsInFlight.contains(group.id)) return;
    _applyState(() {
      _groupActionsInFlight.add(group.id);
    });
    try {
      final hub = Provider.of<CommunityHubProvider>(context, listen: false);
      if (group.isMember) {
        await hub.leaveGroup(group.id);
      } else {
        await hub.joinGroup(group.id);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CommunityScreen: failed to update group membership: $e');
      }
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      _showSnack(l10n.communityGroupMembershipUpdateFailedToast);
    } finally {
      if (mounted) {
        _applyState(() {
          _groupActionsInFlight.remove(group.id);
        });
      }
    }
  }

  void _openGroupFeed(CommunityGroupSummary group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupFeedScreen(group: group),
      ),
    );
  }

  Future<loc.LocationData?> _obtainCurrentLocation() async {
    final l10n = AppLocalizations.of(context)!;
    final location = loc.Location();
    try {
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          _showSnack(l10n.communityLocationEnableServicesToast);
          return null;
        }
      }

      var permission = await location.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await location.requestPermission();
      }
      if (permission != loc.PermissionStatus.granted &&
          permission != loc.PermissionStatus.grantedLimited) {
        _showSnack(l10n.communityLocationPermissionRequiredToast);
        return null;
      }

      final locationData = await location.getLocation();
      if (locationData.latitude == null || locationData.longitude == null) {
        _showSnack(l10n.communityLocationUnableToDetermineToast);
        return null;
      }
      return locationData;
    } catch (e) {
      debugPrint('Location error: $e');
      _showSnack(l10n.communityLocationUnableToAccessToast);
      return null;
    }
  }

  Future<void> _ensureArtFeedLoaded({bool force = false}) async {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoadingArtFeed && !force) return;
    if (!force && _artFeedPosts.isNotEmpty) return;

    _applyState(() {
      _isLoadingArtFeed = true;
      _artFeedError = null;
    });

    final locationData = await _obtainCurrentLocation();
    if (!mounted) return;
    if (locationData == null) {
      _applyState(() {
        _isLoadingArtFeed = false;
        _artFeedError = l10n.communityArtFeedLocationPermissionRequiredError;
      });
      return;
    }

    try {
      final hub = Provider.of<CommunityHubProvider>(context, listen: false);
      await hub.loadArtFeed(
        latitude: locationData.latitude!,
        longitude: locationData.longitude!,
        sort: 'hybrid',
        refresh: true,
      );
      if (!mounted) return;
      _applyState(() {
        _artFeedLatitude = locationData.latitude;
        _artFeedLongitude = locationData.longitude;
        _artFeedPosts = List<CommunityPost>.from(hub.artFeedPosts);
        _isLoadingArtFeed = false;
        _artFeedError = hub.artFeedError;
      });
    } catch (e) {
      debugPrint('Failed to load art feed: $e');
      if (!mounted) return;
      _applyState(() {
        _isLoadingArtFeed = false;
        _artFeedError = l10n.communityArtFeedLoadFailedError;
      });
      _showSnack(l10n.communityArtFeedLoadFailedToast);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showKubusSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _currentWalletAddress() {
    try {
      return Provider.of<WalletProvider>(context, listen: false)
          .currentWalletAddress;
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureBackendAuthForCommunity(String? walletAddress) async {
    final backendApi = BackendApiService();
    try {
      if (walletAddress != null && walletAddress.isNotEmpty) {
        await backendApi.ensureAuthLoaded(walletAddress: walletAddress);
      } else {
        await backendApi.loadAuthToken();
      }
      if (kDebugMode) {
        debugPrint('CommunityScreen: auth token ready for community posts');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'CommunityScreen: auth token not ready for community posts: $e');
      }
    }
  }

  Future<List<CommunityPost>> _fetchCommunityFeed({
    required bool followingOnly,
    String sort = 'hybrid',
  }) async {
    final backendApi = BackendApiService();
    final subjectProvider =
        Provider.of<CommunitySubjectProvider>(context, listen: false);
    if (kDebugMode) {
      debugPrint(
          'CommunityScreen: active feed fetch ${followingOnly ? 'following' : 'discover'} limit=24');
    }
    final posts = await backendApi.getCommunityPosts(
      page: 1,
      limit: 24,
      followingOnly: followingOnly,
      surface: followingOnly ? 'following' : 'discover',
      sort: sort,
    );
    if (mounted) {
      subjectProvider.primeFromPosts(posts);
      final interactionsProvider =
          Provider.of<CommunityInteractionsProvider>(context, listen: false);
      interactionsProvider.hydratePostsFromServer(posts);
    }

    final blocked = await BlockListService().loadBlockedWallets();
    if (blocked.isEmpty) return posts;

    return posts.where((post) {
      final authorWallet = WalletUtils.canonical(post.authorWallet);
      if (authorWallet.isEmpty) return true;
      return !blocked.contains(authorWallet);
    }).toList();
  }

  Future<void> _loadInitialFeeds(
      {bool force = false, String? walletAddress}) async {
    if (_combinedFeedLoadInFlight && !force) return;
    _combinedFeedLoadInFlight = true;
    final resolvedWallet = walletAddress ?? _currentWalletAddress();
    final targetFollowing = _activeFeed == CommunityFeedType.following;

    if (mounted) {
      _applyState(() {
        _isLoading = true;
        if (force) {
          if (targetFollowing) {
            _followingFeedPosts = [];
            _followingFeedLoaded = false;
          } else {
            _discoverFeedPosts = [];
            _discoverFeedLoaded = false;
          }
        }
        _isLoadingFollowingFeed = targetFollowing;
        _isLoadingDiscoverFeed = !targetFollowing;
      });
    }

    await _ensureBackendAuthForCommunity(resolvedWallet);

    List<CommunityPost>? posts;
    try {
      posts = await _fetchCommunityFeed(
        followingOnly: targetFollowing,
      );
      if (kDebugMode) {
        debugPrint(
            'CommunityScreen: loaded ${posts.length} ${targetFollowing ? 'following' : 'discover'} posts');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'CommunityScreen: error loading ${targetFollowing ? 'following' : 'discover'} feed: $e');
      }
    }

    if (!mounted) {
      _combinedFeedLoadInFlight = false;
      return;
    }

    _applyState(() {
      if (targetFollowing) {
        _followingFeedPosts = posts ?? [];
        _followingFeedLoaded = true;
        _isLoadingFollowingFeed = false;
        if (_activeFeed == CommunityFeedType.following) {
          _communityPosts = _followingFeedPosts;
        }
      } else {
        _discoverFeedPosts = posts ?? [];
        _discoverFeedLoaded = true;
        _isLoadingDiscoverFeed = false;
        if (_activeFeed == CommunityFeedType.discover) {
          _communityPosts = _discoverFeedPosts;
        }
      }

      _isLoading = false;
    });

    if (posts == null && mounted) {
      final l10n = AppLocalizations.of(context)!;
      _showSnack(
        targetFollowing
            ? l10n.communityFollowingFeedUnavailableToast
            : l10n.communityDiscoverFeedUnavailableToast,
      );
    }

    _combinedFeedLoadInFlight = false;
  }

  Future<void> _loadCommunityData(
      {bool? followingOnly, bool force = false}) async {
    final bool targetFollowing =
        followingOnly ?? (_activeFeed == CommunityFeedType.following);
    final bool isActiveFeed =
        (_activeFeed == CommunityFeedType.following && targetFollowing) ||
            (_activeFeed == CommunityFeedType.discover && !targetFollowing);

    if (targetFollowing) {
      if (_isLoadingFollowingFeed && !force) return;
    } else {
      if (_isLoadingDiscoverFeed && !force) return;
    }

    if (mounted) {
      _applyState(() {
        if (targetFollowing) {
          _isLoadingFollowingFeed = true;
        } else {
          _isLoadingDiscoverFeed = true;
        }
        if (isActiveFeed) {
          _isLoading = true;
        }
      });
    }

    final walletAddress = _currentWalletAddress();
    await _ensureBackendAuthForCommunity(walletAddress);

    List<CommunityPost>? posts;
    try {
      posts = await _fetchCommunityFeed(
        followingOnly: targetFollowing,
      );
      if (kDebugMode) {
        debugPrint(
            'CommunityScreen: loaded ${posts.length} ${targetFollowing ? 'following' : 'discover'} posts');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CommunityScreen: error loading community data: $e');
      }
    }

    if (!mounted) return;

    _applyState(() {
      if (targetFollowing) {
        _followingFeedPosts = posts ?? [];
        _followingFeedLoaded = true;
        _isLoadingFollowingFeed = false;
        if (isActiveFeed) {
          _communityPosts = _followingFeedPosts;
          _isLoading = false;
        }
      } else {
        _discoverFeedPosts = posts ?? [];
        _discoverFeedLoaded = true;
        _isLoadingDiscoverFeed = false;
        if (isActiveFeed) {
          _communityPosts = _discoverFeedPosts;
          _isLoading = false;
        }
      }
    });

    if (posts == null || posts.isEmpty) {
      if (isActiveFeed && _communityPosts.isEmpty) {
        final alternative =
            targetFollowing ? _discoverFeedPosts : _followingFeedPosts;
        if (alternative.isNotEmpty) {
          final fallbackFeed = targetFollowing
              ? CommunityFeedType.discover
              : CommunityFeedType.following;
          final l10n = AppLocalizations.of(context)!;
          _showSnack(
            fallbackFeed == CommunityFeedType.following
                ? l10n.communityFollowingFeedUnavailableToast
                : l10n.communityDiscoverFeedUnavailableToast,
          );
          _applyState(() {
            _activeFeed = fallbackFeed;
            _communityPosts = alternative;
            try {
              _tabController.animateTo(
                  fallbackFeed == CommunityFeedType.following ? 0 : 1);
            } catch (_) {}
          });
        }
      }
    }
  }

  void _activateFeed(CommunityFeedType target) {
    if (!mounted) return;

    _applyState(() {
      _activeFeed = target;
      if (target == CommunityFeedType.following) {
        _communityPosts = _followingFeedPosts;
        _isLoading = _isLoadingFollowingFeed;
      } else {
        _communityPosts = _discoverFeedPosts;
        _isLoading = _isLoadingDiscoverFeed;
      }
    });

    if (target == CommunityFeedType.following) {
      if (!_followingFeedLoaded && !_isLoadingFollowingFeed) {
        _loadCommunityData(followingOnly: true);
      }
    } else {
      if (!_discoverFeedLoaded && !_isLoadingDiscoverFeed) {
        _loadCommunityData(followingOnly: false);
      }
    }
  }

  Future<void> _reloadCommunityFeedsForWallet({
    String? walletAddress,
    bool force = false,
  }) async {
    if (_communityReloadInFlight) return;
    _communityReloadInFlight = true;
    try {
      final normalized = walletAddress?.trim() ?? '';
      if (normalized.isNotEmpty) {
        try {
          await BackendApiService().ensureAuthLoaded(walletAddress: normalized);
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                'CommunityScreen: ensureAuthLoaded failed for $normalized: $e');
          }
        }
      }

      await _loadInitialFeeds(
        force: force,
        walletAddress: normalized.isNotEmpty ? normalized : null,
      );
    } finally {
      _communityReloadInFlight = false;
    }
  }

  void _onAppRefreshTriggered() {
    if (!mounted || _appRefreshProvider == null) return;
    final communityVersion = _appRefreshProvider!.communityVersion;
    final globalVersion = _appRefreshProvider!.globalVersion;
    final shouldRefresh = communityVersion != _lastCommunityRefreshVersion ||
        globalVersion != _lastGlobalRefreshVersion;
    _lastCommunityRefreshVersion = communityVersion;
    _lastGlobalRefreshVersion = globalVersion;
    if (!shouldRefresh) return;
    try {
      _lastWalletAddress = Provider.of<WalletProvider>(context, listen: false)
          .currentWalletAddress;
    } catch (_) {}
    _reloadCommunityFeedsForWallet(
      walletAddress: _lastWalletAddress,
      force: true,
    );
  }


  void _startInitialCommunityLoad() {
    unawaited(() async {
      await _loadInitialFeeds();
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
            debugPrint('CommunityScreen: post-feed startup work');
          }

          try {
            Provider.of<NavigationProvider>(context, listen: false)
                .trackScreenVisit('community');
          } catch (_) {}

          try {
            SocketService()
                .addNotificationListener(_onSocketNotificationForCommunity);
          } catch (_) {}

          try {
            await SocketService().connect();
            if (!mounted) return;
            SocketService().addPostListener(_handleIncomingPost);
          } catch (_) {}

          try {
            final provider =
                Provider.of<NotificationProvider>(context, listen: false);
            await provider.refresh();
            if (!mounted) return;
            _applyState(() {
              _bellUnreadCount = provider.unreadCount;
            });
            provider.addListener(_onNotificationProviderChange);
          } catch (_) {}

          try {
            final cp = Provider.of<ChatProvider>(context, listen: false);
            await cp.initialize();
            if (!mounted) return;
            _messageUnreadCount = cp.totalUnread;
            cp.addListener(_onChatProviderChanged);
          } catch (_) {}
        },
      ));
    });
  }

  void _handleCommunitySearchControllerChanged() {
    if (!mounted) return;
    _applyState(() {});
  }

  void _onConfigChanged() {
    // Debounce: only reload if at least 1 second has passed since last change
    final now = DateTime.now();
    if (_lastConfigChange != null &&
        now.difference(_lastConfigChange!).inSeconds < 1) {
      return;
    }
    _lastConfigChange = now;
    _loadInitialFeeds(force: true);
  }

  bool _handleArtFeedScrollNotification(ScrollNotification notification) {
    if (!mounted) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    if (_tabController.index != 3) return false;
    if (_artFeedLatitude == null || _artFeedLongitude == null) return false;
    if (notification.metrics.extentAfter > 600) return false;

    if (_artFeedLoadMoreInFlight) return false;
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    if (hub.artFeedLoading || !hub.artFeedHasMore) return false;

    _artFeedLoadMoreInFlight = true;
    (() async {
      try {
        await hub.loadArtFeed(
          latitude: _artFeedLatitude!,
          longitude: _artFeedLongitude!,
          radiusKm: hub.artFeedRadiusKm,
          limit: 20,
          refresh: false,
        );
        if (!mounted) return;
        _applyState(() {
          _artFeedPosts = List<CommunityPost>.from(hub.artFeedPosts);
          _isLoadingArtFeed = hub.artFeedLoading;
          _artFeedError = hub.artFeedError;
        });
      } catch (_) {
        // Errors are surfaced via hub.artFeedError and the existing UI states.
      } finally {
        _artFeedLoadMoreInFlight = false;
      }
    })();

    return false;
  }

  void _handleIncomingPost(Map<String, dynamic> data) async {
    try {
      final id = (data['id'] ?? data['postId'] ?? data['post_id'])?.toString();
      if (id == null) return;
      if (_recentlyCreatedPostIds.remove(id)) return;
      if (_communityPosts.any((p) => p.id == id)) return;
      try {
        final post = await BackendApiService().getCommunityPostById(id);
        if (_isDuplicatePost(post)) return;
        if (!mounted) return;
        try {
          context.read<CommunitySubjectProvider>().primeFromPosts([post]);
        } catch (_) {}

        final atTop = _feedScrollController.hasClients
            ? _feedScrollController.offset <= 120
            : true;
        if (atTop) {
          _applyState(() {
            _communityPosts.insert(0, post);
          });
        } else {
          // Buffer incoming post and show indicator
          _applyState(() {
            // Avoid duplicates in buffer
            if (!_bufferedIncomingPosts.any((p) => p.id == post.id)) {
              _bufferedIncomingPosts.insert(0, post);
            }
          });
        }
      } catch (e) {
        debugPrint('Failed to fetch incoming post $id: $e');
      }
    } catch (e) {
      debugPrint('CommunityScreen incoming post handler error: $e');
    }
  }

  bool _isDuplicatePost(CommunityPost candidate) {
    const proximity = Duration(seconds: 4);

    bool matches(CommunityPost existing) {
      final sameAuthor = existing.authorId == candidate.authorId;
      final sameContent = existing.content == candidate.content;
      final timestampDiff =
          existing.timestamp.difference(candidate.timestamp).abs();
      final existingPostType = (existing.postType ?? '').toLowerCase();
      final candidatePostType = (candidate.postType ?? '').toLowerCase();
      final isRepost =
          candidatePostType == 'repost' || existingPostType == 'repost';
      final sameRepostSource = candidatePostType == 'repost' &&
          existingPostType == 'repost' &&
          candidate.originalPostId != null &&
          candidate.originalPostId == existing.originalPostId &&
          sameAuthor;

      if (existing.id == candidate.id) return true;
      if (sameRepostSource) return true;
      if (isRepost) return false;
      return sameAuthor && sameContent && timestampDiff < proximity;
    }

    return _communityPosts.any(matches) || _bufferedIncomingPosts.any(matches);
  }

  void _prependBufferedPosts() {
    if (_bufferedIncomingPosts.isEmpty) return;
    _applyState(() {
      // Prepend buffered posts preserving order: newest first
      _communityPosts.insertAll(0, _bufferedIncomingPosts);
      _bufferedIncomingPosts.clear();
    });
    // Scroll to top for visibility
    try {
      if (_feedScrollController.hasClients) {
        _feedScrollController.animateTo(0.0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (_) {}
  }

  void _onWalletProviderChanged() async {
    try {
      final walletProvider =
          Provider.of<WalletProvider>(context, listen: false);
      final currentWallet = walletProvider.currentWalletAddress ?? '';
      final normalized = WalletUtils.normalize(currentWallet);
      final previous = WalletUtils.normalize(_lastWalletAddress);
      final hasChanged = previous != normalized;

      if (hasChanged) {
        _lastWalletAddress = normalized;
        await _reloadCommunityFeedsForWallet(
          walletAddress: normalized,
          force: true,
        );
        return;
      }

      if (_communityPosts.isNotEmpty) {
        context
            .read<CommunityInteractionsProvider>()
            .hydratePostsFromServer(_communityPosts);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CommunityScreen: wallet interaction refresh failed: $e');
      }
    }
  }

  Widget _buildAppBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final isSmallScreen = MediaQuery.of(context).size.width < 375;
    final animationTheme = context.animationTheme;
    final scheme = Theme.of(context).colorScheme;
    final surfaceStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.header,
      tintBase: themeProvider.accentColor,
    );
    return Container(
      padding:
          const EdgeInsets.all(KubusHeaderMetrics.appBarHorizontalPaddingLg),
      child: LiquidGlassPanel(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(KubusSpacing.md),
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        blurSigma: surfaceStyle.blurSigma,
        backgroundColor: surfaceStyle.tintColor,
        fallbackMinOpacity: surfaceStyle.fallbackMinOpacity,
        showBorder: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: KubusHeaderMetrics.actionHitArea + KubusSpacing.xs,
                  height: KubusHeaderMetrics.actionHitArea + KubusSpacing.xs,
                  decoration: BoxDecoration(
                    color: themeProvider.accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(KubusRadius.lg),
                  ),
                  child: Icon(
                    Icons.groups_2_outlined,
                    color: themeProvider.accentColor,
                    size: KubusHeaderMetrics.actionIcon + KubusSpacing.xs,
                  ),
                ),
                const SizedBox(width: KubusSpacing.md),
                Expanded(
                  child: KubusHeaderText(
                    title: l10n.navigationScreenCommunity,
                    subtitle: l10n.desktopCommunityHeaderSubtitle,
                    kind: KubusHeaderKind.screen,
                    titleColor: scheme.onSurface,
                    subtitleColor: scheme.onSurface.withValues(alpha: 0.76),
                    titleStyle: KubusTextStyles.sectionTitle.copyWith(
                      color: scheme.onSurface,
                    ),
                    subtitleStyle: KubusTextStyles.sectionSubtitle.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.76),
                    ),
                    maxTitleLines: 1,
                  ),
                ),
                const SizedBox(width: KubusSpacing.sm),
                Wrap(
                  spacing: KubusSpacing.xs,
                  runSpacing: KubusSpacing.xs,
                  alignment: WrapAlignment.end,
                  children: [
                    TopBarIcon(
                      tooltip: l10n.commonNotifications,
                      icon: AnimatedBuilder(
                        animation: _bellController,
                        builder: (ctx, child) {
                          final scale = _bellScale.value;
                          return Transform.scale(
                            scale: scale,
                            child: Icon(
                              _bellUnreadCount > 0
                                  ? Icons.notifications
                                  : Icons.notifications_outlined,
                              color: scheme.onSurface,
                              size: KubusHeaderMetrics.actionIcon,
                            ),
                          );
                        },
                      ),
                      onPressed: _showNotifications,
                      badgeCount: _bellUnreadCount,
                      badgeColor: themeProvider.accentColor,
                    ),
                    Selector<ChatProvider, int>(
                      selector: (_, cp) => cp.totalUnread,
                      builder: (context, totalUnread, child) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (totalUnread > 0 && _messageScale.value == 1.0) {
                            _messagePulseController.forward(from: 0.0);
                          }
                        });
                        return TopBarIcon(
                          tooltip: l10n.messagesTitle,
                          icon: ScaleTransition(
                            scale: _messageScale,
                            child: Icon(
                              totalUnread > 0
                                  ? Icons.chat_bubble
                                  : Icons.chat_bubble_outline,
                              color: totalUnread > 0
                                  ? themeProvider.accentColor
                                  : scheme.onSurface,
                              size: isSmallScreen ? 20 : 24,
                            ),
                          ),
                          onPressed: () {
                            showGeneralDialog(
                              context: context,
                              barrierDismissible: true,
                              barrierLabel: l10n.messagesTitle,
                              barrierColor: scheme.primaryContainer
                                  .withValues(alpha: 0.7),
                              transitionDuration: animationTheme.medium,
                              pageBuilder: (ctx, a1, a2) =>
                                  const MessagesScreen(),
                              transitionBuilder: (ctx, anim1, anim2, child) {
                                final slideCurve = CurvedAnimation(
                                  parent: anim1,
                                  curve: animationTheme.defaultCurve,
                                );
                                final fadeCurve = CurvedAnimation(
                                  parent: anim1,
                                  curve: animationTheme.fadeCurve,
                                );
                                return Transform.translate(
                                  offset: Offset(
                                    0,
                                    (1 - slideCurve.value) *
                                        MediaQuery.of(context).size.height,
                                  ),
                                  child: FadeTransition(
                                    opacity: fadeCurve,
                                    child: child,
                                  ),
                                );
                              },
                            );
                          },
                          badgeCount: totalUnread,
                          badgeColor: themeProvider.accentColor,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: KubusSpacing.md),
            _buildCommunitySearchBar(),
            const SizedBox(height: KubusSpacing.sm),
            _buildTabBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunitySearchBar() {
    return CommunitySearchBar(
      controller: _communitySearchController,
      semanticsLabel: 'community_search_input',
      hintText: AppLocalizations.of(context)!.commonSearchHint,
      onSubmitted: (_) => _communitySearchController.onSubmitted(),
      trailingBuilder: (context, query) {
        if (query.trim().isEmpty) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return IconButton(
          tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
          icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
          onPressed: () =>
              _communitySearchController.clearQueryWithContext(context),
        );
      },
    );
  }

  Future<void> _handleCommunitySearchResultTap(KubusSearchResult result) async {
    _communitySearchController.commitSelection(result.label);
    FocusScope.of(context).unfocus();
    await CommunitySearchActions.handle(
      context,
      result,
      onProfile: (userId) => UserProfileNavigation.open(
        context,
        userId: userId,
      ),
      onArtwork: (artworkId) =>
          openArtwork(context, artworkId, source: 'community_search'),
      onPost: (postId) => PostDetailScreen.openById(context, postId),
      onScreen: (screenKey) => unawaited(
        HomeQuickActionExecutor.execute(
          context,
          screenKey,
          source: HomeQuickActionSurface.legacyProvider,
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
        );
      },
    );
  }

  Future<void> _onSocketNotificationForCommunity(
      Map<String, dynamic> data) async {
    if (!mounted) return;
    try {
      _bellController.forward(from: 0.0);
      // UI will be refreshed by NotificationProvider which is already listening for socket events and
      // updating the unread count and showing local notifications. No local show/dedupe here.
    } catch (_) {}
  }

  void _onNotificationProviderChange() {
    if (!mounted) return;
    try {
      final provider =
          Provider.of<NotificationProvider>(context, listen: false);
      _applyState(() {
        _bellUnreadCount = provider.unreadCount;
      });
    } catch (_) {}
  }

  void _onChatProviderChanged() {
    try {
      final cp = Provider.of<ChatProvider>(context, listen: false);
      final newCount = cp.totalUnread;
      if (newCount > _messageUnreadCount) {
        _messagePulseController.forward(from: 0.0);
      }
      _messageUnreadCount = newCount;
      _applyState(() {});
    } catch (_) {}
  }

  Widget _buildTabBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final tabs = <({String label, IconData icon})>[
      (label: l10n.communityFollowingTab, icon: Icons.people_alt_outlined),
      (label: l10n.communityDiscoverTab, icon: Icons.explore_outlined),
      (label: l10n.communityGroupsTab, icon: Icons.groups_outlined),
      (label: l10n.communityArtTab, icon: Icons.palette_outlined),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;

        final glassStyle = KubusGlassStyle.resolve(
          context,
          surfaceType: KubusGlassSurfaceType.card,
          tintBase: scheme.surface,
        );
        final radius = BorderRadius.circular(KubusRadius.md);

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.18),
              width: KubusSizes.hairline,
            ),
          ),
          child: LiquidGlassPanel(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(KubusSpacing.xxs),
            borderRadius: radius,
            blurSigma: glassStyle.blurSigma,
            backgroundColor: glassStyle.tintColor,
            fallbackMinOpacity: glassStyle.fallbackMinOpacity,
            showBorder: false,
            child: TabBar(
              controller: _tabController,
              isScrollable: constraints.maxWidth < 420,
              tabAlignment: constraints.maxWidth < 420
                  ? TabAlignment.start
                  : TabAlignment.fill,
              indicator: BoxDecoration(
                color: themeProvider.accentColor.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.30
                      : 0.18,
                ),
                borderRadius: BorderRadius.circular(KubusRadius.sm),
                border: Border.all(
                  color: themeProvider.accentColor.withValues(alpha: 0.32),
                  width: KubusSizes.hairline,
                ),
                boxShadow: [
                  BoxShadow(
                    color: themeProvider.accentColor.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              indicatorPadding: const EdgeInsets.all(KubusSpacing.xxs),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: scheme.onSurface,
              unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.68),
              labelStyle: KubusTypography.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle:
                  KubusTypography.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              dividerHeight: 0,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              tabs: [
                for (final tab in tabs)
                  Tab(
                    height: isCompact ? 56 : 60,
                    iconMargin: const EdgeInsets.only(bottom: KubusSpacing.xxs),
                    icon: Icon(
                      tab.icon,
                      size: KubusHeaderMetrics.actionIcon,
                    ),
                    child: Text(
                      tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeedTab() {
    final l10n = AppLocalizations.of(context)!;
    return _buildPostTimeline(
      onRefresh: () => _loadCommunityData(followingOnly: true),
      emptyIcon: Icons.feed,
      emptyTitle: l10n.communityFeedEmptyTitle,
      emptySubtitle: l10n.communityFeedEmptyDescription,
      showBufferedBanner: true,
    );
  }

  Widget _buildDiscoverTab() {
    final l10n = AppLocalizations.of(context)!;
    return _buildPostTimeline(
      onRefresh: () => _loadCommunityData(followingOnly: false),
      emptyIcon: Icons.travel_explore,
      emptyTitle: l10n.communityDiscoverEmptyTitle,
      emptySubtitle: l10n.communityDiscoverEmptyDescription,
    );
  }

  Widget _buildPostTimeline({
    required Future<void> Function() onRefresh,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
    bool showBufferedBanner = false,
  }) {
    final filteredPosts = _filterPostsForQuery(_communityPosts);
    final hasQuery = _communitySearchQuery.isNotEmpty;

    if (_isLoading) {
      return const AppLoading();
    }

    if (filteredPosts.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(
              bottom: KubusLayout.mainBottomNavBarHeight,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              width: double.infinity,
              child: EmptyStateCard(
                icon: emptyIcon,
                title: hasQuery ? l10n.commonNoResultsFound : emptyTitle,
                description: hasQuery
                    ? l10n.communitySearchEmptyNoResults
                    : emptySubtitle,
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Stack(
        children: [
          ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              KubusSpacing.lg,
              KubusSpacing.lg,
              KubusSpacing.lg,
              KubusSpacing.lg + KubusLayout.mainBottomNavBarHeight,
            ),
            itemCount: filteredPosts.length +
                (AppConfig.isFeatureEnabled('season0') ? 1 : 0),
            itemBuilder: (context, index) {
              // Season 0 banner at the top if enabled
              if (AppConfig.isFeatureEnabled('season0') && index == 0) {
                return _buildSeason0Banner();
              }
              final postIndex =
                  AppConfig.isFeatureEnabled('season0') ? index - 1 : index;
              return _buildPostCardForPost(filteredPosts[postIndex]);
            },
          ),
          if (showBufferedBanner && _bufferedIncomingPosts.isNotEmpty)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _prependBufferedPosts,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KubusSpacing.md,
                      vertical: KubusSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(KubusRadius.xl),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                        )
                      ],
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.communityNewPostsBanner(
                        _bufferedIncomingPosts.length,
                      ),
                      style: KubusTypography.inter(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeason0Banner() {
    final l10n = AppLocalizations.of(context)!;
    final accent = context.watch<ThemeProvider>().accentColor;
    return CommunitySeason0Banner(
      title: l10n.season0BannerTitle,
      subtitle: l10n.season0BannerTap,
      accentColor: accent,
      variant: CommunitySeason0BannerVariant.mobile,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const Season0Screen()),
        );
      },
    );
  }

  Widget _buildGroupsTab() {
    return Consumer<CommunityHubProvider>(
      builder: (context, hub, _) {
        final l10n = AppLocalizations.of(context)!;
        if (!hub.groupsInitialized && hub.groupsLoading) {
          return const AppLoading();
        }

        final hasGroups = hub.groups.isNotEmpty;
        final listView = ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            KubusSpacing.lg,
            KubusSpacing.lg,
            KubusSpacing.lg,
            KubusSpacing.lg + KubusLayout.mainBottomNavBarHeight,
          ),
          children: [
            _buildGroupDirectoryHeader(),
            const SizedBox(height: KubusSpacing.md),
            _buildGroupSearchField(hub),
            const SizedBox(height: KubusSpacing.md),
            if (hub.groupsError != null)
              _buildGroupErrorBanner(hub.groupsError!),
            if (!hasGroups)
              Padding(
                padding: const EdgeInsets.only(top: KubusSpacing.xl),
                child: EmptyStateCard(
                  icon: Icons.groups_outlined,
                  title: l10n.communityGroupsEmptyTitle,
                  description: hub.currentGroupSearchQuery.isEmpty
                      ? l10n.communityGroupsEmptyDescription
                      : l10n.communityGroupsEmptySearchDescription(
                          hub.currentGroupSearchQuery,
                        ),
                ),
              ),
            if (hasGroups) ...hub.groups.map((group) => _buildGroupCard(group)),
            if (hub.groupsLoading && hasGroups)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: KubusSpacing.lg,
                ),
                child: InlineLoading(
                  expand: false,
                  shape: BoxShape.circle,
                  progress: null,
                  tileSize: 3.5,
                  color: Provider.of<ThemeProvider>(context, listen: false)
                      .accentColor,
                ),
              ),
            if (!hub.groupsLoading && hasGroups && !hub.hasMoreGroups)
              Padding(
                padding: const EdgeInsets.only(top: KubusSpacing.md),
                child: Center(
                  child: Text(
                    l10n.communityGroupsEndOfDirectory,
                    style: KubusTypography.textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
          ],
        );

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 160 &&
                hub.hasMoreGroups &&
                !hub.groupsLoading) {
              hub.loadGroups(search: hub.currentGroupSearchQuery);
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: () => hub.loadGroups(
              refresh: true,
              search: hub.currentGroupSearchQuery,
            ),
            child: listView,
          ),
        );
      },
    );
  }
}
