import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../config/config.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/community_hub_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/app_refresh_provider.dart';
import '../../../providers/community_subject_provider.dart';
import '../../../community/community_interactions.dart';
import '../../../models/community_group.dart';
import '../../../models/community_subject.dart';
import '../../../models/conversation.dart';
import '../../../services/backend_api_service.dart';
import '../../../services/block_list_service.dart';
import '../../../services/user_service.dart';
import '../../../services/share/share_service.dart';
import '../../../services/share/share_types.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../widgets/inline_loading.dart';
import '../../../widgets/user_activity_status_line.dart';
import '../../../widgets/community/community_post_card.dart';
import '../../../widgets/community/community_author_role_badges.dart';
import '../../../widgets/community/community_post_options_sheet.dart';
import '../../../widgets/community/community_subject_picker.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/media_url_resolver.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/wallet_utils.dart';
import '../../../utils/user_identity_display.dart';
import '../../../utils/community_subject_navigation.dart';
import '../../../widgets/glass_components.dart';
import '../components/desktop_widgets.dart';
import '../desktop_shell.dart';
import '../../community/group_feed_screen.dart';
import '../../community/conversation_screen.dart';
import 'desktop_user_profile_screen.dart';
import '../../community/post_detail_screen.dart';
import '../../download_app_screen.dart';
import '../../map_screen.dart';
import '../../season0/season0_screen.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

class _ComposerImagePayload {
  final Uint8List bytes;
  final String fileName;

  const _ComposerImagePayload({
    required this.bytes,
    required this.fileName,
  });
}

/// Desktop community screen with Twitter/Instagram-style feed
/// Features multi-column layout with trending and suggestions
class DesktopCommunityScreen extends StatefulWidget {
  const DesktopCommunityScreen({super.key});

  @override
  State<DesktopCommunityScreen> createState() => _DesktopCommunityScreenState();
}

