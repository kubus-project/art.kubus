// NOTE: use_build_context_synchronously lint handled per-instance; avoid file-level ignore
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/inline_loading.dart';
import '../widgets/app_loading.dart';
import '../widgets/topbar_icon.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/empty_state_card.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart' as loc;
import 'dart:io';
import 'dart:math' as math;
import '../providers/themeprovider.dart';
import '../providers/config_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/profile_provider.dart';
import '../services/backend_api_service.dart';
import '../services/push_notification_service.dart';
import 'user_profile_screen.dart';
import 'post_detail_screen.dart';
import '../community/community_interactions.dart';
import '../services/user_service.dart';
import '../providers/app_refresh_provider.dart';
import '../services/socket_service.dart';
import '../providers/notification_provider.dart';
import '../providers/chat_provider.dart';
import 'messages_screen.dart';

enum CommunityFeedType {
  following,
  discover,
}

class CommunityScreen extends StatefulWidget {
  // Global key to allow other screens to request opening a post by id
  static final GlobalKey<_CommunityScreenState> globalKey =
      GlobalKey<_CommunityScreenState>();

  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _bellController;
  late Animation<double> _bellScale;
  late AnimationController _messagePulseController;
  late Animation<double> _messageScale;
  int _messageUnreadCount = 0;
  int _bellUnreadCount = 0;

  late TabController _tabController;

  final List<String> _tabs = ['Following', 'Discover', 'Groups', 'Art'];

  // Community data
  List<CommunityPost> _communityPosts = [];
  List<CommunityPost> _followingFeedPosts = [];
  List<CommunityPost> _discoverFeedPosts = [];
  // How many posts to prefetch comments for (make configurable)
  final int _commentPrefetchCount = 8;
  final int _prefetchConcurrencyLimit = 3;
  final int _prefetchMaxRetries = 3;
  final int _prefetchBaseDelayMs = 300; // milliseconds
  List<Map<String, dynamic>> _followingArtists = [];
  bool _isLoading = false;
  bool _isLoadingFollowingFeed = false;
  bool _isLoadingDiscoverFeed = false;
  bool _isLoadingFollowing = false;
  CommunityFeedType _activeFeed = CommunityFeedType.following;
  // Deduplication and local push are now handled centrally by NotificationProvider
  final Map<int, bool> _bookmarkedPosts = {};
  // Avatar cache removed - ChatProvider or UserService are used for user avatars
  final Map<int, bool> _followedArtists = {};
  // Scroll controller for the feed to detect when user is away from top
  late ScrollController _feedScrollController;

  // Buffered incoming posts when user is scrolled away from top
  final List<CommunityPost> _bufferedIncomingPosts = [];
  // Keep ids of posts we just created locally to suppress duplicate socket echoes
  final Set<String> _recentlyCreatedPostIds = <String>{};

  // New post state
  final TextEditingController _newPostController = TextEditingController();
  bool _isPostingNew = false;
  XFile? _selectedPostImage;
  Uint8List? _selectedPostImageBytes; // Store bytes for preview
  XFile? _selectedPostVideo;
  // Location selected by user when creating a new post; may be null.
  // selectedLocation removed; location name is used in the UI when creating posts
  String? _locationName;

