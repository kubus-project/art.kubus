import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/themeprovider.dart';
import '../providers/config_provider.dart';
import 'art_detail_screen.dart';
import 'collection_detail_screen.dart';
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
  final Map<int, bool> _bookmarkedPosts = {};
  final Map<int, bool> _followedArtists = {};

  Future<void> _loadCommunityData() async {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    final posts = CommunityService.getMockPosts(useMockData: configProvider.useMockData);
    
    // Load saved interactions (likes, bookmarks, follows)
    await CommunityService.loadSavedInteractions(posts);
    
    setState(() {
      _communityPosts = posts;
    });
  }
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadCommunityData();
    
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
  
  void _onConfigChanged() {
    _loadCommunityData();
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: themeProvider.isDarkMode 
          ? const Color(0xFF0A0A0A) 
          : const Color(0xFFF8F9FA),
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
            labelColor: Colors.white,
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
    return Consumer<ConfigProvider>(
      builder: (context, config, child) {
        if (!config.useMockData || _communityPosts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.feed,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Posts Available',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Community posts will appear here when available',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[500],
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
      },
    );
  }

  Widget _buildDiscoverTab() {
    return Consumer<ConfigProvider>(
      builder: (context, config, child) {
        if (!config.useMockData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.explore,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Artworks to Discover',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Discover new artworks and artists when content is available',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildDiscoverCategories(),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) => _buildDiscoverArtCard(index),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFollowingTab() {
    return Consumer<ConfigProvider>(
      builder: (context, config, child) {
        if (!config.useMockData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Following List',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Follow artists to see their updates here',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: 8,
          itemBuilder: (context, index) => _buildFollowingItem(index),
        );
      },
    );
  }

  Widget _buildCollectionsTab() {
    return Consumer<ConfigProvider>(
      builder: (context, config, child) {
        if (!config.useMockData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.collections,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Collections Available',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Curated collections will appear here when available',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: 6,
          itemBuilder: (context, index) => _buildCollectionItem(index),
        );
      },
    );
  }

  Widget _buildPostCard(int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final posts = [
      ('Maya Digital', '@maya_3d', 'Just discovered an amazing AR sculpture in Central Park! The way it responds to lighting is incredible 🎨', '2 hours ago'),
      ('Alex Creator', '@alex_nft', 'New collection "Urban Dreams" is now live on the marketplace. Each piece tells a story of city life through AR.', '4 hours ago'),
      ('Sam Artist', '@sam_ar', 'Working on a collaborative piece that changes based on viewer interaction. AR art is the future! 🚀', '6 hours ago'),
      ('Luna Vision', '@luna_viz', 'The intersection of blockchain and creativity opens so many possibilities. Love this community!', '1 day ago'),
    ];
    
    final post = posts[index % posts.length];
    
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
                onTap: () => _viewUserProfile(post.$2),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        themeProvider.accentColor,
                        themeProvider.accentColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _viewUserProfile(post.$2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.$1,
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        post.$2,
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 12 : 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  post.$4,
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 10 : 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            post.$3,
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 13 : 15,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (index % 3 == 0) ...[
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    themeProvider.accentColor.withOpacity(0.3),
                    themeProvider.accentColor.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.view_in_ar, color: Colors.white, size: 60),
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
                onTap: () => _toggleLike(index),
                isActive: index < _communityPosts.length ? _communityPosts[index].isLiked : false,
              ),
              const SizedBox(width: 20),
              _buildInteractionButton(
                Icons.comment_outlined, 
                index < _communityPosts.length ? '${_communityPosts[index].commentCount}' : '0',
                onTap: () => _showComments(index),
              ),
              const SizedBox(width: 20),
              _buildInteractionButton(
                Icons.share_outlined, 
                index < _communityPosts.length ? '${_communityPosts[index].shareCount}' : '0',
                onTap: () => _sharePost(index),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _toggleBookmark(index),
                icon: Icon(
                  index < _communityPosts.length ? 
                    (_communityPosts[index].isBookmarked ? Icons.bookmark : Icons.bookmark_border) :
                    Icons.bookmark_border,
                  color: index < _communityPosts.length && _communityPosts[index].isBookmarked
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
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
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(count),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverCategories() {
    final categories = ['Trending', 'AR Art', 'Sculptures', 'Interactive', 'Collaborative'];
    
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final isSelected = index == 0;
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: FilterChip(
              label: Text(categories[index]),
              selected: isSelected,
              onSelected: (selected) {},
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              selectedColor: Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.2),
              labelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Provider.of<ThemeProvider>(context).accentColor
                    : Theme.of(context).colorScheme.onSurface,
              ),
              side: BorderSide(
                color: isSelected
                    ? Provider.of<ThemeProvider>(context).accentColor
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiscoverArtCard(int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return GestureDetector(
      onTap: () => _viewArtworkDetail(index),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      themeProvider.accentColor.withOpacity(0.3),
                      themeProvider.accentColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(Icons.view_in_ar, color: Colors.white, size: 40),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '🔥 ${12 + index}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AR Creation #${index + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              themeProvider.accentColor,
                              themeProvider.accentColor.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 10),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '@artist${index + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
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

  Widget _buildFollowingItem(int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final artists = [
      ('Maya Digital', '@maya_3d', 'AR Sculptor', true),
      ('Alex Creator', '@alex_nft', 'Digital Artist', false),
      ('Sam Artist', '@sam_ar', 'Interactive Designer', true),
      ('Luna Vision', '@luna_viz', 'Conceptual Artist', false),
    ];
    
    final artist = artists[index % artists.length];
    
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
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  themeProvider.accentColor,
                  themeProvider.accentColor.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artist.$1,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  artist.$2,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                Text(
                  artist.$3,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _toggleFollow(index),
            style: ElevatedButton.styleFrom(
              backgroundColor: _followedArtists[index] == true
                  ? themeProvider.accentColor 
                  : Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: _followedArtists[index] == true
                  ? Colors.white 
                  : themeProvider.accentColor,
              side: _followedArtists[index] == true
                  ? null 
                  : BorderSide(color: themeProvider.accentColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              _followedArtists[index] == true ? 'Following' : 'Follow',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionItem(int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final collections = [
      'Digital Dreams',
      'Urban AR',
      'Nature Spirits',
      'Tech Fusion',
      'Abstract Reality',
      'Collaborative Works'
    ];
    
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
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  themeProvider.accentColor.withOpacity(0.3),
                  themeProvider.accentColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.collections, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collections[index],
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(index + 1) * 8} artworks • Floor: ${(index + 1) * 0.3} SOL',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.trending_up,
                      size: 14,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+${5 + index}% today',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _viewCollectionDetail(index),
            icon: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
      child: const Icon(
        Icons.add,
        color: Colors.white,
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
              child: Consumer<ConfigProvider>(
                builder: (context, configProvider, child) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: configProvider.useMockData ? 6 : 0,
                    itemBuilder: (context, index) => _buildSearchResult(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResult(int index) {
    return Consumer<ConfigProvider>(
      builder: (context, configProvider, child) {
        if (!configProvider.useMockData) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No search results available',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        final results = [
          ('Digital Dreams Collection', 'Collection • 12 items', Icons.collections),
          ('Maya Digital', 'Artist • @maya_3d', Icons.person),
          ('AR Sculpture #1', 'Artwork • By Alex Creator', Icons.view_in_ar),
          ('Urban AR', 'Collection • 8 items', Icons.collections),
          ('Sam Artist', 'Artist • @sam_ar', Icons.person),
          ('Interactive Portal', 'Artwork • By Luna Vision', Icons.view_in_ar),
        ];
        
        final result = results[index];
        
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              result.$3,
              color: Provider.of<ThemeProvider>(context).accentColor,
              size: 20,
            ),
          ),
          title: Text(
            result.$1,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            result.$2,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          onTap: () => Navigator.pop(context),
        );
      },
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
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: 8,
                itemBuilder: (context, index) => _buildNotificationItem(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(int index) {
    final notifications = [
      ('Maya Digital liked your post', 'Your AR sculpture post received a new like', Icons.favorite, '5 min ago'),
      ('New follower', 'Alex Creator started following you', Icons.person_add, '1 hour ago'),
      ('Collection trending', 'Your "Digital Dreams" collection is trending', Icons.trending_up, '2 hours ago'),
      ('Comment on post', 'Sam Artist commented on your artwork', Icons.comment, '4 hours ago'),
    ];
    
    final notification = notifications[index % notifications.length];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              notification.$3,
              color: Provider.of<ThemeProvider>(context).accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.$1,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.$2,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.$4,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _createNewPost() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
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
                    'Create Post',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    TextField(
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
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _buildPostOption(Icons.image, 'Add Image'),
                        const SizedBox(width: 16),
                        _buildPostOption(Icons.view_in_ar, 'Add AR'),
                        const SizedBox(width: 16),
                        _buildPostOption(Icons.location_on, 'Add Location'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostOption(IconData icon, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () {},
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
      ),
    );
  }

  // Interaction methods
  void _toggleLike(int index) async {
    print('DEBUG: _toggleLike called for index: $index');
    if (index >= _communityPosts.length) {
      print('DEBUG: Index $index is out of bounds (posts length: ${_communityPosts.length})');
      return;
    }
    
    final post = _communityPosts[index];
    final wasLiked = post.isLiked;
    print('DEBUG: Post ${post.id} was liked: $wasLiked, count: ${post.likeCount}');
    
    // Update UI immediately with direct state change
    setState(() {
      post.isLiked = !wasLiked;
      post.likeCount = wasLiked ? post.likeCount - 1 : post.likeCount + 1;
      print('DEBUG: UI updated immediately - liked: ${post.isLiked}, count: ${post.likeCount}');
    });
    
    // Update through service in background
    try {
      await CommunityService.togglePostLike(post);
      print('DEBUG: Service call completed successfully');
      
      // Show feedback message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!wasLiked ? 'Post liked!' : 'Post unliked!'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('DEBUG: Error in togglePostLike: $e');
      // Revert state if service fails
      setState(() {
        post.isLiked = wasLiked;
        post.likeCount = wasLiked ? post.likeCount + 1 : post.likeCount - 1;
        print('DEBUG: State reverted due to error');
      });
      
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

  void _toggleFollow(int index) async {
    final artists = [
      ('Maya Digital', '@maya_3d', 'AR Sculptor'),
      ('Alex Creator', '@alex_nft', 'Digital Artist'),
      ('Sam Artist', '@sam_ar', 'Interactive Designer'),
      ('Luna Vision', '@luna_viz', 'Conceptual Artist'),
    ];
    
    final artist = artists[index % artists.length];
    final artistId = 'artist_${index + 1}';
    
    // Update through service
    await CommunityService.toggleFollow(artistId, null);
    
    // Update local state
    setState(() {
      _followedArtists[index] = !(_followedArtists[index] ?? false);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_followedArtists[index] == true 
            ? 'Now following ${artist.$1}!' 
            : 'Unfollowed ${artist.$1}'),
        duration: const Duration(seconds: 2),
      ),
    );
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
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                                Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.7),
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
                                color: Colors.white,
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
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _getTimeAgo(post.comments[commentIndex].timestamp),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
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
                            Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'U',
                          style: TextStyle(
                            color: Colors.white,
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
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
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
                            try {
                              await CommunityService.addComment(
                                post,
                                value.trim(),
                                'Current User',
                              );
                              setModalState(() {});
                              setState(() {});
                              commentController.clear();
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Comment added!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
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
                            Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        onPressed: () async {
                          if (commentController.text.trim().isNotEmpty) {
                            try {
                              await CommunityService.addComment(
                                post,
                                commentController.text.trim(),
                                'Current User',
                              );
                              setModalState(() {});
                              setState(() {});
                              commentController.clear();
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Comment added!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to add comment: $e'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(
                          Icons.send,
                          color: Colors.white,
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
    
    // Share through service
    await CommunityService.sharePost(post);
    
    // Use share_plus for actual platform sharing
    final shareText = '${post.content}\n\n- ${post.authorName} on art.kubus\n\nDiscover more AR art on art.kubus!';
    await Share.share(
      shareText,
      subject: 'Check out this amazing AR artwork!',
    );
    
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

  void _viewArtworkDetail(int index) {
    // Create artwork data for the ArtDetailScreen
    final artData = {
      'title': 'AR Creation #${index + 1}',
      'artist': 'artist${index + 1}',
      'type': 'AR Sculpture',
      'rarity': ['Common', 'Rare', 'Epic', 'Legendary'][index % 4],
      'discovered': true,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArtDetailScreen(artworkId: artData['id']?.toString() ?? ''),
      ),
    );
  }

  void _viewCollectionDetail(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollectionDetailScreen(collectionIndex: index),
      ),
    );
  }

  void _viewUserProfile(String username) {
    // Map usernames to user IDs for navigation
    final userIdMap = {
      '@maya_3d': 'maya_3d',
      '@alex_nft': 'alex_nft',
      '@sam_ar': 'sam_ar',
      '@luna_viz': 'luna_viz',
    };
    
    final userId = userIdMap[username] ?? 'maya_3d';
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          userId: userId,
          username: username,
        ),
      ),
    );
  }

  void _viewPostDetail(int index) {
    // Show post detail dialog or navigate to post detail screen
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final posts = [
          ('Maya Digital', '@maya_3d', 'Just discovered an amazing AR sculpture in Central Park! The way it responds to lighting is incredible 🎨', '2 hours ago'),
          ('Alex Creator', '@alex_nft', 'New collection "Urban Dreams" is now live on the marketplace. Each piece tells a story of city life through AR.', '4 hours ago'),
          ('Sam Artist', '@sam_ar', 'Working on a collaborative piece that changes based on viewer interaction. AR art is the future! 🚀', '6 hours ago'),
          ('Luna Vision', '@luna_viz', 'The intersection of blockchain and creativity opens so many possibilities. Love this community!', '1 day ago'),
        ];
        
        final post = posts[index % posts.length];
        
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
                          onTap: () => _viewUserProfile(post.$2),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Provider.of<ThemeProvider>(context).accentColor,
                                  Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.person, color: Colors.white, size: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _viewUserProfile(post.$2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.$1,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  post.$2,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                      post.$3,
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
