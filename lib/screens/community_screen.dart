import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart' as loc;
import 'dart:io';
import 'dart:typed_data';
import '../providers/themeprovider.dart';
import '../providers/config_provider.dart';
import '../services/backend_api_service.dart';
import '../models/artwork.dart';
import 'art_detail_screen.dart';
import 'user_profile_screen.dart';
import '../community/community_interactions.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  late TabController _tabController;
  
  final List<String> _tabs = ['Feed', 'Discover', 'Following', 'Collections'];
  
  // Community data
  List<CommunityPost> _communityPosts = [];
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
      // Fetch artworks for discovery
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
      // Fetch artists list
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
      // Fetch community posts from backend API
      final posts = await BackendApiService().getCommunityPosts(
        page: 1,
        limit: 50,
      );
      
      // Load saved interactions (likes, bookmarks, follows)
      await CommunityService.loadSavedInteractions(posts);
      
      if (mounted) {
        setState(() {
          _communityPosts = posts;
          _isLoading = false;
        });
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
  Future<String> _getUserAvatar(String walletAddress) async {
    // Check cache first
    if (_avatarCache.containsKey(walletAddress)) {
      return _avatarCache[walletAddress]!;
    }
    
    try {
      final profile = await BackendApiService().getProfileByWallet(walletAddress);
      final avatar = profile['avatar'] ?? '';
      _avatarCache[walletAddress] = avatar; // Cache the result
      return avatar;
    } catch (e) {
      _avatarCache[walletAddress] = ''; // Cache empty result to prevent retries
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
              color: themeProvider.accentColor,
              size: 28,
            ),
          ),
          IconButton(
            onPressed: () {
              _showNotifications();
            },
            icon: Icon(
              Icons.notifications_outlined,
              color: themeProvider.accentColor,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

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
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_communityPosts.isEmpty) {
      return Center(
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _communityPosts.length,
      itemBuilder: (context, index) => _buildPostCard(index),
    );
  }

  Widget _buildDiscoverTab() {
    if (_isLoadingDiscover) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_discoverArtworks.isEmpty) {
      return Center(
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
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: _discoverArtworks.length,
      itemBuilder: (context, index) => _buildDiscoverArtworkCard(_discoverArtworks[index]),
    );
  }

  Widget _buildFollowingTab() {
    if (_isLoadingFollowing) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_followingArtists.isEmpty) {
      return Center(
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _followingArtists.length,
      itemBuilder: (context, index) => _buildArtistCard(_followingArtists[index], index),
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
                child: FutureBuilder<String>(
                  future: _getUserAvatar(post.authorId),
                  builder: (context, snapshot) {
                    return CircleAvatar(
                      radius: 20,
                      backgroundColor: themeProvider.accentColor,
                      backgroundImage: snapshot.hasData && snapshot.data!.isNotEmpty
                          ? NetworkImage(snapshot.data!) as ImageProvider
                          : null,
                      child: !snapshot.hasData || snapshot.data!.isEmpty
                          ? Icon(Icons.person, color: Theme.of(context).colorScheme.onPrimary, size: 20)
                          : null,
                    );
                  },
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
                        '@${post.authorId.substring(0, 8)}',
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
            ClipRRect(
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

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
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
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Mark all read',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Provider.of<ThemeProvider>(context).accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
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
          ],
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
                            final walletAddress = prefs.getString('wallet_address');
                            
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
                                  'walletAddress': walletAddress,
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
                            if (_selectedPostImage != null) {
                              try {
                                final imageFile = File(_selectedPostImage!.path);
                                final fileBytes = await imageFile.readAsBytes();
                                final fileName = _selectedPostImage!.name;
                                
                                final uploadResult = await BackendApiService().uploadFile(
                                  fileBytes: fileBytes,
                                  fileName: fileName,
                                  fileType: 'image',
                                );
                                final url = uploadResult['url'] as String?;
                                if (url != null) mediaUrls.add(url);
                              } catch (e) {
                                debugPrint('Error uploading image: $e');
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
                                  fileType: 'video',
                                );
                                final url = uploadResult['url'] as String?;
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
                                  backgroundColor: Colors.black54,
                                  foregroundColor: Colors.white,
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
                            color: Colors.black87,
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
                                        color: Colors.white,
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
                                    backgroundColor: Colors.black54,
                                    foregroundColor: Colors.white,
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
              color: Provider.of<ThemeProvider>(context).accentColor,
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
    
    // Update UI immediately with direct state change
    setState(() {
      post.isLiked = !wasLiked;
      post.likeCount = wasLiked ? post.likeCount - 1 : post.likeCount + 1;
    debugPrint('DEBUG: UI updated immediately - liked: ${post.isLiked}, count: ${post.likeCount}');
    });
    
    // Update through service in background
    try {
      // Get current user ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('user_id');
      
      await CommunityService.togglePostLike(post, currentUserId: currentUserId);
    debugPrint('DEBUG: Service call completed successfully');
      if (!mounted) return;
      
      // Show feedback message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!wasLiked ? 'Post liked!' : 'Post unliked!'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
    debugPrint('DEBUG: Error in togglePostLike: $e');
      // Revert state if service fails
      setState(() {
        post.isLiked = wasLiked;
        post.likeCount = wasLiked ? post.likeCount + 1 : post.likeCount - 1;
    debugPrint('DEBUG: State reverted due to error');
      });
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
      // Toggle follow state
      final isCurrentlyFollowing = _followedArtists[index] ?? false;
      
      if (isCurrentlyFollowing) {
        // Unfollow
        await BackendApiService().unfollowUser(artistId);
      } else {
        // Follow
        await BackendApiService().followUser(artistId);
      }
      
      if (!mounted) return;
      
      // Update local state
      setState(() {
        _followedArtists[index] = !isCurrentlyFollowing;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!isCurrentlyFollowing 
              ? 'Now following $artistName!' 
              : 'Unfollowed $artistName'),
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

  void _showComments(int index) {
    if (index >= _communityPosts.length) return;
    
    final post = _communityPosts[index];
    final TextEditingController commentController = TextEditingController();
    
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
                        Container(
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
                              post.comments[commentIndex].authorName[0].toUpperCase(),
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
                child: Row(
                  children: [
                    Container(
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
                          'U',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
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
                              final currentUserId = prefs.getString('user_id');
                              final userName = prefs.getString('username') ?? 'Current User';
                              
                              await CommunityService.addComment(
                                post,
                                value.trim(),
                                userName,
                                currentUserId: currentUserId,
                              );
                              if (!mounted) return;
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
                              final currentUserId = prefs.getString('user_id');
                              final userName = prefs.getString('username') ?? 'Current User';
                              final commentText = commentController.text.trim();
                              
                              await CommunityService.addComment(
                                post,
                                commentText,
                                userName,
                                currentUserId: currentUserId,
                              );
                              if (!mounted) return;
                              
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
                  ],
                ),
              ),
            ],
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
    await Share.share(shareText);
    if (!mounted) return;
    
    // Update UI immediately
    setState(() {
      // UI will reflect the updated share count from the service
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
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
                          child: Container(
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
                                  '@${post.authorId.substring(0, 8)}',
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
}
