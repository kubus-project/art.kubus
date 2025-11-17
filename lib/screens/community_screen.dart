// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_loading.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart' as loc;
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import '../providers/themeprovider.dart';
import '../providers/config_provider.dart';
import '../providers/profile_provider.dart';
import '../services/backend_api_service.dart';
import '../models/artwork.dart';
import '../services/push_notification_service.dart';
import 'art_detail_screen.dart';
import 'user_profile_screen.dart';
import '../community/community_interactions.dart';
import '../services/user_service.dart';
import '../providers/app_refresh_provider.dart';
import '../services/socket_service.dart';
import '../providers/notification_provider.dart';
import '../providers/chat_provider.dart';
import 'messages_screen.dart';

class CommunityScreen extends StatefulWidget {
  // Global key to allow other screens to request opening a post by id
  static final GlobalKey<_CommunityScreenState> globalKey = GlobalKey<_CommunityScreenState>();

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
  
  final List<String> _tabs = ['Feed', 'Discover', 'Following', 'Collections'];
  
  // Community data
  List<CommunityPost> _communityPosts = [];
  // How many posts to prefetch comments for (make configurable)
  final int _commentPrefetchCount = 8;
  final int _prefetchConcurrencyLimit = 3;
  final int _prefetchMaxRetries = 3;
  final int _prefetchBaseDelayMs = 300; // milliseconds
  List<Artwork> _discoverArtworks = [];
  List<Map<String, dynamic>> _followingArtists = [];
  bool _isLoading = false;
  bool _isLoadingDiscover = false;
  bool _isLoadingFollowing = false;
  final Map<int, bool> _bookmarkedPosts = {};
  final Map<String, String> _avatarCache = {}; // Cache avatars to prevent repeated API calls
  final Map<int, bool> _followedArtists = {};
  
  // New post state
  final TextEditingController _newPostController = TextEditingController();
  bool _isPostingNew = false;
  XFile? _selectedPostImage;
  Uint8List? _selectedPostImageBytes; // Store bytes for preview
  XFile? _selectedPostVideo;
  loc.LocationData? _selectedLocation;
  String? _locationName;