  Future<void> _loadFollowingArtists() async {
    if (mounted) {
      setState(() {
        _isLoadingFollowing = true;
      });
    }
    try {
      final artists = await BackendApiService().listArtists(
        limit: 20,
        offset: 0,
      );
      if (mounted) {
        setState(() {
          _followingArtists = artists;
          _isLoadingFollowing = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading following artists: $e');
      if (mounted) {
        setState(() {
          _followingArtists = [];
          _isLoadingFollowing = false;
        });
      }
    }
  }

  Future<void> _loadCommunityData({bool? followingOnly}) async {
    final bool targetFollowing =
        followingOnly ?? (_activeFeed == CommunityFeedType.following);
    final bool isActiveFeed =
        (_activeFeed == CommunityFeedType.following && targetFollowing) ||
            (_activeFeed == CommunityFeedType.discover && !targetFollowing);

    if (targetFollowing) {
      if (_isLoadingFollowingFeed) return;
    } else {
      if (_isLoadingDiscoverFeed) return;
    }

    if (mounted) {
      setState(() {
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

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    try {
      final backendApi = BackendApiService();
      try {
        await backendApi.loadAuthToken();
        debugPrint('🔐 Auth token loaded for community posts');
      } catch (e) {
        debugPrint('⚠️ No auth token: $e');
      }

      final posts = await backendApi.getCommunityPosts(
        page: 1,
        limit: 50,
        followingOnly: targetFollowing,
      );
      debugPrint('📥 Loaded ${posts.length} posts from backend');

      await CommunityService.loadSavedInteractions(
        posts,
        walletAddress: walletProvider.currentWalletAddress,
      );
      debugPrint('✅ Restored local interaction state for posts');

      if (mounted) {
        setState(() {
          if (targetFollowing) {
            _followingFeedPosts = posts;
            _isLoadingFollowingFeed = false;
            if (isActiveFeed) {
              _communityPosts = _followingFeedPosts;
              _isLoading = false;
            }
          } else {
            _discoverFeedPosts = posts;
            _isLoadingDiscoverFeed = false;
            if (isActiveFeed) {
              _communityPosts = _discoverFeedPosts;
              _isLoading = false;
            }
          }
        });
        if (targetFollowing && isActiveFeed) {
          _prefetchComments();
        }
      }
    } catch (e) {
      debugPrint('Error loading community data: $e');
      if (mounted) {
        setState(() {
          if (targetFollowing) {
            _isLoadingFollowingFeed = false;
          } else {
            _isLoadingDiscoverFeed = false;
          }
          if (isActiveFeed) {
            _communityPosts = [];
            _isLoading = false;
          }
        });
      }
    }
  }

  void _activateFeed(CommunityFeedType target) {
    if (!mounted) return;

    setState(() {
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
      if (_followingFeedPosts.isEmpty && !_isLoadingFollowingFeed) {
        _loadCommunityData(followingOnly: true);
      }
    } else {
      if (_discoverFeedPosts.isEmpty && !_isLoadingDiscoverFeed) {
        _loadCommunityData(followingOnly: false);
      }
    }
  }

  Future<void> _prefetchComments() async {
    try {
      final prefetchCount =
          math.min(_commentPrefetchCount, _communityPosts.length);
      final concurrency = _prefetchConcurrencyLimit;
      for (var i = 0; i < prefetchCount; i += concurrency) {
        final end = math.min(i + concurrency, prefetchCount);
        final batch = _communityPosts.sublist(i, end);
        await Future.wait(batch.map((post) async {
          int attempt = 0;
          while (attempt < _prefetchMaxRetries) {
            try {
              final comments =
                  await BackendApiService().getComments(postId: post.id);
              post.comments = comments;
              post.commentCount = post.comments.length;
              if (mounted) setState(() {});
              break;
            } catch (e) {
              attempt++;
              final delayMs = _prefetchBaseDelayMs * (1 << (attempt - 1));
              debugPrint(
                  'Prefetch comments failed for post ${post.id} (attempt $attempt): $e. Retrying in ${delayMs}ms');
              await Future.delayed(Duration(milliseconds: delayMs));
            }
          }
        }));
      }
    } catch (e) {
      debugPrint('Unexpected error in _prefetchComments: $e');
    }
  }

  /// Public helper: open comments view for a post by id (if present in current feed)
  void openPostById(String postId) {
    final idx = _communityPosts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      // delay to ensure UI is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showComments(idx);
      });
    } else {
      // If not in feed, attempt to reload and then open
      (() async {
        await _loadCommunityData();
        final newIdx = _communityPosts.indexWhere((p) => p.id == postId);
        if (newIdx != -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showComments(newIdx);
          });
        }
      })();
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    // Load following feed by default
    _communityPosts = _followingFeedPosts;
    _activeFeed = CommunityFeedType.following;
    _loadCommunityData(followingOnly: true);
    // Listen for tab changes to load appropriate content
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      final idx = _tabController.index;
      if (idx == 0) {
        _activateFeed(CommunityFeedType.following);
      } else if (idx == 1) {
        _activateFeed(CommunityFeedType.discover);
      }
      // Groups and Collections tabs currently show placeholders
    });
    _loadFollowingArtists();

    // Initialize bookmark and follow data
    for (int i = 0; i < 10; i++) {
      _bookmarkedPosts[i] = false;
    }

    // Initialize artist follow status
    final followingStatus = [true, false, true, false];
    for (int i = 0; i < 8; i++) {
      _followedArtists[i] = followingStatus[i % followingStatus.length];
    }

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();

    // Feed scroll controller to detect whether user is at top
    _feedScrollController = ScrollController();
    _feedScrollController.addListener(() {
      try {
        // If user scrolled to near-top and we have buffered posts, prepend them
        if (_feedScrollController.hasClients &&
            _feedScrollController.offset <= 120 &&
            _bufferedIncomingPosts.isNotEmpty) {
          _prependBufferedPosts();
        }
      } catch (_) {}
    });

    _bellController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );

    _bellScale = Tween<double>(begin: 1.0, end: 1.18).animate(CurvedAnimation(
      parent: _bellController,
      curve: Curves.elasticOut,
    ));

    _messagePulseController = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
    _messageScale = Tween<double>(begin: 1.0, end: 1.12).animate(
        CurvedAnimation(
            parent: _messagePulseController, curve: Curves.easeOut));

    // Listen for socket notifications to animate bell
    try {
      SocketService()
          .addNotificationListener(_onSocketNotificationForCommunity);
    } catch (_) {}
    // Connect socket and listen for incoming posts to prepend to feed
    try {
      (() async {
        await SocketService().connect();
        SocketService().addPostListener(_handleIncomingPost);
      })();
    } catch (_) {}

    // Load initial unread notification count via provider
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final provider =
            Provider.of<NotificationProvider>(context, listen: false);
        await provider.refresh();
        if (!mounted) return;
        setState(() {
          _bellUnreadCount = provider.unreadCount;
        });
        provider.addListener(_onNotificationProviderChange);
      } catch (_) {}
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final cp = Provider.of<ChatProvider>(context, listen: false);
        // Ensure ChatProvider is initialized so socket subscriptions and unread counts are active
        try {
          await cp.initialize();
        } catch (_) {}
        if (!mounted) return;
        _messageUnreadCount = cp.totalUnread;
        cp.addListener(_onChatProviderChanged);
      } catch (_) {}
    });

    // Listen for config provider changes to reload data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final configProvider =
          Provider.of<ConfigProvider>(context, listen: false);
      configProvider.addListener(_onConfigChanged);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final walletProvider =
            Provider.of<WalletProvider>(context, listen: false);
        walletProvider.addListener(_onWalletProviderChanged);
      } catch (_) {}
    });
  }

  DateTime? _lastConfigChange;

  void _onConfigChanged() {
    // Debounce: only reload if at least 1 second has passed since last change
    final now = DateTime.now();
    if (_lastConfigChange != null &&
        now.difference(_lastConfigChange!).inSeconds < 1) {
      return;
    }
    _lastConfigChange = now;
    _loadCommunityData();
  }

  // Helper to get user avatar from backend
  // _getUserAvatar removed (unused) — avatars are now resolved via UserService and ChatProvider caching

  @override
  void dispose() {
    // Remove config provider listener
    try {
      final configProvider =
          Provider.of<ConfigProvider>(context, listen: false);
      configProvider.removeListener(_onConfigChanged);
    } catch (e) {
      // Provider may not be available during dispose
    }

    _animationController.dispose();
    try {
      SocketService()
          .removeNotificationListener(_onSocketNotificationForCommunity);
    } catch (_) {}
    try {
      Provider.of<NotificationProvider>(context, listen: false)
          .removeListener(_onNotificationProviderChange);
    } catch (_) {}
    _bellController.dispose();
    _messagePulseController.dispose();
    try {
      Provider.of<ChatProvider>(context, listen: false)
          .removeListener(_onChatProviderChanged);
    } catch (_) {}
    try {
      Provider.of<WalletProvider>(context, listen: false)
          .removeListener(_onWalletProviderChanged);
    } catch (_) {}
    try {
      SocketService().removePostListener(_handleIncomingPost);
    } catch (_) {}
    try {
      _feedScrollController.dispose();
    } catch (_) {}
    _tabController.dispose();
    super.dispose();
  }

  void _handleIncomingPost(Map<String, dynamic> data) async {
    try {
      final id = (data['id'] ?? data['postId'] ?? data['post_id'])?.toString();
      if (id == null) return;
      if (_recentlyCreatedPostIds.remove(id)) return;
      if (_communityPosts.any((p) => p.id == id)) return;
      try {
        final post = await BackendApiService().getCommunityPostById(id);
        if (!mounted) return;

        final atTop = _feedScrollController.hasClients
            ? _feedScrollController.offset <= 120
            : true;
        if (atTop) {
          setState(() {
            _communityPosts.insert(0, post);
          });
        } else {
          // Buffer incoming post and show indicator
          setState(() {
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

  void _prependBufferedPosts() {
    if (_bufferedIncomingPosts.isEmpty) return;
    setState(() {
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
    // When wallet/login state changes, reload saved likes state so UI reflects current account
    try {
      if (_communityPosts.isNotEmpty) {
        await CommunityService.loadSavedInteractions(
          _communityPosts,
          walletAddress: Provider.of<WalletProvider>(context, listen: false)
              .currentWalletAddress,
        );
        if (!mounted) return;
        setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to refresh saved interactions on wallet change: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    _buildAppBar(),
                    _buildTabBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildFeedTab(),
                          _buildDiscoverTab(),
                          _buildFollowingTab(),
                          _buildCollectionsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildAppBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 375;
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Text(
            'Connect',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          // Search icon - unified TopBarIcon
          TopBarIcon(
            tooltip: 'Search',
            icon: Icon(
              Icons.search,
              color: Theme.of(context).colorScheme.onSurface,
              size: isSmallScreen ? 20 : 24,
            ),
            onPressed: _showSearchBottomSheet,
          ),
          const SizedBox(width: 8),
          // Bell icon - unified TopBarIcon
          TopBarIcon(
            tooltip: 'Notifications',
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
                    color: Theme.of(context).colorScheme.onSurface,
                    size: isSmallScreen ? 20 : 24,
                  ),
                );
              },
            ),
            onPressed: _showNotifications,
            badgeCount: _bellUnreadCount,
            badgeColor: themeProvider.accentColor,
          ),
          const SizedBox(width: 8),
          // Message icon - open messages screen as a full-screen modal
          Selector<ChatProvider, int>(
            selector: (_, cp) => cp.totalUnread,
            builder: (context, totalUnread, child) {
              // Animate when unread count increases
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (totalUnread > 0 && _messageScale.value == 1.0) {
                  _messagePulseController.forward(from: 0.0);
                }
              });
              return TopBarIcon(
                tooltip: 'Open messages',
                icon: ScaleTransition(
                  scale: _messageScale,
                  child: Icon(
                    totalUnread > 0
                        ? Icons.chat_bubble
                        : Icons.chat_bubble_outline,
                    color: totalUnread > 0
                        ? themeProvider.accentColor
                        : Theme.of(context).colorScheme.onSurface,
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
                onPressed: () {
                  showGeneralDialog(
                    context: context,
                    barrierDismissible: true,
                    barrierLabel: 'Messages',
                    barrierColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withAlpha(179),
                    transitionDuration: const Duration(milliseconds: 300),
                    pageBuilder: (ctx, a1, a2) => const MessagesScreen(),
                    transitionBuilder: (ctx, anim1, anim2, child) {
                      final curved = Curves.easeOut.transform(anim1.value);
                      return Transform.translate(
                        offset: Offset(0,
                            (1 - curved) * MediaQuery.of(context).size.height),
                        child: Opacity(opacity: anim1.value, child: child),
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
      setState(() {
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
      setState(() {});
    } catch (_) {}
  }

  // Unread notification count is now managed via NotificationProvider.

  Widget _buildTabBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 375;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: isSmallScreen,
            tabAlignment:
                isSmallScreen ? TabAlignment.start : TabAlignment.fill,
            tabs: _tabs
                .map((tab) => Tab(
                      child: Text(
                        tab,
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 9 : 10,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            indicator: BoxDecoration(
              color: themeProvider.accentColor,
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorPadding: EdgeInsets.all(isSmallScreen ? 2 : 4),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Theme.of(context).colorScheme.onPrimary,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            labelStyle: GoogleFonts.inter(
              fontSize: isSmallScreen ? 9 : 10,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontSize: isSmallScreen ? 9 : 10,
              fontWeight: FontWeight.normal,
            ),
            dividerHeight: 0,
          ),
        );
      },
    );
  }

  Widget _buildFeedTab() {
    return _buildPostTimeline(
      onRefresh: () => _loadCommunityData(followingOnly: true),
      emptyIcon: Icons.feed,
      emptyTitle: 'No Posts Available',
      emptySubtitle: 'Follow creators to see their updates here.',
      showBufferedBanner: true,
    );
  }

  Widget _buildDiscoverTab() {
    return _buildPostTimeline(
      onRefresh: () => _loadCommunityData(followingOnly: false),
      emptyIcon: Icons.travel_explore,
      emptyTitle: 'No Community Posts Yet',
      emptySubtitle: 'Posts from across Kubus will appear here soon.',
    );
  }

  Widget _buildPostTimeline({
    required Future<void> Function() onRefresh,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
    bool showBufferedBanner = false,
  }) {
    if (_isLoading) {
      return const AppLoading();
    }

    if (_communityPosts.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: EmptyStateCard(
                icon: emptyIcon,
                title: emptyTitle,
                description: emptySubtitle,
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
            controller: showBufferedBanner ? _feedScrollController : null,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            itemCount: _communityPosts.length,
            itemBuilder: (context, index) => _buildPostCard(index),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6)
                      ],
                    ),
                    child: Text(
                      '${_bufferedIncomingPosts.length} new post${_bufferedIncomingPosts.length > 1 ? 's' : ''} — Tap to show',
                      style: GoogleFonts.inter(
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

  Widget _buildFollowingTab() {
    if (_isLoadingFollowing) {
      return const AppLoading();
    }

    if (_followingArtists.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await _loadFollowingArtists();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: EmptyStateCard(
                icon: Icons.people,
                title: 'No Artists Yet',
                description: 'Discover and follow artists in the Discover tab',
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadFollowingArtists();
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemCount: _followingArtists.length,
        itemBuilder: (context, index) =>
            _buildArtistCard(_followingArtists[index], index),
      ),
    );
  }

  Widget _buildCollectionsTab() {
    return Center(
      child: EmptyStateCard(
        icon: Icons.collections,
        title: 'No Collections Available',
        description: 'Curated collections will appear here when available',
      ),
    );
  }

  Widget _buildPostCard(int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Use actual post data from backend
    if (index >= _communityPosts.length) {
      return const SizedBox.shrink();
    }

    final post = _communityPosts[index];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 375;

        return Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: GestureDetector(
                onTap: () => _viewPostDetail(index),
                child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // (Removed repost indicator: top-level repost label and icon were redundant)
                          Row(
                            children: [
                              AvatarWidget(
                                // Always show reposter's avatar on the top-level post card
                                wallet: (post.authorWallet ?? post.authorId),
                                avatarUrl: post.authorAvatar,
                                radius: 20,
                                allowFabricatedFallback: true,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _viewUserProfile(post.authorId),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        post.authorName,
                                        style: GoogleFonts.inter(
                                          fontSize: isSmallScreen ? 14 : 16,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '@${post.authorUsername}',
                                        style: GoogleFonts.inter(
                                          fontSize: isSmallScreen ? 12 : 14,
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
                              ),
                              const Spacer(),
                              Text(
                                _getTimeAgo(post.timestamp),
                                style: GoogleFonts.inter(
                                  fontSize: isSmallScreen ? 10 : 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Repost comment (if exists)
                          if (post.postType == 'repost' &&
                              post.content.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              post.content,
                              style: GoogleFonts.inter(
                                fontSize: isSmallScreen ? 13 : 15,
                                height: 1.5,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Divider(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                          ],
                          // If this is a repost - show original post in its own inner card
                          if (post.postType == 'repost' &&
                              post.originalPost != null) ...[
                            _buildRepostInnerCard(post.originalPost!),
                          ] else ...[
                            Text(
                              post.content,
                              style: GoogleFonts.inter(
                                fontSize: isSmallScreen ? 13 : 15,
                                height: 1.5,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                          if ((post.postType == 'repost' &&
                                  post.originalPost?.imageUrl != null) ||
                              (post.postType != 'repost' &&
                                  post.imageUrl != null)) ...[
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => PostDetailScreen(
                                          post: (post.postType == 'repost' &&
                                                  post.originalPost != null)
                                              ? post.originalPost
                                              : post))),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  (post.postType == 'repost' &&
                                          post.originalPost != null)
                                      ? post.originalPost!.imageUrl!
                                      : post.imageUrl!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      height: 200,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            themeProvider.accentColor
                                                .withValues(alpha: 0.3),
                                            themeProvider.accentColor
                                                .withValues(alpha: 0.1),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                            width: 36,
                                            height: 36,
                                            child: InlineLoading(
                                                expand: true,
                                                shape: BoxShape.circle,
                                                tileSize: 4.0,
                                                progress: loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? (loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!)
                                                    : null)),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 200,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            themeProvider.accentColor
                                                .withValues(alpha: 0.3),
                                            themeProvider.accentColor
                                                .withValues(alpha: 0.1),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Icon(Icons.image_not_supported,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                            size: 60),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildInteractionButton(
                                post.isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                '${post.likeCount}',
                                onTap: () => _toggleLike(index),
                                onCountTap: () => _showPostLikes(post.id),
                                isActive: post.isLiked,
                              ),
                              const SizedBox(width: 20),
                              _buildInteractionButton(
                                Icons.comment_outlined,
                                '${post.commentCount}',
                                onTap: () => _showComments(index),
                              ),
                              const SizedBox(width: 20),
                              _buildInteractionButton(
                                Icons.repeat,
                                '',
                                onTap: () {
                                  // Check if this is user's own repost
                                  final walletProvider =
                                      Provider.of<WalletProvider>(context,
                                          listen: false);
                                  final currentWallet =
                                      walletProvider.currentWalletAddress;
                                  if (post.postType == 'repost' &&
                                      post.authorWallet == currentWallet) {
                                    // Show unrepost option
                                    _showRepostOptions(post);
                                  } else {
                                    _showRepostModal(post);
                                  }
                                },
                              ),
                              const SizedBox(width: 20),
                              _buildInteractionButton(
                                Icons.share_outlined,
                                '${post.shareCount}',
                                onTap: () => _sharePost(index),
                                onCountTap: post.shareCount > 0
                                    ? () => _viewRepostsList(post)
                                    : null,
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => _toggleBookmark(index),
                                icon: Icon(
                                  post.isBookmarked
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: post.isBookmarked
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ]))));
      },
    );
  }

  Widget _buildInteractionButton(IconData icon, String count,
      {VoidCallback? onTap, bool isActive = false, VoidCallback? onCountTap}) {
    return GestureDetector(
      onTapDown: (_) {
        // Immediate haptic feedback and visual response
        if (onTap != null && mounted) {
          setState(() {
            // Force immediate rebuild for ultra-fast response
          });
        }
      },
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            AnimatedScale(
              scale: isActive ? 1.18 : 1.0,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              child: Icon(
                icon,
                color: isActive
                    ? Provider.of<ThemeProvider>(context).accentColor
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                size: 20,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCountTap,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 100),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isActive
                      ? Provider.of<ThemeProvider>(context).accentColor
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(count),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepostInnerCard(CommunityPost originalPost) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => PostDetailScreen(post: originalPost))),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarWidget(
                  wallet: originalPost.authorWallet ?? originalPost.authorId,
                  avatarUrl: originalPost.authorAvatar,
                  radius: 16,
                  allowFabricatedFallback: true,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        originalPost.authorName,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: scheme.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@${originalPost.authorUsername}',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.6)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  _getTimeAgo(originalPost.timestamp),
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              originalPost.content,
              style: GoogleFonts.inter(fontSize: 13, color: scheme.onSurface),
            ),
            if (originalPost.imageUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  originalPost.imageUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 140,
                    color: themeProvider.accentColor.withValues(alpha: 0.1),
                    child: Icon(Icons.image_not_supported,
                        color: themeProvider.accentColor),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildArtistCard(Map<String, dynamic> artist, int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final artistName = artist['name'] as String? ?? 'Unknown Artist';
    final username =
        artist['username'] as String? ?? artist['publicKey'] as String? ?? '';
    final followersCount = artist['followersCount'] as int? ?? 0;
    final artworksCount = artist['artworksCount'] as int? ?? 0;
    final isFollowing = _followedArtists[index] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  themeProvider.accentColor,
                  themeProvider.accentColor.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.person,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),

          // Artist Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artistName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '@${username.length > 15 ? username.substring(0, 15) : username}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '$artworksCount artworks • $followersCount followers',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // Follow Button
          ElevatedButton(
            onPressed: () => _toggleFollowArtist(index),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing
                  ? Theme.of(context).colorScheme.surface
                  : themeProvider.accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isFollowing
                    ? BorderSide(color: Theme.of(context).colorScheme.outline)
                    : BorderSide.none,
              ),
            ),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isFollowing
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return FloatingActionButton(
      onPressed: () {
        _createNewPost();
      },
      backgroundColor: themeProvider.accentColor,
      child: Icon(
        Icons.add,
        color: Theme.of(context).colorScheme.onPrimary,
        size: 28,
      ),
    );
  }

  // Navigation and interaction methods
  void _showSearchBottomSheet() {
    if (!mounted) return;
    final sheetContext = context;
    // Basic profile search in bottom sheet. For now this displays profiles (users).
    // TODO: Expand to include artworks, institutions, and in-app screen search.
    final sheetSearchController = TextEditingController();
    final backend = BackendApiService();
    List<Map<String, dynamic>> results = [];
    bool isLoading = false;

    showModalBottomSheet(
      context: sheetContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: TextField(
                  controller: sheetSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search artists, artworks, collections...',
                    hintStyle: TextStyle(
                      fontSize:
                          MediaQuery.of(context).size.width < 400 ? 14 : 16,
                    ),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.primaryContainer,
                    contentPadding: EdgeInsets.symmetric(
                      vertical:
                          MediaQuery.of(context).size.width < 400 ? 12 : 16,
                      horizontal: 16,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width < 400 ? 14 : 16,
                  ),
                  onChanged: (q) async {
                    final query = q.trim();
                    if (query.isEmpty) {
                      setModalState(() {
                        results.clear();
                      });
                      return;
                    }
                    try {
                      setModalState(() => isLoading = true);
                      final resp = await backend.search(
                          query: query, type: 'profiles', limit: 20);
                      final list = <Map<String, dynamic>>[];
                      if (resp['success'] == true) {
                        if (resp['results'] is Map<String, dynamic>) {
                          final data = resp['results'] as Map<String, dynamic>;
                          final profiles =
                              (data['profiles'] as List<dynamic>?) ??
                                  (data['results'] as List<dynamic>?) ??
                                  [];
                          for (final d in profiles) {
                            try {
                              list.add(d as Map<String, dynamic>);
                            } catch (_) {}
                          }
                        } else if (resp['data'] is List) {
                          for (final d in resp['data']) {
                            try {
                              list.add(d as Map<String, dynamic>);
                            } catch (_) {}
                          }
                        } else if (resp['data'] is Map<String, dynamic>) {
                          final data = resp['data'] as Map<String, dynamic>;
                          final profiles =
                              (data['profiles'] as List<dynamic>?) ?? [];
                          for (final d in profiles) {
                            try {
                              list.add(d as Map<String, dynamic>);
                            } catch (_) {}
                          }
                        }
                      }
                      if (!mounted) return;
                      setModalState(() {
                        results = list;
                        isLoading = false;
                      });
                    } catch (e) {
                      debugPrint('Community search error: $e');
                      if (mounted) setModalState(() => isLoading = false);
                    }
                  },
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : results.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'No results',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.4),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: results.length,
                            itemBuilder: (ctx, idx) {
                              final s = results[idx];
                              final username = s['username'] ??
                                  s['wallet_address'] ??
                                  s['wallet'];
                              final display =
                                  s['displayName'] ?? s['display_name'] ?? '';
                              final avatar = s['avatar'] ??
                                  s['avatar_url'] ??
                                  s['profileImageUrl'] ??
                                  '';
                              final walletAddr = (s['wallet_address'] ??
                                          s['wallet'] ??
                                          s['walletAddress'])
                                      ?.toString() ??
                                  '';
                              final title = (display ?? username)?.toString();
                              final subtitle = walletAddr.isNotEmpty
                                  ? walletAddr
                                  : (username ?? '').toString();
                              return ListTile(
                                leading: AvatarWidget(
                                    avatarUrl: (avatar != null &&
                                            avatar.toString().isNotEmpty)
                                        ? avatar.toString()
                                        : null,
                                    wallet: subtitle,
                                    radius: 20,
                                    allowFabricatedFallback: false),
                                title: Text(title ?? ''),
                                subtitle: Text(subtitle),
                                onTap: () {
                                  Navigator.pop(context);
                                  if (walletAddr.isNotEmpty) {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => UserProfileScreen(
                                                userId: walletAddr)));
                                  }
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showNotifications() async {
    final notificationService = PushNotificationService();
    final backend = BackendApiService();
    List<Map<String, dynamic>> combined = [];

    // Initial load function
    Future<List<Map<String, dynamic>>> loadNotifications() async {
      try {
        // Ensure auth token is loaded for user-specific notifications
        try {
          await backend.loadAuthToken();
          final token = backend.getAuthToken();
          debugPrint(
              '🔐 Auth token loaded for notifications: ${token != null ? (token.length > 16 ? '${token.substring(0, 8)}...' : token) : "<none>"}');
          // Optionally fetch which wallet this token maps to
          try {
            final me = await backend.getMyProfile();
            debugPrint(
                '🔍 Token maps to wallet: ${me['wallet'] ?? me['wallet_address']}');
          } catch (e) {
            debugPrint('⚠️ Unable to map token to profile: $e');
          }
        } catch (e) {
          debugPrint('⚠️ No auth token available: $e');
        }

        // Load local in-app notifications
        final local = await notificationService.getInAppNotifications();
        // Load server notifications (if authenticated)
        final remote = await backend.getNotifications(limit: 50);
        debugPrint(
            '📥 Loaded ${local.length} local + ${remote.length} remote notifications');
        // Normalize remote (ensure Map<String,dynamic>)
        final remapped =
            remote.map((e) => Map<String, dynamic>.from(e)).toList();
        final notifications = [...local, ...remapped];
        // Sort by timestamp desc if available
        notifications.sort((a, b) {
          final ta = a['timestamp'] ?? a['createdAt'] ?? '';
          final tb = b['timestamp'] ?? b['createdAt'] ?? '';
          try {
            final da = DateTime.parse(ta.toString());
            final db = DateTime.parse(tb.toString());
            return db.compareTo(da);
          } catch (_) {
            return 0;
          }
        });
        return notifications;
      } catch (e) {
        debugPrint('Failed to load notifications: $e');
        return [];
      }
    }

    combined = await loadNotifications();
    if (!mounted) return;

    // Clear bell unread count when opening notifications
    try {
      setState(() {
        _bellUnreadCount = 0;
      });
      Provider.of<NotificationProvider>(context, listen: false).markViewed();
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Text(
                      'Community Notifications',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    // Removed 'Mark all read' per UX decision: notifications are marked as read when viewed
                  ],
                ),
              ),
              Expanded(
                child: combined.isEmpty
                    ? RefreshIndicator(
                        onRefresh: () async {
                          final refreshed = await loadNotifications();
                          setModalState(() {
                            combined = refreshed;
                          });
                        },
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.notifications_none,
                                      size: 64,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No Notifications',
                                      style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'You\'re all caught up!',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          final refreshed = await loadNotifications();
                          setModalState(() {
                            combined = refreshed;
                          });
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemBuilder: (ctx, i) {
                            final n = combined[i];
                            final type =
                                (n['interactionType'] ?? n['type'] ?? '')
                                    .toString();
                            // Extract sender info from backend notification structure
                            final sender = n['sender'] as Map<String, dynamic>?;
                            final user = sender?['displayName'] as String? ??
                                sender?['username'] as String? ??
                                (n['userName'] ?? n['authorName'] ?? 'Someone')
                                    .toString();
                            final body = (n['comment'] ??
                                    n['message'] ??
                                    n['content'] ??
                                    '')
                                .toString();
                            final ts = (n['timestamp'] ?? n['createdAt'] ?? '')
                                .toString();
                            String time = ts.isNotEmpty ? ts : '';
                            try {
                              if (time.isNotEmpty)
                                time = _getTimeAgo(DateTime.parse(time));
                            } catch (_) {}
                            final leadSeed = (sender?['wallet'] ??
                                    sender?['wallet_address'] ??
                                    sender?['walletAddress'] ??
                                    user)
                                .toString();
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.06)),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 6)
                                ],
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  final postId = n['postId']?.toString();
                                  if (postId != null && postId.isNotEmpty) {
                                    final idx = _communityPosts
                                        .indexWhere((p) => p.id == postId);
                                    if (idx != -1) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        _showComments(idx);
                                      });
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Row(
                                  children: [
                                    AvatarWidget(
                                        wallet: leadSeed,
                                        radius: 20,
                                        allowFabricatedFallback: false),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            type == 'like'
                                                ? '$user liked your post'
                                                : type == 'comment'
                                                    ? '$user commented'
                                                    : type == 'reply'
                                                        ? '$user replied'
                                                        : type == 'mention'
                                                            ? '$user mentioned you'
                                                            : (n['type'] ??
                                                                    'Notification')
                                                                .toString(),
                                            style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(body,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.7))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(time,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.5))),
                                  ],
                                ),
                              ),
                            );
                          },
                          separatorBuilder: (ctx, i) => Divider(
                              height: 1,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.06)),
                          itemCount: combined.length,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createNewPost() {
    _newPostController.clear();
    _selectedPostImage = null;
    _selectedPostImageBytes = null;
    _selectedPostVideo = null;
    _locationName = null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Text(
                      'Create Post',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    if (_isPostingNew)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: InlineLoading(
                            expand: true,
                            shape: BoxShape.circle,
                            tileSize: 3.5),
                      )
                    else
                      TextButton(
                        onPressed: () async {
                          final content = _newPostController.text.trim();
                          if (content.isEmpty &&
                              _selectedPostImage == null &&
                              _selectedPostVideo == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please add content, an image, or a video')),
                            );
                            return;
                          }

                          // Check if user has auth token
                          try {
                            final prefs = await SharedPreferences.getInstance();
                            final walletAddress = prefs.getString('wallet') ??
                                prefs.getString('wallet_address') ??
                                prefs.getString('walletAddress');

                            if (walletAddress == null ||
                                walletAddress.isEmpty) {
                              if (context.mounted) {
                                final messenger = ScaffoldMessenger.of(context);
                                messenger.showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Please connect your wallet first')),
                                );
                              }
                              return;
                            }

                            // Ensure user is registered and has JWT token
                            await BackendApiService().loadAuthToken();

                            // If no token, try to register/login
                            final secureStorage = const FlutterSecureStorage();
                            final token =
                                await secureStorage.read(key: 'jwt_token');

                            if (token == null || token.isEmpty) {
                              // Auto-register user
                              debugPrint(
                                  'No JWT token found, auto-registering user');
                              try {
                                // Use auth/register so server creates user+profile and returns a JWT
                                final reg =
                                    await BackendApiService().registerWallet(
                                  walletAddress: walletAddress,
                                  username:
                                      'user_${walletAddress.substring(0, 8)}',
                                );
                                debugPrint(
                                    'Auto-register (auth) response: $reg');
                                // Token is stored by registerWallet on success
                              } catch (e) {
                                debugPrint('Auto-registration failed: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Failed to authenticate: $e')),
                                  );
                                }
                                return;
                              }
                            }
                          } catch (e) {
                            debugPrint('Error checking authentication: $e');
                          }

                          setModalState(() => _isPostingNew = true);

                          try {
                            List<String> mediaUrls = [];

                            // Upload image if selected
                            if (_selectedPostImage != null &&
                                _selectedPostImageBytes != null) {
                              try {
                                final fileName = _selectedPostImage!.name;

                                final uploadResult =
                                    await BackendApiService().uploadFile(
                                  fileBytes: _selectedPostImageBytes!,
                                  fileName: fileName,
                                  fileType:
                                      'post-image', // Use post-image to store in profiles/posts folder
                                );
                                final url =
                                    uploadResult['uploadedUrl'] as String?;
                                if (url != null) {
                                  mediaUrls.add(url);
                                  debugPrint(
                                      'Image uploaded successfully: $url');
                                } else {
                                  debugPrint(
                                      'Warning: Upload succeeded but no URL returned. Result: $uploadResult');
                                }
                              } catch (e) {
                                debugPrint('Error uploading image: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Failed to upload image: $e')),
                                  );
                                }
                              }
                            }

                            // Upload video if selected
                            if (_selectedPostVideo != null) {
                              try {
                                final videoFile =
                                    File(_selectedPostVideo!.path);
                                final fileBytes = await videoFile.readAsBytes();
                                final fileName = _selectedPostVideo!.name;

                                final uploadResult =
                                    await BackendApiService().uploadFile(
                                  fileBytes: fileBytes,
                                  fileName: fileName,
                                  fileType:
                                      'post-video', // Use post-video to store in profiles/posts folder
                                );
                                final url =
                                    uploadResult['uploadedUrl'] as String?;
                                if (url != null) mediaUrls.add(url);
                              } catch (e) {
                                debugPrint('Error uploading video: $e');
                              }
                            }

                            // Determine post type
                            String postType = 'text';
                            if (_selectedPostVideo != null) {
                              postType = 'video';
                            } else if (_selectedPostImage != null) {
                              postType = 'image';
                            }

                            // Create post via backend API (uses JWT auth for author info)
                            final createdPost =
                                await BackendApiService().createCommunityPost(
                              content: content.isEmpty
                                  ? (_selectedPostVideo != null ? '🎥' : '📷')
                                  : content,
                              mediaUrls:
                                  mediaUrls.isNotEmpty ? mediaUrls : null,
                              postType: postType,
                            );

                            setModalState(() => _isPostingNew = false);

                            if (context.mounted) {
                              // Clear post state
                              _newPostController.clear();
                              _selectedPostImage = null;
                              _selectedPostImageBytes = null;
                              _selectedPostVideo = null;
                              _locationName = null;

                              // Insert created post immediately at top of feed for instant feedback
                              setState(() {
                                if (createdPost.id.isNotEmpty) {
                                  _recentlyCreatedPostIds.add(createdPost.id);
                                }
                                _communityPosts.insert(0, createdPost);
                              });

                              // Optionally prefetch comments for the new post
                              try {
                                await BackendApiService()
                                    .getComments(postId: createdPost.id);
                              } catch (_) {}

                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Post created successfully!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() => _isPostingNew = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Failed to create post: $e')),
                              );
                            }
                          }
                        },
                        child: Text(
                          'Post',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                Provider.of<ThemeProvider>(context).accentColor,
                          ),
                        ),
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
                        controller: _newPostController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText:
                              'Share your thoughts about art, AR, or your latest creation...',
                          hintStyle: TextStyle(
                            fontSize: MediaQuery.of(context).size.width < 400
                                ? 14
                                : 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: MediaQuery.of(context).size.width < 400
                                ? 12
                                : 16,
                            horizontal: 16,
                          ),
                        ),
                        style: TextStyle(
                          fontSize:
                              MediaQuery.of(context).size.width < 400 ? 14 : 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Selected image preview
                      if (_selectedPostImage != null &&
                          _selectedPostImageBytes != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _selectedPostImageBytes!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                onPressed: () {
                                  setModalState(() {
                                    _selectedPostImage = null;
                                    _selectedPostImageBytes = null;
                                  });
                                },
                                icon: const Icon(Icons.close),
                                style: IconButton.styleFrom(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withAlpha(179),
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (_selectedPostImage != null)
                        const SizedBox(height: 16),
                      // Selected video preview
                      if (_selectedPostVideo != null)
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.videocam,
                                      size: 48,
                                      color: Provider.of<ThemeProvider>(context)
                                          .accentColor,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _selectedPostVideo!.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color:
                                            Provider.of<ThemeProvider>(context)
                                                .accentColor,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  onPressed: () {
                                    setModalState(() {
                                      _selectedPostVideo = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withAlpha(179),
                                    foregroundColor:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_selectedPostVideo != null)
                        const SizedBox(height: 16),
                      // Location display
                      if (_locationName != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Provider.of<ThemeProvider>(context)
                                    .accentColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _locationName!,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setModalState(() {
                                    _locationName = null;
                                  });
                                },
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ],
                          ),
                        ),
                      if (_locationName != null) const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPostOption(
                              Icons.image,
                              'Image',
                              onTap: () async {
                                final picker = ImagePicker();
                                final image = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1920,
                                  maxHeight: 1920,
                                  imageQuality: 85,
                                );
                                if (image != null) {
                                  final bytes = await image.readAsBytes();
                                  setModalState(() {
                                    _selectedPostImage = image;
                                    _selectedPostImageBytes = bytes;
                                    _selectedPostVideo =
                                        null; // Clear video if image selected
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildPostOption(
                              Icons.videocam,
                              'Video',
                              onTap: () async {
                                final picker = ImagePicker();
                                final video = await picker.pickVideo(
                                  source: ImageSource.gallery,
                                  maxDuration: const Duration(minutes: 5),
                                );
                                if (video != null) {
                                  setModalState(() {
                                    _selectedPostVideo = video;
                                    _selectedPostImage =
                                        null; // Clear image if video selected
                                    _selectedPostImageBytes = null;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildPostOption(
                              Icons.location_on,
                              'Location',
                              onTap: () async {
                                try {
                                  final location = loc.Location();

                                  // Check if location service is enabled
                                  bool serviceEnabled =
                                      await location.serviceEnabled();
                                  if (!serviceEnabled) {
                                    serviceEnabled =
                                        await location.requestService();
                                    if (!serviceEnabled) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Location service disabled')),
                                        );
                                      }
                                      return;
                                    }
                                  }

                                  // Check permission
                                  loc.PermissionStatus permissionGranted =
                                      await location.hasPermission();
                                  if (permissionGranted ==
                                      loc.PermissionStatus.denied) {
                                    permissionGranted =
                                        await location.requestPermission();
                                  }

                                  if (permissionGranted !=
                                      loc.PermissionStatus.granted) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Location permission denied')),
                                      );
                                    }
                                    return;
                                  }

                                  // Get current location
                                  final locationData =
                                      await location.getLocation();
                                  setModalState(() {
                                    _locationName =
                                        'Current Location (${locationData.latitude?.toStringAsFixed(4)}, ${locationData.longitude?.toStringAsFixed(4)})';
                                  });
                                } catch (e) {
                                  debugPrint('Error getting location: $e');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Failed to get location: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
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

  Widget _buildPostOption(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.onSurface,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Interaction methods
  void _toggleLike(int index) async {
    debugPrint('DEBUG: _toggleLike called for index: $index');
    if (index >= _communityPosts.length) {
      debugPrint(
          'DEBUG: Index $index is out of bounds (posts length: ${_communityPosts.length})');
      return;
    }

    final post = _communityPosts[index];
    final wasLiked = post.isLiked;
    debugPrint(
        'DEBUG: Post ${post.id} was liked: $wasLiked, count: ${post.likeCount}');
    final walletAddress = Provider.of<WalletProvider>(context, listen: false)
        .currentWalletAddress;

    try {
      // Let the service perform the toggle and persistence; it mutates `post` synchronously
      await CommunityService.togglePostLike(
        post,
        currentUserWallet: walletAddress,
      );
      debugPrint(
          'DEBUG: Service call completed successfully - liked: ${post.isLiked}, count: ${post.likeCount}');

      if (!mounted) return;
      // Rebuild UI to reflect the updated post state
      setState(() {});

      // Show feedback message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!wasLiked ? 'Post liked!' : 'Post unliked!'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('DEBUG: Error in togglePostLike: $e');
      // CommunityService performs rollback on error; ensure UI is refreshed
      setState(() {});
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${!wasLiked ? 'like' : 'unlike'} post'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showPostLikes(String postId) {
    _showLikesDialog(
      title: 'Post Likes',
      loader: () => BackendApiService().getPostLikes(postId),
    );
  }

  void _showCommentLikes(String commentId) {
    _showLikesDialog(
      title: 'Comment Likes',
      loader: () => BackendApiService().getCommentLikes(commentId),
    );
  }

  void _showLikesDialog(
      {required String title,
      required Future<List<CommunityLikeUser>> Function() loader}) {
    if (!mounted) return;

    final theme = Theme.of(context);
    final future = loader();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                              tileSize: 4.0),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  color: theme.colorScheme.error, size: 36),
                              const SizedBox(height: 12),
                              Text(
                                'Failed to load likes',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final likes = snapshot.data ?? <CommunityLikeUser>[];
                    if (likes.isEmpty) {
                      return Center(
                        child: EmptyStateCard(
                          icon: Icons.favorite_border,
                          title: 'No likes yet',
                          description: 'Be the first to like this post.',
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      itemCount: likes.length,
                      separatorBuilder: (_, __) => Divider(
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.3)),
                      itemBuilder: (context, index) {
                        final user = likes[index];
                        final subtitleParts = <String>[];
                        if (user.username != null &&
                            user.username!.isNotEmpty) {
                          subtitleParts.add('@${user.username}');
                        }
                        if (user.walletAddress != null &&
                            user.walletAddress!.isNotEmpty) {
                          final wallet = user.walletAddress!;
                          if (wallet.length > 8) {
                            subtitleParts.add(
                                '${wallet.substring(0, 4)}...${wallet.substring(wallet.length - 4)}');
                          } else {
                            subtitleParts.add(wallet);
                          }
                        }
                        if (user.likedAt != null) {
                          subtitleParts.add(_getTimeAgo(user.likedAt!));
                        }

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: AvatarWidget(
                            wallet: user.walletAddress ?? user.userId,
                            avatarUrl: user.avatarUrl,
                            radius: 20,
                            allowFabricatedFallback: true,
                          ),
                          title: Text(
                            user.displayName.isNotEmpty
                                ? user.displayName
                                : 'Unnamed User',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          subtitle: subtitleParts.isNotEmpty
                              ? Text(
                                  subtitleParts.join(' • '),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
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

  Future<_CommentAuthorContext?> _resolveCommentAuthorContext() async {
    final prefs = await SharedPreferences.getInstance();
    String? currentUserId = prefs.getString('user_id');
    final username = prefs.getString('username') ?? 'Current User';
    String? walletAddress = prefs.getString('wallet') ??
        prefs.getString('wallet_address') ??
        prefs.getString('walletAddress');

    if ((currentUserId == null || currentUserId.isEmpty) &&
        walletAddress != null &&
        walletAddress.isNotEmpty) {
      currentUserId = walletAddress;
    }

    if (currentUserId == null || currentUserId.isEmpty) {
      return null;
    }

    final String resolvedUserId = currentUserId;

    final String? resolvedWallet =
        (walletAddress != null && walletAddress.isNotEmpty)
            ? walletAddress
            : currentUserId;
    final String canonicalWallet = resolvedWallet ?? '';
    String? cachedAvatar;
    try {
      cachedAvatar = canonicalWallet.isNotEmpty
          ? UserService.getCachedUser(canonicalWallet)?.profileImageUrl
          : null;
    } catch (_) {
      cachedAvatar = null;
    }

    return _CommentAuthorContext(
      userId: resolvedUserId,
      walletAddress: canonicalWallet.isNotEmpty ? canonicalWallet : null,
      displayName: username.isNotEmpty ? username : 'Current User',
      avatarUrl: cachedAvatar,
    );
  }

  void _toggleBookmark(int index) async {
    if (index >= _communityPosts.length) return;

    final post = _communityPosts[index];

    // Update through service
    await CommunityService.toggleBookmark(post);
    if (!mounted) return;

    // Update local state
    setState(() {
      _bookmarkedPosts[index] = post.isBookmarked;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(post.isBookmarked ? 'Post bookmarked!' : 'Bookmark removed!'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _toggleFollowArtist(int index) async {
    if (index >= _followingArtists.length) return;

    final artist = _followingArtists[index];
    final artistWallet = (artist['walletAddress'] ??
                artist['wallet_address'] ??
                artist['publicKey'] ??
                artist['public_key'] ??
                artist['id'])
            ?.toString() ??
        '';
    final artistName = artist['name'] as String? ?? 'Artist';

    if (artistWallet.isEmpty) return;
    final appRefresh = Provider.of<AppRefreshProvider>(context, listen: false);

    try {
      // Use centralized UserService.toggleFollow which handles backend sync + local fallback
      final newState = await UserService.toggleFollow(artistWallet);

      if (!mounted) return;

      // Update local follow map and refetch artist stats from backend
      final backend = BackendApiService();
      int updatedFollowers = (artist['followersCount'] as int?) ?? 0;
      try {
        final stats = await backend.getUserStats(artistWallet);
        updatedFollowers = stats['followers'] as int? ?? updatedFollowers;
      } catch (_) {}
      setState(() {
        _followedArtists[index] = newState;
        _followingArtists[index]['followersCount'] = updatedFollowers;
      });

      // Trigger global refresh so other UIs update
      try {
        appRefresh.triggerCommunity();
      } catch (_) {}
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(newState
              ? 'Now following $artistName!'
              : 'Unfollowed $artistName'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error toggling follow: $e');
      if (!mounted) return;
      final messenger2 = ScaffoldMessenger.of(context);
      messenger2.showSnackBar(
        SnackBar(
          content: Text('Failed to update follow status'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showComments(int index) async {
    if (index >= _communityPosts.length) return;

    final post = _communityPosts[index];
    debugPrint('🔵 _showComments called for post ${post.id}');

    // Fetch comments from backend to ensure we have fresh, nested replies and author avatars
    try {
      debugPrint('   📥 Fetching comments from backend...');
      final backendComments =
          await BackendApiService().getComments(postId: post.id);
      debugPrint(
          '   ✅ Received ${backendComments.length} root comments from backend');

      // Count total comments including nested replies
      int totalComments = backendComments.length;
      for (final comment in backendComments) {
        totalComments += comment.replies.length;
        debugPrint(
            '   Comment ${comment.id} has ${comment.replies.length} replies');
      }
      debugPrint('   Total comments (including nested): $totalComments');

      // Replace current comments with backend-provided nested comments
      post.comments = backendComments;
      post.commentCount = totalComments;

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Failed to load backend comments for post ${post.id}: $e');
    }

    final TextEditingController commentController = TextEditingController();
    String? replyToCommentId; // Track which comment is being replied to

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Text(
                      'Comments',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${post.commentCount} comments',
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
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: post.comments.length,
                  itemBuilder: (context, commentIndex) => Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar (if available) or fallback initial avatar
                        AvatarWidget(
                          wallet: post.comments[commentIndex].authorWallet ??
                              post.comments[commentIndex].authorId,
                          avatarUrl: post.comments[commentIndex].authorAvatar,
                          radius: 16,
                          allowFabricatedFallback: true,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.comments[commentIndex].authorName,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                post.comments[commentIndex].content,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _getTimeAgo(
                                    post.comments[commentIndex].timestamp),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Comment actions: like and reply
                              Row(
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(
                                      post.comments[commentIndex].isLiked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      size: 18,
                                      color: post.comments[commentIndex].isLiked
                                          ? Colors.red
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                    ),
                                    onPressed: () async {
                                      // Optimistic toggle
                                      setModalState(() {
                                        post.comments[commentIndex].isLiked =
                                            !post
                                                .comments[commentIndex].isLiked;
                                        post.comments[commentIndex].likeCount +=
                                            post.comments[commentIndex].isLiked
                                                ? 1
                                                : -1;
                                      });
                                      try {
                                        await CommunityService
                                            .toggleCommentLike(
                                                post.comments[commentIndex],
                                                post.id);
                                      } catch (e) {
                                        // rollback on error
                                        setModalState(() {
                                          post.comments[commentIndex].isLiked =
                                              !post.comments[commentIndex]
                                                  .isLiked;
                                          post.comments[commentIndex]
                                              .likeCount += post
                                                  .comments[commentIndex]
                                                  .isLiked
                                              ? 1
                                              : -1;
                                        });
                                        // Show error feedback
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Failed to update like: $e'),
                                              backgroundColor: Colors.red,
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _showCommentLikes(
                                        post.comments[commentIndex].id),
                                    child: Text(
                                      '${post.comments[commentIndex].likeCount}',
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () {
                                      // Set reply parent and prefill mention
                                      final authorName = post
                                          .comments[commentIndex].authorName;
                                      final fallbackId =
                                          post.comments[commentIndex].authorId;
                                      String mention;
                                      if (authorName.isNotEmpty) {
                                        final sanitized =
                                            authorName.replaceAll(' ', '');
                                        mention =
                                            '@${sanitized.length > 20 ? sanitized.substring(0, 20) : sanitized} ';
                                      } else if (fallbackId.isNotEmpty) {
                                        mention =
                                            '@${fallbackId.substring(0, 8)} ';
                                      } else {
                                        mention = '';
                                      }
                                      setModalState(() {
                                        replyToCommentId = post
                                            .comments[commentIndex]
                                            .id; // Track parent comment
                                        commentController.text = mention;
                                        // place cursor at end
                                        commentController.selection =
                                            TextSelection.fromPosition(
                                                TextPosition(
                                                    offset: commentController
                                                        .text.length));
                                      });
                                    },
                                    child: Row(
                                      children: [
                                        Icon(Icons.reply_outlined,
                                            size: 18,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6)),
                                        const SizedBox(width: 6),
                                        Text('Reply',
                                            style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // Nested replies (rendered indented)
                              if (post.comments[commentIndex].replies
                                  .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: post.comments[commentIndex].replies
                                      .map((reply) {
                                    return Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surface,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          AvatarWidget(
                                            wallet: reply.authorWallet ??
                                                reply.authorId,
                                            avatarUrl: reply.authorAvatar,
                                            radius: 12,
                                            allowFabricatedFallback: true,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(reply.authorName,
                                                    style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface)),
                                                const SizedBox(height: 4),
                                                Text(reply.content,
                                                    style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withValues(
                                                                alpha: 0.8))),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Text(
                                                        _getTimeAgo(
                                                            reply.timestamp),
                                                        style: GoogleFonts.inter(
                                                            fontSize: 12,
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .onSurface
                                                                .withValues(
                                                                    alpha:
                                                                        0.5))),
                                                    const SizedBox(width: 16),
                                                    Row(
                                                      children: [
                                                        IconButton(
                                                          padding:
                                                              EdgeInsets.zero,
                                                          constraints:
                                                              const BoxConstraints(),
                                                          icon: Icon(
                                                            reply.isLiked
                                                                ? Icons.favorite
                                                                : Icons
                                                                    .favorite_border,
                                                            size: 14,
                                                            color: reply.isLiked
                                                                ? Colors.red
                                                                : Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .onSurface
                                                                    .withValues(
                                                                        alpha:
                                                                            0.6),
                                                          ),
                                                          onPressed: () async {
                                                            setModalState(() {
                                                              reply.isLiked =
                                                                  !reply
                                                                      .isLiked;
                                                              reply.likeCount +=
                                                                  reply.isLiked
                                                                      ? 1
                                                                      : -1;
                                                            });
                                                            try {
                                                              await CommunityService
                                                                  .toggleCommentLike(
                                                                      reply,
                                                                      post.id);
                                                            } catch (e) {
                                                              setModalState(() {
                                                                reply.isLiked =
                                                                    !reply
                                                                        .isLiked;
                                                                reply.likeCount +=
                                                                    reply.isLiked
                                                                        ? 1
                                                                        : -1;
                                                              });
                                                              // Show error feedback
                                                              if (context
                                                                  .mounted) {
                                                                ScaffoldMessenger.of(
                                                                        context)
                                                                    .showSnackBar(
                                                                  SnackBar(
                                                                    content: Text(
                                                                        'Failed to update like: $e'),
                                                                    backgroundColor:
                                                                        Colors
                                                                            .red,
                                                                    duration: const Duration(
                                                                        seconds:
                                                                            2),
                                                                  ),
                                                                );
                                                              }
                                                            }
                                                          },
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
                                                        GestureDetector(
                                                          behavior:
                                                              HitTestBehavior
                                                                  .opaque,
                                                          onTap: () =>
                                                              _showCommentLikes(
                                                                  reply.id),
                                                          child: Text(
                                                            '${reply.likeCount}',
                                                            style: GoogleFonts.inter(
                                                                fontSize: 12,
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .onSurface
                                                                    .withValues(
                                                                        alpha:
                                                                            0.6)),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Comment input section
              Container(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reply indicator (shows when replying to a comment)
                    if (replyToCommentId != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Provider.of<ThemeProvider>(context)
                              .accentColor
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.reply,
                                size: 16,
                                color: Provider.of<ThemeProvider>(context)
                                    .accentColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Replying to comment',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Provider.of<ThemeProvider>(context)
                                      .accentColor,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                setModalState(() {
                                  replyToCommentId = null;
                                  commentController.clear();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        // Current user avatar
                        Consumer<ProfileProvider>(
                          builder: (context, profileProvider, _) {
                            final currentUser = profileProvider.currentUser;
                            final avatarUrl = currentUser?.avatar;
                            final displayName = currentUser?.displayName ??
                                currentUser?.username ??
                                'U';

                            return CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  Provider.of<ThemeProvider>(context)
                                      .accentColor,
                              backgroundImage:
                                  avatarUrl != null && avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                              child: avatarUrl == null || avatarUrl.isEmpty
                                  ? Text(
                                      displayName.isNotEmpty
                                          ? displayName[0].toUpperCase()
                                          : 'U',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide(
                                  color: Provider.of<ThemeProvider>(context)
                                      .accentColor,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (value) async {
                              if (value.trim().isNotEmpty) {
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  final authorContext =
                                      await _resolveCommentAuthorContext();
                                  if (authorContext == null) {
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Please complete onboarding or re-login to comment.'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  }
                                  debugPrint(
                                      '💬 Adding comment with parentCommentId: $replyToCommentId');
                                  await CommunityService.addComment(
                                    post,
                                    value.trim(),
                                    authorContext.displayName,
                                    currentUserId: authorContext.userId,
                                    parentCommentId:
                                        replyToCommentId, // Pass parent comment ID for nesting
                                    userName: authorContext.displayName,
                                    authorWallet: authorContext.walletAddress,
                                    authorAvatar: authorContext.avatarUrl,
                                  );
                                  // Refresh comments from backend to ensure server state (avatars, real ids)
                                  try {
                                    final backendComments =
                                        await BackendApiService()
                                            .getComments(postId: post.id);
                                    post.comments = backendComments;
                                    post.commentCount = post.comments.length;
                                  } catch (e) {
                                    debugPrint(
                                        'Warning: failed to refresh comments after submit: $e');
                                  }
                                  if (!mounted) return;
                                  // Reset reply state
                                  replyToCommentId = null;
                                  setModalState(() {});
                                  setState(() {});
                                  commentController.clear();

                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Comment added!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Failed to add comment: $e'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Provider.of<ThemeProvider>(context).accentColor,
                                Provider.of<ThemeProvider>(context)
                                    .accentColor
                                    .withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              if (commentController.text.trim().isNotEmpty) {
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  final commentText =
                                      commentController.text.trim();
                                  final authorContext =
                                      await _resolveCommentAuthorContext();
                                  if (authorContext == null) {
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Please complete onboarding or re-login to comment.'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  }
                                  debugPrint(
                                      '💬 Adding comment (button) with parentCommentId: $replyToCommentId');
                                  await CommunityService.addComment(
                                    post,
                                    commentText,
                                    authorContext.displayName,
                                    currentUserId: authorContext.userId,
                                    parentCommentId:
                                        replyToCommentId, // Pass parent comment ID for nesting
                                    userName: authorContext.displayName,
                                    authorWallet: authorContext.walletAddress,
                                    authorAvatar: authorContext.avatarUrl,
                                  );
                                  // Refresh comments to reflect server state
                                  try {
                                    final backendComments =
                                        await BackendApiService()
                                            .getComments(postId: post.id);
                                    post.comments = backendComments;
                                    post.commentCount = post.comments.length;
                                  } catch (e) {
                                    debugPrint(
                                        'Warning: failed to refresh comments after send: $e');
                                  }
                                  if (!mounted) return;

                                  // Reset reply state
                                  replyToCommentId = null;
                                  setModalState(() {});
                                  setState(() {});
                                  commentController.clear();

                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Comment added!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Failed to add comment: $e'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: Icon(
                              Icons.send,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 20,
                            ),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                        ),
                      ], // End of Row children
                    ), // End of Row
                  ], // End of Column children
                ), // End of Column
              ), // End of Container
            ], // End of main Column children
          ),
        ),
      ),
    );
  }

  void _sharePost(int index) async {
    if (index >= _communityPosts.length) return;
    final post = _communityPosts[index];
    _showShareModal(post);
  }

  void _showShareModal(CommunityPost post) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Share Post',
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface)),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext)),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for profiles...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: theme.colorScheme.primaryContainer,
                  ),
                  onChanged: (query) async {
                    if (query.trim().isEmpty) {
                      setModalState(() {
                        searchResults.clear();
                      });
                      return;
                    }
                    setModalState(() => isSearching = true);
                    try {
                      final resp = await BackendApiService()
                          .search(query: query, type: 'profiles', limit: 20);
                      final list = <Map<String, dynamic>>[];
                      if (resp['success'] == true && resp['results'] is Map) {
                        final profiles =
                            (resp['results']['profiles'] as List?) ?? [];
                        for (final p in profiles) {
                          try {
                            list.add(p as Map<String, dynamic>);
                          } catch (_) {}
                        }
                      }
                      setModalState(() {
                        searchResults = list;
                        isSearching = false;
                      });
                    } catch (e) {
                      setModalState(() => isSearching = false);
                    }
                  },
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  children: [
                    ListTile(
                      leading:
                          Icon(Icons.link, color: theme.colorScheme.primary),
                      title: Text('Copy Link', style: GoogleFonts.inter()),
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(
                            text: 'https://app.kubus.site/post/${post.id}'));
                        Navigator.pop(sheetContext);
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Link copied to clipboard')));

                        // Track analytics
                        BackendApiService().trackAnalyticsEvent(
                          eventType: 'share_copy_link',
                          postId: post.id,
                          metadata: {'method': 'copy_link'},
                        );
                      },
                    ),
                    ListTile(
                      leading:
                          Icon(Icons.share, color: theme.colorScheme.primary),
                      title: Text('Share via...', style: GoogleFonts.inter()),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final shareText =
                            '${post.content}\n\n- ${post.authorName} on app.kubus\n\nhttps://app.kubus.site/post/${post.id}';
                        await SharePlus.instance
                            .share(ShareParams(text: shareText));
                        BackendApiService().trackAnalyticsEvent(
                          eventType: 'share_external',
                          postId: post.id,
                          metadata: {'method': 'platform_share'},
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (searchController.text.isNotEmpty) ...[
                const Divider(),
                Expanded(
                  child: isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : searchResults.isEmpty
                          ? Center(
                              child: EmptyStateCard(
                                icon: Icons.person_search,
                                title: 'No profiles found',
                                description: 'Try a different search term',
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: searchResults.length,
                              itemBuilder: (ctx, idx) {
                                final profile = searchResults[idx];
                                final walletAddr = profile['wallet_address'] ??
                                    profile['walletAddress'] ??
                                    profile['wallet'] ??
                                    profile['walletAddr'];
                                final username = profile['username'] ??
                                    walletAddr ??
                                    'unknown';
                                final display = profile['displayName'] ??
                                    profile['display_name'] ??
                                    username;
                                final avatar =
                                    profile['avatar'] ?? profile['avatar_url'];
                                return ListTile(
                                  leading: AvatarWidget(
                                      wallet: username,
                                      avatarUrl: avatar,
                                      radius: 20),
                                  title: Text(display ?? 'Unnamed',
                                      style: GoogleFonts.inter()),
                                  subtitle: Text('@$username',
                                      style: GoogleFonts.inter(fontSize: 12)),
                                  onTap: () async {
                                    Navigator.pop(sheetContext);

                                    try {
                                      // Share post via DM
                                      await BackendApiService().sharePostViaDM(
                                        postId: post.id,
                                        recipientWallet: walletAddr ?? username,
                                        message: 'Check out this post!',
                                      );
                                      BackendApiService().trackAnalyticsEvent(
                                        eventType: 'share_dm',
                                        postId: post.id,
                                        metadata: {
                                          'recipient': walletAddr ?? username
                                        },
                                      );

                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'Shared post with @$username')),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content:
                                                  Text('Failed to share: $e')),
                                        );
                                      }
                                    }
                                  },
                                );
                              },
                            ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRepostModal(CommunityPost post) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final repostContentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
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
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Repost',
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface)),
                    Row(
                      children: [
                        TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: Text('Cancel', style: GoogleFonts.inter())),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final content = repostContentController.text.trim();
                            Navigator.pop(sheetContext);

                            try {
                              // Create repost via backend
                              final createdRepost =
                                  await BackendApiService().createRepost(
                                originalPostId: post.id,
                                content: content.isNotEmpty ? content : null,
                              );
                              BackendApiService().trackAnalyticsEvent(
                                eventType: 'repost_created',
                                postId: post.id,
                                metadata: {'has_comment': content.isNotEmpty},
                              );

                              if (mounted) {
                                // Insert repost into feed immediately for instant feedback
                                setState(() {
                                  _communityPosts.insert(0, createdRepost);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(content.isEmpty
                                          ? 'Reposted!'
                                          : 'Reposted with comment!')),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Failed to repost: $e')),
                                );
                              }
                            }
                          },
                          child: Text('Repost', style: GoogleFonts.inter()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: repostContentController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Add your thoughts (optional)...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: theme.colorScheme.primaryContainer,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Reposting:',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(12),
                          color: theme.colorScheme.surface,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                AvatarWidget(
                                    wallet: post.authorId,
                                    avatarUrl: post.authorAvatar,
                                    radius: 16,
                                    enableProfileNavigation: false),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(post.authorName,
                                          style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14)),
                                      Text(_getTimeAgo(post.timestamp),
                                          style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.5))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(post.content,
                                style: GoogleFonts.inter(fontSize: 14),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis),
                            if (post.imageUrl != null &&
                                post.imageUrl!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(post.imageUrl!,
                                    fit: BoxFit.cover,
                                    height: 120,
                                    width: double.infinity),
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          userId: userId,
        ),
      ),
    );
  }

  void _viewRepostsList(CommunityPost post) async {
    if (!mounted) return;
    final theme = Theme.of(context);

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
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Reposted by',
                      style: GoogleFonts.inter(
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
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error loading reposts',
                            style: GoogleFonts.inter()));
                  }
                  final reposts = snapshot.data ?? [];
                  if (reposts.isEmpty) {
                    return Center(
                      child: EmptyStateCard(
                        icon: Icons.repeat,
                        title: 'No reposts yet',
                        description: 'This post has not been reposted yet.',
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
                          'Unknown';
                      final displayName = user?['displayName'] ?? username;
                      final avatar = user?['avatar'];
                      final comment = repost['repostComment'] as String?;
                      final createdAt =
                          DateTime.tryParse(repost['createdAt'] ?? '');

                      return ListTile(
                        leading: AvatarWidget(
                            wallet: username, avatarUrl: avatar, radius: 20),
                        title: Text(displayName,
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('@$username',
                                style: GoogleFonts.inter(fontSize: 12)),
                            if (comment != null && comment.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(comment,
                                  style: GoogleFonts.inter(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                        trailing: createdAt != null
                            ? Text(_getTimeAgo(createdAt),
                                style: GoogleFonts.inter(
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

  void _showRepostOptions(CommunityPost post) {
    if (!mounted) return;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title:
                  Text('Unrepost', style: GoogleFonts.inter(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetContext);
                _unrepostPost(post);
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              title: Text('Cancel', style: GoogleFonts.inter()),
              onTap: () => Navigator.pop(sheetContext),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _unrepostPost(CommunityPost post) async {
    if (!mounted) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Unrepost', style: GoogleFonts.inter()),
        content: Text('Are you sure you want to remove this repost?',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Unrepost', style: GoogleFonts.inter()),
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

      if (mounted) {
        await _loadCommunityData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repost removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unrepost: $e')),
        );
      }
    }
  }

  void _viewPostDetail(int index) {
    if (index >= _communityPosts.length) return;

    final post = _communityPosts[index];

    // Open full post detail screen instead of dialog
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()}w ago';
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
}

class _CommentAuthorContext {
  final String userId;
  final String? walletAddress;
  final String displayName;
  final String? avatarUrl;

  const _CommentAuthorContext({
    required this.userId,
    required this.displayName,
    this.walletAddress,
    this.avatarUrl,
  });
}
