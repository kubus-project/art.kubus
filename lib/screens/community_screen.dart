import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/themeprovider.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    
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
  }

  @override
  void dispose() {
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
        final isVerySmallScreen = constraints.maxWidth < 350;
        
        return Container(
          margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabController,
            tabs: _tabs.map((tab) => Tab(
              child: Text(
                tab,
                style: GoogleFonts.inter(
                  fontSize: isVerySmallScreen ? 11 : isSmallScreen ? 12 : 14,
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
              fontSize: isVerySmallScreen ? 11 : isSmallScreen ? 12 : 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontSize: isVerySmallScreen ? 11 : isSmallScreen ? 12 : 14,
              fontWeight: FontWeight.normal,
            ),
            dividerHeight: 0,
          ),
        );
      },
    );
  }

  Widget _buildFeedTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: 10,
      itemBuilder: (context, index) => _buildPostCard(index),
    );
  }

  Widget _buildDiscoverTab() {
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
  }

  Widget _buildFollowingTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: 8,
      itemBuilder: (context, index) => _buildFollowingItem(index),
    );
  }

  Widget _buildCollectionsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: 6,
      itemBuilder: (context, index) => _buildCollectionItem(index),
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
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              Container(
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
              const SizedBox(width: 12),
              Expanded(
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
              Text(
                post.$4,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
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
              _buildInteractionButton(Icons.favorite_border, '${12 + index * 3}'),
              const SizedBox(width: 20),
              _buildInteractionButton(Icons.comment_outlined, '${3 + index}'),
              const SizedBox(width: 20),
              _buildInteractionButton(Icons.share_outlined, '${1 + index}'),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.bookmark_border,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionButton(IconData icon, String count) {
    return GestureDetector(
      onTap: () {},
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(
            count,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
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
      onTap: () => _viewArtwork(index),
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
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: artist.$4 
                  ? themeProvider.accentColor 
                  : Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: artist.$4 
                  ? Colors.white 
                  : themeProvider.accentColor,
              side: artist.$4 
                  ? null 
                  : BorderSide(color: themeProvider.accentColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              artist.$4 ? 'Following' : 'Follow',
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
            onPressed: () => _viewCollection(index),
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
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: 6,
                itemBuilder: (context, index) => _buildSearchResult(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResult(int index) {
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

  void _viewArtwork(int index) {
    Navigator.pushNamed(context, '/artwork-detail', arguments: index);
  }

  void _viewCollection(int index) {
    Navigator.pushNamed(context, '/collection-detail', arguments: index);
  }
}