  Future<void> _loadDiscoverArtworks() async {
    if (mounted) {
      setState(() {
        _isLoadingDiscover = true;
      });
    }

    try {
      final artworks = await BackendApiService().getArtworks(
        arEnabled: true,
        page: 1,
        limit: 20,
      );
      if (mounted) {
        setState(() {
          _discoverArtworks = artworks;
          _isLoadingDiscover = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading discover artworks: $e');
      if (mounted) {
        setState(() {
          _discoverArtworks = [];
          _isLoadingDiscover = false;
        });
      }
    }
  }

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

  Future<void> _loadCommunityData() async {
    // Prevent multiple simultaneous loads
    if (_isLoading) return;
    
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {
      // Ensure auth token is loaded first
      final backendApi = BackendApiService();
      try {
        await backendApi.loadAuthToken();
        debugPrint('🔐 Auth token loaded for community posts');
      } catch (e) {
        debugPrint('⚠️ No auth token: $e');
      }
      
      // Fetch community posts from backend API
      final posts = await backendApi.getCommunityPosts(
        page: 1,
        limit: 50,
      );
      debugPrint('📥 Loaded ${posts.length} posts from backend');
      
      // Load saved interactions (likes, bookmarks, follows) - this overrides backend isLiked with local state
      await CommunityService.loadSavedInteractions(posts);
      debugPrint('✅ Restored local interaction state for posts');
      
      if (mounted) {
        setState(() {
          _communityPosts = posts;
          _isLoading = false;
        });
        // Prefetch comments for the first few posts in background for snappier UI
        _prefetchComments();
      }
    } catch (e) {
      debugPrint('Error loading community data: $e');
      // Keep empty list if error occurs
      if (mounted) {
        setState(() {
          _communityPosts = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _prefetchComments() async {
    try {
      final prefetchCount = math.min(_commentPrefetchCount, _communityPosts.length);
      final concurrency = _prefetchConcurrencyLimit;
      for (var i = 0; i < prefetchCount; i += concurrency) {
        final end = math.min(i + concurrency, prefetchCount);
        final batch = _communityPosts.sublist(i, end);
        await Future.wait(batch.map((post) async {
          int attempt = 0;
          while (attempt < _prefetchMaxRetries) {
            try {
              final comments = await BackendApiService().getComments(postId: post.id);
              post.comments = comments;
              post.commentCount = post.comments.length;
              if (mounted) setState(() {});
              break;
            } catch (e) {
              attempt++;
              final delayMs = _prefetchBaseDelayMs * (1 << (attempt - 1));
              debugPrint('Prefetch comments failed for post ${post.id} (attempt $attempt): $e. Retrying in ${delayMs}ms');
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
    _loadCommunityData();
    _loadDiscoverArtworks();
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
    _messageScale = Tween<double>(begin: 1.0, end: 1.12).animate(CurvedAnimation(parent: _messagePulseController, curve: Curves.easeOut));

    // Listen for socket notifications to animate bell
    try {
      SocketService().addNotificationListener(_onSocketNotificationForCommunity);
    } catch (_) {}
    
    // Load initial unread notification count via provider
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final provider = Provider.of<NotificationProvider>(context, listen: false);
        await provider.refresh();
        if (!mounted) return;
        setState(() { _bellUnreadCount = provider.unreadCount; });
        provider.addListener(_onNotificationProviderChange);
      } catch (_) {}
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final cp = Provider.of<ChatProvider>(context, listen: false);
        // Ensure ChatProvider is initialized so socket subscriptions and unread counts are active
        try { await cp.initialize(); } catch (_) {}
        if (!mounted) return;
        _messageUnreadCount = cp.totalUnread;
        cp.addListener(_onChatProviderChanged);
      } catch (_) {}
    });
    
    // Listen for config provider changes to reload data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final configProvider = Provider.of<ConfigProvider>(context, listen: false);
      configProvider.addListener(_onConfigChanged);
    });
  }
  
  DateTime? _lastConfigChange;
  
  void _onConfigChanged() {
    // Debounce: only reload if at least 1 second has passed since last change
    final now = DateTime.now();
    if (_lastConfigChange != null && now.difference(_lastConfigChange!).inSeconds < 1) {
      return;
    }
    _lastConfigChange = now;
    _loadCommunityData();
  }
  
  // Helper to get user avatar from backend
  Future<String> _getUserAvatar(String wallet) async {
    // Check cache first
    if (_avatarCache.containsKey(wallet)) {
      return _avatarCache[wallet]!;
    }

    try {
      // Prefer cache-first lookup via UserService to avoid immediate network call
      final user = await UserService.getUserById(wallet);
      final avatar = (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty) ? user.profileImageUrl! : '';
      _avatarCache[wallet] = avatar; // Cache the result (may be empty)
      if (avatar.isNotEmpty) return avatar;

      // Fallback to backend API if no avatar found in cached profile
      try {
        final profile = await BackendApiService().getProfileByWallet(wallet);
        final a = profile['avatar'] ?? '';
        _avatarCache[wallet] = a;
        return a ?? '';
      } catch (_) {
        _avatarCache[wallet] = ''; // Cache empty result to prevent retries
        return '';
      }
    } catch (e) {
      debugPrint('CommunityScreen._getUserAvatar: lookup failed: $e');
      _avatarCache[wallet] = '';
      return '';
    }
  }

  @override
  void dispose() {
    // Remove config provider listener
    try {
      final configProvider = Provider.of<ConfigProvider>(context, listen: false);
      configProvider.removeListener(_onConfigChanged);
    } catch (e) {
      // Provider may not be available during dispose
    }
    
    _animationController.dispose();
    try {
      SocketService().removeNotificationListener(_onSocketNotificationForCommunity);
    } catch (_) {}
    try { Provider.of<NotificationProvider>(context, listen: false).removeListener(_onNotificationProviderChange); } catch (_) {}
    _bellController.dispose();
    _messagePulseController.dispose();
    try { Provider.of<ChatProvider>(context, listen: false).removeListener(_onChatProviderChanged); } catch (_) {}
    _tabController.dispose();
    super.dispose();
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
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Text(
            'Community',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              _showSearchBottomSheet();
            },
            icon: Icon(
              Icons.search,
              color: Theme.of(context).colorScheme.onSurface,
              size: 28,
            ),
          ),
          GestureDetector(
            onTap: _showNotifications,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: _bellController,
                  builder: (ctx, child) {
                    final scale = _bellScale.value;
                    return Transform.scale(
                      scale: scale,
                      child: Icon(
                        _bellUnreadCount > 0 ? Icons.notifications : Icons.notifications_outlined,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 28,
                      ),
                    );
                  },
                ),
                if (_bellUnreadCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: themeProvider.accentColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 18),
                      child: Center(
                        child: Text(
                          _bellUnreadCount > 99 ? '99+' : '$_bellUnreadCount',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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
              return GestureDetector(
                onTap: () {
                  showGeneralDialog(
                    context: context,
                    barrierDismissible: true,
                    barrierLabel: 'Messages',
                    barrierColor: Theme.of(context).colorScheme.primaryContainer.withAlpha(179),
                    transitionDuration: const Duration(milliseconds: 300),
                    pageBuilder: (ctx, a1, a2) => const MessagesScreen(),
                    transitionBuilder: (ctx, anim1, anim2, child) {
                      final curved = Curves.easeOut.transform(anim1.value);
                      return Transform.translate(
                        offset: Offset(0, (1 - curved) * MediaQuery.of(context).size.height),
                        child: Opacity(opacity: anim1.value, child: child),
                      );
                    },
                  );
                },
                child: Tooltip(
                  message: 'Open messages',
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ScaleTransition(
                        scale: _messageScale,
                        child: Icon(
                          totalUnread > 0 ? Icons.chat_bubble : Icons.chat_bubble_outline,
                          color: totalUnread > 0 ? themeProvider.accentColor : Theme.of(context).colorScheme.onSurface,
                          size: 26,
                        ),
                      ),
                      // Unread indicator for messages
                      if (totalUnread > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: themeProvider.accentColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
                            ),
                            constraints: const BoxConstraints(minWidth: 20, minHeight: 18),
                            child: Center(
                              child: Text(
                                totalUnread > 99 ? '99+' : '$totalUnread',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
        ],
      ),
    );
  }

  void _onSocketNotificationForCommunity(Map<String, dynamic> data) {
    if (!mounted) return;
    try {
      setState(() {
        _bellUnreadCount += 1;
      });
      _bellController.forward(from: 0.0);
    } catch (_) {}
  }

  void _onNotificationProviderChange() {
    if (!mounted) return;
    try {
      final provider = Provider.of<NotificationProvider>(context, listen: false);
      setState(() { _bellUnreadCount = provider.unreadCount; });
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
            tabAlignment: isSmallScreen ? TabAlignment.start : TabAlignment.fill,
            tabs: _tabs.map((tab) => Tab(
              child: Text(
                tab,
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 9 : 10,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )).toList(),
            indicator: BoxDecoration(
              color: themeProvider.accentColor,
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorPadding: EdgeInsets.all(isSmallScreen ? 2 : 4),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Theme.of(context).colorScheme.onPrimary,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
    if (_isLoading) {
      return const AppLoading();
    }
    
    if (_communityPosts.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await _loadCommunityData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.feed,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Posts Available',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Community posts will appear here when available',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadCommunityData();
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemCount: _communityPosts.length,
        itemBuilder: (context, index) => _buildPostCard(index),
      ),
    );
  }

  Widget _buildDiscoverTab() {
    if (_isLoadingDiscover) {
      return const AppLoading();
    }
    
    if (_discoverArtworks.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await _loadDiscoverArtworks();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.explore,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Artworks to Discover',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'New artworks will appear here',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadDiscoverArtworks();
      },
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: _discoverArtworks.length,
        itemBuilder: (context, index) => _buildDiscoverArtworkCard(_discoverArtworks[index]),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Artists Yet',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Discover and follow artists in the Discover tab',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
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
        itemBuilder: (context, index) => _buildArtistCard(_followingArtists[index], index),
      ),
    );
  }

  Widget _buildCollectionsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.collections,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'No Collections Available',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Curated collections will appear here when available',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _viewUserProfile(post.authorId),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: themeProvider.accentColor,
                  backgroundImage: post.authorAvatar != null && post.authorAvatar!.isNotEmpty
                      ? NetworkImage(post.authorAvatar!) as ImageProvider
                      : null,
                  child: post.authorAvatar == null || post.authorAvatar!.isEmpty
                      ? Icon(Icons.person, color: Theme.of(context).colorScheme.onPrimary, size: 20)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _viewUserProfile(post.authorId),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@${post.authorUsername}',
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 12 : 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            post.content,
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 13 : 15,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (post.imageUrl != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _showImageLightbox(post.imageUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            themeProvider.accentColor.withValues(alpha: 0.3),
                            themeProvider.accentColor.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            themeProvider.accentColor.withValues(alpha: 0.3),
                            themeProvider.accentColor.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(Icons.image_not_supported, color: Theme.of(context).colorScheme.onPrimary, size: 60),
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
                post.isLiked ? Icons.favorite : Icons.favorite_border, 
                '${post.likeCount}',
                onTap: () => _toggleLike(index),
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
                Icons.share_outlined, 
                '${post.shareCount}',
                onTap: () => _sharePost(index),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _toggleBookmark(index),
                icon: Icon(
                  post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: post.isBookmarked
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
            ],
          ),
        ]
        )
        )
        )
          );
      },
    );
  }

  Widget _buildInteractionButton(IconData icon, String count, {VoidCallback? onTap, bool isActive = false}) {
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isActive 
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            AnimatedScale(
              scale: isActive ? 1.3 : 1.0,
              duration: const Duration(milliseconds: 100),
              curve: Curves.bounceOut,
              child: Icon(
                icon,
                color: isActive 
                    ? Theme.of(context).colorScheme.primary 
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                size: 20,
              ),
            ),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 100),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(count),
            ),
          ],
        ),
      ),
    );
  }






  Widget _buildDiscoverArtworkCard(Artwork artwork) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtDetailScreen(artworkId: artwork.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: (artwork.imageUrl != null && artwork.imageUrl!.isNotEmpty)
                    ? Image.network(
                        artwork.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Theme.of(context).colorScheme.surface,
                            child: Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Theme.of(context).colorScheme.surface,
                        child: Icon(
                          Icons.art_track,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
              ),
            ),
            
            // Artwork Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          artwork.title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (artwork.arMarkerId != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: themeProvider.accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.view_in_ar,
                            size: 14,
                            color: themeProvider.accentColor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    artwork.artist,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistCard(Map<String, dynamic> artist, int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final artistName = artist['name'] as String? ?? 'Unknown Artist';
    final username = artist['username'] as String? ?? artist['publicKey'] as String? ?? '';
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '$artworksCount artworks • $followersCount followers',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
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
                decoration: InputDecoration(
                  hintText: 'Search artists, artworks, collections...',
                  hintStyle: TextStyle(
                    fontSize: MediaQuery.of(context).size.width < 400 ? 14 : 16,
                  ),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.primaryContainer,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: MediaQuery.of(context).size.width < 400 ? 12 : 16,
                    horizontal: 16,
                  ),
                ),
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width < 400 ? 14 : 16,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: 0, // TODO: Implement search with backend
                itemBuilder: (context, index) => _buildSearchResult(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResult(int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Search coming soon',
        style: GoogleFonts.inter(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        textAlign: TextAlign.center,
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
          debugPrint('🔐 Auth token loaded for notifications: ${token != null ? (token.length > 16 ? '${token.substring(0, 8)}...' : token) : "<none>"}');
          // Optionally fetch which wallet this token maps to
          try {
            final me = await backend.getMyProfile();
            debugPrint('🔍 Token maps to wallet: ${me['wallet'] ?? me['wallet_address']}');
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
        debugPrint('📥 Loaded ${local.length} local + ${remote.length} remote notifications');
        // Normalize remote (ensure Map<String,dynamic>)
        final remapped = remote.map((e) => Map<String, dynamic>.from(e)).toList();
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
      setState(() { _bellUnreadCount = 0; });
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
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No Notifications',
                                      style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'You\'re all caught up!',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemBuilder: (ctx, i) {
                            final n = combined[i];
                            final type = (n['interactionType'] ?? n['type'] ?? '').toString();
                            // Extract sender info from backend notification structure
                            final sender = n['sender'] as Map<String, dynamic>?;
                            final user = sender?['displayName'] as String? ?? sender?['username'] as String? ?? (n['userName'] ?? n['authorName'] ?? 'Someone').toString();
                            final body = (n['comment'] ?? n['message'] ?? n['content'] ?? '').toString();
                            final ts = (n['timestamp'] ?? n['createdAt'] ?? '').toString();
                            String time = ts.isNotEmpty ? ts : '';
                            try {
                              if (time.isNotEmpty) time = _getTimeAgo(DateTime.parse(time));
                            } catch (_) {}
                            final leadSeed = (sender?['wallet'] ?? sender?['wallet_address'] ?? sender?['walletAddress'] ?? user).toString();
                            return ListTile(
                              leading: CircleAvatar(backgroundImage: NetworkImage(UserService.safeAvatarUrl(leadSeed))),
                              title: Text(
                                type == 'like' ? '$user liked your post' : type == 'comment' ? '$user commented' : type == 'reply' ? '$user replied' : type == 'mention' ? '$user mentioned you' : (n['type'] ?? 'Notification').toString(),
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: Text(time, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                              onTap: () {
                                // Close and navigate to post or take appropriate action
                                Navigator.pop(context);
                                final postId = n['postId']?.toString();
                                if (postId != null && postId.isNotEmpty) {
                                  // attempt to find post in current feed and open comments
                                  final idx = _communityPosts.indexWhere((p) => p.id == postId);
                                  if (idx != -1) {
                                    // open comments for that post
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      _showComments(idx);
                                    });
                                  }
                                }
                              },
                            );
                          },
                          separatorBuilder: (_, __) => const Divider(height: 1),
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
    _selectedLocation = null;
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
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton(
                        onPressed: () async {
                          final content = _newPostController.text.trim();
                          if (content.isEmpty && _selectedPostImage == null && _selectedPostVideo == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please add content, an image, or a video')),
                            );
                            return;
                          }
                          
                          // Check if user has auth token
                          try {
                            final prefs = await SharedPreferences.getInstance();
                            final walletAddress = prefs.getString('wallet') ?? prefs.getString('wallet_address') ?? prefs.getString('walletAddress');

                            if (walletAddress == null || walletAddress.isEmpty) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please connect your wallet first')),
                                );
                              }
                              return;
                            }
                            
                            // Ensure user is registered and has JWT token
                            await BackendApiService().loadAuthToken();
                            
                            // If no token, try to register/login
                            final secureStorage = const FlutterSecureStorage();
                            final token = await secureStorage.read(key: 'jwt_token');
                            
                            if (token == null || token.isEmpty) {
                              // Auto-register user
                              debugPrint('No JWT token found, auto-registering user');
                              try {
                                await BackendApiService().saveProfile({
                                  'wallet': walletAddress,
                                  'username': 'user_${walletAddress.substring(0, 8)}',
                                  'displayName': 'User ${walletAddress.substring(0, 8)}',
                                  'bio': '',
                                  'isArtist': false,
                                });
                                // Token should now be stored
                                await BackendApiService().loadAuthToken();
                              } catch (e) {
                                debugPrint('Auto-registration failed: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to authenticate: $e')),
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
                            if (_selectedPostImage != null && _selectedPostImageBytes != null) {
                              try {
                                final fileName = _selectedPostImage!.name;
                                
                                final uploadResult = await BackendApiService().uploadFile(
                                  fileBytes: _selectedPostImageBytes!,
                                  fileName: fileName,
                                  fileType: 'post-image', // Use post-image to store in profiles/posts folder
                                );
                                final url = uploadResult['uploadedUrl'] as String?;
                                if (url != null) {
                                  mediaUrls.add(url);
                                  debugPrint('Image uploaded successfully: $url');
                                } else {
                                  debugPrint('Warning: Upload succeeded but no URL returned. Result: $uploadResult');
                                }
                              } catch (e) {
                                debugPrint('Error uploading image: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to upload image: $e')),
                                  );
                                }
                              }
                            }
                            
                            // Upload video if selected
                            if (_selectedPostVideo != null) {
                              try {
                                final videoFile = File(_selectedPostVideo!.path);
                                final fileBytes = await videoFile.readAsBytes();
                                final fileName = _selectedPostVideo!.name;
                                
                                final uploadResult = await BackendApiService().uploadFile(
                                  fileBytes: fileBytes,
                                  fileName: fileName,
                                  fileType: 'post-video', // Use post-video to store in profiles/posts folder
                                );
                                final url = uploadResult['uploadedUrl'] as String?;
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
                            await BackendApiService().createCommunityPost(
                              content: content.isEmpty ? (_selectedPostVideo != null ? '🎥' : '📷') : content,
                              mediaUrls: mediaUrls.isNotEmpty ? mediaUrls : null,
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
                              
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Post created successfully!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              // Reload community feed
                              _loadCommunityData();
                            }
                          } catch (e) {
                            setModalState(() => _isPostingNew = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to create post: $e')),
                              );
                            }
                          }
                        },
                        child: Text(
                          'Post',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Provider.of<ThemeProvider>(context).accentColor,
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
                          hintText: 'Share your thoughts about art, AR, or your latest creation...',
                          hintStyle: TextStyle(
                            fontSize: MediaQuery.of(context).size.width < 400 ? 14 : 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.primaryContainer,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: MediaQuery.of(context).size.width < 400 ? 12 : 16,
                            horizontal: 16,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width < 400 ? 14 : 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Selected image preview
                      if (_selectedPostImage != null && _selectedPostImageBytes != null)
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
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer.withAlpha(179),
                                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (_selectedPostImage != null) const SizedBox(height: 16),
                      // Selected video preview
                      if (_selectedPostVideo != null)
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
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
                                      color: Provider.of<ThemeProvider>(context).accentColor,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _selectedPostVideo!.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Provider.of<ThemeProvider>(context).accentColor,
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
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer.withAlpha(179),
                                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_selectedPostVideo != null) const SizedBox(height: 16),
                      // Location display
                      if (_locationName != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Provider.of<ThemeProvider>(context).accentColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _locationName!,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setModalState(() {
                                    _selectedLocation = null;
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
                                    _selectedPostVideo = null; // Clear video if image selected
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
                                    _selectedPostImage = null; // Clear image if video selected
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
                                  bool serviceEnabled = await location.serviceEnabled();
                                  if (!serviceEnabled) {
                                    serviceEnabled = await location.requestService();
                                    if (!serviceEnabled) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Location service disabled')),
                                        );
                                      }
                                      return;
                                    }
                                  }
                                  
                                  // Check permission
                                  loc.PermissionStatus permissionGranted = await location.hasPermission();
                                  if (permissionGranted == loc.PermissionStatus.denied) {
                                    permissionGranted = await location.requestPermission();
                                  }
                                  
                                  if (permissionGranted != loc.PermissionStatus.granted) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Location permission denied')),
                                      );
                                    }
                                    return;
                                  }
                                  
                                  // Get current location
                                  final locationData = await location.getLocation();
                                  setModalState(() {
                                    _selectedLocation = locationData;
                                    _locationName = 'Current Location (${locationData.latitude?.toStringAsFixed(4)}, ${locationData.longitude?.toStringAsFixed(4)})';
                                  });
                                } catch (e) {
                                  debugPrint('Error getting location: $e');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to get location: $e')),
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
    debugPrint('DEBUG: Index $index is out of bounds (posts length: ${_communityPosts.length})');
      return;
    }
    
    final post = _communityPosts[index];
    final wasLiked = post.isLiked;
    debugPrint('DEBUG: Post ${post.id} was liked: $wasLiked, count: ${post.likeCount}');

    try {
      // Get current user wallet from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final currentUserWallet = prefs.getString('wallet') ?? prefs.getString('wallet_address') ?? prefs.getString('user_id');

      // Let the service perform the toggle and persistence; it mutates `post` synchronously
      await CommunityService.togglePostLike(post, currentUserWallet: currentUserWallet);
      debugPrint('DEBUG: Service call completed successfully - liked: ${post.isLiked}, count: ${post.likeCount}');

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
        content: Text(post.isBookmarked ? 'Post bookmarked!' : 'Bookmark removed!'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _toggleFollowArtist(int index) async {
    if (index >= _followingArtists.length) return;
    
    final artist = _followingArtists[index];
    final artistId = artist['id'] as String? ?? artist['publicKey'] as String? ?? '';
    final artistName = artist['name'] as String? ?? 'Artist';
    
    if (artistId.isEmpty) return;
    
    try {
      // Use centralized UserService.toggleFollow which handles backend sync + local fallback
      final newState = await UserService.toggleFollow(artistId);

      if (!mounted) return;

      // Update local follow map and refetch artist stats from backend
      final backend = BackendApiService();
      int updatedFollowers = (artist['followersCount'] as int?) ?? 0;
      try {
        final stats = await backend.getUserStats(artistId);
        updatedFollowers = stats['followers'] as int? ?? updatedFollowers;
      } catch (_) {}
      setState(() {
        _followedArtists[index] = newState;
        _followingArtists[index]['followersCount'] = updatedFollowers;
      });

      // Trigger global refresh so other UIs update
      try { Provider.of<AppRefreshProvider>(context, listen: false).triggerCommunity(); } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newState ? 'Now following $artistName!' : 'Unfollowed $artistName'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error toggling follow: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
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
      final backendComments = await BackendApiService().getComments(postId: post.id);
      debugPrint('   ✅ Received ${backendComments.length} root comments from backend');
      
      // Count total comments including nested replies
      int totalComments = backendComments.length;
      for (final comment in backendComments) {
        totalComments += comment.replies.length;
        debugPrint('   Comment ${comment.id} has ${comment.replies.length} replies');
      }
      debugPrint('   Total comments (including nested): $totalComments');
      
      // Replace current comments with backend-provided nested comments
      post.comments = backendComments;
      post.commentCount = post.comments.length;
      
      // Load liked state from SharedPreferences for all comments and replies
      debugPrint('   📥 Loading liked state from SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      final likedComments = prefs.getStringList('community_likes_comments') ?? [];
      debugPrint('   Found ${likedComments.length} liked comments in local storage');
      
      void applyLikedState(Comment comment) {
        final commentKey = '${post.id}|${comment.id}';
        comment.isLiked = likedComments.contains(commentKey);
        debugPrint('   Comment ${comment.id}: isLiked=${comment.isLiked}, key=$commentKey');
        for (final reply in comment.replies) {
          applyLikedState(reply);
        }
      }
      
      for (final comment in post.comments) {
        applyLikedState(comment);
      }
      
      debugPrint('   ✅ Liked state applied to all comments');
      
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Failed to load backend comments for post ${post.id}: $e');
    }
    
    final TextEditingController commentController = TextEditingController();
    String? replyToCommentId; // Track which comment is being replied to
    
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
                      '${post.comments.length} comments',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                        post.comments[commentIndex].authorAvatar != null && post.comments[commentIndex].authorAvatar!.isNotEmpty
                            ? CircleAvatar(
                                radius: 16,
                                backgroundImage: NetworkImage(post.comments[commentIndex].authorAvatar!),
                                backgroundColor: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.2),
                              )
                            : Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Provider.of<ThemeProvider>(context).accentColor,
                                      Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    post.comments[commentIndex].authorName.isNotEmpty ? post.comments[commentIndex].authorName[0].toUpperCase() : 'U',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onPrimary,
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
                                post.comments[commentIndex].authorName,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                post.comments[commentIndex].content,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _getTimeAgo(post.comments[commentIndex].timestamp),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                                      post.comments[commentIndex].isLiked ? Icons.favorite : Icons.favorite_border,
                                      size: 18,
                                      color: post.comments[commentIndex].isLiked ? Colors.red : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                    onPressed: () async {
                                      // Optimistic toggle
                                      setModalState(() {
                                        post.comments[commentIndex].isLiked = !post.comments[commentIndex].isLiked;
                                        post.comments[commentIndex].likeCount += post.comments[commentIndex].isLiked ? 1 : -1;
                                      });
                                      try {
                                        await CommunityService.toggleCommentLike(post.comments[commentIndex], post.id);
                                      } catch (e) {
                                        // rollback on error
                                        setModalState(() {
                                          post.comments[commentIndex].isLiked = !post.comments[commentIndex].isLiked;
                                          post.comments[commentIndex].likeCount += post.comments[commentIndex].isLiked ? 1 : -1;
                                        });
                                        // Show error feedback
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Failed to update like: $e'),
                                              backgroundColor: Colors.red,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${post.comments[commentIndex].likeCount}',
                                    style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () {
                                      // Set reply parent and prefill mention
                                      final authorName = post.comments[commentIndex].authorName;
                                      final fallbackId = post.comments[commentIndex].authorId;
                                      String mention;
                                      if (authorName.isNotEmpty) {
                                        final sanitized = authorName.replaceAll(' ', '');
                                        mention = '@${sanitized.length > 20 ? sanitized.substring(0, 20) : sanitized} ';
                                      } else if (fallbackId.isNotEmpty) {
                                        mention = '@${fallbackId.substring(0, 8)} ';
                                      } else {
                                        mention = '';
                                      }
                                      setModalState(() {
                                        replyToCommentId = post.comments[commentIndex].id; // Track parent comment
                                        commentController.text = mention;
                                        // place cursor at end
                                        commentController.selection = TextSelection.fromPosition(TextPosition(offset: commentController.text.length));
                                      });
                                    },
                                    child: Row(
                                      children: [
                                        Icon(Icons.reply_outlined, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                        const SizedBox(width: 6),
                                        Text('Reply', style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // Nested replies (rendered indented)
                              if (post.comments[commentIndex].replies.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: post.comments[commentIndex].replies.map((reply) {
                                    return Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          reply.authorAvatar != null && reply.authorAvatar!.isNotEmpty
                                              ? CircleAvatar(radius: 12, backgroundImage: NetworkImage(reply.authorAvatar!))
                                              : Container(width: 24, height: 24, decoration: BoxDecoration(color: Provider.of<ThemeProvider>(context).accentColor, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(reply.authorName.isNotEmpty ? reply.authorName[0].toUpperCase() : 'U', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12)))),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(reply.authorName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                                                const SizedBox(height: 4),
                                                Text(reply.content, style: GoogleFonts.inter(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Text(_getTimeAgo(reply.timestamp), style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                                                    const SizedBox(width: 16),
                                                    GestureDetector(
                                                      onTap: () async {
                                                        setModalState(() {
                                                          reply.isLiked = !reply.isLiked;
                                                          reply.likeCount += reply.isLiked ? 1 : -1;
                                                        });
                                                        try {
                                                          await CommunityService.toggleCommentLike(reply, post.id);
                                                        } catch (e) {
                                                          setModalState(() {
                                                            reply.isLiked = !reply.isLiked;
                                                            reply.likeCount += reply.isLiked ? 1 : -1;
                                                          });
                                                          // Show error feedback
                                                          if (context.mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(
                                                                content: Text('Failed to update like: $e'),
                                                                backgroundColor: Colors.red,
                                                                duration: const Duration(seconds: 2),
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      },
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            reply.isLiked ? Icons.favorite : Icons.favorite_border,
                                                            size: 14,
                                                            color: reply.isLiked ? Colors.red : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text('${reply.likeCount}', style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                                                        ],
                                                      ),
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
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.reply, size: 16, color: Provider.of<ThemeProvider>(context).accentColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Replying to comment',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Provider.of<ThemeProvider>(context).accentColor,
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
                        final displayName = currentUser?.displayName ?? currentUser?.username ?? 'U';
                        
                        return CircleAvatar(
                          radius: 16,
                          backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
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
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide(
                              color: Provider.of<ThemeProvider>(context).accentColor,
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
                                final prefs = await SharedPreferences.getInstance();
                                var currentUserId = prefs.getString('user_id');
                                var userName = prefs.getString('username') ?? 'Current User';
                                if (currentUserId == null || currentUserId.isEmpty) {
                                  // Allow commenting if wallet is connected (mnemonic or wallet_address present)
                                  final walletAddress = prefs.getString('wallet') ?? prefs.getString('wallet_address') ?? prefs.getString('walletAddress');
                                  if (walletAddress != null && walletAddress.isNotEmpty) {
                                    currentUserId = walletAddress;
                                    userName = prefs.getString('username') ?? 'user_${walletAddress.substring(0, 8)}';
                                  }
                                }
                                if (currentUserId == null || currentUserId.isEmpty) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Please complete onboarding or re-login to comment.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                debugPrint('💬 Adding comment with parentCommentId: $replyToCommentId');
                                await CommunityService.addComment(
                                  post,
                                  value.trim(),
                                  userName,
                                  currentUserId: currentUserId,
                                  parentCommentId: replyToCommentId, // Pass parent comment ID for nesting
                                );
                                // Refresh comments from backend to ensure server state (avatars, real ids)
                                try {
                                  final backendComments = await BackendApiService().getComments(postId: post.id);
                                  post.comments = backendComments;
                                  post.commentCount = post.comments.length;
                                } catch (e) {
                                  debugPrint('Warning: failed to refresh comments after submit: $e');
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
                                  content: Text('Failed to add comment: $e'),
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
                            Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        onPressed: () async {
                            if (commentController.text.trim().isNotEmpty) {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              final prefs = await SharedPreferences.getInstance();
                              var currentUserId = prefs.getString('user_id');
                              var userName = prefs.getString('username') ?? 'Current User';
                              final commentText = commentController.text.trim();
                              if (currentUserId == null || currentUserId.isEmpty) {
                                final walletAddress = prefs.getString('wallet') ?? prefs.getString('wallet_address') ?? prefs.getString('walletAddress');
                                if (walletAddress != null && walletAddress.isNotEmpty) {
                                  currentUserId = walletAddress;
                                  userName = prefs.getString('username') ?? 'user_${walletAddress.substring(0, 8)}';
                                }
                              }
                              if (currentUserId == null || currentUserId.isEmpty) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Please complete onboarding or re-login to comment.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              debugPrint('💬 Adding comment (button) with parentCommentId: $replyToCommentId');
                              await CommunityService.addComment(
                                post,
                                commentText,
                                userName,
                                currentUserId: currentUserId,
                                parentCommentId: replyToCommentId, // Pass parent comment ID for nesting
                              );
                              // Refresh comments to reflect server state
                              try {
                                final backendComments = await BackendApiService().getComments(postId: post.id);
                                post.comments = backendComments;
                                post.commentCount = post.comments.length;
                              } catch (e) {
                                debugPrint('Warning: failed to refresh comments after send: $e');
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
                                  content: Text('Failed to add comment: $e'),
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
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('username') ?? 'Current User';

    // Share through service (with backend sync and notification)
    await CommunityService.sharePost(post, currentUserName: userName);

    // Use share_plus for actual platform sharing
    final shareText = '${post.content}\n\n- ${post.authorName} on art.kubus\n\nDiscover more AR art on art.kubus!';
    final messenger = ScaffoldMessenger.of(context);
    await SharePlus.instance.share(ShareParams(text: shareText));
    if (!mounted) return;

    // Update UI immediately
    setState(() {
      // UI will reflect the updated share count from the service
    });

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Post shared!'),
        duration: Duration(seconds: 2),
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

  void _viewPostDetail(int index) {
    if (index >= _communityPosts.length) return;
    
    final post = _communityPosts[index];
    
    // Show post detail dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Dialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(24),
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _viewUserProfile(post.authorId),
                          child: post.authorAvatar != null && post.authorAvatar!.isNotEmpty
                              ? CircleAvatar(
                                  radius: 20,
                                  backgroundImage: NetworkImage(post.authorAvatar!),
                                  backgroundColor: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.2),
                                )
                              : Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Provider.of<ThemeProvider>(context).accentColor,
                                        Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(Icons.person, color: Theme.of(context).colorScheme.onPrimary, size: 20),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _viewUserProfile(post.authorId),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.authorName,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  '@${post.authorUsername}',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      post.content,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (post.imageUrl != null) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => _showImageLightbox(post.imageUrl!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            post.imageUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.3),
                                      Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.3),
                                      Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(Icons.image_not_supported, color: Theme.of(context).colorScheme.onPrimary, size: 60),
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
                          index < _communityPosts.length ? 
                            (_communityPosts[index].isLiked ? Icons.favorite : Icons.favorite_border) : 
                            Icons.favorite_border, 
                          index < _communityPosts.length ? '${_communityPosts[index].likeCount}' : '0',
                          onTap: () {
                            _toggleLike(index);
                            setDialogState(() {
                              // Update dialog state when like changes
                            });
                          },
                          isActive: index < _communityPosts.length ? _communityPosts[index].isLiked : false,
                        ),
                        const SizedBox(width: 20),
                        _buildInteractionButton(
                          Icons.comment_outlined, 
                          index < _communityPosts.length ? '${_communityPosts[index].commentCount}' : '0',
                          onTap: () {
                            Navigator.pop(context);
                            _showComments(index);
                          },
                        ),
                        const SizedBox(width: 20),
                        _buildInteractionButton(
                          Icons.share_outlined, 
                          index < _communityPosts.length ? '${_communityPosts[index].shareCount}' : '0',
                          onTap: () {
                            _sharePost(index);
                            setDialogState(() {
                              // Update dialog state when share changes
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

  void _showImageLightbox(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Theme.of(context).colorScheme.onSurface.withAlpha(230),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  color: Colors.transparent,
                  width: double.infinity,
                  height: double.infinity,
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onSurface, size: 64),
                                const SizedBox(height: 16),
                                Text(
                                  'Failed to load image',
                                  style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface, size: 32),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer.withAlpha(179),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
