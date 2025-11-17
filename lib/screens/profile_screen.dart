import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_loading.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/themeprovider.dart';
import '../providers/web3provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/config_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/task_provider.dart';
import '../services/backend_api_service.dart';
import '../community/community_interactions.dart';
import '../web3/wallet.dart';
import '../web3/achievements/achievements_page.dart';
import 'settings_screen.dart';
import 'saved_items_screen.dart';
import 'profile_screen_methods.dart';
import '../models/achievements.dart';
import 'profile_edit_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  late TabController _tabController;
  final List<String> _tabs = ['Activity', 'Stats'];
  
  // Privacy settings state
  bool _privateProfile = false;
  bool _showActivityStatus = true;
  bool _showCollection = true;
  bool _allowMessages = true;

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
    _loadPrivacySettings();
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
          ? Theme.of(context).scaffoldBackgroundColor 
          : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: CustomScrollView(
                  slivers: [
                    _buildProfileHeader(),
                    _buildStatsSection(),
                    SliverToBoxAdapter(
                      child: SizedBox(height: 24),
                    ),
                    _buildTabBar(),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildActivityTab(),
                            _buildStatsTab(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final web3Provider = Provider.of<Web3Provider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    
    return SliverToBoxAdapter(
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isSmallScreen = constraints.maxWidth < 375;
          bool isVerySmallScreen = constraints.maxWidth < 320;
          
          return Container(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Profile',
                        style: GoogleFonts.inter(
                          fontSize: isVerySmallScreen ? 24 : isSmallScreen ? 26 : 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            _shareProfile();
                          },
                          icon: Icon(
                            Icons.share,
                            color: themeProvider.accentColor,
                            size: isSmallScreen ? 22 : 24,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SettingsScreen()),
                            );
                          },
                          icon: Icon(
                            Icons.settings,
                            color: themeProvider.accentColor,
                            size: isSmallScreen ? 22 : 24,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 24 : 32),
                Container(
                  width: isVerySmallScreen ? 100 : isSmallScreen ? 110 : 120,
                  height: isVerySmallScreen ? 100 : isSmallScreen ? 110 : 120,
                  decoration: BoxDecoration(
                    gradient: profileProvider.currentUser?.avatar == null || profileProvider.currentUser!.avatar.isEmpty
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              themeProvider.accentColor,
                              themeProvider.accentColor.withValues(alpha: 0.7),
                            ],
                          )
                        : null,
                    image: profileProvider.currentUser?.avatar != null && profileProvider.currentUser!.avatar.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(profileProvider.currentUser!.avatar),
                            fit: BoxFit.cover,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(isVerySmallScreen ? 50 : isSmallScreen ? 55 : 60),
                    boxShadow: [
                      BoxShadow(
                        color: themeProvider.accentColor.withValues(alpha: 0.3),
                        blurRadius: isSmallScreen ? 15 : 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: profileProvider.currentUser?.avatar == null || profileProvider.currentUser!.avatar.isEmpty
                      ? Icon(
                          Icons.person,
                          color: Colors.white,
                          size: isVerySmallScreen ? 50 : isSmallScreen ? 55 : 60,
                        )
                      : null,
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
                Text(
                  profileProvider.currentUser?.displayName ?? profileProvider.currentUser?.username ?? 'Anonymous Artist',
                  style: GoogleFonts.inter(
                    fontSize: isVerySmallScreen ? 20 : isSmallScreen ? 22 : 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                if (profileProvider.currentUser?.username != null && profileProvider.currentUser?.displayName != null) ...[  
                  SizedBox(height: isSmallScreen ? 4 : 6),
                  Text(
                    '@${profileProvider.currentUser!.username}',
                    style: GoogleFonts.inter(
                      fontSize: isVerySmallScreen ? 14 : isSmallScreen ? 15 : 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                SizedBox(height: isSmallScreen ? 6 : 8),
                if (web3Provider.isConnected) ...[
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16, 
                      vertical: isSmallScreen ? 6 : 8
                    ),
                    decoration: BoxDecoration(
                      color: themeProvider.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: themeProvider.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      web3Provider.formatAddress(web3Provider.walletAddress),
                      style: GoogleFonts.robotoMono(
                        fontSize: isSmallScreen ? 12 : 14,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.accentColor,
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Connect wallet to see profile',
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                SizedBox(height: isSmallScreen ? 12 : 16),
                if (profileProvider.currentUser?.bio != null && profileProvider.currentUser!.bio.isNotEmpty)
                  Text(
                    profileProvider.currentUser!.bio,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: isVerySmallScreen ? 14 : isSmallScreen ? 15 : 16,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                    maxLines: isSmallScreen ? 3 : 4,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    'No bio yet. Tap "Edit Profile" to add one.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: isVerySmallScreen ? 14 : isSmallScreen ? 15 : 16,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                SizedBox(height: isSmallScreen ? 20 : 24),
                isSmallScreen 
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              _editProfile();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeProvider.accentColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: isVerySmallScreen ? 14 : 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Edit Profile',
                              style: GoogleFonts.inter(
                                fontSize: isVerySmallScreen ? 14 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: themeProvider.accentColor,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextButton(
                            onPressed: () {
                              _showMoreOptions();
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: isVerySmallScreen ? 14 : 16),
                            ),
                            child: Text(
                              'More Options',
                              style: GoogleFonts.inter(
                                fontSize: isVerySmallScreen ? 14 : 16,
                                fontWeight: FontWeight.w600,
                                color: themeProvider.accentColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _editProfile();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeProvider.accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Edit Profile',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: themeProvider.accentColor,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () {
                              _showMoreOptions();
                            },
                            icon: Icon(
                              Icons.more_horiz,
                              color: themeProvider.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsSection() {
    final web3Provider = Provider.of<Web3Provider>(context);
    
    return SliverToBoxAdapter(
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isSmallScreen = constraints.maxWidth < 375;
          
          return Container(
            margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            child: Column(
              children: [
                if (web3Provider.isConnected) ...[
                  Consumer<WalletProvider>(
                    builder: (context, walletProvider, child) {
                      // Get KUB8 balance
                      final kub8Balance = walletProvider.tokens
                          .where((token) => token.symbol.toUpperCase() == 'KUB8')
                          .isNotEmpty 
                          ? walletProvider.tokens
                              .where((token) => token.symbol.toUpperCase() == 'KUB8')
                              .first.balance 
                          : 0.0;
                      
                      // Get SOL balance  
                      final solBalance = walletProvider.tokens
                          .where((token) => token.symbol.toUpperCase() == 'SOL')
                          .isNotEmpty 
                          ? walletProvider.tokens
                              .where((token) => token.symbol.toUpperCase() == 'SOL')
                              .first.balance 
                          : 0.0;

                      return isSmallScreen && constraints.maxWidth < 300
                        ? Column(
                            children: [
                              _buildBalanceCard(
                                'KUB8 Balance',
                                kub8Balance.toStringAsFixed(2),
                                Icons.currency_bitcoin,
                                isSmallScreen: isSmallScreen,
                              ),
                              const SizedBox(height: 12),
                              _buildBalanceCard(
                                'SOL Balance',
                                solBalance.toStringAsFixed(3),
                                Icons.account_balance_wallet,
                                isSmallScreen: isSmallScreen,
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _buildBalanceCard(
                                  'KUB8 Balance',
                                  kub8Balance.toStringAsFixed(2),
                                  Icons.currency_bitcoin,
                                  isSmallScreen: isSmallScreen,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildBalanceCard(
                                  'SOL Balance',
                                  solBalance.toStringAsFixed(3),
                                  Icons.account_balance_wallet,
                                  isSmallScreen: isSmallScreen,
                                ),
                              ),
                            ],
                          );
                    },
                  ),
                  SizedBox(height: isSmallScreen ? 16 : 20),
                ],
                isSmallScreen
                  ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Consumer<ProfileProvider>(
                                builder: (context, profileProvider, child) {
                                  return _buildStatCard(
                                    'Artworks',
                                    profileProvider.formattedArtworksCount,
                                    Icons.palette,
                                    isSmallScreen: isSmallScreen,
                                    onTap: () => ProfileScreenMethods.showArtworks(context),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Consumer<ProfileProvider>(
                                builder: (context, profileProvider, child) {
                                  return _buildStatCard(
                                    'Collections',
                                    profileProvider.formattedCollectionsCount,
                                    Icons.collections,
                                    isSmallScreen: isSmallScreen,
                                    onTap: () => ProfileScreenMethods.showCollections(context),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Consumer<ProfileProvider>(
                                builder: (context, profileProvider, child) {
                                  return _buildStatCard(
                                    'Followers',
                                    profileProvider.formattedFollowersCount,
                                    Icons.people,
                                    isSmallScreen: isSmallScreen,
                                    onTap: () => ProfileScreenMethods.showFollowers(context),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Consumer<ProfileProvider>(
                                builder: (context, profileProvider, child) {
                                  return _buildStatCard(
                                    'Following',
                                    profileProvider.formattedFollowingCount,
                                    Icons.person_add,
                                    isSmallScreen: isSmallScreen,
                                    onTap: () => ProfileScreenMethods.showFollowing(context),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Consumer<ProfileProvider>(
                            builder: (context, profileProvider, child) {
                              return _buildStatCard(
                                'Artworks',
                                profileProvider.formattedArtworksCount,
                                Icons.palette,
                                isSmallScreen: isSmallScreen,
                                onTap: () => ProfileScreenMethods.showArtworks(context),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Consumer<ProfileProvider>(
                            builder: (context, profileProvider, child) {
                              return _buildStatCard(
                                'Collections',
                                profileProvider.formattedCollectionsCount,
                                Icons.collections,
                                isSmallScreen: isSmallScreen,
                                onTap: () => ProfileScreenMethods.showCollections(context),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Consumer<ProfileProvider>(
                            builder: (context, profileProvider, child) {
                              return _buildStatCard(
                                'Followers',
                                profileProvider.formattedFollowersCount,
                                Icons.people,
                                isSmallScreen: isSmallScreen,
                                onTap: () => ProfileScreenMethods.showFollowers(context),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Consumer<ProfileProvider>(
                            builder: (context, profileProvider, child) {
                              return _buildStatCard(
                                'Following',
                                profileProvider.formattedFollowingCount,
                                Icons.person_add,
                                isSmallScreen: isSmallScreen,
                                onTap: () => ProfileScreenMethods.showFollowing(context),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(String title, String value, IconData icon, {bool isSmallScreen = false}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const Wallet()),
        );
      },
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        decoration: BoxDecoration(
          color: themeProvider.accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
          border: Border.all(
            color: themeProvider.accentColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: themeProvider.accentColor,
              size: isSmallScreen ? 20 : 24,
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: themeProvider.accentColor,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 8 : 10,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, {bool isSmallScreen = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Provider.of<ThemeProvider>(context).accentColor,
              size: isSmallScreen ? 16 : 18,
            ),
            SizedBox(height: isSmallScreen ? 4 : 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 10 : 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 7 : 8,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return SliverToBoxAdapter(
      child: LayoutBuilder(
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
              isScrollable: false, // Make tabs full width
              tabAlignment: TabAlignment.fill, // Ensure full width distribution
              tabs: _tabs.map((tab) => Tab(
                child: Text(
                  tab,
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 12 : 14,
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
                fontSize: isSmallScreen ? 12 : 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: isSmallScreen ? 12 : 14,
                fontWeight: FontWeight.normal,
              ),
              dividerHeight: 0,
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isSmallScreen = constraints.maxWidth < 375;
        
        return Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
          child: FutureBuilder<Map<String, List<dynamic>>>(
            future: _loadUserActivity(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AppLoading();
              }
              
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error Loading Activity',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              final activityData = snapshot.data ?? {};
              final activities = _buildActivityList(activityData);
              
              if (activities.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timeline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Activity Yet',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start creating and interacting to see your activity here',
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
                itemCount: activities.length,
                itemBuilder: (context, index) => _buildRealActivityItem(activities[index]),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildAchievementsSection(),
          const SizedBox(height: 24),
          _buildPerformanceStats(),
        ],
      ),
    );
  }

  /// Load user activity from backend (posts, likes, comments, saved items)
  Future<Map<String, List<dynamic>>> _loadUserActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final walletAddress = prefs.getString('wallet_address');
      
      if (walletAddress == null || walletAddress.isEmpty) {
        return {};
      }

      // Load user's posts (filtered by wallet address)
      final posts = await BackendApiService().getCommunityPosts(
        page: 1,
        limit: 50,
        authorWallet: walletAddress,
      );

      // Load liked posts (from local storage)
      final likedPostIds = prefs.getStringList('liked_posts') ?? [];
      
      // Load bookmarked posts
      final bookmarkedPostIds = prefs.getStringList('bookmarked_posts') ?? [];
      
      // Load saved artworks
      final savedArtworkIds = prefs.getStringList('saved_artwork_ids') ?? [];

      return {
        'posts': posts,
        'likes': likedPostIds,
        'bookmarks': bookmarkedPostIds,
        'savedArtworks': savedArtworkIds,
      };
    } catch (e) {
      debugPrint('Error loading user activity: $e');
      return {};
    }
  }

  /// Build activity list from backend data
  List<Map<String, dynamic>> _buildActivityList(Map<String, List<dynamic>> activityData) {
    final activities = <Map<String, dynamic>>[];
    
    // Add posts
    final posts = activityData['posts'] ?? [];
    for (final post in posts) {
      if (post is CommunityPost) {
        activities.add({
          'type': 'post',
          'icon': Icons.create,
          'title': 'Created a post',
          'description': post.content.length > 50 
              ? '${post.content.substring(0, 50)}...' 
              : post.content,
          'timestamp': post.timestamp,
        });
      }
    }
    
    // Add likes
    final likes = activityData['likes'] ?? [];
    if (likes.isNotEmpty) {
      activities.add({
        'type': 'likes',
        'icon': Icons.favorite,
        'title': 'Liked ${likes.length} posts',
        'description': 'You\'ve been active in the community',
        'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
      });
    }
    
    // Add bookmarks
    final bookmarks = activityData['bookmarks'] ?? [];
    if (bookmarks.isNotEmpty) {
      activities.add({
        'type': 'bookmarks',
        'icon': Icons.bookmark,
        'title': 'Saved ${bookmarks.length} posts',
        'description': 'Building your collection',
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
      });
    }
    
    // Add saved artworks
    final savedArtworks = activityData['savedArtworks'] ?? [];
    if (savedArtworks.isNotEmpty) {
      activities.add({
        'type': 'saved',
        'icon': Icons.collections,
        'title': 'Saved ${savedArtworks.length} artworks',
        'description': 'Curating your favorites',
        'timestamp': DateTime.now().subtract(const Duration(hours: 3)),
      });
    }
    
    // Sort by timestamp (newest first)
    activities.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
    
    return activities;
  }

  /// Build activity item widget from real data
  Widget _buildRealActivityItem(Map<String, dynamic> activity) {
    final icon = activity['icon'] as IconData;
    final title = activity['title'] as String;
    final description = activity['description'] as String;
    final timestamp = activity['timestamp'] as DateTime;
    final timeAgo = _getTimeAgo(timestamp);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              color: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
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
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeAgo,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
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

  Widget _buildAchievementsSection() {
    return Consumer2<TaskProvider, ConfigProvider>(
      builder: (context, taskProvider, configProvider, child) {
        if (!configProvider.useMockData) {
          // Show real achievement data when mock data is disabled
          final achievements = taskProvider.achievementProgress;
          
          // Get the first 6 achievements to display
          final displayAchievements = allAchievements.take(6).toList();
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Achievements',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AchievementsPage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF9C27B0), width: 1),
                      ),
                      child: Text(
                        'View All',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF9C27B0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              achievements.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.emoji_events,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No Achievements Yet',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Start exploring to unlock achievements',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: displayAchievements.map((achievement) {
                      final progress = achievements.firstWhere(
                        (p) => p.achievementId == achievement.id,
                        orElse: () => AchievementProgress(
                          achievementId: achievement.id,
                          currentProgress: 0,
                          isCompleted: false,
                        ),
                      );
                      return _buildAchievementBadge(
                        achievement.title,
                        achievement.icon,
                        progress.isCompleted,
                      );
                    }).toList(),
                  ),
            ],
          );
        } else {
          // Show mock data when mock data is enabled
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Achievements',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AchievementsPage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF9C27B0), width: 1),
                      ),
                      child: Text(
                        'View All',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF9C27B0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildAchievementBadge('First AR Explorer', Icons.visibility, true),
                  _buildAchievementBadge('Gallery Explorer', Icons.explore, true),
                  _buildAchievementBadge('Art Curator', Icons.folder_special, true),
                  _buildAchievementBadge('Social Butterfly', Icons.share, false),
                  _buildAchievementBadge('AR Master', Icons.auto_awesome, false),
                  _buildAchievementBadge('Art Influencer', Icons.trending_up, false),
                ],
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildAchievementBadge(String title, IconData icon, bool unlocked) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked 
            ? themeProvider.accentColor.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked 
              ? themeProvider.accentColor.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: unlocked 
                ? themeProvider.accentColor
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: unlocked
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceStats() {
    return Consumer<ConfigProvider>(
      builder: (context, config, child) {
        if (!config.useMockData) {
          // Real stats would come from providers/API
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Performance',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                Icon(
                  Icons.analytics,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Stats Available',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Performance stats will appear as you interact with the platform',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Mock data for demo purposes
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildPerformanceCard('Total Views', '2,456', Icons.visibility, '+12%'),
        const SizedBox(height: 12),
        _buildPerformanceCard('Likes Received', '389', Icons.favorite, '+8%'),
        const SizedBox(height: 12),
        _buildPerformanceCard('KUB8 Earned', '156.7', Icons.currency_bitcoin, '+23%'),
        const SizedBox(height: 12),
        _buildPerformanceCard('Discoveries', '42', Icons.location_on, '+15%'),
      ],
    );
      },
    );
  }

  Widget _buildPerformanceCard(String title, String value, IconData icon, String change) {
    Widget cardContent = Container(
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
              color: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Provider.of<ThemeProvider>(context).accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              change,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );

    // Make KUB8-related cards tappable to open wallet
    if (title.contains('KUB8')) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Wallet()),
          );
        },
        child: cardContent,
      );
    }
    
    return cardContent;
  }

  // Navigation and interaction methods
  void _shareProfile() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Share Profile',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(Icons.link, 'Copy Link'),
                _buildShareOption(Icons.qr_code, 'QR Code'),
                _buildShareOption(Icons.share, 'Social'),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(IconData icon, String label) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              color: Provider.of<ThemeProvider>(context).accentColor,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _editProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileEditScreen(),
      ),
    );
    
    // Reload profile if changes were saved
    if (result == true && mounted) {
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final web3Provider = Provider.of<Web3Provider>(context, listen: false);
      if (web3Provider.isConnected && web3Provider.walletAddress.isNotEmpty) {
        await profileProvider.loadProfile(web3Provider.walletAddress);
      }
    }
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionItem(Icons.bookmark, 'Saved Items', () {
              Navigator.pop(context);
              _navigateToSavedItems();
            }),
            _buildOptionItem(Icons.history, 'View History', () {
              Navigator.pop(context);
              _navigateToViewHistory();
            }),
            _buildOptionItem(Icons.security, 'Privacy Settings', () {
              Navigator.pop(context);
              _navigateToPrivacySettings();
            }),
            _buildOptionItem(Icons.help, 'Help & Support', () {
              Navigator.pop(context);
              _navigateToHelpSupport();
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(
        icon,
        color: Provider.of<ThemeProvider>(context).accentColor,
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      onTap: onTap,
    );
  }

  // Navigation methods for menu options
  void _navigateToSavedItems() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SavedItemsScreen()),
    );
  }

  void _navigateToViewHistory() {
    // Show history dialog for now
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'View History',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Your viewing history will appear here',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  void _navigateToPrivacySettings() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Privacy Settings',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPrivacyOptionStateful('Private Profile', _privateProfile, (val) {
                setDialogState(() => _privateProfile = val);
                setState(() {});
                _savePrivacySettings();
              }),
              _buildPrivacyOptionStateful('Show Activity Status', _showActivityStatus, (val) {
                setDialogState(() => _showActivityStatus = val);
                setState(() {});
                _savePrivacySettings();
              }),
              _buildPrivacyOptionStateful('Show Collection', _showCollection, (val) {
                setDialogState(() => _showCollection = val);
                setState(() {});
                _savePrivacySettings();
              }),
              _buildPrivacyOptionStateful('Allow Messages', _allowMessages, (val) {
                setDialogState(() => _allowMessages = val);
                setState(() {});
                _savePrivacySettings();
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: GoogleFonts.inter()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyOptionStateful(String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
          ),
        ],
      ),
    );
  }
  
  Future<void> _savePrivacySettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('private_profile', _privateProfile);
    await prefs.setBool('show_activity_status', _showActivityStatus);
    await prefs.setBool('show_collection', _showCollection);
    await prefs.setBool('allow_messages', _allowMessages);
  }
  
  Future<void> _loadPrivacySettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _privateProfile = prefs.getBool('private_profile') ?? false;
      _showActivityStatus = prefs.getBool('show_activity_status') ?? true;
      _showCollection = prefs.getBool('show_collection') ?? true;
      _allowMessages = prefs.getBool('allow_messages') ?? true;
    });
  }

  void _navigateToHelpSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Help & Support',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpOption(Icons.description, 'Documentation'),
            _buildHelpOption(Icons.chat_bubble_outline, 'Contact Support'),
            _buildHelpOption(Icons.bug_report, 'Report a Bug'),
            _buildHelpOption(Icons.info_outline, 'About art.kubus'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpOption(IconData icon, String title) {
    return ListTile(
      leading: Icon(
        icon,
        color: Provider.of<ThemeProvider>(context, listen: false).accentColor,
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(fontSize: 14),
      ),
      dense: true,
      onTap: () {
        Navigator.pop(context);
        _handleHelpOptionTap(title);
      },
    );
  }
  
  void _handleHelpOptionTap(String option) {
    switch (option) {
      case 'Documentation':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening documentation...'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Visit',
              onPressed: () {
                // In production, open https://docs.art-kubus.io
              },
            ),
          ),
        );
        break;
      case 'Contact Support':
        _showContactSupportDialog();
        break;
      case 'Report a Bug':
        _showReportBugDialog();
        break;
      case 'About art.kubus':
        _showAboutDialog();
        break;
    }
  }
  
  void _showContactSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Contact Support',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get help from our support team:',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildContactOption(Icons.email, 'Email', 'support@art-kubus.io'),
            const SizedBox(height: 12),
            _buildContactOption(Icons.chat, 'Live Chat', 'Available Mon-Fri 9AM-5PM'),
            const SizedBox(height: 12),
            _buildContactOption(Icons.public, 'Website', 'https://art.kubus.site'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContactOption(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Provider.of<ThemeProvider>(context).accentColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  void _showReportBugDialog() {
    final bugController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Report a Bug',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Describe the issue you encountered:',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bugController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter bug description...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bug report submitted. Thank you!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Text('Submit', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
  
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'About art.kubus',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.palette,
                size: 40,
                color: Provider.of<ThemeProvider>(context).accentColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'art.kubus',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Version 1.0.0+1',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'AR art platform connecting artists and institutions through blockchain technology.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '© 2024 Kubus Project',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }
}

// Edit Profile Screen
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController(text: 'Anonymous Artist');
  final _bioController = TextEditingController(
    text: 'Digital artist exploring the intersection of AR, blockchain, and creativity.',
  );
  final _websiteController = TextEditingController();
  final _twitterController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Provider.of<ThemeProvider>(context).accentColor,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile picture
            Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Provider.of<ThemeProvider>(context).accentColor,
                        Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 60),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Provider.of<ThemeProvider>(context).accentColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Form fields
            _buildTextField('Display Name', _nameController),
            const SizedBox(height: 16),
            _buildTextField('Bio', _bioController, maxLines: 3),
            const SizedBox(height: 16),
            _buildTextField('Website', _websiteController),
            const SizedBox(height: 16),
            _buildTextField('Twitter', _twitterController, prefix: '@'),
            const SizedBox(height: 32),
            
            // Account settings
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Settings',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSettingItem('Private Profile', false),
                  _buildSettingItem('Show Activity', true),
                  _buildSettingItem('Email Notifications', true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, String? prefix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixText: prefix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Provider.of<ThemeProvider>(context).accentColor),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.primaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(String title, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Switch(
            value: value,
            onChanged: (newValue) {},
            activeColor: Provider.of<ThemeProvider>(context).accentColor,
          ),
        ],
      ),
    );
  }
}

