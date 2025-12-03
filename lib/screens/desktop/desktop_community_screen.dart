import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../providers/themeprovider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/community_hub_provider.dart';
import '../../providers/chat_provider.dart';
import '../../community/community_interactions.dart';
import '../../models/community_group.dart';
import '../../models/conversation.dart';
import '../../services/backend_api_service.dart';
import '../../widgets/avatar_widget.dart';
import '../../utils/app_animations.dart';
import 'components/desktop_widgets.dart';
import '../community/group_feed_screen.dart';
import '../community/user_profile_screen.dart';
import '../download_app_screen.dart';

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
  Timer? _groupSearchDebounce;
  Timer? _searchDebounce;
  bool _isFabExpanded = false;
  final LayerLink _searchFieldLink = LayerLink();
  final List<String> _tabs = ['Discover', 'Following', 'Groups', 'Art'];
  final BackendApiService _backendApi = BackendApiService();
  List<Map<String, dynamic>> _searchSuggestions = [];
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
  final TextEditingController _composeController = TextEditingController();
  final List<Uint8List> _selectedImages = [];
  String? _selectedLocation;
  String _selectedCategory = 'post';
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _mentionController = TextEditingController();
  List<Map<String, dynamic>> _trendingTopics = [];
  bool _isLoadingTrending = false;
  String? _trendingError;
  List<Map<String, dynamic>> _suggestedArtists = [];
  bool _isLoadingSuggestions = false;
  String? _suggestionsError;
  
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
    _animationController.forward();
    
    // Load community feed data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFeed();
      _loadSidebarData();
      _initializeChat();
    });
  }

  Future<void> _initializeChat() async {
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.initialize();
  }

  Future<void> _loadFeed() async {
    final communityProvider = context.read<CommunityHubProvider>();
    // Load art feed with default location (can be updated with user's location)
    await communityProvider.loadArtFeed(
      latitude: 46.05,  // Default to Ljubljana
      longitude: 14.50,
      radiusKm: 50,
      limit: 50,
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
  }

  Future<void> _loadDiscoverFeed() async {
    if (_isLoadingDiscover) return;
    setState(() {
      _isLoadingDiscover = true;
      _discoverError = null;
    });
    try {
      final posts = await BackendApiService().getCommunityPosts(
        page: 1,
        limit: 50,
        followingOnly: false,
      );
      if (mounted) {
        setState(() {
          _discoverPosts = posts;
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
      final results = await backend.getTrendingSearches(limit: 12);
      if (mounted) {
        setState(() {
          _trendingTopics = results;
          _isLoadingTrending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _trendingError = e.toString();
          _isLoadingTrending = false;
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
      final artists = await backend.listArtists(
        featured: true,
        limit: 8,
        offset: 0,
      );
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

  Future<void> _loadFollowingFeed() async {
    if (_isLoadingFollowing) return;
    setState(() {
      _isLoadingFollowing = true;
      _followingError = null;
    });
    try {
      final posts = await BackendApiService().getCommunityPosts(
        page: 1,
        limit: 50,
        followingOnly: true,
      );
      if (mounted) {
        setState(() {
          _followingPosts = posts;
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
    _animationController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    _groupSearchDebounce?.cancel();
    _searchDebounce?.cancel();
    _groupSearchController.dispose();
    _communitySearchController.dispose();
    _tagController.dispose();
    _mentionController.dispose();
    _composeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;
    final isMedium = screenWidth >= 900 && screenWidth < 1200;

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8F9FA),
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
                Container(
                  width: isLarge ? 360 : 300,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: _buildRightSidebar(themeProvider),
                ),
            ],
          ),

          if (_showSearchOverlay) _buildSearchOverlay(themeProvider),

          // Compose dialog
          if (_showComposeDialog)
            _buildComposeDialog(themeProvider),
        ],
      ),
    );
  }

  Widget _buildMainFeed(ThemeProvider themeProvider, AppAnimationTheme animationTheme) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _animationController,
            curve: animationTheme.fadeCurve,
          ),
          child: Stack(
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

                  // Feed content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: _tabs.map((tab) => _buildFeedList(tab, themeProvider)).toList(),
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
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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

  Widget _buildSearchOverlay(ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    final trimmedQuery = _searchQuery.trim();
    if (!_isFetchingSearch && _searchSuggestions.isEmpty && trimmedQuery.length < 2) {
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
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(12),
            color: scheme.surface,
            shadowColor: themeProvider.accentColor.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
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

                  if (_searchSuggestions.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.search_off, color: scheme.onSurface.withValues(alpha: 0.4)),
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
                    itemCount: _searchSuggestions.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: scheme.outlineVariant,
                    ),
                    itemBuilder: (context, index) {
                      final suggestion = _searchSuggestions[index];
                      final type = suggestion['type']?.toString() ?? 'profile';
                      final label = suggestion['label']?.toString() ??
                          suggestion['displayName']?.toString() ??
                          suggestion['title']?.toString() ??
                          suggestion['tag']?.toString() ??
                          'Result';
                      final subtitle = suggestion['subtitle']?.toString();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: themeProvider.accentColor.withValues(alpha: 0.1),
                          child: Icon(
                            _iconForSuggestionType(type),
                            color: themeProvider.accentColor,
                          ),
                        ),
                        title: Text(
                          label,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        subtitle: subtitle == null
                            ? null
                            : Text(
                                subtitle,
                                style: GoogleFonts.inter(
                                  color: scheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                        onTap: () => _handleSearchSuggestionTap(suggestion),
                      );
                    },
                  );
                },
              ),
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
            ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
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
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
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
        tabs: _tabs.map((tab) => Tab(
          height: 40,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(tab),
          ),
        )).toList(),
      ),
    );
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
        _searchSuggestions = [];
        _isFetchingSearch = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 275), () async {
      setState(() => _isFetchingSearch = true);
      try {
        final raw = await _backendApi.getSearchSuggestions(query: trimmed, limit: 8);
        final normalized = _backendApi.normalizeSearchSuggestions(raw);
        if (!mounted) return;
        setState(() {
          _searchSuggestions = normalized;
          _isFetchingSearch = false;
          _showSearchOverlay = true;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _searchSuggestions = [];
          _isFetchingSearch = false;
        });
      }
    });
  }

  void _handleSearchSubmit(String value) {
    setState(() {
      _searchQuery = value.trim();
      _showSearchOverlay = false;
      _searchSuggestions = [];
      _isFetchingSearch = false;
    });
  }

  void _handleSearchSuggestionTap(Map<String, dynamic> suggestion) {
    final label = suggestion['label']?.toString() ??
        suggestion['displayName']?.toString() ??
        suggestion['title']?.toString() ??
        suggestion['tag']?.toString() ??
        '';
    if (label.isNotEmpty) {
      _communitySearchController.text = label;
      _handleSearchSubmit(label);
    }

    final type = suggestion['type']?.toString() ?? '';
    final id = suggestion['id']?.toString() ??
        suggestion['wallet']?.toString() ??
        suggestion['wallet_address']?.toString();

    if (type == 'profile' && id != null && id.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: id),
        ),
      );
    }
  }

  IconData _iconForSuggestionType(String type) {
    switch (type) {
      case 'profile':
        return Icons.account_circle_outlined;
      case 'tag':
      case 'tags':
        return Icons.tag;
      case 'artwork':
        return Icons.auto_awesome;
      case 'group':
        return Icons.groups_rounded;
      default:
        return Icons.search;
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
      final mentionMatch = post.mentions.any((m) => m.toLowerCase().contains(query));
      final groupMatch = post.group?.name.toLowerCase().contains(query) ?? false;
      return contentMatch || authorMatch || tagMatch || mentionMatch || groupMatch;
    }).toList();
  }

  Widget _buildDiscoverFeed(ThemeProvider themeProvider) {
    final posts = _filterPostsForQuery(_discoverPosts);

    if (_isLoadingDiscover && _discoverPosts.isEmpty) {
      return _buildLoadingState(themeProvider, 'Loading posts...');
    }

    if (_discoverError != null && _discoverPosts.isEmpty) {
      return _buildErrorState(themeProvider, _discoverError!, _loadDiscoverFeed);
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
        itemCount: posts.length,
        itemBuilder: (context, index) => _buildPostCard(posts[index], themeProvider),
      ),
    );
  }

  Widget _buildFollowingFeed(ThemeProvider themeProvider) {
    final posts = _filterPostsForQuery(_followingPosts);

    if (_isLoadingFollowing && _followingPosts.isEmpty) {
      return _buildLoadingState(themeProvider, 'Loading posts...');
    }

    if (_followingError != null && _followingPosts.isEmpty) {
      return _buildErrorState(themeProvider, _followingError!, _loadFollowingFeed);
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
        itemBuilder: (context, index) => _buildPostCard(posts[index], themeProvider),
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

        final posts = _filterPostsForQuery(allPosts);
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
            );
          },
          color: themeProvider.accentColor,
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
                          );
                        },
                        icon: const Icon(Icons.my_location),
                        label: const Text('Use current area'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeProvider.accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      label: Text(single.label, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
              _showCreateGroupDialog(Provider.of<ThemeProvider>(context, listen: false));
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
                        milliseconds: animationTheme.medium.inMilliseconds + (index * 50),
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                              heroTag: 'desktop_comm_fab_option_${option.label}',
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
          backgroundColor: _isFabExpanded ? scheme.surfaceContainerHighest : themeProvider.accentColor,
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
            await communityProvider.loadGroups(refresh: true, search: _groupSearchController.text);
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
                        child: TextField(
                          controller: _groupSearchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _groupSearchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      _groupSearchController.clear();
                                      communityProvider.loadGroups(refresh: true);
                                      setState(() {});
                                    },
                                  )
                                : null,
                            hintText: 'Search groups...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {});
                            _groupSearchDebounce?.cancel();
                            _groupSearchDebounce = Timer(const Duration(milliseconds: 300), () {
                              communityProvider.loadGroups(refresh: true, search: value.trim());
                            });
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final communityProvider = Provider.of<CommunityHubProvider>(context, listen: false);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await communityProvider.createGroup(name: name, description: descController.text.trim());
              if (!mounted) return;
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.accentColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(CommunityGroupSummary group, ThemeProvider themeProvider) {
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
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupFeedScreen(group: group),
            ),
          ),
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
                  child: group.coverImage != null && group.coverImage!.isNotEmpty
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
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${group.memberCount} members',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          if (group.latestPost?.createdAt != null) ...[
                            const SizedBox(width: 16),
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 14,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Latest: ${_formatTimeAgo(group.latestPost!.createdAt!)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider, String error, VoidCallback onRetry) {
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              error,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.accentColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider themeProvider, IconData icon, String title, String subtitle) {
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
    return DesktopCard(
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
                        Text(
                          post.authorName,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (post.category == 'artist') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: themeProvider.accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Artist',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: themeProvider.accentColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _formatTimeAgo(post.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
              children: post.tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: themeProvider.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '#$tag',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: themeProvider.accentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
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
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
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
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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
                Icons.favorite_border,
                post.likeCount.toString(),
                themeProvider,
                onPressed: () {},
              ),
              const SizedBox(width: 24),
              _buildActionButton(
                Icons.chat_bubble_outline,
                post.commentCount.toString(),
                themeProvider,
                onPressed: () {},
              ),
              const SizedBox(width: 24),
              _buildActionButton(
                Icons.repeat,
                post.shareCount.toString(),
                themeProvider,
                onPressed: () {},
              ),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.bookmark_border,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.share_outlined,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String count,
    ThemeProvider themeProvider, {
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        hoverColor: themeProvider.accentColor.withValues(alpha: 0.08),
        splashColor: themeProvider.accentColor.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Text(
                count,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightSidebar(ThemeProvider themeProvider) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Sidebar tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSidebarTab(
                    'Feed',
                    Icons.dynamic_feed,
                    !_showMessagesPanel,
                    () => setState(() => _showMessagesPanel = false),
                    themeProvider,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSidebarTab(
                    'Messages',
                    Icons.message,
                    _showMessagesPanel,
                    () => setState(() => _showMessagesPanel = true),
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
                      // Create post prompt
                      _buildCreatePostPrompt(themeProvider),
                      const SizedBox(height: 24),

                      // Trending section
                      _buildTrendingSection(themeProvider),
                      const SizedBox(height: 24),

                      // Who to follow
                      _buildWhoToFollowSection(themeProvider),
                      const SizedBox(height: 24),

                      // Active communities
                      _buildActiveCommunitiesSection(themeProvider),
                    ],
                  ),
          ),
        ],
      ),
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
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
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
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? themeProvider.accentColor
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesPanel(ThemeProvider themeProvider) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final conversations = chatProvider.conversations;

        return Column(
          children: [
            // Search and new message
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search messages...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          border: InputBorder.none,
                          icon: Icon(
                            Icons.search,
                            size: 20,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _startNewConversation,
                    icon: Icon(
                      Icons.edit_square,
                      color: themeProvider.accentColor,
                    ),
                    tooltip: 'New message',
                  ),
                ],
              ),
            ),
            // Conversations list
            Expanded(
              child: conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start a conversation with an artist',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        return _buildConversationItem(
                          conversations[index],
                          themeProvider,
                          chatProvider,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConversationItem(Conversation conversation, ThemeProvider themeProvider, ChatProvider chatProvider) {
    final unreadCount = chatProvider.unreadCounts[conversation.id] ?? 0;
    final hasUnread = unreadCount > 0;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openConversation(conversation),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: hasUnread
                ? themeProvider.accentColor.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  AvatarWidget(
                    avatarUrl: conversation.displayAvatar,
                    wallet: conversation.memberWallets.isNotEmpty
                        ? conversation.memberWallets.first
                        : '',
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
                          color: themeProvider.accentColor,
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
                      conversation.title ?? 'Conversation',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (conversation.lastMessage != null)
                      Text(
                        conversation.lastMessage!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTimeAgo(conversation.lastMessageAt),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startNewConversation() {
    // Show dialog to start new conversation
    showDialog(
      context: context,
      builder: (context) => _NewConversationDialog(
        themeProvider: Provider.of<ThemeProvider>(context),
        onStartConversation: (userId) {
          Navigator.pop(context);
          // Navigate to conversation screen
        },
      ),
    );
  }

  void _openConversation(Conversation conversation) {
    // Open conversation detail - for now show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening conversation with ${conversation.title ?? "user"}...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
              onTap: () => setState(() => _isComposerExpanded = !_isComposerExpanded),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'What\'s happening?',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                              ? Theme.of(context).colorScheme.surfaceContainerHighest
                              : themeProvider.accentColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _isComposerExpanded ? Icons.expand_less : Icons.edit_outlined,
                          size: 16,
                          color: _isComposerExpanded
                              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
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
              hintText: 'Share what you\'re building, discovering, or thinking...',
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
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
                ...hub.draft.tags.map((tag) => _buildMiniChip('#$tag', themeProvider, () {
                  hub.removeTag(tag);
                  setState(() {});
                })),
                ...hub.draft.mentions.map((m) => _buildMiniChip('@$m', themeProvider, () {
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
                            image: MemoryImage(_selectedImages[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 10,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImages.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
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
                  Icon(Icons.location_on, size: 14, color: themeProvider.accentColor),
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
                    child: Icon(Icons.close, size: 12, color: themeProvider.accentColor),
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
                          ? Colors.orange
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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
                  disabledBackgroundColor: themeProvider.accentColor.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildMiniChip(String label, ThemeProvider themeProvider, VoidCallback onRemove) {
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
            child: Icon(Icons.close, size: 12, color: themeProvider.accentColor),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Tag', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
            child: const Text('Cancel'),
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

  Future<void> _submitInlinePost() async {
    if (_composeController.text.trim().isEmpty) return;

    setState(() => _isPosting = true);

    try {
      final api = BackendApiService();
      final hub = Provider.of<CommunityHubProvider>(context, listen: false);
      hub.setDraftCategory(_selectedCategory);

      final draft = hub.draft;
      final location = draft.location;
      final locationName = _selectedLocation ?? draft.locationLabel ?? location?.name;

      if (draft.targetGroup != null) {
        await api.createGroupPost(
          draft.targetGroup!.id,
          content: _composeController.text.trim(),
          category: draft.category,
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Post published!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 12),
                Text(
                  'No trending topics yet. Engage with the community to surface trends.',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: _trendingTopics.asMap().entries.map((entry) {
              final topic = entry.value;
              final rank = entry.key + 1;
              final title = (topic['term'] ?? topic['tag'] ?? topic['query'] ?? topic['search'] ?? '').toString();
              final count = topic['count'] ?? topic['search_count'] ?? topic['occurrences'] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DesktopCard(
                  onTap: () => _composeController.text = '${_composeController.text} #$title '.trim(),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: themeProvider.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '#$rank',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: themeProvider.accentColor,
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
                              title,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$count mentions',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.add,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Follow artists to personalize your feed.',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: _suggestedArtists.map((artist) {
              final displayName = (artist['displayName'] ?? artist['name'] ?? artist['username'] ?? 'Creator').toString();
              final handle = (artist['username'] ?? artist['walletAddress'] ?? artist['wallet'] ?? '').toString();
              final avatar = (artist['avatar'] ?? artist['avatarUrl'] ?? artist['profileImage'])?.toString();
              final walletAddress = (artist['walletAddress'] ?? artist['wallet'])?.toString();
              final profileId = walletAddress ?? handle;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DesktopCard(
                  onTap: profileId.isEmpty
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(userId: profileId, username: handle),
                            ),
                          ),
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
                        Icon(Icons.verified, color: themeProvider.accentColor, size: 16),
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
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Followed $displayName'),
                            ),
                          );
                        },
                        child: Text(
                          'Follow',
                          style: GoogleFonts.inter(
                            color: themeProvider.accentColor,
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              )
            else
              ...groups.take(5).map((group) => _buildCommunityItemFromGroup(group, themeProvider)),
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

  Widget _buildCommunityItemFromGroup(CommunityGroupSummary group, ThemeProvider themeProvider) {
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
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (group.isMember)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
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
                          onPressed: _composeController.text.trim().isEmpty || _isPosting
                              ? null
                              : _submitPost,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.accentColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: themeProvider.accentColor.withValues(alpha: 0.4),
                            disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
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
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTagMentionRow(themeProvider, inset: false),
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
                                          borderRadius: BorderRadius.circular(12),
                                          image: DecorationImage(
                                            image: MemoryImage(_selectedImages[index]),
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
                                              color: Colors.black.withValues(alpha: 0.6),
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
                          // Location indicator
                          if (_selectedLocation != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: themeProvider.accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: themeProvider.accentColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _selectedLocation!,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: themeProvider.accentColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => setState(() => _selectedLocation = null),
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: themeProvider.accentColor,
                                    ),
                                  ),
                                ],
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
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _pickImage,
                          icon: Icon(Icons.image_outlined, color: themeProvider.accentColor),
                          tooltip: 'Add image',
                        ),
                        IconButton(
                          onPressed: _showARAttachmentInfo,
                          icon: Icon(Icons.view_in_ar, color: themeProvider.accentColor),
                          tooltip: 'Add AR content',
                        ),
                        IconButton(
                          onPressed: _pickLocation,
                          icon: Icon(Icons.location_on_outlined, color: themeProvider.accentColor),
                          tooltip: 'Add location',
                        ),
                        IconButton(
                          onPressed: _showEmojiPicker,
                          icon: Icon(Icons.emoji_emotions_outlined, color: themeProvider.accentColor),
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
                                    ? Colors.orange
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
      setState(() {
        _selectedImages.add(bytes);
      });
    }
  }

  Future<void> _pickLocation() async {
    final controller = TextEditingController(text: _selectedLocation ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
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
              child: const Text('Cancel'),
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
    const emojis = ['🎨', '🔥', '✨', '🛰️', '🖼️', '🌐', '💫', '🚀'];
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
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
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
                ...hub.draft.tags.map((tag) => _buildChip(tag, themeProvider, () {
                      hub.removeTag(tag);
                      setState(() {});
                    })),
                ...hub.draft.mentions.map((m) => _buildChip('@$m', themeProvider, () {
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
                decoration: const InputDecoration(
                  hintText: 'Add tag',
                  prefixText: '# ',
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
                decoration: const InputDecoration(
                  hintText: 'Mention',
                  prefixText: '@ ',
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

  Widget _buildChip(String label, ThemeProvider themeProvider, VoidCallback onRemove) {
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.view_in_ar, color: Theme.of(context).colorScheme.onSurface),
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
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DownloadAppScreen(),
                ),
              );
            },
            child: Text(
              'Open mobile app',
              style: GoogleFonts.inter(
                color: Provider.of<ThemeProvider>(context, listen: false).accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPost() async {
    if (_composeController.text.trim().isEmpty) return;

    setState(() => _isPosting = true);

    try {
      final api = BackendApiService();
      final hub = Provider.of<CommunityHubProvider>(context, listen: false);
      hub.setDraftCategory(_selectedCategory);

      // In parity with mobile, we would upload media first; skip upload here but keep hook
      final mediaUrls = <String>[];

      final draft = hub.draft;
      final location = draft.location;
      final locationName = _selectedLocation ?? draft.locationLabel ?? location?.name;

      if (draft.targetGroup != null) {
        await hub.submitGroupPost(
          draft.targetGroup!.id,
          content: _composeController.text.trim(),
          mediaUrls: mediaUrls.isEmpty ? null : mediaUrls,
          category: draft.category,
          tags: draft.tags,
          mentions: draft.mentions,
          location: location,
          locationLabel: locationName,
        );
      } else {
        await api.createCommunityPost(
          content: _composeController.text.trim(),
          mediaUrls: mediaUrls.isEmpty ? null : mediaUrls,
          category: draft.category,
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Post created successfully!'),
            backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Refresh the feed
        await _loadFeed();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
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
  final TextEditingController _searchController = TextEditingController();
  final List<dynamic> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                  icon: Icon(
                    Icons.search,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                style: GoogleFonts.inter(fontSize: 14),
                onChanged: (value) {
                  // Search users - placeholder
                  setState(() => _isSearching = value.isNotEmpty);
                },
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: _isSearching && _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Search for users to message',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                        return ListTile(
                          leading: AvatarWidget(
                            wallet: user['wallet'] ?? '',
                            radius: 20,
                            allowFabricatedFallback: true,
                          ),
                          title: Text(user['name'] ?? 'User'),
                          subtitle: Text(user['username'] ?? ''),
                          onTap: () => widget.onStartConversation(user['id']),
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
