import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/themeprovider.dart';
import '../providers/web3provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/artwork_provider.dart';
import '../providers/config_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/recent_activity_provider.dart';
import '../providers/profile_provider.dart';
import '../models/recent_activity.dart';
import 'web3/dao/governance_hub.dart';
import 'web3/artist/artist_studio.dart';
import 'web3/institution/institution_hub.dart';
import 'web3/marketplace/marketplace.dart';
import 'web3/wallet/wallet_home.dart';
import 'web3/wallet/connectwallet_screen.dart';
import 'web3/onboarding/web3_onboarding.dart' as web3;
import '../widgets/app_logo.dart';
import '../widgets/topbar_icon.dart';
import '../utils/activity_navigation.dart';

import '../widgets/enhanced_stats_chart.dart';
import '../widgets/empty_state_card.dart';
import 'activity/advanced_analytics_screen.dart';
import '../utils/app_animations.dart';
import '../widgets/staggered_fade_slide.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppAnimationTheme.defaults.long,
      vsync: this,
    );
    _animationController.forward();

    // Initialize navigation provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigationProvider =
          Provider.of<NavigationProvider>(context, listen: false);
      navigationProvider.initialize();

      // Add some default visits for demo purposes if no visits exist
      if (navigationProvider.visitCounts.isEmpty) {
        navigationProvider.trackScreenVisit('map');
        navigationProvider.trackScreenVisit('ar');
        navigationProvider.trackScreenVisit('community');
        navigationProvider.trackScreenVisit(
            'map'); // Visit map twice to show it as most visited
      }

      final recentActivityProvider =
          Provider.of<RecentActivityProvider>(context, listen: false);
      recentActivityProvider.initialize();
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
    final animationTheme = context.animationTheme;
    final fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: animationTheme.fadeCurve,
    );
    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: animationTheme.defaultCurve,
    ));

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(
                position: slideAnimation,
                child: CustomScrollView(
                  slivers: [
                    _buildAppBar(),
                    SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = constraints.crossAxisExtent;
                        final isSmallScreen = screenWidth < 375;
                        final padding = isSmallScreen ? 16.0 : 24.0;
                        final spacing = isSmallScreen ? 16.0 : 24.0;

                        return SliverPadding(
                          padding: EdgeInsets.all(padding),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate(
                              _buildAnimatedSections(spacing),
                            ),
                          ),
                        );
                      },
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

  List<Widget> _buildAnimatedSections(double spacing) {
    final sections = <Widget>[];
    var animationIndex = 0;

    Widget animated(Widget child) {
      final indexForWidget = animationIndex++;
      return StaggeredFadeSlide(
        animation: _animationController,
        position: indexForWidget,
        child: child,
      );
    }

    sections.add(animated(_buildWelcomeSection()));
    sections.add(SizedBox(height: spacing));
    sections.add(animated(_buildQuickActions()));
    sections.add(SizedBox(height: spacing));
    sections.add(animated(_buildStatsCards()));
    sections.add(SizedBox(height: spacing));
    sections.add(animated(_buildWeb3Section()));
    sections.add(SizedBox(height: spacing));
    sections.add(animated(_buildRecentActivity()));
    sections.add(SizedBox(height: spacing));
    sections.add(animated(_buildFeaturedArtworks()));

    return sections;
  }

  Widget _buildAppBar() {
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
            child: Row(
              children: [
                // Logo and app name
                AppLogo(
                  width: isSmallScreen ? 36 : 40,
                  height: isSmallScreen ? 36 : 40,
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
                          web3Provider
                              .formatAddress(web3Provider.walletAddress),
                          style: GoogleFonts.robotoMono(
                            fontSize: isSmallScreen ? 10 : 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
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
                Consumer<NotificationProvider>(
                  builder: (context, np, _) => TopBarIcon(
                    tooltip: 'Notifications',
                    icon: Icon(
                      Icons.notifications_outlined,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: isSmallScreen ? 22 : 26,
                    ),
                    onPressed: () {
                      _showNotificationsBottomSheet(context);
                    },
                    badgeCount: np.unreadCount,
                    badgeColor: Provider.of<ThemeProvider>(context).accentColor,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final web3Provider = Provider.of<Web3Provider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 375;
        final padding = isSmallScreen ? 16.0 : 24.0;
        final titleSize = isSmallScreen ? 20.0 : 24.0;
        final descriptionSize = isSmallScreen ? 12.0 : 14.0;
        final iconSize = isSmallScreen ? 50.0 : 60.0;

        return Container(
          padding: EdgeInsets.all(padding),
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
                          profileProvider.currentUser?.displayName != null
                              ? 'Welcome back, ${profileProvider.currentUser!.displayName}!'
                              : 'Welcome Back!',
                          style: GoogleFonts.inter(
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        Text(
                          'Discover amazing AR art and connect with creators',
                          style: GoogleFonts.inter(
                            fontSize: descriptionSize,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.view_in_ar,
                      color: Colors.white,
                      size: isSmallScreen ? 25 : 30,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 16 : 20),
              if (web3Provider.isConnected) ...[
                Consumer<WalletProvider>(
                  builder: (context, walletProvider, child) {
                    // Get KUB8 balance
                    final kub8Balance = walletProvider.tokens
                            .where(
                                (token) => token.symbol.toUpperCase() == 'KUB8')
                            .isNotEmpty
                        ? walletProvider.tokens
                            .where(
                                (token) => token.symbol.toUpperCase() == 'KUB8')
                            .first
                            .balance
                        : 0.0;

                    // Get SOL balance
                    final solBalance = walletProvider.tokens
                            .where(
                                (token) => token.symbol.toUpperCase() == 'SOL')
                            .isNotEmpty
                        ? walletProvider.tokens
                            .where(
                                (token) => token.symbol.toUpperCase() == 'SOL')
                            .first
                            .balance
                        : 0.0;

                    return Row(
                      children: [
                        _buildBalanceChip(
                            'KUB8', kub8Balance.toStringAsFixed(2)),
                        const SizedBox(width: 12),
                        _buildBalanceChip('SOL', solBalance.toStringAsFixed(3)),
                      ],
                    );
                  },
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: () => _showWalletOnboarding(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: themeProvider.accentColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    Icons.explore,
                    size: isSmallScreen ? 16 : 18,
                  ),
                  label: Text(
                    'Explore Web3',
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 12 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceChip(String symbol, String amount) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WalletHome()),
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
                    color: Provider.of<ThemeProvider>(context).accentColor,
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
                  'Recently Used',
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
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
                                onTap: () => navigationProvider
                                    .navigateToScreen(context, screen['key']),
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
                                onTap: () => navigationProvider
                                    .navigateToScreen(context, screen['key']),
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
                            onTap: () => navigationProvider.navigateToScreen(
                                context, screen['key']),
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
        onTap: onTap ??
            () {
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
    return Consumer<ConfigProvider>(
      builder: (context, configProvider, child) {
        if (!configProvider.useMockData) {
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
              const EmptyStateCard(
                  icon: Icons.analytics,
                  title: 'No Stats Available',
                  description:
                      'Stats will appear as you interact with the platform',
                ),
            ],
          );
        }

        final stats = [
          ('Artworks', '42', Icons.image),
          ('Followers', '1.2k', Icons.people),
          ('Views', '8.5k', Icons.visibility),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 375;
            final isVerySmallScreen = constraints.maxWidth < 320;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Stats',
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12 : 16),
                if (isVerySmallScreen)
                  // Stack vertically on very small screens - show full details
                  Column(
                    children: stats.asMap().entries.map((entry) {
                      final index = entry.key;
                      final stat = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                            bottom: index < stats.length - 1 ? 8 : 0),
                        child: _buildStatCard(stat.$1, stat.$2, stat.$3,
                            showIconOnly: false, isVerticalLayout: true),
                      );
                    }).toList(),
                  )
                else
                  // Horizontal layout for other screen sizes - show icons only
                  Row(
                    children: stats.map((stat) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _buildStatCard(stat.$1, stat.$2, stat.$3,
                              showIconOnly: true, isVerticalLayout: false),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      {bool showIconOnly = false, bool isVerticalLayout = false}) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 375;

        return GestureDetector(
          onTap: () => _showStatsDialog(title, icon),
          child: Container(
            width: isVerticalLayout ? double.infinity : null,
            padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
              boxShadow: [
                BoxShadow(
                  color: themeProvider.accentColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: showIconOnly
                ? Column(
                    children: [
                      Icon(
                        icon,
                        color: themeProvider.accentColor,
                        size: 28, // Keep original icon size
                      ),
                      if (isSmallScreen) ...[
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
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  )
                : isVerticalLayout
                    ? Row(
                        children: [
                          Icon(
                            icon,
                            color: themeProvider.accentColor,
                            size: 20, // Keep original icon size
                          ),
                          SizedBox(width: isSmallScreen ? 8 : 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  value,
                                  style: GoogleFonts.inter(
                                    fontSize: isSmallScreen ? 10 : 12,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  title,
                                  style: GoogleFonts.inter(
                                    fontSize: isSmallScreen ? 7 : 8,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Icon(
                            icon,
                            color: themeProvider.accentColor,
                            size: 24, // Keep original icon size
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
          ),
        );
      },
    );
  }

  Widget _buildWeb3Section() {
    return Consumer<Web3Provider>(
      builder: (context, web3Provider, child) {
        // Show as connected if wallet is connected (mock or real)
        final bool isEffectivelyConnected = web3Provider.isConnected;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Community and Art',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (!isEffectivelyConnected)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock, size: 12, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          'Account Required',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
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
                    isEffectivelyConnected
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const GovernanceHub()),
                            )
                        : () => _showWalletOnboarding(context),
                    isLocked: !isEffectivelyConnected,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildWeb3Card(
                    'Artist',
                    'Studio',
                    Icons.palette,
                    const Color(0xFFFF9A8B),
                    isEffectivelyConnected
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const ArtistStudio()),
                            )
                        : () => _showWalletOnboarding(context),
                    isLocked: !isEffectivelyConnected,
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
                    isEffectivelyConnected
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const InstitutionHub()),
                            )
                        : () => _showWalletOnboarding(context),
                    isLocked: !isEffectivelyConnected,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildWeb3Card(
                    'Marketplace',
                    'NFTs',
                    Icons.store,
                    const Color(0xFFFF6B6B),
                    isEffectivelyConnected
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const Marketplace()),
                            )
                        : () => _showWalletOnboarding(context),
                    isLocked: !isEffectivelyConnected,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildWeb3Card(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap,
      {bool isLocked = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120, // Fixed height for consistent layout
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: isLocked ? 0.05 : 0.1),
              color.withValues(alpha: isLocked ? 0.02 : 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: isLocked ? 0.1 : 0.3),
          ),
        ),
        child: Stack(
          children: [
            // Use Center widget for perfect centering when unlocked
            if (!isLocked)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            // Locked state - positioned at top
            if (isLocked)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          color: color.withValues(alpha: 0.5),
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            // Lock indicator - positioned absolutely
            if (isLocked)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.lock,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final accentColor = Provider.of<ThemeProvider>(context).accentColor;
    return Consumer<RecentActivityProvider>(
      builder: (context, activityProvider, child) {
        final activities =
            activityProvider.activities.take(5).toList(growable: false);
        final isLoading = activityProvider.isLoading && activities.isEmpty;
        final error = activityProvider.error;

        Widget content;
        if (isLoading) {
          content = _buildActivityLoadingState(accentColor);
        } else if (error != null && activities.isEmpty) {
          content = _buildActivityErrorState(
              error, () => activityProvider.refresh(force: true));
        } else if (activities.isEmpty) {
          content = _buildActivityEmptyState();
        } else {
          content = ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            itemBuilder: (context, index) => RecentActivityTile(
              activity: activities[index],
              accentColor: accentColor,
              onTap: () => ActivityNavigation.open(context, activities[index]),
            ),
          );
        }

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
                  onPressed: _showFullActivity,
                  child: Text(
                    'View All',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            content,
          ],
        );
      },
    );
  }

  Widget _buildActivityLoadingState(Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
        ),
      ),
    );
  }

  Widget _buildActivityEmptyState() {
    return EmptyStateCard(
          icon: Icons.timeline,
          title: 'No Recent Activity',
          description:
              'Your recent interactions will appear here as soon as something happens.',
        );
  }

  Widget _buildActivityErrorState(String error, VoidCallback onRetry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmptyStateCard(
          icon: Icons.wifi_off,
          title: 'Unable to load activity',
          description: error,
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildFeaturedArtworks() {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, child) {
        final featuredArtworks = artworkProvider.artworks.take(5).toList();

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
              child: featuredArtworks.isEmpty
                  ?  EmptyStateCard(
                          icon: Icons.image_not_supported,
                          title: 'No featured artworks',
                          description:
                              'Explore the gallery to discover featured AR artworks.',
                          showAction: true,
                          actionLabel: 'Explore',
                          onAction: _navigateToGallery,
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: featuredArtworks.length,
                      itemBuilder: (context, index) {
                        return _buildArtworkCard(
                            featuredArtworks[index], index);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildArtworkCard(dynamic artwork, int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return GestureDetector(
      onTap: () {
        _showArtworkDetail(artwork);
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
                      themeProvider.accentColor.withValues(alpha: 0.3),
                      themeProvider.accentColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
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
                    artwork?.title ?? 'AR Art #${index + 1}',
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
                    'by ${artwork?.artist ?? '@artist'}',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Navigation and interaction methods
  Future<void> _showNotificationsBottomSheet(BuildContext context) async {
    final config = context.read<ConfigProvider>();
    if (config.useMockData) {
      _showMockNotificationsBottomSheet(context);
      return;
    }

    final activityProvider = context.read<RecentActivityProvider>();
    final notificationProvider = context.read<NotificationProvider>();

    if (activityProvider.initialized) {
      await activityProvider.refresh(force: true);
    } else {
      await activityProvider.initialize(force: true);
    }

    if (!context.mounted) return;

    await notificationProvider.markViewed();

    if (!context.mounted) return;

    final accentColor = context.read<ThemeProvider>().accentColor;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return ChangeNotifierProvider.value(
          value: activityProvider,
          child: _NotificationsBottomSheet(
            accentColor: accentColor,
            showUnreadOnly: true,
            onActivitySelected: (activity) async {
              Navigator.of(sheetContext).pop();
              await ActivityNavigation.open(context, activity);
            },
          ),
        );
      },
    );

    activityProvider.markAllReadLocally();
  }

  void _showMockNotificationsBottomSheet(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

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
                        color: themeProvider.accentColor,
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
      (
        'New artwork discovered nearby',
        'Check out "Digital Dreams" by @artist_maya',
        Icons.location_on,
        '5 min ago'
      ),
      (
        'KUB8 rewards earned',
        'You earned 15 KUB8 tokens for discovering 3 artworks',
        Icons.account_balance_wallet,
        '1 hour ago'
      ),
      (
        'Friend request',
        '@collector_sam wants to connect with you',
        Icons.person_add,
        '2 hours ago'
      ),
      (
        'Artwork featured',
        'Your AR sculpture was featured in trending',
        Icons.star,
        '4 hours ago'
      ),
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
              color: Provider.of<ThemeProvider>(context)
                  .accentColor
                  .withValues(alpha: 0.1),
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.$4,
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
        ],
      ),
    );
  }

  void _handleQuickAction(String action) {
    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);

    switch (action) {
      case 'Create AR':
        navigationProvider.trackScreenVisit('ar');
        DefaultTabController.of(context).animateTo(1);
        break;
      case 'Explore Map':
        navigationProvider.trackScreenVisit('map');
        // Switch to map tab in main app
        DefaultTabController.of(context).animateTo(0);
        break;
      case 'Connect':
        navigationProvider.trackScreenVisit('community');
        // Switch to community tab in main app
        DefaultTabController.of(context).animateTo(3);
        break;
      case 'Profile':
        navigationProvider.trackScreenVisit('profile');
        // Switch to profile tab in main app
        DefaultTabController.of(context).animateTo(4);
        break;
      default:
        // Handle any other actions through navigation provider
        final screenKey = _getScreenKeyFromName(action);
        if (screenKey != null) {
          navigationProvider.navigateToScreen(context, screenKey);
        }
    }
  }

  String? _getScreenKeyFromName(String name) {
    final entry = NavigationProvider.screenDefinitions.entries
        .where((entry) => entry.value['name'] == name)
        .firstOrNull;
    return entry?.key;
  }

  // Show wallet onboarding for first-time users
  void _showWalletOnboarding(BuildContext context) {
    debugPrint('DEBUG: Wallet onboarding triggered from home screen');

    // Navigate directly to comprehensive Web3 onboarding
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => web3.Web3OnboardingScreen(
          featureName: 'Web3 Features',
          pages: _getWeb3OnboardingPages(),
          onComplete: () {
            Navigator.of(context).pop();
            // Navigate to wallet creation/connection screen
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

  void _showFullActivity() {
    final activityProvider =
        Provider.of<RecentActivityProvider>(context, listen: false);
    if (!activityProvider.initialized) {
      activityProvider.initialize(force: true);
    } else {
      activityProvider.refresh(force: true);
    }
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
                            Provider.of<ThemeProvider>(context)
                                .accentColor
                                .withValues(alpha: 0.3),
                            Provider.of<ThemeProvider>(context)
                                .accentColor
                                .withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(Icons.view_in_ar,
                            color: Colors.white, size: 60),
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
                                Provider.of<ThemeProvider>(context)
                                    .accentColor
                                    .withValues(alpha: 0.3),
                                Provider.of<ThemeProvider>(context)
                                    .accentColor
                                    .withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.person,
                              color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'by @artist_name',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
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
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Provider.of<ThemeProvider>(context)
                                      .accentColor,
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
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            foregroundColor:
                                Theme.of(context).colorScheme.onSurface,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 16),
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
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),
          Text(
            value,
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
              Icon(icon,
                  color: Provider.of<ThemeProvider>(dialogContext).accentColor),
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
                    labels: const [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun'
                    ],
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
                    builder: (context) =>
                        AdvancedAnalyticsScreen(statType: statType),
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
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            )),
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
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _NotificationsBottomSheet extends StatelessWidget {
  const _NotificationsBottomSheet({
    required this.accentColor,
    required this.onActivitySelected,
    this.showUnreadOnly = false,
  });

  final Color accentColor;
  final Future<void> Function(RecentActivity activity) onActivitySelected;
  final bool showUnreadOnly;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider =
        Provider.of<RecentActivityProvider>(context, listen: false);

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () => provider.refresh(force: true),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<RecentActivityProvider>(
              builder: (context, activityProvider, _) {
                final activities = showUnreadOnly
                    ? activityProvider.unreadActivities
                    : activityProvider.activities;
                final isLoading =
                    activityProvider.isLoading && activities.isEmpty;
                final hasError =
                    activityProvider.error != null && activities.isEmpty;

                if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                return RefreshIndicator(
                  onRefresh: () => activityProvider.refresh(force: true),
                  child: activities.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 40),
                          children: [
                            EmptyStateCard(
                              icon: hasError
                                  ? Icons.error_outline
                                  : Icons.notifications_off_outlined,
                              title: hasError
                                  ? 'Unable to load notifications'
                                  : 'No Notifications',
                              description: hasError
                                  ? (activityProvider.error ??
                                      'Something went wrong')
                                  : 'You\'re all caught up!',
                              showAction: hasError,
                              actionLabel: hasError ? 'Retry' : null,
                              onAction: hasError
                                  ? () => activityProvider.refresh(force: true)
                                  : null,
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          itemCount: activities.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final activity = activities[index];
                            return RecentActivityTile(
                              activity: activity,
                              accentColor: accentColor,
                              onTap: () => onActivitySelected(activity),
                              margin: EdgeInsets.zero,
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<RecentActivityProvider>(context, listen: false);
      if (!provider.initialized) {
        provider.initialize(force: true);
      } else {
        provider.refresh(force: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Provider.of<ThemeProvider>(context).accentColor;
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
      body: Consumer<RecentActivityProvider>(
        builder: (context, activityProvider, child) {
          final activities = activityProvider.activities;

          if (activityProvider.isLoading && activities.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (activityProvider.error != null && activities.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => activityProvider.refresh(force: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  EmptyStateCard(
                    icon: Icons.wifi_off,
                    title: 'Unable to load activity',
                    description: activityProvider.error!,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => activityProvider.refresh(force: true),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (activities.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => activityProvider.refresh(force: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  EmptyStateCard(
                    icon: Icons.timeline,
                    title: 'No Recent Activity',
                    description:
                        'Your interactions will show up here as soon as they happen.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => activityProvider.refresh(force: true),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              itemCount: activities.length,
              itemBuilder: (context, index) => RecentActivityTile(
                activity: activities[index],
                accentColor: accentColor,
                margin: EdgeInsets.only(
                    bottom: index == activities.length - 1 ? 0 : 16),
                onTap: () =>
                    ActivityNavigation.open(context, activities[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class RecentActivityTile extends StatelessWidget {
  final RecentActivity activity;
  final Color accentColor;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const RecentActivityTile({
    super.key,
    required this.activity,
    required this.accentColor,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = activity.description.trim().isNotEmpty
        ? activity.description
        : (activity.metadata['message']?.toString() ?? '');
    final isUnread = !activity.isRead;

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isUnread
                  ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.7)
                  : theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isUnread
                    ? accentColor.withValues(alpha: 0.4)
                    : theme.colorScheme.outline,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    activityCategoryIcon(activity.category),
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              activity.title,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: accentColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        formatActivityTime(activity.timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
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
    );
  }
}

IconData activityCategoryIcon(ActivityCategory category) {
  switch (category) {
    case ActivityCategory.like:
      return Icons.favorite;
    case ActivityCategory.comment:
      return Icons.chat_bubble_outline;
    case ActivityCategory.discovery:
      return Icons.location_on;
    case ActivityCategory.reward:
      return Icons.account_balance_wallet;
    case ActivityCategory.follow:
      return Icons.person_add;
    case ActivityCategory.share:
      return Icons.share;
    case ActivityCategory.mention:
      return Icons.alternate_email;
    case ActivityCategory.nft:
      return Icons.blur_on;
    case ActivityCategory.ar:
      return Icons.view_in_ar;
    case ActivityCategory.save:
      return Icons.bookmark;
    case ActivityCategory.achievement:
      return Icons.emoji_events;
    case ActivityCategory.system:
      return Icons.notifications;
  }
}

String formatActivityTime(DateTime timestamp) {
  final now = DateTime.now();
  final diff = now.difference(timestamp);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
}
