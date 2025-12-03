import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/web3provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/recent_activity_provider.dart';
import '../../providers/community_hub_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/config_provider.dart';
import '../../models/artwork.dart';
import '../../models/recent_activity.dart';
import '../../models/wallet.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/artist_badge.dart';
import '../../widgets/institution_badge.dart';
import '../../utils/app_animations.dart';
import '../../utils/activity_navigation.dart';
import 'components/desktop_widgets.dart';
import '../web3/dao/governance_hub.dart';
import '../web3/artist/artist_studio.dart';
import '../web3/institution/institution_hub.dart';
import '../web3/marketplace/marketplace.dart';
import '../web3/wallet/connectwallet_screen.dart';
import '../web3/onboarding/web3_onboarding.dart' as web3;
import '../art/art_detail_screen.dart';
import 'community/desktop_user_profile_screen.dart';
import 'desktop_settings_screen.dart';
import 'desktop_shell.dart';
import '../activity/advanced_analytics_screen.dart';
import '../home_screen.dart' show ActivityScreen;

/// Desktop home screen with spacious layout and proper grid systems
/// Inspired by Twitter/X feed presentation and Google Maps panels
class DesktopHomeScreen extends StatefulWidget {
  const DesktopHomeScreen({super.key});

  @override
  State<DesktopHomeScreen> createState() => _DesktopHomeScreenState();
}

