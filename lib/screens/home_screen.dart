import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/themeprovider.dart';
import '../providers/web3provider.dart';
import '../providers/navigation_provider.dart';
import '../web3/dao/governance_hub.dart';
import '../web3/artist/artist_studio.dart';
import '../web3/institution/institution_hub.dart';
import '../web3/marketplace/marketplace.dart';
import '../web3/wallet.dart';
import '../widgets/enhanced_stats_chart.dart';
import 'advanced_analytics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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
    
    // Initialize navigation provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NavigationProvider>(context, listen: false).initialize();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
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
                child: CustomScrollView(
                  slivers: [
                    _buildAppBar(),
                    SliverPadding(
                      padding: const EdgeInsets.all(24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildWelcomeSection(),
                          const SizedBox(height: 24),
                          _buildQuickActions(),
                          const SizedBox(height: 24),
                          _buildStatsCards(),
                          const SizedBox(height: 24),
                          _buildWeb3Section(),
                          const SizedBox(height: 24),
                          _buildRecentActivity(),
                          const SizedBox(height: 24),
                          _buildFeaturedArtworks(),
                        ]),
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

  Widget _buildAppBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final web3Provider = Provider.of<Web3Provider>(context);
    
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      expandedHeight: 120,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 375;
          
          return Container(
            padding: EdgeInsets.fromLTRB(
              isSmallScreen ? 16 : 24, 
              16, 
              isSmallScreen ? 16 : 24, 
              16,
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Logo and app name
                  Container(
                    width: isSmallScreen ? 36 : 40,
                    height: isSmallScreen ? 36 : 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          themeProvider.accentColor,
                          themeProvider.accentColor.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: themeProvider.accentColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: isSmallScreen ? 18 : 20,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'art.kubus',
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (web3Provider.isConnected) ...[
                          Text(
                            web3Provider.formatAddress(web3Provider.walletAddress),
                            style: GoogleFonts.robotoMono(
                              fontSize: isSmallScreen ? 10 : 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.only(top: isSmallScreen ? 2 : 4),
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 6 : 8, 
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'DEVNET',
                              style: GoogleFonts.inter(
                                fontSize: isSmallScreen ? 8 : 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Notification bell
                  Container(
                    width: isSmallScreen ? 36 : 40,
                    height: isSmallScreen ? 36 : 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.notifications_outlined,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: isSmallScreen ? 18 : 20,
                        ),
                        onPressed: () {
                          _showNotificationsBottomSheet(context);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final web3Provider = Provider.of<Web3Provider>(context);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            themeProvider.accentColor,
            themeProvider.accentColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: themeProvider.accentColor.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back!',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Discover amazing AR art and connect with creators',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.view_in_ar,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (web3Provider.isConnected) ...[
            Row(
              children: [
                _buildBalanceChip('KUB8', web3Provider.kub8Balance.toStringAsFixed(2)),
                const SizedBox(width: 12),
                _buildBalanceChip('SOL', web3Provider.solBalance.toStringAsFixed(3)),
              ],
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () => web3Provider.connectWallet(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: themeProvider.accentColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Connect Wallet',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceChip(String symbol, String amount) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const Wallet()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  symbol == 'KUB8' ? 'K' : 'S',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6C63FF),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$amount $symbol',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 375;
        final navigationProvider = Provider.of<NavigationProvider>(context);
        final frequentScreens = navigationProvider.getFrequentScreensData();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quick Actions',
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Most Visited',
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            isSmallScreen 
              ? Column(
                  children: [
                    Row(
                      children: frequentScreens.take(2).map((screen) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildActionCard(
                              screen['name'], 
                              screen['icon'], 
                              screen['color'],
                              isSmallScreen,
                              onTap: () => navigationProvider.navigateToScreen(context, screen['key']),
                              visitCount: screen['visitCount'],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: frequentScreens.skip(2).map((screen) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildActionCard(
                              screen['name'], 
                              screen['icon'], 
                              screen['color'],
                              isSmallScreen,
                              onTap: () => navigationProvider.navigateToScreen(context, screen['key']),
                              visitCount: screen['visitCount'],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                )
              : Row(
                  children: frequentScreens.map((screen) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildActionCard(
                          screen['name'], 
                          screen['icon'], 
                          screen['color'],
                          isSmallScreen,
                          onTap: () => navigationProvider.navigateToScreen(context, screen['key']),
                          visitCount: screen['visitCount'],
                        ),
                      ),
                    );
                  }).toList(),
                ),
          ],
        );
      },
    );
  }

  Widget _buildActionCard(
    String title, 
    IconData icon, 
    Color color, 
    bool isSmallScreen, {
    VoidCallback? onTap,
    int visitCount = 0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {
          _handleQuickAction(title);
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withValues(alpha: 0.1),
        highlightColor: color.withValues(alpha: 0.05),
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: isSmallScreen ? 32 : 40,
                    height: isSmallScreen ? 32 : 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: isSmallScreen ? 16 : 20,
                    ),
                  ),
                  if (visitCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          visitCount.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 6 : 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 10 : 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final stats = [
      ('Artworks', '42', Icons.image),
      ('Followers', '1.2k', Icons.people),
      ('Views', '8.5k', Icons.visibility),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Stats',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: stats.map((stat) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildStatCard(stat.$1, stat.$2, stat.$3),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return GestureDetector(
      onTap: () => _showStatsDialog(title, icon),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
          ),
          boxShadow: [
            BoxShadow(
              color: themeProvider.accentColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: themeProvider.accentColor,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeb3Section() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Web3 Features',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildWeb3Card(
                'DAO',
                'Governance',
                Icons.how_to_vote,
                const Color(0xFF4ECDC4),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GovernanceHub()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildWeb3Card(
                'Artist',
                'Studio',
                Icons.palette,
                const Color(0xFFFF9A8B),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ArtistStudio()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildWeb3Card(
                'Institution',
                'Hub',
                Icons.museum,
                const Color(0xFF667eea),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InstitutionHub()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildWeb3Card(
                'Marketplace',
                'NFTs',
                Icons.store,
                const Color(0xFFFF6B6B),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Marketplace()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeb3Card(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            TextButton(
              onPressed: () {
                _showFullActivity();
              },
              child: Text(
                'View All',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Provider.of<ThemeProvider>(context).accentColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          itemBuilder: (context, index) {
            return _buildActivityItem(index);
          },
        ),
      ],
    );
  }

  Widget _buildActivityItem(int index) {
    final activities = [
      ('New follower: @artist_123', Icons.person_add, '2 hours ago'),
      ('Artwork liked by @collector_456', Icons.favorite, '5 hours ago'),
      ('KUB8 tokens received', Icons.account_balance_wallet, '1 day ago'),
    ];

    final activity = activities[index % activities.length];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
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
              activity.$2,
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
                  activity.$1,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  activity.$3,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedArtworks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Featured Artworks',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            TextButton(
              onPressed: () {
                _navigateToGallery();
              },
              child: Text(
                'Explore',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Provider.of<ThemeProvider>(context).accentColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            itemBuilder: (context, index) {
              return _buildArtworkCard(index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArtworkCard(int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return GestureDetector(
      onTap: () {
        _showArtworkDetail(index);
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
          ),
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
                child: const Center(
                  child: Icon(
                    Icons.view_in_ar,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AR Art #${index + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by @artist',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Navigation and interaction methods
  void _showNotificationsBottomSheet(BuildContext context) {
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
                    'Notifications',
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
      ('New artwork discovered nearby', 'Check out "Digital Dreams" by @artist_maya', Icons.location_on, '5 min ago'),
      ('KUB8 rewards earned', 'You earned 15 KUB8 tokens for discovering 3 artworks', Icons.account_balance_wallet, '1 hour ago'),
      ('Friend request', '@collector_sam wants to connect with you', Icons.person_add, '2 hours ago'),
      ('Artwork featured', 'Your AR sculpture was featured in trending', Icons.star, '4 hours ago'),
    ];
    
    final notification = notifications[index % notifications.length];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
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

  void _handleQuickAction(String action) {
    switch (action) {
      case 'Create AR':
        Navigator.pushNamed(context, '/ar');
        break;
      case 'Explore Map':
        // Switch to map tab in main app
        DefaultTabController.of(context).animateTo(0);
        break;
      case 'Community':
        // Switch to community tab in main app
        DefaultTabController.of(context).animateTo(3);
        break;
      case 'Profile':
        // Switch to profile tab in main app
        DefaultTabController.of(context).animateTo(4);
        break;
    }
  }

  void _showMarketBottomSheet() {
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
              child: Row(
                children: [
                  Text(
                    'Art Marketplace',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Text(
                      'DEVNET',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(
                      tabs: const [
                        Tab(text: 'Trending'),
                        Tab(text: 'New'),
                        Tab(text: 'Collections'),
                      ],
                      labelColor: Provider.of<ThemeProvider>(context).accentColor,
                      unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      indicatorColor: Provider.of<ThemeProvider>(context).accentColor,
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildMarketGrid('trending'),
                          _buildMarketGrid('new'),
                          _buildCollectionsGrid(),
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
    );
  }

  Widget _buildMarketGrid(String type) {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => _buildMarketItem(index, type),
    );
  }

  Widget _buildMarketItem(int index, String type) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final prices = ['2.5 SOL', '1.8 SOL', '3.2 SOL', '0.9 SOL', '4.1 SOL', '2.0 SOL'];
    
    return Container(
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
              child: const Center(
                child: Icon(Icons.view_in_ar, color: Colors.white, size: 40),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$type Art #${index + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'by @artist${index + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      prices[index],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.accentColor,
                      ),
                    ),
                    Icon(
                      Icons.favorite_border,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsGrid() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: 4,
      itemBuilder: (context, index) => _buildCollectionItem(index),
    );
  }

  Widget _buildCollectionItem(int index) {
    final collections = [
      'Digital Dreams',
      'Urban AR',
      'Nature Spirits',
      'Tech Fusion'
    ];
    
    final themeProvider = Provider.of<ThemeProvider>(context);
    
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
                  '${(index + 1) * 12} items • Floor: ${(index + 1) * 0.5} SOL',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ],
      ),
    );
  }

  void _showFullActivity() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ActivityScreen(),
      ),
    );
  }

  void _navigateToGallery() {
    // Navigate to main app with explore tab
    Navigator.pushReplacementNamed(context, '/main');
  }

  void _showArtworkDetail(int index) {
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Artwork preview
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.3),
                            Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(Icons.view_in_ar, color: Colors.white, size: 60),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Artwork info
                    Text(
                      'AR Art #${index + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.3),
                                Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'by @artist_name',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Description
                    Text(
                      'Description',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'An immersive AR artwork that transforms your surroundings into a digital canvas. Experience the fusion of reality and imagination.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Stats
                    Row(
                      children: [
                        _buildStatChip(Icons.favorite, '234'),
                        const SizedBox(width: 12),
                        _buildStatChip(Icons.visibility, '1.2k'),
                        const SizedBox(width: 12),
                        _buildStatChip(Icons.share, '89'),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/ar');
                            },
                            icon: const Icon(Icons.view_in_ar),
                            label: Text(
                              'View in AR',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            // Add to favorites
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Icon(Icons.favorite_border),
                        ),
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

  Widget _buildStatChip(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  void _showStatsDialog(String statType, IconData icon) {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(dialogContext).colorScheme.surface,
          title: Row(
            children: [
              Icon(icon, color: Provider.of<ThemeProvider>(dialogContext).accentColor),
              const SizedBox(width: 12),
              Text('$statType Details'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  EnhancedBarChart(
                    title: '$statType Trend (Last 7 days)',
                    data: _getStatsData(statType),
                    accentColor: const Color(0xFF4A90E2),
                    labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
                  ),
                  const SizedBox(height: 20),
                  _buildStatsTimeline(statType),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                // Navigate to advanced analytics screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdvancedAnalyticsScreen(statType: statType),
                  ),
                );
              },
              child: const Text('View Advanced'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTimeline(String statType) {
    final milestones = _getStatsMilestones(statType);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Milestones',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        ...milestones.map((milestone) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF4A90E2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  milestone,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  List<double> _getStatsData(String statType) {
    switch (statType) {
      case 'Artworks':
        return [35.0, 37.0, 39.0, 40.0, 41.0, 42.0, 42.0];
      case 'Followers':
        return [980.0, 1050.0, 1120.0, 1150.0, 1180.0, 1200.0, 1200.0];
      case 'Views':
        return [7200.0, 7800.0, 8100.0, 8300.0, 8450.0, 8500.0, 8500.0];
      default:
        return [10.0, 20.0, 30.0, 25.0, 35.0, 40.0, 45.0];
    }
  }

  List<String> _getStatsMilestones(String statType) {
    switch (statType) {
      case 'Artworks':
        return [
          'Uploaded "Digital Dreams" - 2 days ago',
          'Reached 40 artworks milestone - 3 days ago',
          'Featured artwork in gallery - 1 week ago',
        ];
      case 'Followers':
        return [
          'Gained 50 new followers this week',
          'Reached 1K followers - 2 days ago',
          'Featured in trending artists - 1 week ago',
        ];
      case 'Views':
        return [
          'Daily views record: 850 - Yesterday',
          'Reached 8K total views - 2 days ago',
          'Viral artwork: 1.2K views - 1 week ago',
        ];
      default:
        return ['No milestones yet'];
    }
  }
}

// New Activity Screen
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Activity',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: 20,
        itemBuilder: (context, index) {
          final activities = [
            ('Artwork discovered', 'You found "Quantum Sculpture" near Central Park', Icons.location_on, '2 min ago'),
            ('KUB8 earned', 'Received 10 KUB8 tokens for artwork discovery', Icons.account_balance_wallet, '15 min ago'),
            ('New follower', '@digital_artist started following you', Icons.person_add, '1 hour ago'),
            ('Artwork liked', 'Someone liked your "AR Portal" creation', Icons.favorite, '2 hours ago'),
            ('Friend activity', '@maya_3d discovered a new artwork', Icons.people, '3 hours ago'),
            ('Achievement unlocked', 'Explorer Badge - 10 artworks discovered', Icons.star, '1 day ago'),
          ];
          
          final activity = activities[index % activities.length];
          
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
                    color: Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    activity.$3,
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
                        activity.$1,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity.$2,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity.$4,
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
        },
      ),
    );
  }
}