class _DesktopCommunityScreenState extends State<DesktopCommunityScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late TabController _tabController;
  late ScrollController _scrollController;
  late TextEditingController _groupSearchController;
  late TextEditingController _communitySearchController;
  late TextEditingController _messageSearchController;
  Timer? _groupSearchDebounce;
  Timer? _searchDebounce;
  bool _isFabExpanded = false;
  final LayerLink _searchFieldLink = LayerLink();
  final List<String> _tabs = ['Discover', 'Following', 'Groups', 'Art'];
  final BackendApiService _backendApi = BackendApiService();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isFetchingSearch = false;
  String _searchQuery = '';
  bool _showSearchOverlay = false;
  static const List<_ComposerCategoryOption> _composerCategories = [
    _ComposerCategoryOption(
      value: 'post',
      label: 'Post',
      icon: Icons.edit_outlined,
      description: 'Share an update with the community',
    ),
    _ComposerCategoryOption(
      value: 'art_drop',
      label: 'Art drop',
      icon: Icons.view_in_ar_outlined,
      description: 'Highlight a location-based activation',
    ),
    _ComposerCategoryOption(
      value: 'art_review',
      label: 'Art review',
      icon: Icons.rate_review_outlined,
      description: 'Share your thoughts on an artwork',
    ),
    _ComposerCategoryOption(
      value: 'event',
      label: 'Event',
      icon: Icons.event_outlined,
      description: 'Announce meetups and gatherings',
    ),
    _ComposerCategoryOption(
      value: 'question',
      label: 'Question',
      icon: Icons.help_outline,
      description: 'Ask the community for feedback',
    ),
  ];
  bool _showComposeDialog = false;
  bool _showMessagesPanel = false;
  bool _isComposerExpanded = false;
  bool _isPosting = false;
  int _lastHandledComposerOpenNonce = 0;
  final TextEditingController _composeController = TextEditingController();
  final List<_ComposerImagePayload> _selectedImages = [];
  String? _selectedLocation;
  String _selectedCategory = 'post';
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _mentionController = TextEditingController();
  List<Map<String, dynamic>> _trendingTopics = [];
  bool _isLoadingTrending = false;
  String? _trendingError;
  bool _trendingFromFeed = false;
  List<Map<String, dynamic>> _suggestedArtists = [];
  bool _isLoadingSuggestions = false;
  String? _suggestionsError;
  String? _activeConversationId;
  String _messageSearchQuery = '';
  final List<_PaneRoute> _paneStack = [];
  final Map<String, _TagFeedState> _tagFeeds = {};
  String _discoverSortMode = 'recent';
  String _followingSortMode = 'recent';
  String _artSortMode = 'recent';

  AppRefreshProvider? _appRefreshProvider;
  int _lastCommunityRefreshVersion = 0;
  int _lastGlobalRefreshVersion = 0;
  bool _refreshInFlight = false;
  Set<String> _followingWallets = <String>{};
  final Set<String> _followRequestsInFlight = <String>{};

  // Feed state for different tabs
  List<CommunityPost> _discoverPosts = [];
  List<CommunityPost> _followingPosts = [];
  bool _isLoadingDiscover = false;
  bool _isLoadingFollowing = false;
  String? _discoverError;
  String? _followingError;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_isFabExpanded) {
        setState(() => _isFabExpanded = false);
      }
      setState(() {}); // refresh FAB options per tab like mobile
    });
    _scrollController = ScrollController();
    _groupSearchController = TextEditingController();
    _communitySearchController = TextEditingController();
    _messageSearchController = TextEditingController();
    _messageSearchController.addListener(_handleMessageSearchChanged);
    _animationController.forward();

    // Load community feed data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFeed();
      _loadSidebarData();
      unawaited(_syncFollowingWallets());

      try {
        _appRefreshProvider = Provider.of<AppRefreshProvider>(context, listen: false);
        _lastCommunityRefreshVersion = _appRefreshProvider?.communityVersion ?? 0;
        _lastGlobalRefreshVersion = _appRefreshProvider?.globalVersion ?? 0;
        _appRefreshProvider?.addListener(_onAppRefreshTriggered);
      } catch (_) {}
    });
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
      setState(() {
        _followingWallets = wallets.map(WalletUtils.canonical).where((w) => w.isNotEmpty).toSet();
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
            label: 'Sign in',
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

    setState(() {
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
      setState(() => _followRequestsInFlight.remove(wallet));
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
      setState(() {
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
    final communityProvider = context.read<CommunityHubProvider>();
    // Load art feed with default location (can be updated with user's location)
    await communityProvider.loadArtFeed(
      latitude: 46.05, // Default to Ljubljana
      longitude: 14.50,
      radiusKm: 50,
      limit: 50,
      refresh: true,
    );
    // Also load groups for sidebar
    if (!communityProvider.groupsInitialized) {
      await communityProvider.loadGroups();
    }
    // Load discover and following feeds
    await Future.wait([
      _loadDiscoverFeed(),
      _loadFollowingFeed(),
    ]);

    // Trending topics are loaded in parallel with the feeds. When the trending
    // request finishes before the feed data is available, we end up with
    // "0 tagged posts" because the backend trending endpoint does not include
    // community tag counts. Once feeds are loaded, enrich (or seed) trending
    // counts from the local posts so the desktop sidebar stays informative.
    if (!mounted) return;
    _enrichTrendingTopicsFromFeedCounts();
  }

  void _enrichTrendingTopicsFromFeedCounts() {
    if (!mounted) return;
    final fallback = _buildFallbackTrendingTopics();
    if (fallback.isEmpty) return;

    // If trending wasn't loaded yet (or failed), seed from feed-derived counts.
    if (_trendingTopics.isEmpty) {
      setState(() {
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
    setState(() {
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
    setState(() {
      _isLoadingDiscover = true;
      _discoverError = null;
    });
    try {
      final posts = await BackendApiService().getCommunityPosts(
        page: 1,
        limit: 50,
        followingOnly: false,
        sort: sort,
      );
      final filtered = await _filterBlockedPosts(posts);
      if (mounted) {
        _primeSubjectPreviews(filtered);
      }
      if (mounted) {
        setState(() {
          _discoverPosts = filtered;
          _isLoadingDiscover = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _discoverError = e.toString();
          _isLoadingDiscover = false;
        });
      }
    }
  }

  Future<void> _loadSidebarData() async {
    await Future.wait([
      _loadTrendingTopics(),
      _loadSuggestions(),
    ]);
  }

  Future<void> _loadTrendingTopics() async {
    if (!mounted) return;
    setState(() {
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
        setState(() {
          _trendingTopics = normalized;
          _isLoadingTrending = false;
          _trendingFromFeed = usedFallback;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _trendingError = e.toString();
          _isLoadingTrending = false;
          _trendingFromFeed = false;
        });
      }
    }
  }

  Future<void> _loadSuggestions() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSuggestions = true;
      _suggestionsError = null;
    });
    try {
      final backend = BackendApiService();
      final aggregated = <Map<String, dynamic>>[];

      try {
        final featured =
            await backend.listArtists(featured: true, limit: 12, offset: 0);
        aggregated.addAll(featured);
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
        setState(() {
          _suggestedArtists = artists;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
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
    setState(() {
      _isLoadingFollowing = true;
      _followingError = null;
    });
    try {
      final posts = await BackendApiService().getCommunityPosts(
        page: 1,
        limit: 50,
        followingOnly: true,
        sort: sort,
      );
      final filtered = await _filterBlockedPosts(posts);
      if (mounted) {
        _primeSubjectPreviews(filtered);
      }
      if (mounted) {
        setState(() {
          _followingPosts = filtered;
          _isLoadingFollowing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _followingError = e.toString();
          _isLoadingFollowing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _appRefreshProvider?.removeListener(_onAppRefreshTriggered);
    _animationController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    _groupSearchDebounce?.cancel();
    _searchDebounce?.cancel();
    _groupSearchController.dispose();
    _communitySearchController.dispose();
    _messageSearchController.removeListener(_handleMessageSearchChanged);
    _messageSearchController.dispose();
    _tagController.dispose();
    _mentionController.dispose();
    _composeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<CommunityHubProvider>();
    _maybeHandleComposerOpenRequest(hub);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;
    final isMedium = screenWidth >= 900 && screenWidth < 1200;

    return PopScope(
      canPop: _paneStack.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_paneStack.isNotEmpty) {
          _popPane();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main feed
                Expanded(
                  flex: isLarge ? 3 : 2,
                  child: _buildMainFeed(themeProvider, animationTheme),
                ),

                // Right sidebar
                if (isMedium || isLarge)
                  SizedBox(
                    width: isLarge ? 360 : 300,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : scheme.outline.withValues(alpha: 0.10),
                            width: 1,
                          ),
                        ),
                      ),
                      child: LiquidGlassPanel(
                        padding: EdgeInsets.zero,
                        margin: EdgeInsets.zero,
                        borderRadius: BorderRadius.zero,
                        showBorder: false,
                        backgroundColor:
                            scheme.surface.withValues(alpha: isDark ? 0.16 : 0.10),
                        child: _buildRightSidebar(themeProvider),
                      ),
                    ),
                  ),
              ],
            ),

            if (_showSearchOverlay) _buildSearchOverlay(themeProvider),

            // Compose dialog
            if (_showComposeDialog) _buildComposeDialog(themeProvider),
          ],
        ),
      ),
    );
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
        Column(
          children: [
            // Header with tabs
            _buildHeader(themeProvider),

            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildTabBar(themeProvider),
            ),

            _buildSortControls(themeProvider),

            // Feed content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _tabs
                    .map((tab) => _buildFeedList(tab, themeProvider))
                    .toList(),
              ),
            ),
          ],
        ),

        // Floating actions
        Positioned(
          bottom: 20,
          right: 20,
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
            : _buildPostDetailPane(post, initialAction: route.initialAction);
        break;
      case _PaneViewType.conversation:
        final conversation = route.conversation;
        child = conversation == null
            ? const SizedBox.shrink()
            : _buildConversationPane(conversation);
        break;
    }
    return KeyedSubtree(
      key: ValueKey(route.viewKey),
      child: child,
    );
  }

  void _popPane() {
    if (_paneStack.isEmpty) return;
    setState(() {
      final removed = _paneStack.removeLast();
      if (removed.type == _PaneViewType.conversation) {
        _activeConversationId = null;
      }
    });
  }

  Widget _buildTagFeedPane(String tag, ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    final sanitized = _sanitizeTagValue(tag);
    if (sanitized == null) {
      return Container(
        key: const ValueKey('tag-pane-invalid'),
        color: scheme.surface,
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
                  'Tag unavailable',
                  'We could not open that tag feed.',
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
          _buildLoadingState(themeProvider, 'Loading #$sanitized posts...'),
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
            'No posts for #$sanitized',
            'Create or discover posts tagged #$sanitized to see them here.',
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
                  'Top posts for #$sanitized',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sorted by popularity (likes, shares, comments, and views).',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                if (taggedCount != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${_formatTrendingCount(taggedCount)} tagged posts across the community',
                    style: GoogleFonts.inter(
                      fontSize: 12,
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#$rank',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: themeProvider.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Popular for #$sanitized',
                    style: GoogleFonts.inter(
                      fontSize: 12,
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
      color: scheme.surface,
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to feed',
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
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Sorted by popularity',
                      style: GoogleFonts.inter(
                        fontSize: 12,
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
                        '${_formatTrendingCount(tagCount)} tagged posts',
                        style: GoogleFonts.inter(
                          fontSize: 12,
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
            tooltip: sortMode == 'popularity'
                ? 'Sorted by popularity'
                : 'Sorted by recent',
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
            tooltip: isLoading ? 'Loading' : 'Refresh',
            onPressed: isLoading
                ? null
                : () => _loadTagFeed(tagValue, forceRefresh: true),
            icon: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: themeProvider.accentColor,
                    ),
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
    PostDetailInitialAction? initialAction,
  }) {
    return Container(
      key: ValueKey('post-pane-${post.id}'),
      color: Theme.of(context).colorScheme.surface,
      child: PostDetailScreen(
        post: post,
        initialAction: initialAction,
        onClose: _popPane,
      ),
    );
  }

  Widget _buildConversationPane(Conversation conversation) {
    return Container(
      key: ValueKey('conversation-pane-${conversation.id}'),
      color: Theme.of(context).colorScheme.surface,
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
    setState(() {
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
    setState(() {
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
    setState(() {
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
      setState(() {
        _tagFeeds[key] = previous.copyWith(
          posts: _sortPosts(filtered, sortMode),
          isLoading: false,
          error: filtered.isEmpty ? 'No posts found for #$sanitized' : null,
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
      setState(() {
        _tagFeeds[key] = previous.copyWith(
          posts: _sortPosts(filtered, sortMode),
          isLoading: false,
          error: filtered.isEmpty ? e.toString() : null,
        );
      });
    }
  }

  Widget _buildHeader(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Community',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Connect with artists and collectors',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 280,
            child: CompositedTransformTarget(
              link: _searchFieldLink,
              child: DesktopSearchBar(
                controller: _communitySearchController,
                hintText: 'Search posts, users, tags...',
                onChanged: _handleSearchChange,
                onSubmitted: _handleSearchSubmit,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagFilters({
    required ThemeProvider themeProvider,
    required String tagValue,
    required bool followingOnly,
    required bool arOnly,
    required String sortMode,
  }) {
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
                  style: GoogleFonts.inter(
                    fontSize: 12,
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
            label: 'All posts',
            active: !followingOnly,
            onTap: () => _updateTagFeedFilters(tagValue, followingOnly: false),
            icon: Icons.public,
          ),
          buildChip(
            label: 'Following',
            active: followingOnly,
            onTap: () => _updateTagFeedFilters(tagValue, followingOnly: true),
            icon: Icons.people_alt,
          ),
          buildChip(
            label: 'AR only',
            active: arOnly,
            onTap: () => _updateTagFeedFilters(tagValue, arOnly: !arOnly),
            icon: Icons.view_in_ar_outlined,
          ),
          buildChip(
            label: sortMode == 'popularity' ? 'Popularity' : 'Recent',
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

  Widget _buildSearchOverlay(ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassTint = scheme.surface.withValues(alpha: isDark ? 0.22 : 0.26);
    final trimmedQuery = _searchQuery.trim();
    if (!_isFetchingSearch &&
        _searchResults.isEmpty &&
        trimmedQuery.length < 2) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: CompositedTransformFollower(
        link: _searchFieldLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 50),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 320,
            maxHeight: 320,
          ),
          child: LiquidGlassPanel(
            padding: const EdgeInsets.symmetric(vertical: 8),
            margin: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(12),
            blurSigma: KubusGlassEffects.blurSigmaLight,
            backgroundColor: glassTint,
            child: Builder(
              builder: (context) {
                if (trimmedQuery.length < 2) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Type at least 2 characters to search',
                      style: GoogleFonts.inter(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  );
                }

                if (_isFetchingSearch) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (_searchResults.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_off,
                          color: scheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'No results found',
                          style: GoogleFonts.inter(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: scheme.outlineVariant,
                  ),
                  itemBuilder: (context, index) {
                    final profile = _searchResults[index];
                    final wallet = (profile['wallet_address'] ??
                            profile['walletAddress'] ??
                            profile['wallet'])
                        ?.toString();

                    final identity = UserIdentityDisplayUtils.fromProfileMap(
                      Map<String, dynamic>.from(
                        profile.map((k, v) => MapEntry(k.toString(), v)),
                      ),
                    );
                    final subtitleText = identity.handle;

                    final avatarUrl = profile['avatar'] ??
                        profile['avatar_url'] ??
                        profile['profileImageUrl'];
                    return ListTile(
                      leading: AvatarWidget(
                        avatarUrl: avatarUrl?.toString(),
                        wallet: wallet ?? '',
                        radius: 20,
                        allowFabricatedFallback: true,
                      ),
                      title: Text(
                        identity.name,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: subtitleText == null
                          ? null
                          : Text(
                              subtitleText,
                              style: GoogleFonts.inter(
                                color: scheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                      onTap: () => _handleSearchResultTap(profile),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5)
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: Colors.white,
        unselectedLabelColor:
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
        ),
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              themeProvider.accentColor,
              themeProvider.accentColor.withValues(alpha: 0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: themeProvider.accentColor.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsets.zero,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        tabs: _tabs
            .map((tab) => Tab(
                  height: 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(tab),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildSortControls(ThemeProvider themeProvider) {
    if (_paneStack.isNotEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final currentTab = _tabs[_tabController.index];
    if (currentTab == 'Groups') return const SizedBox.shrink();
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
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (isSelected) {
          if (isSelected) _changeSortForTab(currentTab, value);
        },
        selectedColor: themeProvider.accentColor,
        backgroundColor: scheme.surfaceContainerHighest,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
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
            'Sort',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 12),
          buildChip('Recent', 'recent', Icons.schedule),
          const SizedBox(width: 8),
          buildChip('Top', 'popularity', Icons.trending_up),
        ],
      ),
    );
  }

  String _sortModeForTab(String tabName) {
    switch (tabName) {
      case 'Following':
        return _followingSortMode;
      case 'Art':
        return _artSortMode;
      default:
        return _discoverSortMode;
    }
  }

  void _changeSortForTab(String tabName, String mode) {
    switch (tabName) {
      case 'Following':
        if (_followingSortMode == mode) return;
        _followingSortMode = mode;
        _loadFollowingFeed(sortOverride: mode);
        break;
      case 'Art':
        if (_artSortMode == mode) return;
        setState(() {
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

  void _handleSearchChange(String value) {
    setState(() {
      _searchQuery = value;
      _showSearchOverlay = value.trim().isNotEmpty;
    });

    _searchDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      setState(() {
        _searchResults = [];
        _isFetchingSearch = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 275), () async {
      setState(() => _isFetchingSearch = true);
      try {
        final response = await _backendApi.search(
          query: trimmed,
          type: 'profiles',
          limit: 12,
        );
        final parsed = _parseProfileSearchResults(response);
        if (!mounted) return;
        setState(() {
          _searchResults = parsed;
          _isFetchingSearch = false;
          _showSearchOverlay = true;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _searchResults = [];
          _isFetchingSearch = false;
        });
      }
    });
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
    setState(() {
      _searchQuery = value.trim();
      _showSearchOverlay = false;
      _searchResults = [];
      _isFetchingSearch = false;
    });
  }

  void _handleSearchResultTap(Map<String, dynamic> profile) {
    final identity = UserIdentityDisplayUtils.fromProfileMap(profile);
    final label = identity.name == 'Unknown creator' ? '' : identity.name;
    setState(() {
      if (label.isNotEmpty) {
        _communitySearchController.text = label;
        _searchQuery = label;
      }
      _showSearchOverlay = false;
      _searchResults = [];
      _isFetchingSearch = false;
    });

    final wallet = profile['wallet_address'] ??
        profile['walletAddress'] ??
        profile['wallet'] ??
        profile['id'];

    if (wallet != null && wallet.toString().isNotEmpty) {
      _openUserProfileModal(userId: wallet.toString());
    }
  }

  Widget _buildFeedList(String tabName, ThemeProvider themeProvider) {
    // Route to appropriate tab content
    switch (tabName) {
      case 'Following':
        return _buildFollowingFeed(themeProvider);
      case 'Groups':
        return _buildGroupsTab(themeProvider);
      case 'Art':
        return _buildArtFeed(themeProvider);
      default:
        return _buildDiscoverFeed(themeProvider);
    }
  }

  List<CommunityPost> _filterPostsForQuery(List<CommunityPost> posts) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return posts;

    return posts.where((post) {
      final contentMatch = post.content.toLowerCase().contains(query);
      final authorMatch = post.authorName.toLowerCase().contains(query) ||
          (post.authorUsername?.toLowerCase().contains(query) ?? false);
      final tagMatch = post.tags.any((t) => t.toLowerCase().contains(query));
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
    final posts =
        _sortPosts(_filterPostsForQuery(_discoverPosts), _discoverSortMode);

    if (_isLoadingDiscover && _discoverPosts.isEmpty) {
      return _buildLoadingState(themeProvider, 'Loading posts...');
    }

    if (_discoverError != null && _discoverPosts.isEmpty) {
      return _buildErrorState(
          themeProvider, _discoverError!, _loadDiscoverFeed);
    }

    if (posts.isEmpty) {
      return _buildEmptyState(
        themeProvider,
        Icons.travel_explore,
        'No Posts Yet',
        _searchQuery.isEmpty
            ? 'Posts from creators around the world will appear here.'
            : 'No posts match your search.',
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
    final scheme = Theme.of(context).colorScheme;
    final accent = themeProvider.accentColor;
    final l10n = AppLocalizations.of(context)!;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final shellScope = DesktopShellScope.of(context);
          if (shellScope != null) {
            shellScope.pushScreen(
              DesktopSubScreen(
                title: 'Season 0',
                child: const Season0Screen(),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Season0Screen()),
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.12),
                scheme.primaryContainer.withValues(alpha: 0.3)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(Icons.rocket_launch_outlined, color: accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.season0BannerTitle,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.season0BannerTap,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: scheme.onSurface.withValues(alpha: 0.35)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFollowingFeed(ThemeProvider themeProvider) {
    final posts =
        _sortPosts(_filterPostsForQuery(_followingPosts), _followingSortMode);

    if (_isLoadingFollowing && _followingPosts.isEmpty) {
      return _buildLoadingState(themeProvider, 'Loading posts...');
    }

    if (_followingError != null && _followingPosts.isEmpty) {
      return _buildErrorState(
          themeProvider, _followingError!, _loadFollowingFeed);
    }

    if (posts.isEmpty) {
      return _buildEmptyState(
        themeProvider,
        Icons.people_outline,
        'No Posts From Followed Creators',
        _searchQuery.isEmpty
            ? 'Follow artists and creators to see their updates here.'
            : 'No followed posts match your search.',
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
        final allPosts = communityProvider.artFeedPosts;
        final isLoading = communityProvider.artFeedLoading;
        final error = communityProvider.artFeedError;

        if (isLoading && allPosts.isEmpty) {
          return _buildLoadingState(themeProvider, 'Loading nearby art...');
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
            'No Nearby Art Found',
            'Explore your surroundings to discover location-based art.',
          );
        }

        final posts = _sortPosts(_filterPostsForQuery(allPosts), _artSortMode);
        if (posts.isEmpty) {
          return _buildEmptyState(
            themeProvider,
            Icons.search,
            'No posts match your search',
            'Try adjusting your keywords to find relevant art posts.',
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
              controller: _scrollController,
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
                          label: const Text('Use current area'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.accentColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
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
                          label: const Text('Wider radius'),
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
    final scheme = Theme.of(context).colorScheme;
    final animationTheme = context.animationTheme;
    final tabIndex = _tabController.index;
    final options = _getFabOptions(tabIndex);

    if (options.length > 1) {
      return _buildExpandableFab(
        themeProvider: themeProvider,
        scheme: scheme,
        animationTheme: animationTheme,
        mainIcon: Icons.add,
        mainLabel: 'Create',
        options: options,
      );
    }

    final single = options.first;
    return FloatingActionButton.extended(
      heroTag: 'desktop_comm_fab_$tabIndex',
      onPressed: single.onTap,
      backgroundColor: themeProvider.accentColor,
      icon: Icon(single.icon, color: scheme.onSurface),
      label: Text(single.label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
    );
  }

  List<_FabOption> _getFabOptions(int tabIndex) {
    switch (tabIndex) {
      case 2: // Groups
        return [
          _FabOption(
            icon: Icons.group_add_outlined,
            label: 'Create group',
            onTap: () {
              setState(() => _isFabExpanded = false);
              _showCreateGroupDialog(
                  Provider.of<ThemeProvider>(context, listen: false));
            },
          ),
          _FabOption(
            icon: Icons.post_add_outlined,
            label: 'Group post',
            onTap: () {
              setState(() {
                _isFabExpanded = false;
                _showComposeDialog = true;
              });
            },
          ),
        ];
      case 3: // Art
        return [
          _FabOption(
            icon: Icons.place_outlined,
            label: 'Art drop',
            onTap: () {
              setState(() {
                _isFabExpanded = false;
                _showComposeDialog = true;
              });
              _showARAttachmentInfo();
            },
          ),
          _FabOption(
            icon: Icons.rate_review_outlined,
            label: 'Post review',
            onTap: () {
              setState(() {
                _isFabExpanded = false;
                _showComposeDialog = true;
              });
            },
          ),
        ];
      default:
        return [
          _FabOption(
            icon: Icons.edit_outlined,
            label: 'Post',
            onTap: () {
              setState(() {
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
    required List<_FabOption> options,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSize(
          duration: animationTheme.medium,
          curve: animationTheme.emphasisCurve,
          child: _isFabExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(
                        milliseconds:
                            animationTheme.medium.inMilliseconds + (index * 50),
                      ),
                      curve: animationTheme.emphasisCurve,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 16 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: scheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                option.label,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FloatingActionButton.small(
                              heroTag:
                                  'desktop_comm_fab_option_${option.label}',
                              onPressed: () {
                                setState(() => _isFabExpanded = false);
                                option.onTap();
                              },
                              backgroundColor: scheme.primaryContainer,
                              foregroundColor: scheme.onSurface,
                              child: Icon(option.icon, size: 20),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.extended(
          heroTag: 'desktop_comm_fab_main',
          onPressed: () => setState(() => _isFabExpanded = !_isFabExpanded),
          backgroundColor: _isFabExpanded
              ? scheme.surfaceContainerHighest
              : themeProvider.accentColor,
          foregroundColor: _isFabExpanded ? scheme.onSurface : scheme.onPrimary,
          icon: AnimatedRotation(
            turns: _isFabExpanded ? 0.125 : 0,
            duration: animationTheme.short,
            child: Icon(_isFabExpanded ? Icons.close : mainIcon),
          ),
          label: AnimatedSwitcher(
            duration: animationTheme.short,
            child: Text(
              _isFabExpanded ? 'Close' : mainLabel,
              key: ValueKey(_isFabExpanded),
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupsTab(ThemeProvider themeProvider) {
    return Consumer<CommunityHubProvider>(
      builder: (context, communityProvider, _) {
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
          return _buildLoadingState(themeProvider, 'Loading groups...');
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
            'No Groups Yet',
            'Join or create groups to connect with like-minded art enthusiasts.',
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
                          hintText: 'Search groups...',
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
                        label: const Text('Create'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeProvider.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final communityProvider =
        Provider.of<CommunityHubProvider>(context, listen: false);

    await showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Create Group',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Group name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration:
                  const InputDecoration(labelText: 'Description (optional)'),
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
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.commonCreate),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(
      CommunityGroupSummary group, ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Theme.of(context).colorScheme.surface
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final shellScope = DesktopShellScope.of(context);
            if (shellScope != null) {
              shellScope.pushScreen(
                DesktopSubScreen(
                  title: group.name,
                  child: GroupFeedScreen(group: group),
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
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Group avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: themeProvider.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      group.coverImage != null && group.coverImage!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                group.coverImage!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.groups,
                                  color: themeProvider.accentColor,
                                  size: 28,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.groups,
                              color: themeProvider.accentColor,
                              size: 28,
                            ),
                ),
                const SizedBox(width: 16),
                // Group info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (group.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          group.description!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${group.memberCount} members',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          if (group.latestPost?.createdAt != null) ...[
                            const SizedBox(width: 16),
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Latest: ${_formatTimeAgo(group.latestPost!.createdAt!)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildLoadingState(ThemeProvider themeProvider, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: themeProvider.accentColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14,
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
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.error_outline,
              size: 36,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Failed to load',
            style: GoogleFonts.inter(
              fontSize: 17,
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
              error,
              style: GoogleFonts.inter(
                fontSize: 14,
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
                foregroundColor: Colors.white,
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
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 36,
              color: themeProvider.accentColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 17,
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
              style: GoogleFonts.inter(
                fontSize: 14,
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

  Widget _buildPostCard(CommunityPost post, ThemeProvider themeProvider) {
    if (MediaQuery.of(context).size.width >= 0) {
      return CommunityPostCard(
        post: post,
        accentColor: themeProvider.accentColor,
        onOpenPostDetail: _openPostDetail,
        onOpenAuthorProfile: () => unawaited(
          _openUserProfileModal(
            userId: post.authorId,
            username: post.authorUsername,
          ),
        ),
        onToggleLike: () => _togglePostLike(post),
        onOpenComments: () => _openPostDetail(post),
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
      );
    }

    return DesktopCard(
      onTap: () => _openPostDetail(post),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              AvatarWidget(
                avatarUrl: post.authorAvatar,
                wallet: post.authorId,
                radius: 22,
                allowFabricatedFallback: true,
              ),
              const SizedBox(width: 12),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                            CommunityAuthorRoleBadges(
                              post: post,
                              fontSize: 9,
                              iconOnly: false,
                            ),
                      ],
                    ),
                    Text(
                      _formatTimeAgo(post.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  // Show more options
                },
                icon: Icon(
                  Icons.more_horiz,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content
          Text(
            post.content,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          // Tags
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: post.tags
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: KubusColorRoles.of(context)
                              .tagChipBackground
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '#$tag',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: KubusColorRoles.of(context).tagChipBackground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],

          // Media preview
          if (post.imageUrl != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 280,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      themeProvider.accentColor.withValues(alpha: 0.3),
                      themeProvider.accentColor.withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.image,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],

          // AR artwork link
          if (post.artwork != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: themeProvider.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.view_in_ar,
                      color: themeProvider.accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AR Artwork',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Tap to view in augmented reality',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Action row
          Row(
            children: [
              _buildActionButton(
                icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                label: _formatTrendingCount(post.likeCount),
                themeProvider: themeProvider,
                isActive: post.isLiked,
                activeColor: AppColorUtils.coralAccent,
                onPressed: () => _togglePostLike(post),
              ),
              const SizedBox(width: 24),
              _buildActionButton(
                icon: Icons.chat_bubble_outline,
                label: _formatTrendingCount(post.commentCount),
                themeProvider: themeProvider,
                activeColor: Theme.of(context).colorScheme.secondary,
                onPressed: () => _openPostDetail(post),
              ),
              const SizedBox(width: 24),
              _buildActionButton(
                icon: Icons.repeat,
                label: _formatTrendingCount(post.shareCount),
                themeProvider: themeProvider,
                activeColor: Theme.of(context).colorScheme.tertiary,
                onPressed: () => _showRepostOptions(post),
              ),
              const Spacer(),
              IconButton(
                tooltip:
                    post.isBookmarked ? 'Remove bookmark' : 'Save for later',
                onPressed: () => _toggleBookmark(post),
                icon: Icon(
                  post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: post.isBookmarked
                      ? themeProvider.accentColor
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                ),
              ),
              IconButton(
                tooltip: 'Share',
                onPressed: () => _showShareDialog(post),
                icon: Icon(
                  Icons.share_outlined,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required ThemeProvider themeProvider,
    required VoidCallback onPressed,
    bool isActive = false,
    VoidCallback? onLabelTap,
    Color? activeColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveActiveColor = activeColor ?? themeProvider.accentColor;
    final color = isActive
        ? effectiveActiveColor
        : scheme.onSurface.withValues(alpha: label.isEmpty ? 0.5 : 0.65);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        hoverColor: effectiveActiveColor.withValues(alpha: 0.08),
        splashColor: effectiveActiveColor.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isActive ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: Icon(icon, size: 18, color: color),
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onLabelTap ?? onPressed,
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: color,
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

  Future<void> _togglePostLike(CommunityPost post) async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final wasLiked = post.isLiked;
    try {
      await CommunityService.togglePostLike(
        post,
        currentUserWallet: walletProvider.currentWalletAddress,
      );
      if (!mounted) return;
      setState(() {});
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(wasLiked ? 'Post unliked' : 'Post liked'),
          duration: const Duration(milliseconds: 1300),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {});
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text('Failed to ${wasLiked ? 'unlike' : 'like'} post: $e'),
        ),
      );
    }
  }

  Future<void> _toggleBookmark(CommunityPost post) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await CommunityService.toggleBookmark(post);
      if (!mounted) return;
      setState(() {});
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(post.isBookmarked
              ? 'Saved to bookmarks'
              : 'Removed from bookmarks'),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text('Failed to update bookmark: $e')),
      );
    }
  }

  Future<void> _showShareDialog(CommunityPost post) async {
    await ShareService().showShareSheet(
      context,
      target: ShareTarget.post(postId: post.id, title: post.content),
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
      setState(() {
        _isComposerExpanded = true;
        _selectedCategory = hub.draft.category.isNotEmpty ? hub.draft.category : _selectedCategory;
      });
    });
  }

  Future<void> _showRepostOptions(CommunityPost post) async {
    await showKubusDialog(
      context: context,
      builder: (dialogContext) {
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
                      Icon(icon, size: 18, color: iconColor ?? scheme.onSurface),
                      const SizedBox(width: KubusSpacing.md),
                      Expanded(child: Text(label)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return KubusAlertDialog(
          title: const Text('Share post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              optionTile(
                icon: Icons.repeat,
                label: 'Quick repost',
                onTap: () => _createRepost(post),
              ),
              const SizedBox(height: KubusSpacing.md),
              optionTile(
                icon: Icons.edit_note,
                label: 'Repost with comment',
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
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return KubusAlertDialog(
              title: const Text('Repost with comment'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Add your thoughts (optional)',
                        border: OutlineInputBorder(),
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Text('Repost'),
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
    try {
      final createdRepost = await BackendApiService().createRepost(
        originalPostId: post.id,
        content: comment != null && comment.trim().isNotEmpty
            ? comment.trim()
            : null,
      );
      if (!mounted) return false;
      setState(() {
        post.shareCount++;
        _discoverPosts = _prependUniquePost(_discoverPosts, createdRepost);
        _followingPosts = _prependUniquePost(_followingPosts, createdRepost);
      });
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(comment != null && comment.trim().isNotEmpty
              ? 'Reposted with comment'
              : 'Reposted'),
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      messenger.showKubusSnackBar(
        SnackBar(content: Text('Failed to repost: $e')),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  displayPost.authorName,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              CommunityAuthorRoleBadges(
                post: displayPost,
                fontSize: 8,
                iconOnly: false,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            displayPost.content,
            style: GoogleFonts.inter(
              fontSize: 13,
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
    final lat = location.lat;
    final lng = location.lng;
    if (lat == null || lng == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          initialCenter: LatLng(lat, lng),
          initialZoom: 15,
          autoFollow: false,
        ),
      ),
    );
  }

  void _openGroupFromPost(CommunityGroupReference group) {
    final summary = CommunityGroupSummary(
      id: group.id,
      name: group.name,
      slug: group.slug,
      coverImage: group.coverImage,
      description: group.description,
      isPublic: true,
      ownerWallet: '',
      memberCount: 0,
      isMember: false,
      isOwner: false,
    );

    final shellScope = DesktopShellScope.of(context);
    if (shellScope != null) {
      shellScope.pushScreen(
        DesktopSubScreen(
          title: summary.name,
          child: GroupFeedScreen(group: summary),
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
    if (post.postType == 'repost' && WalletUtils.equals(authorWallet, currentWallet)) {
      unawaited(_showUnrepostOptions(post));
      return;
    }
    unawaited(_showRepostOptions(post));
  }

  Future<void> _showUnrepostOptions(CommunityPost post) async {
    final l10n = AppLocalizations.of(context)!;
    await showKubusDialog(
      context: context,
      builder: (dialogContext) {
        Widget optionTile({
          required IconData icon,
          required String label,
          Color? iconColor,
          TextStyle? textStyle,
          required VoidCallback onTap,
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
                  Navigator.of(dialogContext).pop();
                  onTap();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.lg,
                    vertical: KubusSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: iconColor ?? scheme.onSurface),
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
                textStyle: GoogleFonts.inter(color: scheme.error),
                onTap: () => unawaited(_unrepostPost(post)),
              ),
              const SizedBox(height: KubusSpacing.md),
              optionTile(
                icon: Icons.cancel,
                label: l10n.commonCancel,
                iconColor: scheme.onSurface.withValues(alpha: 0.65),
                onTap: () {},
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _unrepostPost(CommunityPost post) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        title: Text(l10n.communityUnrepostTitle, style: GoogleFonts.inter()),
        content: Text(l10n.communityUnrepostConfirmBody, style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel, style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(l10n.communityUnrepostAction, style: GoogleFonts.inter()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await BackendApiService().deleteRepost(post.id);
      BackendApiService().trackAnalyticsEvent(
        eventType: 'repost_deleted',
        postId: post.originalPostId ?? post.id,
        metadata: {'repost_id': post.id},
      );

      await Future.wait([_loadDiscoverFeed(), _loadFollowingFeed()]);
      if (!mounted) return;
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.communityRepostRemovedToast)));
    } catch (e) {
      if (!mounted) return;
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.communityUnrepostFailedToast)));
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
    if (!mounted) return;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final future = loader();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: theme.colorScheme.onSurface,
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<CommunityLikeUser>>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: InlineLoading(
                            expand: true,
                            shape: BoxShape.circle,
                            tileSize: 4.0,
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l10n.postDetailLoadLikesFailedMessage,
                            style: GoogleFonts.inter(color: theme.colorScheme.onSurface),
                          ),
                        ),
                      );
                    }

                    final likes = snapshot.data ?? <CommunityLikeUser>[];
                    if (likes.isEmpty) {
                      return Center(
                        child: EmptyStateCard(
                          icon: Icons.favorite_border,
                          title: l10n.postDetailNoLikesTitle,
                          description: l10n.postDetailNoLikesDescription,
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      itemCount: likes.length,
                      separatorBuilder: (_, __) => Divider(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      itemBuilder: (context, index) {
                        final user = likes[index];
                        final subtitleParts = <String>[];
                        if (user.username != null && user.username!.isNotEmpty) {
                          subtitleParts.add('@${user.username}');
                        }
                        if (user.likedAt != null) {
                          subtitleParts.add(_formatTimeAgo(user.likedAt));
                        }
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: AvatarWidget(
                            wallet: user.walletAddress ?? user.userId,
                            avatarUrl: user.avatarUrl,
                            radius: 20,
                            enableProfileNavigation: true,
                          ),
                          title: Text(
                            user.displayName.isNotEmpty ? user.displayName : l10n.commonUnnamed,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          subtitle: subtitleParts.isNotEmpty
                              ? Text(
                                  subtitleParts.join(' • '),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
        );
      },
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
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
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        l10n.communityRepostsLoadFailedMessage,
                        style: GoogleFonts.inter(),
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
                      final username = user?['username'] ??
                          user?['walletAddress'] ??
                          l10n.commonUnknown;
                      final displayName = user?['displayName'] ?? username;
                      final avatar = user?['avatar'];
                      final comment = repost['repostComment'] as String?;
                      final createdAt = DateTime.tryParse(repost['createdAt'] ?? '');

                      return ListTile(
                        leading: AvatarWidget(
                          wallet: username,
                          avatarUrl: avatar,
                          radius: 20,
                        ),
                        title: Text(
                          displayName,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('@$username', style: GoogleFonts.inter(fontSize: 12)),
                            if (comment != null && comment.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                comment,
                                style: GoogleFonts.inter(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                        trailing: createdAt != null
                            ? Text(
                                _formatTimeAgo(createdAt),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
    setState(() {
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
    return Column(
      children: [
          // Sidebar tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                const SizedBox(width: 8),
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
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildCreatePostPrompt(themeProvider),
                      const SizedBox(height: 24),
                      _buildTrendingSection(themeProvider),
                      const SizedBox(height: 24),
                      _buildWhoToFollowSection(themeProvider),
                      const SizedBox(height: 24),
                      _buildActiveCommunitiesSection(themeProvider),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? themeProvider.accentColor.withValues(alpha: 0.4)
                  : Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.1),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: themeProvider.accentColor.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? themeProvider.accentColor
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? themeProvider.accentColor
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
    setState(() {
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: scheme.outline.withValues(alpha: 0.18),
                          ),
                        ),
                        child: LiquidGlassPanel(
                          // Keep the glass background full-bleed; spacing belongs to the input.
                          padding: EdgeInsets.zero,
                          margin: EdgeInsets.zero,
                          borderRadius: BorderRadius.circular(12),
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
                              hintText: 'Search messages...',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 14,
                                color: scheme.onSurface.withValues(alpha: 0.5),
                              ),
                              border: InputBorder.none,
                              prefixIcon: Icon(
                                Icons.search,
                                size: 20,
                                color:
                                    scheme.onSurface.withValues(alpha: 0.45),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              suffixIcon: trimmedQuery.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
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
                            style: GoogleFonts.inter(fontSize: 14),
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
                    filteredConversations.length == 1
                        ? 'Showing 1 result for â€œ$trimmedQueryâ€'
                        : 'Showing ${filteredConversations.length} results for â€œ$trimmedQueryâ€',
                    style: GoogleFonts.inter(
                      fontSize: 12,
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

  Widget _buildConversationItem(
    Conversation conversation,
    ThemeProvider themeProvider,
    ChatProvider chatProvider, {
    String? searchHighlight,
    bool showSearchContext = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final unreadCount = chatProvider.unreadCounts[conversation.id] ?? 0;
    final hasUnread = unreadCount > 0;
    final isActive = _activeConversationId == conversation.id;
    final baseColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05);
    final bool highlightActive =
        showSearchContext && (searchHighlight?.isNotEmpty ?? false);

    final bool isOneToOne = conversation.isGroup != true;
    final String otherWallet = isOneToOne ? _resolveConversationOtherWallet(conversation) : '';
    final String avatarWallet = isOneToOne && otherWallet.isNotEmpty
        ? otherWallet
        : (conversation.memberWallets.isNotEmpty ? conversation.memberWallets.first : '');

    final List<Widget> subtitleLines = [];
    if (isOneToOne && otherWallet.isNotEmpty) {
      subtitleLines.add(
        UserActivityStatusLine(
          walletAddress: otherWallet,
          textAlign: TextAlign.start,
          textStyle: GoogleFonts.inter(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    if (highlightActive) {
      if (subtitleLines.isNotEmpty) subtitleLines.add(const SizedBox(height: 2));
      subtitleLines.add(
        Text(
          searchHighlight!,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.secondary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else if ((conversation.lastMessage ?? '').trim().isNotEmpty) {
      if (subtitleLines.isNotEmpty) subtitleLines.add(const SizedBox(height: 2));
      subtitleLines.add(
        Text(
          conversation.lastMessage!,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openConversation(conversation),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? scheme.secondary.withValues(alpha: 0.12)
                : hasUnread
                    ? scheme.secondary.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(
                    color: scheme.secondary.withValues(alpha: 0.4), width: 1.2)
                : Border.all(color: baseColor, width: hasUnread ? 1 : 0),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  AvatarWidget(
                    avatarUrl: conversation.displayAvatar,
                    wallet: avatarWallet,
                    radius: 24,
                    allowFabricatedFallback: true,
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: scheme.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.title ??
                          l10n.messagesFallbackConversationTitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight:
                            hasUnread ? FontWeight.w600 : FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitleLines.isNotEmpty) ...subtitleLines,
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTimeAgo(conversation.lastMessageAt),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveConversationOtherWallet(Conversation conversation) {
    final counterpart = conversation.counterpartProfile?.wallet ?? '';
    if (counterpart.trim().isNotEmpty) return counterpart.trim();

    ProfileProvider? profileProvider;
    try {
      profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    } catch (_) {
      profileProvider = null;
    }
    final myWallet = profileProvider?.currentUser?.walletAddress ?? '';

    for (final w in conversation.memberWallets) {
      final candidate = w.trim();
      if (candidate.isEmpty) continue;
      if (myWallet.isNotEmpty && WalletUtils.equals(candidate, myWallet)) continue;
      return candidate;
    }

    return '';
  }

  Widget _buildEmptyMessagesState(ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: scheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with an artist',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: scheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoConversationMatchesState(
      ThemeProvider themeProvider, String queryLabel) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: scheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No matches found',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          if (queryLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'We couldn\'t find any conversations, members, or messages matching â€œ$queryLabelâ€.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _messageSearchController.clear(),
            icon: const Icon(Icons.refresh),
            label: const Text('Clear search'),
          ),
        ],
      ),
    );
  }

  List<String> _buildMessageSearchVariants(String rawQuery) {
    final normalized = rawQuery.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    final variants = <String>[];

    void addVariant(String value) {
      final candidate = value.trim().toLowerCase();
      if (candidate.isEmpty) return;
      if (!variants.contains(candidate)) variants.add(candidate);
    }

    addVariant(normalized);
    addVariant(normalized.replaceAll(RegExp(r'\s+'), ' '));

    for (final token in normalized.split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      addVariant(token);
      if (token.startsWith('@') && token.length > 1) {
        addVariant(token.substring(1));
      }
    }

    return variants;
  }

  List<Conversation> _applyMessageSearchFilters(
    List<Conversation> conversations,
    ChatProvider chatProvider,
    List<String> queryVariants,
    Map<String, String> highlightMap,
  ) {
    if (queryVariants.isEmpty) return conversations;
    final hits = <_ConversationSearchResult>[];

    for (final conversation in conversations) {
      final match = _matchConversationForSearch(
          conversation, chatProvider, queryVariants);
      if (match == null) continue;
      if ((match.highlight ?? '').isNotEmpty) {
        highlightMap[conversation.id] = match.highlight!;
      }
      hits.add(match);
    }

    hits.sort((a, b) {
      final scoreDiff = b.score.compareTo(a.score);
      if (scoreDiff != 0) return scoreDiff;
      final aDate = a.conversation.lastMessageAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.conversation.lastMessageAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final dateDiff = bDate.compareTo(aDate);
      if (dateDiff != 0) return dateDiff;
      final aTitle = a.conversation.title ?? a.conversation.rawTitle ?? '';
      final bTitle = b.conversation.title ?? b.conversation.rawTitle ?? '';
      return aTitle.compareTo(bTitle);
    });

    return hits.map((hit) => hit.conversation).toList();
  }

  _ConversationSearchResult? _matchConversationForSearch(
    Conversation conversation,
    ChatProvider chatProvider,
    List<String> queryVariants,
  ) {
    if (queryVariants.isEmpty) return null;
    double bestScore = 0;
    String? bestHighlight;

    void register(double score, String highlight) {
      if (score > bestScore ||
          (score == bestScore &&
              (bestHighlight == null ||
                  highlight.length < bestHighlight!.length))) {
        bestScore = score;
        bestHighlight = highlight;
      }
    }

    final title = (conversation.title ?? conversation.rawTitle ?? '').trim();
    final titlePreview = _matchField(title, queryVariants);
    if (titlePreview != null) {
      register(4.0, 'Title match • $titlePreview');
    }

    final preloaded =
        chatProvider.getPreloadedProfileMapsForConversation(conversation.id);
    final memberNames = <String>{};
    final memberWallets = <String>{};

    void addName(String? value) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) return;
      memberNames.add(trimmed);
    }

    void addWallet(String? wallet) {
      final normalized = WalletUtils.normalize(wallet);
      if (normalized.isEmpty) return;
      memberWallets.add(normalized);
    }

    for (final profile in conversation.memberProfiles) {
      addName(profile.displayName);
      addWallet(profile.wallet);
    }
    if (conversation.counterpartProfile != null) {
      addName(conversation.counterpartProfile!.displayName);
      addWallet(conversation.counterpartProfile!.wallet);
    }
    for (final wallet in conversation.memberWallets) {
      addWallet(wallet);
    }

    final namesMap = preloaded['names'];
    if (namesMap is Map) {
      namesMap.forEach((key, value) {
        if (key is String) addWallet(key);
        if (value is String) addName(value);
      });
    }
    final membersList = preloaded['members'];
    if (membersList is List) {
      for (final entry in membersList) {
        if (entry == null) continue;
        addWallet(entry.toString());
      }
    }

    for (final name in memberNames) {
      final snippet = _matchField(name, queryVariants);
      if (snippet != null) {
        register(3.2, 'Member • $snippet');
        break;
      }
    }

    for (final wallet in memberWallets) {
      final snippet = _matchWallet(wallet, queryVariants);
      if (snippet != null) {
        register(2.8, snippet);
        break;
      }
    }

    final lastMessageSnippet =
        _matchField(conversation.lastMessage, queryVariants);
    if (lastMessageSnippet != null) {
      register(2.6, 'Latest message • â€œ$lastMessageSnippetâ€');
    }

    final cachedMessages = chatProvider.messages[conversation.id];
    if (cachedMessages != null && cachedMessages.isNotEmpty) {
      for (final message in cachedMessages) {
        final snippet = _matchField(message.message, queryVariants);
        if (snippet != null) {
          final sender = (message.senderDisplayName ??
                  message.senderUsername ??
                  message.senderWallet)
              .trim();
          final prefix = sender.isNotEmpty ? '$sender • ' : '';
          register(2.4, 'Message • $prefixâ€œ$snippetâ€');
          break;
        }
      }
    }

    if (bestScore <= 0 || bestHighlight == null || bestHighlight!.isEmpty) {
      return null;
    }

    return _ConversationSearchResult(
      conversation: conversation,
      score: bestScore,
      highlight: bestHighlight,
    );
  }

  String? _matchField(String? source, List<String> queryVariants) {
    final value = source?.trim();
    if (value == null || value.isEmpty) return null;
    final lower = value.toLowerCase();
    for (final variant in queryVariants) {
      if (variant.isEmpty) continue;
      final index = lower.indexOf(variant);
      if (index != -1) {
        return _buildMatchPreview(value, index, variant.length);
      }
    }
    return null;
  }

  String? _matchWallet(String? wallet, List<String> queryVariants) {
    final normalized = WalletUtils.normalize(wallet);
    if (normalized.isEmpty) return null;
    final lower = normalized.toLowerCase();
    for (final variant in queryVariants) {
      if (variant.isEmpty) continue;
      if (lower.contains(variant)) {
        return 'Wallet match • ${_shortenWallet(normalized)}';
      }
    }
    return null;
  }

  String _buildMatchPreview(String value, int matchStart, int matchLength) {
    const radius = 18;
    final start = math.max(0, matchStart - radius);
    final end = math.min(value.length, matchStart + matchLength + radius);
    final prefix = start > 0 ? 'â€¦' : '';
    final suffix = end < value.length ? 'â€¦' : '';
    final snippet = value.substring(start, end).trim();
    if (snippet.isEmpty) return value;
    return '$prefix$snippet$suffix';
  }

  String _shortenWallet(String wallet) {
    if (wallet.length <= 12) return wallet;
    return '${wallet.substring(0, 4)}â€¦${wallet.substring(wallet.length - 4)}';
  }

  void _startNewConversation() {
    // Show dialog to start new conversation
    showKubusDialog(
      context: context,
      builder: (dialogContext) => _NewConversationDialog(
        themeProvider: Provider.of<ThemeProvider>(dialogContext),
        onStartConversation: (walletAddress) async {
          final target = walletAddress.trim();
          Navigator.of(dialogContext).pop();
          if (target.isEmpty) return;

          final chatProvider = context.read<ChatProvider>();
          final messenger = ScaffoldMessenger.of(context);
          try {
            final conv =
                await chatProvider.createConversation('', false, [target]);
            if (!mounted) return;
            if (conv != null) {
              _openConversation(conv);
              return;
            }
            messenger.showKubusSnackBar(
              const SnackBar(content: Text('Unable to start conversation')),
            );
          } catch (e) {
            if (!mounted) return;
            messenger.showKubusSnackBar(
              SnackBar(content: Text('Unable to start conversation: $e')),
            );
          }
        },
      ),
    );
  }

  void _openConversation(Conversation conversation) {
    setState(() {
      _showMessagesPanel = true;
      _activeConversationId = conversation.id;
      _paneStack.removeWhere(
        (route) =>
            route.type == _PaneViewType.conversation &&
            route.conversation?.id == conversation.id,
      );
      _paneStack.add(_PaneRoute.conversation(conversation));
    });
  }

  Widget _buildCreatePostPrompt(ThemeProvider themeProvider) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final user = profileProvider.currentUser;
    final hub = Provider.of<CommunityHubProvider>(context);
    final animationTheme = context.animationTheme;

    return AnimatedContainer(
      duration: animationTheme.medium,
      curve: animationTheme.emphasisCurve,
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isComposerExpanded
              ? themeProvider.accentColor.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: _isComposerExpanded ? 1.5 : 1,
        ),
        boxShadow: _isComposerExpanded
            ? [
                BoxShadow(
                  color: themeProvider.accentColor.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Collapsed prompt / Header
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  setState(() => _isComposerExpanded = !_isComposerExpanded),
              borderRadius: BorderRadius.circular(_isComposerExpanded ? 0 : 16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    AvatarWidget(
                      avatarUrl: user?.avatar,
                      wallet: user?.walletAddress ?? '',
                      radius: 18,
                      allowFabricatedFallback: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedCrossFade(
                        duration: animationTheme.short,
                        crossFadeState: _isComposerExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'What\'s happening?',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        secondChild: Text(
                          'Create Post',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedRotation(
                      turns: _isComposerExpanded ? 0.5 : 0,
                      duration: animationTheme.short,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isComposerExpanded
                              ? Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                              : themeProvider.accentColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _isComposerExpanded
                              ? Icons.expand_less
                              : Icons.edit_outlined,
                          size: 16,
                          color: _isComposerExpanded
                              ? Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expanded composer content
          AnimatedCrossFade(
            duration: animationTheme.medium,
            sizeCurve: animationTheme.emphasisCurve,
            crossFadeState: _isComposerExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedComposer(themeProvider, user, hub),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedComposer(
    ThemeProvider themeProvider,
    dynamic user,
    CommunityHubProvider hub,
  ) {
    final remainingChars = 280 - _composeController.text.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          height: 1,
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),

        // Category selector
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: _buildCategorySelector(themeProvider),
        ),

        // Text input
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: TextField(
            controller: _composeController,
            maxLines: 4,
            minLines: 2,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText:
                  'Share what you\'re building, discovering, or thinking...',
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.4,
            ),
          ),
        ),

        // Tags and mentions
        if (hub.draft.tags.isNotEmpty || hub.draft.mentions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...hub.draft.tags
                    .map((tag) => _buildMiniChip('#$tag', themeProvider, () {
                          hub.removeTag(tag);
                          setState(() {});
                        })),
                ...hub.draft.mentions
                    .map((m) => _buildMiniChip('@$m', themeProvider, () {
                          hub.removeMention(m);
                          setState(() {});
                        })),
              ],
            ),
          ),

        // Selected images preview
        if (_selectedImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: MemoryImage(_selectedImages[index].bytes),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 10,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedImages.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

        // Location indicator
        if (_selectedLocation != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: themeProvider.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on,
                      size: 14, color: themeProvider.accentColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _selectedLocation!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: themeProvider.accentColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _selectedLocation = null),
                    child: Icon(Icons.close,
                        size: 12, color: themeProvider.accentColor),
                  ),
                ],
              ),
            ),
          ),

        // Action bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildCompactActionButton(
                Icons.image_outlined,
                'Photo',
                themeProvider,
                onTap: _pickImage,
              ),
              _buildCompactActionButton(
                Icons.location_on_outlined,
                'Location',
                themeProvider,
                onTap: _pickLocation,
              ),
              _buildCompactActionButton(
                Icons.tag,
                'Tag',
                themeProvider,
                onTap: () => _showAddTagDialog(hub),
              ),
              _buildCompactActionButton(
                Icons.alternate_email_outlined,
                'Mention',
                themeProvider,
                onTap: () => _showMentionPicker(hub),
              ),
              const Spacer(),
              // Character count
              Text(
                '$remainingChars',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: remainingChars < 0
                      ? Theme.of(context).colorScheme.error
                      : remainingChars < 20
                          ? KubusColorRoles.of(context).warningAction
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 12),
              // Post button
              ElevatedButton(
                onPressed: _composeController.text.trim().isEmpty || _isPosting
                    ? null
                    : _submitInlinePost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.accentColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      themeProvider.accentColor.withValues(alpha: 0.4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(60, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isPosting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Post',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniChip(
      String label, ThemeProvider themeProvider, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: themeProvider.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: themeProvider.accentColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child:
                Icon(Icons.close, size: 12, color: themeProvider.accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactActionButton(
    IconData icon,
    String tooltip,
    ThemeProvider themeProvider, {
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 18,
              color: themeProvider.accentColor,
            ),
          ),
        ),
      ),
    );
  }

  void _showAddTagDialog(CommunityHubProvider hub) {
    final controller = TextEditingController();
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Tag',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter tag (e.g., art, photography)',
            prefixText: '# ',
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              hub.addTag(value.trim());
              Navigator.pop(context);
              setState(() {});
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                hub.addTag(controller.text.trim());
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<T?> _showDesktopModal<T>({
    required WidgetBuilder builder,
    double maxWidth = 900,
    double maxHeight = 880,
    double minWidth = 420,
    bool barrierDismissible = true,
    bool wrapWithSurface = true,
  }) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(28);

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Desktop modal',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (modalContext, _, __) {
        final modalShell = Container(
          decoration: BoxDecoration(
            color: wrapWithSurface
                ? theme.colorScheme.surface
                : Colors.transparent,
            borderRadius: radius,
            boxShadow: const [
              BoxShadow(
                color: Color(0x2F000000),
                blurRadius: 32,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: builder(modalContext),
          ),
        );

        return SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: minWidth,
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: modalShell,
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _openUserProfileModal({
    required String userId,
    String? username,
  }) async {
    if (userId.isEmpty) return;
    await _showDesktopModal(
      builder: (_) => UserProfileScreen(userId: userId, username: username),
      maxWidth: 920,
      maxHeight: 920,
      minWidth: 520,
      wrapWithSurface: false,
    );
  }

  void _openPostDetail(CommunityPost post) {
    // Avoid stacking duplicate instances of the same post detail
    final existingIndex = _paneStack.lastIndexWhere(
      (route) =>
          route.type == _PaneViewType.postDetail && route.post?.id == post.id,
    );
    if (existingIndex != -1 && existingIndex == _paneStack.length - 1) {
      return;
    }
    setState(() {
      // Remove any older instance of the same post to keep stack clean
      if (existingIndex != -1) {
        _paneStack.removeAt(existingIndex);
      }
      _paneStack.add(_PaneRoute.post(post));
    });
  }

  void _openPostDetailWithAction(
    CommunityPost post,
    PostDetailInitialAction initialAction,
  ) {
    // Force a new route key when opening with an action, otherwise we may reuse
    // an existing subtree and the initialAction won't run.
    final existingIndex = _paneStack.lastIndexWhere(
      (route) =>
          route.type == _PaneViewType.postDetail && route.post?.id == post.id,
    );
    setState(() {
      if (existingIndex != -1) {
        _paneStack.removeAt(existingIndex);
      }
      _paneStack.add(_PaneRoute.post(post, initialAction: initialAction));
    });
  }

  bool _isCurrentUserPost(CommunityPost post) {
    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final currentWallet = walletProvider.currentWalletAddress;
      if (currentWallet == null || currentWallet.trim().isEmpty) return false;
      return WalletUtils.equals(post.authorWallet ?? post.authorId, currentWallet);
    } catch (_) {
      return false;
    }
  }

  void _showPostOptionsForPost(CommunityPost post) {
    if (!mounted) return;
    final isOwner = _isCurrentUserPost(post);

    unawaited(
      showCommunityPostOptionsSheet(
        context: context,
        post: post,
        isOwner: isOwner,
        onReport: () => _openPostDetailWithAction(post, PostDetailInitialAction.report),
        onEdit: () => _openPostDetailWithAction(post, PostDetailInitialAction.edit),
        onDelete: () => _openPostDetailWithAction(post, PostDetailInitialAction.delete),
      ),
    );
  }

  Future<void> _showMentionPicker(CommunityHubProvider hub) async {
    final selectedHandle = await _presentMentionPickerDialog();
    if (selectedHandle == null || selectedHandle.isEmpty) return;
    hub.addMention(selectedHandle);
    if (mounted) setState(() {});
  }

  Future<String?> _presentMentionPickerDialog() async {
    final controller = TextEditingController();
    List<Map<String, dynamic>> results = <Map<String, dynamic>>[];
    bool isLoading = false;
    String? errorMessage;
    Timer? debounce;

    final selection = await showKubusDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> runSearch(String query) async {
              if (query.length < 2) {
                setDialogState(() {
                  results = <Map<String, dynamic>>[];
                  isLoading = false;
                  errorMessage = null;
                });
                return;
              }
              setDialogState(() {
                isLoading = true;
                errorMessage = null;
              });
              try {
                final response = await _backendApi.search(
                  query: query,
                  type: 'profiles',
                  limit: 12,
                );
                final parsed = _parseProfileSearchResults(response);
                setDialogState(() {
                  results = parsed;
                  isLoading = false;
                  errorMessage = parsed.isEmpty ? 'No profiles found' : null;
                });
              } catch (e) {
                debugPrint('Mention picker search failed: $e');
                setDialogState(() {
                  isLoading = false;
                  results = <Map<String, dynamic>>[];
                  errorMessage = 'Search failed. Try again.';
                });
              }
            }

            return KubusAlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Mention someone',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search artists, collectors, or wallets',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: controller.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  controller.clear();
                                  setDialogState(() {
                                    results = <Map<String, dynamic>>[];
                                    errorMessage = null;
                                  });
                                },
                              ),
                      ),
                      onChanged: (value) {
                        debounce?.cancel();
                        final query = value.trim();
                        if (query.length < 2) {
                          setDialogState(() {
                            results = <Map<String, dynamic>>[];
                            isLoading = false;
                            errorMessage = null;
                          });
                          return;
                        }
                        debounce = Timer(const Duration(milliseconds: 275), () {
                          unawaited(runSearch(query));
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 260,
                      child: isLoading
                          ? const Center(
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : results.isEmpty
                              ? Center(
                                  child: Text(
                                    controller.text.trim().length < 2
                                        ? 'Type at least 2 characters to search'
                                        : (errorMessage ?? 'No profiles found'),
                                    style: GoogleFonts.inter(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: results.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                  ),
                                  itemBuilder: (_, index) {
                                    final profile = results[index];
                                    final identity =
                                        UserIdentityDisplayUtils.fromProfileMap(
                                      Map<String, dynamic>.from(
                                        profile.map(
                                          (k, v) => MapEntry(k.toString(), v),
                                        ),
                                      ),
                                    );
                                    final handle = _sanitizeHandle(
                                      profile['username'] ??
                                          profile['handle'] ??
                                          profile['id'] ??
                                          '',
                                    );
                                    final wallet = (profile['wallet_address'] ??
                                                profile['wallet'] ??
                                                profile['id'])
                                            ?.toString() ??
                                        '';
                                    final avatarUrl = profile['avatar'] ??
                                        profile['avatar_url'] ??
                                        profile['profileImageUrl'];
                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 6),
                                      leading: AvatarWidget(
                                        avatarUrl: avatarUrl?.toString(),
                                        wallet: wallet,
                                        radius: 20,
                                        allowFabricatedFallback: true,
                                      ),
                                      title: Text(
                                        identity.name,
                                        style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: identity.handle == null
                                          ? null
                                          : Text(
                                              identity.handle!,
                                              style: GoogleFonts.inter(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                                fontSize: 12,
                                              ),
                                            ),
                                      trailing: Icon(
                                          Icons.person_add_alt_1_outlined,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.4)),
                                      onTap: () => Navigator.of(dialogContext)
                                          .pop(handle.isNotEmpty
                                              ? handle
                                              : wallet),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: controller.text.trim().isEmpty
                      ? null
                      : () => Navigator.of(dialogContext)
                          .pop(_sanitizeHandle(controller.text)),
                  child: const Text('Add handle'),
                ),
              ],
            );
          },
        );
      },
    );

    debounce?.cancel();
    controller.dispose();
    final sanitized = _sanitizeHandle(selection ?? '');
    return sanitized.isEmpty ? null : sanitized;
  }

  String _sanitizeHandle(Object? raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return '';
    return value.replaceFirst(RegExp(r'^@+'), '');
  }

  Future<void> _submitInlinePost() async {
    if (_composeController.text.trim().isEmpty) return;

    setState(() => _isPosting = true);

    try {
      final api = BackendApiService();
      final hub = Provider.of<CommunityHubProvider>(context, listen: false);
      hub.setDraftCategory(_selectedCategory);

      final draft = hub.draft;
      final location = draft.location;
      final locationName =
          _selectedLocation ?? draft.locationLabel ?? location?.name;

      if (draft.targetGroup != null) {
        await api.createGroupPost(
          draft.targetGroup!.id,
          content: _composeController.text.trim(),
          category: draft.category,
          artworkId: draft.artwork?.id,
          subjectType: draft.subjectType,
          subjectId: draft.subjectId,
          tags: draft.tags,
          mentions: draft.mentions,
          location: location,
          locationName: locationName,
          locationLat: location?.lat,
          locationLng: location?.lng,
        );
      } else {
        await api.createCommunityPost(
          content: _composeController.text.trim(),
          category: draft.category,
          artworkId: draft.artwork?.id,
          subjectType: draft.subjectType,
          subjectId: draft.subjectId,
          tags: draft.tags,
          mentions: draft.mentions,
          location: location,
          locationName: locationName,
          locationLat: location?.lat,
          locationLng: location?.lng,
        );
      }

      if (mounted) {
        // Clear composer state
        _composeController.clear();
        _selectedImages.clear();
        _selectedLocation = null;
        _selectedCategory = 'post';
        hub.resetDraft();

        setState(() {
          _isPosting = false;
          _isComposerExpanded = false;
        });

        // Refresh feed
        _loadDiscoverFeed();

        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: const Text('Post published!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor:
                Provider.of<ThemeProvider>(context, listen: false).accentColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text('Failed to post: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildTrendingSection(ThemeProvider themeProvider) {
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Trending',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _loadTrendingTopics,
              icon: Icon(
                Icons.refresh,
                size: 18,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingTrending)
          Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: themeProvider.accentColor,
            ),
          )
        else if (_trendingError != null)
          DesktopCard(
            onTap: _loadTrendingTopics,
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Could not load trending topics. Tap to retry.',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (_trendingTopics.isEmpty)
          DesktopCard(
            child: Row(
              children: [
                Icon(
                  Icons.trending_down,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No trending tags yet. Engage with the community to surface trends.',
                    style: GoogleFonts.inter(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_trendingFromFeed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
                  child: Text(
                    'Based on recent posts',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ..._trendingTopics.asMap().entries.map((entry) {
                final topic = entry.value;
                final rank = entry.key + 1;
                final rawTag = topic['tag']?.toString() ?? '';
                if (rawTag.isEmpty) return const SizedBox.shrink();
                final displayTag = rawTag.startsWith('#') ? rawTag : '#$rawTag';
                final count = topic['count'] is num
                    ? topic['count'] as num
                    : num.tryParse(topic['count']?.toString() ?? '') ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DesktopCard(
                    onTap: () => _openTagFeed(rawTag),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _getTrendingRankColor(rank)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '#$rank',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: _getTrendingRankColor(rank),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayTag,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_formatTrendingCount(count)} tagged posts',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Add to post',
                          onPressed: () {
                            final sanitized = _sanitizeTagValue(rawTag);
                            if (sanitized == null) return;
                            hub.addTag(sanitized);

                            // Make the action visible immediately by expanding
                            // the quick composer in the sidebar.
                            if (!_isComposerExpanded) {
                              setState(() {
                                _isComposerExpanded = true;
                              });
                            } else {
                              // Still rebuild so the mini-chip row reflects the
                              // added tag even if the composer is already open.
                              setState(() {});
                            }

                            _appendComposerToken('#$sanitized');
                          },
                          icon: Icon(
                            Icons.add,
                            size: 18,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
      ],
    );
  }

  /// Get varied color for trending rank badges
  Color _getTrendingRankColor(int rank) {
    final scheme = Theme.of(context).colorScheme;
    switch (rank) {
      case 1:
        return AppColorUtils.coralAccent;
      case 2:
        return AppColorUtils.amberAccent;
      case 3:
        return AppColorUtils.tealAccent;
      case 4:
        return scheme.secondary;
      case 5:
        return AppColorUtils.indigoAccent;
      default:
        return scheme.tertiary;
    }
  }

  void _appendComposerToken(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;
    final existing = _composeController.text.trimRight();
    final updated = existing.isEmpty ? trimmed : '$existing $trimmed';
    setState(() {
      _composeController.text = '$updated ';
    });
  }

  List<Map<String, dynamic>> _normalizeTrendingTopics(
      List<Map<String, dynamic>> raw) {
    final normalized = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final entry in raw) {
      final tag = _extractTrendingTag(entry);
      if (tag == null) continue;
      final key = tag.toLowerCase();
      if (seen.contains(key)) continue;
      final countValue = entry['count'] ??
          entry['search_count'] ??
          entry['post_count'] ??
          entry['frequency'] ??
          entry['occurrences'] ??
          entry['uses'] ??
          0;
      final numCount = countValue is num
          ? countValue
          : num.tryParse(countValue.toString()) ?? 0;
      normalized.add({'tag': tag, 'count': numCount});
      seen.add(key);
    }
    return normalized;
  }

  String? _extractTrendingTag(Map<String, dynamic> topic) {
    final rawTerm =
        topic['tag'] ?? topic['term'] ?? topic['query'] ?? topic['search'];
    if (rawTerm == null) return null;
    final type = (topic['type'] ?? topic['category'] ?? topic['kind'] ?? '')
        .toString()
        .toLowerCase();
    final rawString = rawTerm.toString().trim();
    if (rawString.isEmpty) return null;
    if (rawString.startsWith('@')) return null;

    if (type.isNotEmpty &&
        type != 'tag' &&
        type != 'tags' &&
        type != 'hashtag') {
      if (!rawString.startsWith('#') && topic['tag'] == null) {
        return null;
      }
    }

    final sanitized = _sanitizeTagValue(rawString);
    return sanitized;
  }

  String? _sanitizeTagValue(Object? raw) {
    if (raw == null) return null;
    var value = raw.toString().trim();
    if (value.isEmpty) return null;
    value = value.replaceFirst(RegExp(r'^#+'), '');
    value = value.replaceAll(RegExp(r'\s+'), '');
    if (value.isEmpty) return null;
    if (!RegExp(r'[a-zA-Z0-9_-]').hasMatch(value)) return null;
    return value;
  }

  List<Map<String, dynamic>> _buildFallbackTrendingTopics() {
    final combinedPosts = <CommunityPost>[];
    combinedPosts
      ..addAll(_discoverPosts)
      ..addAll(_followingPosts);
    try {
      final communityProvider = context.read<CommunityHubProvider>();
      combinedPosts.addAll(communityProvider.artFeedPosts);
    } catch (_) {}
    if (combinedPosts.isEmpty) return const [];

    final counts = <String, Map<String, dynamic>>{};
    for (final post in combinedPosts) {
      for (final tag in post.tags) {
        final sanitized = _sanitizeTagValue(tag);
        if (sanitized == null) continue;
        final key = sanitized.toLowerCase();
        final existing =
            counts.putIfAbsent(key, () => {'tag': sanitized, 'count': 0});
        existing['count'] = (existing['count'] as int) + 1;
      }
    }

    final sorted = counts.values.toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return sorted;
  }

  List<CommunityPost> _sortPosts(List<CommunityPost> posts, String sortMode) {
    if (posts.length <= 1) return posts;
    final normalized = sortMode.toLowerCase();
    final sorted = List<CommunityPost>.from(posts);
    if (normalized == 'popularity' || normalized == 'popular') {
      sorted.sort((a, b) => _popularityScore(b).compareTo(_popularityScore(a)));
    } else {
      sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    return sorted;
  }

  double _popularityScore(CommunityPost post) {
    final likes = post.likeCount.toDouble();
    final comments = post.commentCount.toDouble();
    final shares = post.shareCount.toDouble();
    final views = post.viewCount.toDouble();
    final hoursOld = DateTime.now().difference(post.timestamp).inMinutes / 60.0;
    final recencyBoost = math.max(0, 72 - hoursOld);
    return (likes * 4) +
        (comments * 6) +
        (shares * 5) +
        (views * 0.25) +
        recencyBoost;
  }

  List<CommunityPost> _filterLocalPostsByTag(String tag) {
    final key = _sanitizeTagValue(tag)?.toLowerCase() ?? tag.toLowerCase();
    final List<CommunityPost> local = [];
    local
      ..addAll(_discoverPosts)
      ..addAll(_followingPosts);
    try {
      local.addAll(context.read<CommunityHubProvider>().artFeedPosts);
    } catch (_) {}
    return local.where((post) {
      return post.tags.any((t) {
        final normalized =
            _sanitizeTagValue(t)?.toLowerCase() ?? t.toLowerCase();
        return normalized == key;
      });
    }).toList();
  }

  String _formatTrendingCount(num? count) {
    final value = count ?? 0;
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  List<Map<String, dynamic>> _dedupeSuggestedProfiles(
      List<Map<String, dynamic>> source,
      {int take = 8}) {
    if (source.isEmpty) return const [];
    final seen = <String>{};
    final deduped = <Map<String, dynamic>>[];
    for (final entry in source) {
      if (entry.isEmpty) continue;
      final key = (entry['walletAddress'] ??
              entry['wallet_address'] ??
              entry['wallet'] ??
              entry['id'] ??
              entry['username'])
          ?.toString()
          .toLowerCase();
      if (key == null || key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      deduped.add(entry);
      if (deduped.length >= take) break;
    }
    return deduped;
  }

  Widget _buildWhoToFollowSection(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Who to follow',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _loadSuggestions,
              icon: Icon(
                Icons.refresh,
                size: 18,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingSuggestions)
          Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: themeProvider.accentColor,
            ),
          )
        else if (_suggestionsError != null)
          DesktopCard(
            onTap: _loadSuggestions,
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Unable to load suggestions. Tap to retry.',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (_suggestedArtists.isEmpty)
          DesktopCard(
            child: Row(
              children: [
                Icon(
                  Icons.people_outline,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Follow artists to personalize your feed.',
                    style: GoogleFonts.inter(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: _suggestedArtists.map((artist) {
              final displayName = (artist['displayName'] ??
                      artist['name'] ??
                      artist['username'] ??
                      'Creator')
                  .toString();
              final handle = (artist['username'] ??
                      artist['walletAddress'] ??
                      artist['wallet'] ??
                      '')
                  .toString();
              final avatar = (artist['avatar'] ??
                      artist['avatarUrl'] ??
                      artist['profileImage'])
                  ?.toString();
              final walletAddress =
                  (artist['walletAddress'] ?? artist['wallet'])?.toString();
              final profileId = walletAddress ?? handle;
              final canonicalWallet = WalletUtils.canonical(walletAddress);
              final currentWallet =
                  WalletUtils.canonical(context.read<WalletProvider>().currentWalletAddress);
              final canFollow = canonicalWallet.isNotEmpty &&
                  !WalletUtils.equals(canonicalWallet, currentWallet);
              final isFollowing = canFollow && _followingWallets.contains(canonicalWallet);
              final isFollowBusy =
                  canFollow && _followRequestsInFlight.contains(canonicalWallet);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DesktopCard(
                  onTap: profileId.isEmpty
                      ? null
                      : () => _openUserProfileModal(
                          userId: profileId,
                          username: handle.isEmpty ? null : handle),
                  child: Row(
                    children: [
                      AvatarWidget(
                        avatarUrl: avatar,
                        wallet: profileId,
                        radius: 22,
                        allowFabricatedFallback: true,
                      ),
                      if (artist['verified'] == true) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.verified,
                            color: themeProvider.accentColor, size: 16),
                      ],
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (handle.isNotEmpty)
                              Text(
                                '@$handle',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: (!canFollow || isFollowBusy)
                            ? null
                            : () => _toggleSuggestedFollow(
                                  walletAddress: canonicalWallet,
                                  displayName: displayName,
                                ),
                        child: Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: GoogleFonts.inter(
                            color: isFollowing
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7)
                                : themeProvider.accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildActiveCommunitiesSection(ThemeProvider themeProvider) {
    return Consumer<CommunityHubProvider>(
      builder: (context, communityProvider, _) {
        final groups = communityProvider.groups;
        final isLoading = communityProvider.groupsLoading;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Communities',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: themeProvider.accentColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (groups.isEmpty && !isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No communities found',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              )
            else
              ...groups.take(5).map((group) =>
                  _buildCommunityItemFromGroup(group, themeProvider)),
            if (groups.length > 5)
              TextButton(
                onPressed: () {
                  // Navigate to full communities list
                },
                child: Text(
                  'View all ${groups.length} communities',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: themeProvider.accentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCommunityItemFromGroup(
      CommunityGroupSummary group, ThemeProvider themeProvider) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Navigate to group detail
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      themeProvider.accentColor,
                      themeProvider.accentColor.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: group.coverImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          group.coverImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.group,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.group,
                        size: 22,
                        color: Colors.white,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${group.memberCount} members',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (group.isMember)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: themeProvider.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Joined',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: themeProvider.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposeDialog(ThemeProvider themeProvider) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final user = profileProvider.currentUser;
    final remainingChars = 280 - _composeController.text.length;
    final hub = Provider.of<CommunityHubProvider>(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _showComposeDialog = false;
          _selectedImages.clear();
          _selectedLocation = null;
        });
      },
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 560,
              constraints: const BoxConstraints(maxHeight: 600),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
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
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showComposeDialog = false;
                              _selectedImages.clear();
                              _selectedLocation = null;
                            });
                          },
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Create Post',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _composeController.text.trim().isEmpty ||
                                  _isPosting
                              ? null
                              : _submitPost,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.accentColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: themeProvider.accentColor
                                .withValues(alpha: 0.4),
                            disabledForegroundColor:
                                Colors.white.withValues(alpha: 0.7),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _isPosting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Post',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600),
                                ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCategorySelector(themeProvider),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AvatarWidget(
                                avatarUrl: user?.avatar,
                                wallet: user?.walletAddress ?? '',
                                radius: 24,
                                allowFabricatedFallback: true,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _composeController,
                                  maxLines: null,
                                  minLines: 3,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText: 'What\'s happening?',
                                    hintStyle: GoogleFonts.inter(
                                      fontSize: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.4),
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTagMentionRow(themeProvider, inset: false),
                          const SizedBox(height: 16),
                          _buildGroupAttachmentCard(themeProvider, hub),
                          const SizedBox(height: 12),
                          _buildSubjectAttachmentCard(themeProvider, hub),
                          const SizedBox(height: 12),
                          _buildLocationAttachmentCard(themeProvider, hub),
                          // Selected images preview
                          if (_selectedImages.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedImages.length,
                                itemBuilder: (context, index) {
                                  return Stack(
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          image: DecorationImage(
                                            image: MemoryImage(
                                                _selectedImages[index].bytes),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 12,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedImages.removeAt(index);
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Actions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _pickImage,
                          icon: Icon(Icons.image_outlined,
                              color: themeProvider.accentColor),
                          tooltip: 'Add image',
                        ),
                        IconButton(
                          onPressed: _showARAttachmentInfo,
                          icon: Icon(Icons.view_in_ar,
                              color: themeProvider.accentColor),
                          tooltip: 'Add AR content',
                        ),
                        IconButton(
                          onPressed: _pickLocation,
                          icon: Icon(Icons.location_on_outlined,
                              color: themeProvider.accentColor),
                          tooltip: 'Add location',
                        ),
                        IconButton(
                          onPressed: () => _showMentionPicker(
                              Provider.of<CommunityHubProvider>(context,
                                  listen: false)),
                          icon: Icon(Icons.alternate_email_outlined,
                              color: themeProvider.accentColor),
                          tooltip: 'Mention user',
                        ),
                        IconButton(
                          onPressed: _showEmojiPicker,
                          icon: Icon(Icons.emoji_emotions_outlined,
                              color: themeProvider.accentColor),
                          tooltip: 'Add emoji',
                        ),
                        const Spacer(),
                        Text(
                          '$remainingChars',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: remainingChars < 0
                                ? Theme.of(context).colorScheme.error
                                : remainingChars < 20
                                    ? KubusColorRoles.of(context).warningAction
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final fileName = (image.name.trim().isNotEmpty)
          ? image.name.trim()
          : 'post-image-${DateTime.now().millisecondsSinceEpoch}.jpg';
      setState(() {
        _selectedImages.add(_ComposerImagePayload(bytes: bytes, fileName: fileName));
      });
    }
  }

  Future<List<String>> _uploadComposerMedia() async {
    if (_selectedImages.isEmpty) return const <String>[];
    final api = BackendApiService();
    final mediaUrls = <String>[];
    for (final image in _selectedImages) {
      final uploadResult = await api.uploadFile(
        fileBytes: image.bytes,
        fileName: image.fileName,
        fileType: 'post-image',
      );
      final url = uploadResult['uploadedUrl'] as String?;
      if (url == null || url.trim().isEmpty) {
        throw Exception('Image upload returned no URL');
      }
      mediaUrls.add(url);
    }
    return mediaUrls;
  }

  Future<void> _pickLocation() async {
    final controller = TextEditingController(text: _selectedLocation ?? '');
    final result = await showKubusDialog<String>(
      context: context,
      builder: (context) {
        return KubusAlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Tag a location',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'e.g. Ljubljana, Slovenia',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(
                'Save',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (result != null && result.isNotEmpty) {
      setState(() => _selectedLocation = result);
      Provider.of<CommunityHubProvider>(context, listen: false)
          .setDraftLocation(null, label: result);
    }
  }

  void _showEmojiPicker() {
    const emojis = ['ðŸŽ¨', 'ðŸ”¥', 'âœ¨', 'ðŸ›°ï¸', 'ðŸ–¼ï¸', 'ðŸŒ', 'ðŸ’«', 'ðŸš€'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: emojis.map((emoji) {
            return GestureDetector(
              onTap: () {
                _composeController.text = '${_composeController.text}$emoji';
                Navigator.pop(context);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategorySelector(ThemeProvider themeProvider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _composerCategories.map((option) {
          final isSelected = option.value == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    option.icon,
                    size: 16,
                    color: isSelected
                        ? themeProvider.accentColor
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(option.label),
                ],
              ),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) {
                setState(() => _selectedCategory = option.value);
                Provider.of<CommunityHubProvider>(context, listen: false)
                    .setDraftCategory(option.value);
              },
              selectedColor: themeProvider.accentColor.withValues(alpha: 0.14),
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
              side: BorderSide(
                color: isSelected
                    ? themeProvider.accentColor.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? themeProvider.accentColor
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.75),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTagMentionRow(ThemeProvider themeProvider, {bool inset = true}) {
    final hub = Provider.of<CommunityHubProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hub.draft.tags.isNotEmpty || hub.draft.mentions.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: inset ? 8 : 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...hub.draft.tags
                    .map((tag) => _buildChip(tag, themeProvider, () {
                          hub.removeTag(tag);
                          setState(() {});
                        })),
                ...hub.draft.mentions
                    .map((m) => _buildChip('@$m', themeProvider, () {
                          hub.removeMention(m);
                          setState(() {});
                        })),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                decoration: InputDecoration(
                  hintText: 'Add tag',
                  prefixText: '# ',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.tag),
                    tooltip: 'Browse tags',
                    onPressed: () => _showAddTagDialog(hub),
                  ),
                ),
                onSubmitted: (value) {
                  final v = value.trim();
                  if (v.isEmpty) return;
                  hub.addTag(v);
                  _tagController.clear();
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _mentionController,
                decoration: InputDecoration(
                  hintText: 'Mention',
                  prefixText: '@ ',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.alternate_email_outlined),
                    tooltip: 'Find profiles',
                    onPressed: () => _showMentionPicker(hub),
                  ),
                ),
                onSubmitted: (value) {
                  final v = value.trim();
                  if (v.isEmpty) return;
                  hub.addMention(v);
                  _mentionController.clear();
                  setState(() {});
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGroupAttachmentCard(
      ThemeProvider themeProvider, CommunityHubProvider hub) {
    final scheme = Theme.of(context).colorScheme;
    final group = hub.draft.targetGroup;
    final animationTheme = context.animationTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final selection = await _showGroupPicker();
          if (selection != null) {
            hub.setDraftGroup(selection);
          }
        },
        child: AnimatedContainer(
          duration: animationTheme.short,
          curve: animationTheme.defaultCurve,
          decoration: BoxDecoration(
            color: group != null
                ? scheme.primaryContainer.withValues(alpha: 0.2)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: group != null
                  ? themeProvider.accentColor.withValues(alpha: 0.4)
                  : scheme.outline.withValues(alpha: 0.2),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.groups_3_outlined,
                  color: scheme.onSurface.withValues(alpha: 0.8)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group?.name ?? 'Target a community (optional)',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group == null
                          ? 'Posts shared to groups notify members instantly.'
                          : (group.description?.isNotEmpty == true
                              ? group.description!
                              : 'Posting to ${group.name}'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (group != null)
                IconButton(
                  tooltip: 'Remove group',
                  onPressed: () => hub.setDraftGroup(null),
                  icon: const Icon(Icons.close),
                )
              else
                Icon(
                  Icons.add_circle_outline,
                  color: themeProvider.accentColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectAttachmentCard(
      ThemeProvider themeProvider, CommunityHubProvider hub) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final subjectProvider = context.read<CommunitySubjectProvider>();
    final animationTheme = context.animationTheme;

    CommunitySubjectPreview? preview;
    final type = (hub.draft.subjectType ?? '').trim();
    final id = (hub.draft.subjectId ?? '').trim();
    if (type.isNotEmpty && id.isNotEmpty) {
      preview = subjectProvider.previewFor(
        CommunitySubjectRef(type: type, id: id),
      );
    }
    if (preview == null && hub.draft.artwork != null) {
      preview = CommunitySubjectPreview(
        ref: CommunitySubjectRef(type: 'artwork', id: hub.draft.artwork!.id),
        title: hub.draft.artwork!.title,
        imageUrl: MediaUrlResolver.resolve(hub.draft.artwork!.imageUrl) ??
            hub.draft.artwork!.imageUrl,
      );
    }

    final previewValue = preview;
    final bool hasSubject = previewValue != null;
    final String label;
    final String title;
    final IconData subjectIcon;
    final String? imageUrl;
    if (previewValue == null) {
      label = l10n.communitySubjectSelectPrompt;
      title = l10n.communitySubjectSelectTitle;
      subjectIcon = Icons.link;
      imageUrl = null;
    } else {
      label = l10n.communitySubjectLinkedLabel(
        _subjectTypeLabel(l10n, previewValue.ref.normalizedType),
      );
      title = previewValue.title;
      subjectIcon = _subjectTypeIcon(previewValue.ref.normalizedType);
      imageUrl = previewValue.imageUrl;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final selection =
              await CommunitySubjectPicker.pick(context, initialType: hub.draft.subjectType);
          if (selection == null) return;
          if (selection.cleared) {
            hub.setDraftSubject();
            hub.setDraftArtwork(null);
            return;
          }
          final selected = selection.preview;
          if (selected == null) return;
          subjectProvider.upsertPreview(selected);
          hub.setDraftSubject(type: selected.ref.normalizedType, id: selected.ref.id);
          if (selected.ref.normalizedType == 'artwork') {
            hub.setDraftArtwork(
              CommunityArtworkReference(
                id: selected.ref.id,
                title: selected.title,
                imageUrl: selected.imageUrl,
              ),
            );
          } else {
            hub.setDraftArtwork(null);
          }
        },
        child: AnimatedContainer(
          duration: animationTheme.short,
          curve: animationTheme.defaultCurve,
          decoration: BoxDecoration(
            color: hasSubject
                ? scheme.primaryContainer.withValues(alpha: 0.2)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasSubject
                  ? themeProvider.accentColor.withValues(alpha: 0.35)
                  : scheme.outline.withValues(alpha: 0.2),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (previewValue != null &&
                  imageUrl != null &&
                  imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      subjectIcon,
                      color: themeProvider.accentColor,
                    ),
                  ),
                )
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: themeProvider.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    subjectIcon,
                    color: themeProvider.accentColor,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (hasSubject)
                IconButton(
                  tooltip: l10n.communitySubjectRemoveTooltip,
                  onPressed: () {
                    hub.setDraftSubject();
                    hub.setDraftArtwork(null);
                  },
                  icon: const Icon(Icons.close),
                )
              else
                Icon(
                  Icons.add_circle_outline,
                  color: themeProvider.accentColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _subjectTypeLabel(AppLocalizations l10n, String type) {
    switch (type.toLowerCase()) {
      case 'artwork':
        return l10n.commonArtwork;
      case 'exhibition':
        return l10n.commonExhibition;
      case 'collection':
        return l10n.commonCollection;
      case 'institution':
        return l10n.commonInstitution;
      default:
        return l10n.commonDetails;
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

  Widget _buildLocationAttachmentCard(
      ThemeProvider themeProvider, CommunityHubProvider hub) {
    final scheme = Theme.of(context).colorScheme;
    final location = hub.draft.location;
    final label =
        _selectedLocation ?? hub.draft.locationLabel ?? location?.name;
    final animationTheme = context.animationTheme;

    return AnimatedSwitcher(
      duration: animationTheme.short,
      switchInCurve: animationTheme.defaultCurve,
      switchOutCurve: animationTheme.fadeCurve,
      child: label == null
          ? Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const ValueKey('location_add'),
                onPressed: _pickLocation,
                icon: const Icon(Icons.location_on_outlined),
                label: const Text('Tag a location'),
              ),
            )
          : Container(
              key: ValueKey(label),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: themeProvider.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: themeProvider.accentColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: themeProvider.accentColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        if (location?.lat != null && location?.lng != null)
                          Text(
                            '${location!.lat!.toStringAsFixed(4)}, ${location.lng!.toStringAsFixed(4)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit label',
                    onPressed: _pickLocation,
                    icon: const Icon(Icons.edit_location_alt_outlined),
                  ),
                  IconButton(
                    tooltip: 'Remove location',
                    onPressed: () {
                      setState(() => _selectedLocation = null);
                      hub.setDraftLocation(null);
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
    );
  }

  Future<CommunityGroupSummary?> _showGroupPicker() async {
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    if (!hub.groupsInitialized && !hub.groupsLoading) {
      try {
        await hub.loadGroups(refresh: true);
      } catch (e) {
        debugPrint('Failed to refresh community groups: $e');
      }
    }
    if (!mounted) return null;
    final groups = hub.groups.where((g) => g.isMember || g.isOwner).toList();
    if (groups.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        const SnackBar(
            content: Text('Join a community group to target your post.')),
      );
      return null;
    }

    return showKubusDialog<CommunityGroupSummary>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Row(
                    children: [
                      Text(
                        'Select community',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          group.name,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (group.description?.isNotEmpty == true)
                              Text(
                                group.description!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            else
                              Text(
                                '${group.memberCount} members',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                          ],
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                        onTap: () => Navigator.of(dialogContext).pop(group),
                      );
                    },
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.1),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(null),
                        child: const Text('Clear selection'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildChip(
      String label, ThemeProvider themeProvider, VoidCallback onRemove) {
    return Chip(
      backgroundColor: themeProvider.accentColor.withValues(alpha: 0.1),
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: themeProvider.accentColor,
        ),
      ),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onRemove,
    );
  }

  void _showARAttachmentInfo() {
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.view_in_ar,
                color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 8),
            Text(
              'AR attachments',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'Attach AR assets from your mobile device to ensure ARCore/ARKit compatibility. You can still tag this post and continue editing here.',
          style: GoogleFonts.inter(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final shellScope = DesktopShellScope.of(context);
              if (shellScope != null) {
                shellScope.pushScreen(
                  DesktopSubScreen(
                    title: 'Download App',
                    child: const DownloadAppScreen(),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DownloadAppScreen(),
                  ),
                );
              }
            },
            child: Text(
              'Download app',
              style: GoogleFonts.inter(
                color: Provider.of<ThemeProvider>(context, listen: false)
                    .accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPost() async {
    final rawContent = _composeController.text.trim();
    if (rawContent.isEmpty && _selectedImages.isEmpty) return;

    setState(() => _isPosting = true);

    try {
      final api = BackendApiService();
      final hub = Provider.of<CommunityHubProvider>(context, listen: false);
      hub.setDraftCategory(_selectedCategory);

      final mediaUrls = await _uploadComposerMedia();
      final postType = mediaUrls.isNotEmpty ? 'image' : 'text';
      var content = rawContent;
      if (content.isEmpty && mediaUrls.isNotEmpty) {
        content = 'Shared a photo';
      }

      final draft = hub.draft;
      final location = draft.location;
      final locationName =
          _selectedLocation ?? draft.locationLabel ?? location?.name;

      if (draft.targetGroup != null) {
        await hub.submitGroupPost(
          draft.targetGroup!.id,
          content: content,
          mediaUrls: mediaUrls.isEmpty ? null : mediaUrls,
          postType: postType,
          category: draft.category,
          artworkId: draft.artwork?.id,
          subjectType: draft.subjectType,
          subjectId: draft.subjectId,
          tags: draft.tags,
          mentions: draft.mentions,
          location: location,
          locationLabel: locationName,
        );
      } else {
        await api.createCommunityPost(
          content: content,
          mediaUrls: mediaUrls.isEmpty ? null : mediaUrls,
          postType: postType,
          category: draft.category,
          artworkId: draft.artwork?.id,
          subjectType: draft.subjectType,
          subjectId: draft.subjectId,
          tags: draft.tags,
          mentions: draft.mentions,
          location: location,
          locationName: locationName,
          locationLat: location?.lat,
          locationLng: location?.lng,
        );
      }

      if (mounted) {
        setState(() {
          _showComposeDialog = false;
          _isPosting = false;
          _composeController.clear();
          _selectedImages.clear();
          _selectedLocation = null;
        });
        hub.resetDraft();

        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: const Text('Post created successfully!'),
            backgroundColor:
                Provider.of<ThemeProvider>(context, listen: false).accentColor,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Refresh the feed
        await _loadFeed();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text('Failed to create post: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

enum _PaneViewType { tagFeed, postDetail, conversation }

class _PaneRoute {
  const _PaneRoute.tag(this.tag)
      : type = _PaneViewType.tagFeed,
        post = null,
        conversation = null,
        initialAction = null;

  const _PaneRoute.post(this.post, {this.initialAction})
      : type = _PaneViewType.postDetail,
        tag = null,
        conversation = null;

  const _PaneRoute.conversation(this.conversation)
      : type = _PaneViewType.conversation,
        tag = null,
        post = null,
        initialAction = null;

  final _PaneViewType type;
  final String? tag;
  final CommunityPost? post;
  final Conversation? conversation;
  final PostDetailInitialAction? initialAction;

  String get viewKey {
    switch (type) {
      case _PaneViewType.tagFeed:
        return 'tag-${(tag ?? '').toLowerCase()}';
      case _PaneViewType.postDetail:
        return 'post-${post?.id ?? ''}-${initialAction?.name ?? 'view'}';
      case _PaneViewType.conversation:
        return 'conversation-${conversation?.id ?? ''}';
    }
  }
}

class _TagFeedState {
  final List<CommunityPost> posts;
  final bool isLoading;
  final String? error;
  final DateTime? lastFetched;
  final bool followingOnly;
  final bool arOnly;
  final String sortMode; // 'popularity' or 'recent'

  const _TagFeedState({
    this.posts = const <CommunityPost>[],
    this.isLoading = false,
    this.error,
    this.lastFetched,
    this.followingOnly = false,
    this.arOnly = false,
    this.sortMode = 'popularity',
  });

  _TagFeedState copyWith({
    List<CommunityPost>? posts,
    bool? isLoading,
    String? error,
    DateTime? lastFetched,
    bool? followingOnly,
    bool? arOnly,
    String? sortMode,
  }) {
    return _TagFeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastFetched: lastFetched ?? this.lastFetched,
      followingOnly: followingOnly ?? this.followingOnly,
      arOnly: arOnly ?? this.arOnly,
      sortMode: sortMode ?? this.sortMode,
    );
  }
}

/// Dialog to start a new conversation
class _NewConversationDialog extends StatefulWidget {
  final ThemeProvider themeProvider;
  final Function(String) onStartConversation;

  const _NewConversationDialog({
    required this.themeProvider,
    required this.onStartConversation,
  });

  @override
  State<_NewConversationDialog> createState() => _NewConversationDialogState();
}

class _FabOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FabOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _ComposerCategoryOption {
  final String value;
  final String label;
  final IconData icon;
  final String description;

  const _ComposerCategoryOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.description,
  });
}

class _NewConversationDialogState extends State<_NewConversationDialog> {
  final BackendApiService _backendApi = BackendApiService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final query = value.trim();
    setState(() {
      _isSearching = query.isNotEmpty;
    });

    _debounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        final resp =
            await _backendApi.search(query: query, type: 'profiles', limit: 20);
        final parsed = _parseProfileSearchResults(resp);
        if (!mounted) return;
        setState(() {
          _searchResults = parsed;
          _isLoading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    });
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
          final mapped = <String, dynamic>{};
          item.forEach((key, value) {
            mapped[key.toString()] = value;
          });
          results.add(mapped);
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
      addEntries(payload['profiles'] as List?);
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Message',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.18),
                ),
              ),
              child: LiquidGlassPanel(
                padding: EdgeInsets.zero,
                margin: EdgeInsets.zero,
                borderRadius: BorderRadius.circular(12),
                showBorder: false,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? 0.22
                          : 0.26,
                    ),
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      hintText: 'Search users...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                    style: GoogleFonts.inter(fontSize: 14),
                    onChanged: _onSearchChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _isSearching && _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_search,
                                size: 48,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Search for users to message',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            final wallet = (user['wallet_address'] ??
                                        user['walletAddress'] ??
                                        user['wallet'] ??
                                        user['id'])
                                    ?.toString() ??
                                '';
                            final name = user['displayName']?.toString() ??
                                user['display_name']?.toString() ??
                                user['username']?.toString() ??
                                (wallet.isNotEmpty ? wallet : 'User');
                            final username = user['username']?.toString();
                            final subtitle =
                                username != null && username.isNotEmpty
                                    ? '@$username'
                                    : wallet;
                            final avatarUrl = user['avatar'] ??
                                user['avatar_url'] ??
                                user['profileImageUrl'] ??
                                user['profileImage'];
                            return ListTile(
                              leading: AvatarWidget(
                                wallet: wallet,
                                avatarUrl: avatarUrl?.toString(),
                                radius: 20,
                                allowFabricatedFallback: true,
                              ),
                              title: Text(name),
                              subtitle:
                                  subtitle.isNotEmpty ? Text(subtitle) : null,
                              onTap: wallet.isEmpty
                                  ? null
                                  : () => widget.onStartConversation(wallet),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationSearchResult {
  final Conversation conversation;
  final double score;
  final String? highlight;

  const _ConversationSearchResult({
    required this.conversation,
    required this.score,
    this.highlight,
  });
}