class _DesktopHomeScreenState extends State<DesktopHomeScreen> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late ScrollController _scrollController;
  bool _showFloatingHeader = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _animationController.forward();

    // Initialize providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final recentActivity = Provider.of<RecentActivityProvider>(context, listen: false);
      if (!recentActivity.initialized) {
        recentActivity.initialize();
      }
      final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
      navigationProvider.initialize();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShowHeader = _scrollController.offset > 100;
    if (shouldShowHeader != _showFloatingHeader) {
      setState(() => _showFloatingHeader = shouldShowHeader);
    }
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
              // Main content area
              Expanded(
                flex: isLarge ? 3 : 2,
                child: _buildMainContent(animationTheme),
              ),
              
              // Right sidebar (activity feed, trending, etc.)
              if (isMedium || isLarge)
                Container(
                  width: isLarge ? 380 : 320,
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
          
          // Floating header on scroll
          if (_showFloatingHeader)
            _buildFloatingHeader(themeProvider, animationTheme),
        ],
      ),
    );
  }

  Widget _buildMainContent(AppAnimationTheme animationTheme) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _animationController,
            curve: animationTheme.fadeCurve,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _animationController,
              curve: animationTheme.defaultCurve,
            )),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: _buildHeader(),
                ),
                
                // Welcome card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                    child: _buildWelcomeCard(),
                  ),
                ),
                
                // Stats grid
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                    child: _buildStatsGrid(),
                  ),
                ),
                
                // Quick actions
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                    child: _buildQuickActions(),
                  ),
                ),
                
                // Featured artworks
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                    child: _buildFeaturedArtworks(),
                  ),
                ),
                
                // Web3 section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                    child: _buildWeb3Section(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final user = profileProvider.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isArtist = user?.isArtist ?? false;
    final isInstitution = user?.isInstitution ?? false;

    return Container(
      padding: const EdgeInsets.all(32),
      child: Row(
        children: [
          // Left side - greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      const AppLogo(width: 44, height: 44),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                fit: FlexFit.loose,
                                child: Text(
                                  user?.displayName ?? 'Welcome to art.kubus',
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                              if (isArtist) ...[
                                const SizedBox(width: 8),
                                const ArtistBadge(),
                              ],
                              if (isInstitution) ...[
                                const SizedBox(width: 8),
                                const InstitutionBadge(),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Right side - search and actions
          Row(
            children: [
              SizedBox(
                width: 280,
                child: DesktopSearchBar(
                  hintText: 'Search artworks, artists...',
                  onSubmitted: (value) {
                    // Handle search
                  },
                ),
              ),
              const SizedBox(width: 16),
              _buildNotificationButton(themeProvider),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationButton(ThemeProvider themeProvider) {
    return Consumer<NotificationProvider>(
      builder: (context, np, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _showNotificationsPanel(themeProvider, np);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Stack(
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  if (np.unreadCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: themeProvider.accentColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          np.unreadCount > 9 ? '9+' : np.unreadCount.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeCard() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final web3Provider = Provider.of<Web3Provider>(context);

    return DesktopCard(
      padding: EdgeInsets.zero,
      showBorder: false,
      child: Container(
        padding: const EdgeInsets.all(32),
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
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover Art Around You',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Explore immersive augmented reality artworks, connect with creators, '
                    'and earn KUB8 tokens for discovering art.',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (web3Provider.isConnected)
                    _buildWalletBalances()
                  else
                    ElevatedButton.icon(
                      onPressed: _showWalletOnboarding,
                      icon: const Icon(Icons.account_balance_wallet),
                      label: const Text('Connect Wallet'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: themeProvider.accentColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 48),
            // Decorative 3D cube/AR icon
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.view_in_ar,
                size: 80,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletBalances() {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        final kub8 = walletProvider.tokens
            .where((t) => t.symbol.toUpperCase() == 'KUB8')
            .firstOrNull;
        final sol = walletProvider.tokens
            .where((t) => t.symbol.toUpperCase() == 'SOL')
            .firstOrNull;

        return Row(
          children: [
            _buildBalanceChip('KUB8', kub8?.balance.toStringAsFixed(2) ?? '0.00'),
            const SizedBox(width: 16),
            _buildBalanceChip('SOL', sol?.balance.toStringAsFixed(3) ?? '0.000'),
          ],
        );
      },
    );
  }

  Widget _buildBalanceChip(String symbol, String amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                symbol == 'KUB8' ? 'K' : 'S',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Provider.of<ThemeProvider>(context).accentColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$amount $symbol',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final artworkProvider = Provider.of<ArtworkProvider>(context);
    final web3Provider = Provider.of<Web3Provider>(context);
    final walletProvider = Provider.of<WalletProvider>(context);
    final activityProvider = Provider.of<RecentActivityProvider>(context);

    final discoveredCount =
        artworkProvider.artworks.where((a) => a.isDiscovered).length;
    final arSessions = activityProvider.activities
        .where((a) => a.category == ActivityCategory.ar)
        .length;
    final nftCount = walletProvider.tokens
        .where((t) => t.type == TokenType.nft)
        .length;
    final kub8Token = walletProvider.tokens
        .where((t) => t.symbol.toUpperCase() == 'KUB8')
        .cast<Token?>()
        .firstWhere((_) => true, orElse: () => null);
    final kub8Earned = kub8Token != null
        ? kub8Token.formattedBalance
        : walletProvider.achievementTokenTotal.toStringAsFixed(2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DesktopSectionHeader(
          title: 'Your Activity',
          subtitle: 'Track your progress and engagement',
          icon: Icons.analytics_outlined,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 48) / 4;
            
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: cardWidth,
                  height: 160,
                  child: DesktopStatCard(
                    label: 'Artworks Discovered',
                    value: discoveredCount.toString(),
                    icon: Icons.explore,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  height: 160,
                  child: DesktopStatCard(
                    label: 'AR Sessions',
                    value: arSessions.toString(),
                    icon: Icons.view_in_ar,
                    color: const Color(0xFF4ECDC4),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  height: 160,
                  child: DesktopStatCard(
                    label: 'NFTs Collected',
                    value: web3Provider.isConnected ? nftCount.toString() : '0',
                    icon: Icons.collections,
                    color: const Color(0xFFFF6B6B),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  height: 160,
                  child: DesktopStatCard(
                    label: 'KUB8 Earned',
                    value: kub8Earned,
                    icon: Icons.monetization_on,
                    color: const Color(0xFFFFD700),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final quickScreens = navigationProvider.getQuickActionScreens(maxItems: 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: 'Quick Actions',
          subtitle: quickScreens.isEmpty 
              ? 'Start exploring to see your recent screens here'
              : 'Based on your recent visits',
          icon: Icons.flash_on,
        ),
        const SizedBox(height: 16),
        if (quickScreens.isEmpty)
          DesktopCard(
            child: Row(
              children: [
                Icon(
                  Icons.touch_app,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  size: 40,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No recent visits yet',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Navigate to different screens and they\'ll appear here for quick access. '
                        'Cards disappear after 24 hours of inactivity.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: quickScreens.map((screen) {
                final color = (screen['color'] as Color?) ?? themeProvider.accentColor;
                final icon = screen['icon'] as IconData? ?? Icons.arrow_forward;
                final key = screen['key']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildQuickActionCard(
                    screen['name']?.toString() ?? 'Open',
                    icon,
                    color,
                    () => _handleQuickAction(key),
                    visitCount: screen['visitCount'] as int? ?? 0,
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _handleQuickAction(String screenKey) {
    if (screenKey.isEmpty) return;
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);

    switch (screenKey) {
      case 'map':
        _openShellTab(1);
        return;
      case 'community':
        _openShellTab(2);
        return;
      case 'marketplace':
        _openShellTab(3);
        return;
      case 'wallet':
        _openShellTab(4);
        return;
      case 'profile':
        _pushScreen(const DesktopSettingsScreen(), screenKey);
        return;
      case 'analytics':
        _pushScreen(const AdvancedAnalyticsScreen(statType: ''), screenKey);
        return;
      case 'dao_hub':
        _pushScreen(const GovernanceHub(), screenKey);
        return;
      case 'studio':
        _pushScreen(const ArtistStudio(), screenKey);
        return;
      case 'institution_hub':
        _pushScreen(const InstitutionHub(), screenKey);
        return;
      case 'achievements':
        // Reuse onboarding to surface achievements context
        final screen = web3.Web3OnboardingScreen(
          featureName: 'Achievements',
          pages: _getWeb3OnboardingPages(),
          onComplete: () => Navigator.of(context).pop(),
        );
        _pushScreen(screen, screenKey);
        return;
      case 'ar':
        _showARInfo();
        return;
      default:
        navigationProvider.navigateToScreen(context, screenKey);
        return;
    }
  }

  void _pushScreen(Widget screen, String screenKey) {
    Provider.of<NavigationProvider>(context, listen: false).trackScreenVisit(screenKey);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openShellTab(int index) {
    Provider.of<NavigationProvider>(context, listen: false).trackScreenVisit(_indexToKey(index));
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DesktopShell(initialIndex: index),
    ));
  }

  String _indexToKey(int index) {
    switch (index) {
      case 1:
        return 'map';
      case 2:
        return 'community';
      case 3:
        return 'marketplace';
      case 4:
        return 'wallet';
      default:
        return 'home';
    }
  }

  void _navigateToTab(int tabIndex) {
    switch (tabIndex) {
      case 2:
        _handleQuickAction('community');
        break;
      case 3:
        _handleQuickAction('marketplace');
        break;
      default:
        _handleQuickAction('map');
    }
  }

  void _openFullActivity() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ActivityScreen()),
    );
  }

  void _showARInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.view_in_ar, color: const Color(0xFF4ECDC4)),
            const SizedBox(width: 12),
            Text(
              'AR Experience',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AR features require a mobile device with ARCore (Android) or ARKit (iOS) support.',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Download the art.kubus mobile app to experience AR artworks in the real world!',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    int visitCount = 0,
  }) {
    return DesktopCard(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              if (visitCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      visitCount.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedArtworks() {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, _) {
        final artworks = artworkProvider.artworks.take(6).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DesktopSectionHeader(
              title: 'Featured Artworks',
              subtitle: 'Discover trending AR art',
              icon: Icons.auto_awesome,
              action: TextButton.icon(
                onPressed: () => _openShellTab(3),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('View All'),
              ),
            ),
            const SizedBox(height: 16),
            if (artworks.isEmpty)
              const EmptyStateCard(
                icon: Icons.image_not_supported,
                title: 'No artworks available',
                description: 'Check back later for featured artworks',
              )
            else
              SizedBox(
                height: 260,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: artworks.length,
                  itemBuilder: (context, index) {
                    return _buildArtworkCard(artworks[index], index);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildArtworkCard(Artwork artwork, int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return DesktopCard(
      width: 200,
      margin: EdgeInsets.only(right: index < 5 ? 16 : 0),
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ArtDetailScreen(artworkId: artwork.id),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  themeProvider.accentColor.withValues(alpha: 0.3),
                  themeProvider.accentColor.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(
                    Icons.view_in_ar,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                if (artwork.arEnabled)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: themeProvider.accentColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.view_in_ar, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text('AR', style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          )),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artwork.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${artwork.artist}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      artwork.likesCount.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.visibility,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      artwork.viewsCount.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
  }

  Widget _buildWeb3Section() {
    final web3Provider = Provider.of<Web3Provider>(context);
    final isConnected = web3Provider.isConnected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: 'Web3 Hub',
          subtitle: 'Access decentralized features',
          icon: Icons.hub,
          action: isConnected ? null : TextButton.icon(
            onPressed: _showWalletOnboarding,
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Connect Wallet'),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 48) / 4;
            
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _buildWeb3Card(
                    'DAO Governance',
                    'Vote on proposals',
                    Icons.how_to_vote,
                    const Color(0xFF4ECDC4),
                    isConnected,
                    () => _navigateToWeb3Screen(const GovernanceHub(), isConnected),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildWeb3Card(
                    'Artist Studio',
                    'Create & mint',
                    Icons.palette,
                    const Color(0xFFFF9A8B),
                    isConnected,
                    () => _navigateToWeb3Screen(const ArtistStudio(), isConnected),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildWeb3Card(
                    'Institution Hub',
                    'Gallery tools',
                    Icons.museum,
                    const Color(0xFF667eea),
                    isConnected,
                    () => _navigateToWeb3Screen(const InstitutionHub(), isConnected),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildWeb3Card(
                    'NFT Marketplace',
                    'Buy & sell',
                    Icons.store,
                    const Color(0xFFFF6B6B),
                    isConnected,
                    () => _navigateToWeb3Screen(const Marketplace(), isConnected),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _navigateToWeb3Screen(Widget screen, bool isConnected) {
    if (isConnected) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => screen),
      );
    } else {
      _showWalletOnboarding();
    }
  }

  void _showWalletOnboarding() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => web3.Web3OnboardingScreen(
          featureName: 'Web3 Features',
          pages: _getWeb3OnboardingPages(),
          onComplete: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ConnectWallet()),
            );
          },
        ),
      ),
    );
  }

  List<web3.OnboardingPage> _getWeb3OnboardingPages() {
    return [
      const web3.OnboardingPage(
        title: 'Welcome to Web3',
        description:
            'Connect your wallet to unlock decentralized features powered by blockchain technology.',
        icon: Icons.account_balance_wallet,
        gradientColors: [
          Colors.white,
          Color(0xFF3F51B5),
        ],
        features: [
          'Secure wallet-based authentication',
          'True ownership of digital assets',
          'Decentralized transactions',
          'Cross-platform compatibility',
        ],
      ),
      const web3.OnboardingPage(
        title: 'NFT Marketplace',
        description:
            'Buy, sell, and trade unique digital artworks as NFTs with full ownership rights.',
        icon: Icons.store,
        gradientColors: [
          Color(0xFFFF6B6B),
          Color(0xFFE91E63),
        ],
        features: [
          'Browse trending digital artworks',
          'Purchase NFTs with SOL tokens',
          'List your own creations for sale',
          'Track marketplace analytics',
          'Discover featured collections',
        ],
      ),
      const web3.OnboardingPage(
        title: 'Artist Studio',
        description:
            'Create, mint, and manage your digital artworks with professional tools.',
        icon: Icons.palette,
        gradientColors: [
          Color(0xFFFF9A8B),
          Color(0xFFFF7043),
        ],
        features: [
          'Upload and mint AR artworks as NFTs',
          'Set pricing and royalties',
          'Track creation analytics',
          'Manage your digital portfolio',
          'Collaborate with other artists',
        ],
      ),
      const web3.OnboardingPage(
        title: 'DAO Governance',
        description:
            'Participate in community decisions and help shape the future of the platform.',
        icon: Icons.how_to_vote,
        gradientColors: [
          Color(0xFF4ECDC4),
          Color(0xFF26A69A),
        ],
        features: [
          'Vote on platform proposals',
          'Submit improvement suggestions',
          'Earn governance tokens',
          'Access exclusive DAO benefits',
          'Shape community guidelines',
        ],
      ),
      const web3.OnboardingPage(
        title: 'Institution Hub',
        description:
            'Connect with galleries, museums, and cultural institutions in the Web3 space.',
        icon: Icons.museum,
        gradientColors: [
          Color(0xFF667eea),
          Color(0xFF764ba2),
        ],
        features: [
          'Partner with verified institutions',
          'Access exclusive exhibitions',
          'Institutional-grade security',
          'Professional networking tools',
          'Curated collection management',
        ],
      ),
      const web3.OnboardingPage(
        title: 'KUB8 Token Economy',
        description:
            'Earn and spend KUB8 tokens throughout the ecosystem for various activities.',
        icon: Icons.monetization_on,
        gradientColors: [
          Color(0xFFFFD700),
          Color(0xFFFF8C00),
        ],
        features: [
          'Earn tokens for discoveries',
          'Reward system for creators',
          'Stake tokens for benefits',
          'Pay for premium features',
          'Trade on decentralized exchanges',
        ],
      ),
    ];
  }

  Widget _buildWeb3Card(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool isUnlocked,
    VoidCallback onTap,
  ) {
    return DesktopCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isUnlocked ? 0.15 : 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color.withValues(alpha: isUnlocked ? 1.0 : 0.4),
                  size: 24,
                ),
              ),
              if (!isUnlocked)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lock,
                    size: 14,
                    color: Colors.orange,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: isUnlocked ? 1.0 : 0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: isUnlocked ? 0.6 : 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightSidebar(ThemeProvider themeProvider) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Activity',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          
          // Recent activity from provider
          _buildRecentActivitySection(themeProvider),
          const SizedBox(height: 24),
          
          // Trending Art Section
          _buildTrendingArtSection(themeProvider),
          const SizedBox(height: 24),
          
          // Top Creators Section
          _buildTopCreatorsSection(themeProvider),
          const SizedBox(height: 24),
          
          // Platform Stats Section
          _buildPlatformStatsSection(themeProvider),
        ],
      ),
    );
  }

  Widget _buildTrendingArtSection(ThemeProvider themeProvider) {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, _) {
        final trendingArtworks = artworkProvider.artworks
            .where((a) => a.arEnabled)
            .take(4)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Trending Art',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _navigateToTab(3), // Marketplace
                  child: Text(
                    'See All',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: themeProvider.accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (trendingArtworks.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.view_in_ar,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Trending artworks will appear here',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...trendingArtworks.map((artwork) => _buildTrendingArtItem(artwork, themeProvider)),
          ],
        );
      },
    );
  }

  Widget _buildTrendingArtItem(Artwork artwork, ThemeProvider themeProvider) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ArtDetailScreen(artworkId: artwork.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 8),
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
                  gradient: LinearGradient(
                    colors: [
                      themeProvider.accentColor.withValues(alpha: 0.3),
                      themeProvider.accentColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.view_in_ar, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artwork.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'by ${artwork.artist}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(Icons.favorite, size: 14, color: Colors.red.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text(
                        artwork.likesCount.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  if (artwork.arEnabled)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: themeProvider.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'AR',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.accentColor,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopCreatorsSection(ThemeProvider themeProvider) {
    return Consumer<CommunityHubProvider>(
      builder: (context, communityProvider, _) {
        // Get unique creators from recent posts
        final posts = communityProvider.artFeedPosts.take(20).toList();
        final creatorsMap = <String, Map<String, dynamic>>{};
        
        for (final post in posts) {
          if (post.category == 'artist' || post.artwork != null) {
            final key = post.authorWallet ?? post.authorId;
            if (!creatorsMap.containsKey(key)) {
              creatorsMap[key] = {
                'id': post.authorId,
                'wallet': post.authorWallet,
                'name': post.authorName,
                'avatar': post.authorAvatar,
                'username': post.authorUsername,
                'postCount': 1,
              };
            } else {
              creatorsMap[key]!['postCount'] = (creatorsMap[key]!['postCount'] as int) + 1;
            }
          }
        }

        final creators = creatorsMap.values.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Top Creators',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _navigateToTab(2), // Community
                  child: Text(
                    'Explore',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: themeProvider.accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (creators.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.people,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Top creators will appear here',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...creators.map((creator) => _buildCreatorItem(creator, themeProvider)),
          ],
        );
      },
    );
  }

  Widget _buildCreatorItem(Map<String, dynamic> creator, ThemeProvider themeProvider) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final walletOrId = creator['wallet'] ?? creator['id'];
          if (walletOrId != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(userId: walletOrId),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              AvatarWidget(
                avatarUrl: creator['avatar'],
                wallet: creator['wallet'] ?? creator['id'],
                radius: 20,
                allowFabricatedFallback: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      creator['name'] ?? 'Creator',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (creator['username'] != null)
                      Text(
                        '@${creator['username']}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: themeProvider.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${creator['postCount']} posts',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.accentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformStatsSection(ThemeProvider themeProvider) {
    final artworkProvider = Provider.of<ArtworkProvider>(context);
    final communityProvider = Provider.of<CommunityHubProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.analytics,
              color: themeProvider.accentColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Platform Stats',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildPlatformStatRow(
                'Total Artworks',
                artworkProvider.artworks.length.toString(),
                Icons.view_in_ar,
                themeProvider.accentColor,
              ),
              const Divider(height: 24),
              _buildPlatformStatRow(
                'AR Enabled',
                artworkProvider.artworks.where((a) => a.arEnabled).length.toString(),
                Icons.visibility,
                const Color(0xFF4ECDC4),
              ),
              const Divider(height: 24),
              _buildPlatformStatRow(
                'Community Posts',
                communityProvider.artFeedPosts.length.toString(),
                Icons.forum,
                const Color(0xFFFF9A8B),
              ),
              const Divider(height: 24),
              _buildPlatformStatRow(
                'Active Groups',
                communityProvider.groups.length.toString(),
                Icons.groups,
                const Color(0xFF667eea),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection(ThemeProvider themeProvider) {
    return Consumer<RecentActivityProvider>(
      builder: (context, activityProvider, _) {
        final activities = activityProvider.activities.take(5).toList();
        final isLoading = activityProvider.isLoading && activities.isEmpty;
        final error = activityProvider.error;

        Widget content;
        if (isLoading) {
          content = _buildRecentActivityLoading(themeProvider);
        } else if (error != null && activities.isEmpty) {
          content = _buildRecentActivityError(
            themeProvider,
            error,
            () => activityProvider.refresh(force: true),
          );
        } else if (activities.isEmpty) {
          content = _buildRecentActivityEmpty(themeProvider);
        } else {
          content = Column(
            children: activities
                .map((activity) => _buildActivityItem(activity, themeProvider))
                .toList(),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                TextButton(
                  onPressed: _openFullActivity,
                  child: Text(
                    'View All',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: themeProvider.accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            content,
          ],
        );
      },
    );
  }

  Widget _buildRecentActivityLoading(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(themeProvider.accentColor),
        ),
      ),
    );
  }

  Widget _buildRecentActivityError(
    ThemeProvider themeProvider,
    String error,
    VoidCallback onRetry,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unable to load activity',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: themeProvider.accentColor,
              side: BorderSide(color: themeProvider.accentColor.withValues(alpha: 0.5)),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityEmpty(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'No recent activity',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem(RecentActivity activity, ThemeProvider themeProvider) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ActivityNavigation.open(context, activity),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: themeProvider.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getActivityIcon(activity.category),
                  color: themeProvider.accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      activity.description,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
      ),
    );
  }

  IconData _getActivityIcon(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.discovery:
        return Icons.explore;
      case ActivityCategory.like:
        return Icons.favorite;
      case ActivityCategory.comment:
        return Icons.chat_bubble;
      case ActivityCategory.follow:
        return Icons.person_add;
      case ActivityCategory.nft:
        return Icons.collections;
      case ActivityCategory.ar:
        return Icons.view_in_ar;
      case ActivityCategory.reward:
        return Icons.stars;
      case ActivityCategory.share:
        return Icons.share;
      case ActivityCategory.mention:
        return Icons.alternate_email;
      case ActivityCategory.achievement:
        return Icons.emoji_events;
      case ActivityCategory.save:
        return Icons.bookmark;
      case ActivityCategory.system:
        return Icons.info;
    }
  }

  Widget _buildFloatingHeader(ThemeProvider themeProvider, AppAnimationTheme animationTheme) {
    return AnimatedPositioned(
      duration: animationTheme.short,
      curve: animationTheme.defaultCurve,
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const AppLogo(width: 32, height: 32),
            const SizedBox(width: 12),
            Text(
              'art.kubus',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 240,
              height: 40,
              child: DesktopSearchBar(
                hintText: 'Search...',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  Future<void> _showNotificationsPanel(
    ThemeProvider themeProvider,
    NotificationProvider np,
  ) async {
    final configProvider = context.read<ConfigProvider>();
    if (configProvider.useMockData) {
      await _showMockNotificationsDialog(themeProvider);
      return;
    }

    final activityProvider = context.read<RecentActivityProvider>();
    if (activityProvider.initialized) {
      await activityProvider.refresh(force: true);
    } else {
      await activityProvider.initialize(force: true);
    }

    if (!mounted) return;

    await np.markViewed();
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (dialogContext) => Align(
        alignment: Alignment.topRight,
        child: Container(
          width: 400,
          height: MediaQuery.of(dialogContext).size.height * 0.7,
          margin: const EdgeInsets.only(top: 80, right: 32),
          decoration: BoxDecoration(
            color: Theme.of(dialogContext).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(dialogContext).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(dialogContext).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    if (np.unreadCount > 0)
                      TextButton(
                        onPressed: () => np.markViewed(),
                        child: Text(
                          'Mark all read',
                          style: GoogleFonts.inter(
                            color: themeProvider.accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(dialogContext).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: np.unreadCount == 0
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: Theme.of(dialogContext).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No notifications yet',
                              style: GoogleFonts.inter(
                                color: Theme.of(dialogContext).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You\'ll see activity here as you interact',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Theme.of(dialogContext).colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Consumer<RecentActivityProvider>(
                        builder: (dialogInnerContext, activityProvider, _) {
                          final activities = activityProvider.activities
                              .where((a) => !a.isRead)
                              .take(10)
                              .toList();
                          if (activities.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: themeProvider.accentColor.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${np.unreadCount}',
                                        style: GoogleFonts.inter(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: themeProvider.accentColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'unread notifications',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Theme.of(dialogInnerContext).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: activities.length,
                            itemBuilder: (itemContext, index) {
                              final activity = activities[index];
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(dialogContext);
                                    ActivityNavigation.open(context, activity);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(dialogInnerContext).colorScheme.primaryContainer.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: themeProvider.accentColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            _getActivityIcon(activity.category),
                                            color: themeProvider.accentColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                activity.title,
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(dialogInnerContext).colorScheme.onSurface,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                activity.description,
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: Theme.of(dialogInnerContext).colorScheme.onSurface.withValues(alpha: 0.6),
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
                                ),
                              );
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

    if (!mounted) return;
    activityProvider.markAllReadLocally();
  }

  Future<void> _showMockNotificationsDialog(ThemeProvider themeProvider) async {
    final mockNotifications = [
      {
        'title': 'New artwork discovered nearby',
        'description': 'Check out "Digital Dreams" by @artist_maya',
        'icon': Icons.location_on,
        'time': '5 min ago',
      },
      {
        'title': 'KUB8 rewards earned',
        'description': 'You earned 15 KUB8 tokens for discovering 3 artworks',
        'icon': Icons.account_balance_wallet,
        'time': '1 hour ago',
      },
      {
        'title': 'Friend request',
        'description': '@collector_sam wants to connect with you',
        'icon': Icons.person_add,
        'time': '2 hours ago',
      },
      {
        'title': 'Artwork featured',
        'description': 'Your AR sculpture was featured in trending',
        'icon': Icons.star,
        'time': '4 hours ago',
      },
    ];

    await showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (dialogContext) => Align(
        alignment: Alignment.topRight,
        child: Container(
          width: 380,
          height: MediaQuery.of(dialogContext).size.height * 0.6,
          margin: const EdgeInsets.only(top: 80, right: 32),
          decoration: BoxDecoration(
            color: Theme.of(dialogContext).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(dialogContext).colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(dialogContext).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(dialogContext).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: mockNotifications.length,
                  itemBuilder: (context, index) => _buildMockNotificationItem(
                    themeProvider,
                    mockNotifications[index],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMockNotificationItem(
    ThemeProvider themeProvider,
    Map<String, dynamic> notification,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: themeProvider.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              notification['icon'] as IconData,
              color: themeProvider.accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification['title'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification['description'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification['time'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
