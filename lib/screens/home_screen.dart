import 'package:flutter/foundation.dart';
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
import '../models/artwork.dart';
import '../models/recent_activity.dart';
import '../models/user_persona.dart';
import 'web3/dao/governance_hub.dart';
import 'web3/artist/artist_studio.dart';
import 'web3/institution/institution_hub.dart';
import 'web3/marketplace/marketplace.dart';
import 'web3/wallet/wallet_home.dart';
import 'web3/wallet/connectwallet_screen.dart';
import 'onboarding/web3/web3_onboarding.dart' as web3;
import 'onboarding/web3/onboarding_data.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../widgets/app_logo.dart';
import '../widgets/topbar_icon.dart';
import '../utils/activity_navigation.dart';
import '../widgets/artist_badge.dart';
import '../widgets/institution_badge.dart';
import '../widgets/artwork_creator_byline.dart';
import '../widgets/inline_loading.dart';
import '../widgets/enhanced_stats_chart.dart';
import '../widgets/empty_state_card.dart';
import 'activity/advanced_analytics_screen.dart';
import '../utils/app_animations.dart';
import '../utils/app_color_utils.dart';
import '../utils/kubus_color_roles.dart';
import '../utils/artwork_media_resolver.dart';
import '../widgets/staggered_fade_slide.dart';
import 'art/art_detail_screen.dart';

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
    final l10n = AppLocalizations.of(context)!;

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
                    tooltip: l10n.commonNotifications,
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
    final l10n = AppLocalizations.of(context)!;
    final greeting = _getGreeting(l10n);
    final isArtist = profileProvider.currentUser?.isArtist ?? false;
    final isInstitution = profileProvider.currentUser?.isInstitution ?? false;

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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                '$greeting ${profileProvider.currentUser?.displayName ?? l10n.homeDefaultDisplayName}',
                                style: GoogleFonts.inter(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isArtist) ...[
                              const SizedBox(width: 8),
                              ArtistBadge(
                                fontSize: isSmallScreen ? 9 : 10,
                                useOnPrimary: true,
                              ),
                            ],
                            if (isInstitution) ...[
                              const SizedBox(width: 8),
                              InstitutionBadge(
                                fontSize: isSmallScreen ? 9 : 10,
                                useOnPrimary: true,
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        Text(
                          l10n.homeWelcomeSubtitle,
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
                    foregroundColor: AppColorUtils.tealAccent,
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
                    l10n.homeExploreWeb3Button,
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
        final navigationProvider = Provider.of<NavigationProvider>(context);
        final profileProvider = context.watch<ProfileProvider>();
        final l10n = AppLocalizations.of(context)!;
        final frequentScreens =
            navigationProvider.getQuickActionScreens(maxItems: 12);
        final persona = profileProvider.userPersona;
        final suggestedKeys = _suggestedQuickActionKeys(persona)
            .where(
                (key) => NavigationProvider.screenDefinitions.containsKey(key))
            .toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.homeQuickActionsTitle,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (frequentScreens.isNotEmpty)
                  Text(
                    l10n.homeRecentlyUsedLabel,
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
            const SizedBox(height: 12),
            if (frequentScreens.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            l10n.homeQuickActionsEmptyDescription,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (suggestedKeys.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: suggestedKeys.map((key) {
                          final def =
                              NavigationProvider.screenDefinitions[key]!;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _buildActionCard(
                              def.name,
                              def.icon,
                              AppColorUtils.featureColor(
                                key,
                                Theme.of(context).colorScheme,
                                roles: KubusColorRoles.of(context),
                              ),
                              false,
                              onTap: () => navigationProvider.navigateToScreen(
                                  context, key),
                              visitCount: 0,
                            ),
                          );
                        }).toList(growable: false),
                      ),
                    ),
                  ],
                ],
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: frequentScreens.map((screen) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildActionCard(
                        screen.name,
                        screen.icon,
                        AppColorUtils.featureColor(
                          screen.key,
                          Theme.of(context).colorScheme,
                          roles: KubusColorRoles.of(context),
                        ),
                        false,
                        onTap: () => navigationProvider.navigateToScreen(
                            context, screen.key),
                        visitCount: screen.visitCount,
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  List<String> _suggestedQuickActionKeys(UserPersona? persona) {
    switch (persona) {
      case UserPersona.lover:
        return const ['map', 'community', 'marketplace'];
      case UserPersona.creator:
        return const ['studio', 'ar', 'map'];
      case UserPersona.institution:
        return const ['institution_hub', 'map', 'community'];
      case null:
        return const ['map', 'studio', 'institution_hub'];
    }
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
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16 : 20,
            vertical: isSmallScreen ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
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
                      top: -4,
                      right: -4,
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
              SizedBox(width: isSmallScreen ? 10 : 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 12 : 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
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
        final l10n = AppLocalizations.of(context)!;
        if (!configProvider.useMockData) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.homeYourStatsTitle,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              EmptyStateCard(
                icon: Icons.analytics,
                title: l10n.homeNoStatsAvailableTitle,
                description: l10n.homeNoStatsAvailableDescription,
              ),
            ],
          );
        }

        final stats = [
          ('artworks', '42', Icons.image),
          ('followers', '1.2k', Icons.people),
          ('views', '8.5k', Icons.visibility),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 375;
            final isVerySmallScreen = constraints.maxWidth < 320;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeYourStatsTitle,
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
                            color: AppColorUtils.statColor(
                                index, Theme.of(context).colorScheme),
                            showIconOnly: false,
                            isVerticalLayout: true),
                      );
                    }).toList(),
                  )
                else
                  // Horizontal layout for other screen sizes - show icons only
                  Row(
                    children: stats.asMap().entries.map((entry) {
                      final stat = entry.value;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _buildStatCard(stat.$1, stat.$2, stat.$3,
                              color: AppColorUtils.statColor(
                                  entry.key, Theme.of(context).colorScheme),
                              showIconOnly: true,
                              isVerticalLayout: false),
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
      {Color? color,
      bool showIconOnly = false,
      bool isVerticalLayout = false}) {
    final scheme = Theme.of(context).colorScheme;
    final statColor = color ?? AppColorUtils.featureColor(title, scheme);
    final l10n = AppLocalizations.of(context)!;
    final displayTitle = _getStatDisplayTitle(title, l10n);

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
                  color: statColor.withValues(alpha: 0.1),
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
                        color: statColor,
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
                          displayTitle,
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
                            color: statColor,
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
                                  displayTitle,
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
                            color: statColor,
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
                            displayTitle,
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

  String _getGreeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.commonGreetingMorning;
    if (hour < 17) return l10n.commonGreetingAfternoon;
    return l10n.commonGreetingEvening;
  }

  Widget _buildWeb3Section() {
    return Consumer<Web3Provider>(
      builder: (context, web3Provider, child) {
        final l10n = AppLocalizations.of(context)!;
        // Show as connected if wallet is connected (mock or real)
        final bool isEffectivelyConnected = web3Provider.isConnected;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.homeWeb3SectionTitle,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (!isEffectivelyConnected)
                  Builder(
                    builder: (context) {
                      final roles = KubusColorRoles.of(context);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: roles.lockedFeature.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  roles.lockedFeature.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock,
                                size: 12, color: roles.lockedFeature),
                            Text(
                              l10n.homeAccountRequiredLabel,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: roles.lockedFeature,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildWeb3Card(
                    l10n.homeWeb3DaoTitle,
                    l10n.homeWeb3DaoSubtitle,
                    Icons.how_to_vote,
                    KubusColorRoles.of(context).web3DaoAccent,
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
                    l10n.homeWeb3ArtistTitle,
                    l10n.homeWeb3ArtistSubtitle,
                    Icons.palette,
                    KubusColorRoles.of(context).web3ArtistStudioAccent,
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
                    l10n.homeWeb3InstitutionTitle,
                    l10n.homeWeb3InstitutionSubtitle,
                    Icons.museum,
                    KubusColorRoles.of(context).web3InstitutionAccent,
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
                    l10n.homeWeb3MarketplaceTitle,
                    l10n.homeWeb3MarketplaceSubtitle,
                    Icons.store,
                    KubusColorRoles.of(context).web3MarketplaceAccent,
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
    return Consumer<RecentActivityProvider>(
      builder: (context, activityProvider, child) {
        final l10n = AppLocalizations.of(context)!;
        final activities =
            activityProvider.activities.take(5).toList(growable: false);
        final isLoading = activityProvider.isLoading && activities.isEmpty;
        final error = activityProvider.error;

        Widget content;
        if (isLoading) {
          content = _buildActivityLoadingState();
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
                  l10n.homeRecentActivityTitle,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: _showFullActivity,
                  child: Text(
                    l10n.commonViewAll,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.tertiary,
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

  Widget _buildActivityLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(AppColorUtils.amberAccent),
        ),
      ),
    );
  }

  Widget _buildActivityEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateCard(
      icon: Icons.timeline,
      title: l10n.homeNoRecentActivityTitle,
      description: l10n.homeNoRecentActivityDescription,
    );
  }

  Widget _buildActivityErrorState(String error, VoidCallback onRetry) {
    if (kDebugMode) {
      debugPrint('HomeScreen: activity load failed: $error');
    }
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmptyStateCard(
          icon: Icons.wifi_off,
          title: l10n.homeUnableToLoadActivityTitle,
          description: l10n.commonSomethingWentWrong,
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRetry,
          child: Text(l10n.commonRetry),
        ),
      ],
    );
  }

  Widget _buildFeaturedArtworks() {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, child) {
        final l10n = AppLocalizations.of(context)!;
        final featuredArtworks = artworkProvider.artworks.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.homeFeaturedArtworksTitle,
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
                    l10n.commonExplore,
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
                  ? EmptyStateCard(
                      icon: Icons.image_not_supported,
                      title: l10n.homeNoFeaturedArtworksTitle,
                      description: l10n.homeNoFeaturedArtworksDescription,
                      showAction: true,
                      actionLabel: l10n.commonExplore,
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

  Widget _buildArtworkCard(Artwork artwork, int index) {
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
            SizedBox(
              height: 110,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: _buildCardCover(artwork, themeProvider),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
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
                  ArtworkCreatorByline(
                    artwork: artwork,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardCover(Artwork artwork, ThemeProvider themeProvider) {
    final imageUrl = ArtworkMediaResolver.resolveCover(artwork: artwork);
    final placeholder = _artworkCoverPlaceholder(themeProvider);

    if (imageUrl == null || imageUrl.isEmpty) {
      return placeholder;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: InlineLoading(
                    shape: BoxShape.circle,
                    color: themeProvider.accentColor,
                  ),
                ),
              ),
            );
          },
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.22),
                ],
              ),
            ),
          ),
        ),
        if (artwork.arEnabled)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColorUtils.tealAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.view_in_ar, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'AR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _artworkCoverPlaceholder(ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            themeProvider.accentColor.withValues(alpha: 0.25),
            themeProvider.accentColor.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.image,
          color: Colors.white70,
          size: 32,
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

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return ChangeNotifierProvider.value(
          value: activityProvider,
          child: _NotificationsBottomSheet(
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
    final l10n = AppLocalizations.of(context)!;

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
                    l10n.commonNotifications,
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
                      l10n.homeMarkAllReadButton,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColorUtils.greenAccent,
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
    final l10n = AppLocalizations.of(context)!;
    final notifications = [
      (
        l10n.homeMockNotificationNewArtworkTitle,
        l10n.homeMockNotificationNewArtworkBody,
        Icons.location_on,
        l10n.commonTimeAgoMinutes(5)
      ),
      (
        l10n.homeMockNotificationRewardsTitle,
        l10n.homeMockNotificationRewardsBody,
        Icons.account_balance_wallet,
        l10n.commonTimeAgoHours(1)
      ),
      (
        l10n.homeMockNotificationFriendRequestTitle,
        l10n.homeMockNotificationFriendRequestBody,
        Icons.person_add,
        l10n.commonTimeAgoHours(2)
      ),
      (
        l10n.homeMockNotificationFeaturedTitle,
        l10n.homeMockNotificationFeaturedBody,
        Icons.star,
        l10n.commonTimeAgoHours(4)
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
              color: AppColorUtils.amberAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              notification.$3,
              color: AppColorUtils.amberAccent,
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
    for (final entry in NavigationProvider.screenDefinitions.entries) {
      if (entry.value.name == name) return entry.key;
    }
    return null;
  }

  // Show wallet onboarding for first-time users
  void _showWalletOnboarding(BuildContext context) {
    if (kDebugMode) {
      debugPrint('HomeScreen: wallet onboarding triggered');
    }

    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);

    // Navigate directly to comprehensive Web3 onboarding
    navigator.push(
      MaterialPageRoute(
        builder: (_) => web3.Web3OnboardingScreen(
          featureKey: Web3FeaturesOnboardingData.featureKey,
          featureTitle: Web3FeaturesOnboardingData.featureTitle(l10n),
          pages: _getWeb3OnboardingPages(l10n),
          onComplete: () {
            // Navigate to wallet creation/connection screen
            navigator.push(
              MaterialPageRoute(builder: (_) => const ConnectWallet()),
            );
          },
        ),
      ),
    );
  }

  List<web3.OnboardingPage> _getWeb3OnboardingPages(AppLocalizations l10n) {
    return Web3FeaturesOnboardingData.pages(l10n);
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

  void _showArtworkDetail(Artwork artwork) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ArtDetailScreen(artworkId: artwork.id),
      ),
    );
  }

  void _showStatsDialog(String statType, IconData icon) {
    final l10n = AppLocalizations.of(context)!;
    final displayTitle = _getStatDisplayTitle(statType, l10n);
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
              Text(l10n.homeStatsDialogTitle(displayTitle)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  EnhancedBarChart(
                    title: l10n.homeStatsTrendTitle(displayTitle),
                    data: _getStatsData(statType),
                    accentColor:
                        Provider.of<ThemeProvider>(dialogContext).accentColor,
                    labels: [
                      l10n.commonWeekdayMonShort,
                      l10n.commonWeekdayTueShort,
                      l10n.commonWeekdayWedShort,
                      l10n.commonWeekdayThuShort,
                      l10n.commonWeekdayFriShort,
                      l10n.commonWeekdaySatShort,
                      l10n.commonWeekdaySunShort,
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
              child: Text(l10n.commonClose),
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
              child: Text(l10n.homeViewAdvancedButton),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTimeline(String statType) {
    final milestones = _getStatsMilestones(statType);
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final accent =
        Provider.of<ThemeProvider>(context, listen: false).accentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.homeRecentMilestonesTitle,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
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
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      milestone,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.8),
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
      case 'artworks':
        return [35.0, 37.0, 39.0, 40.0, 41.0, 42.0, 42.0];
      case 'followers':
        return [980.0, 1050.0, 1120.0, 1150.0, 1180.0, 1200.0, 1200.0];
      case 'views':
        return [7200.0, 7800.0, 8100.0, 8300.0, 8450.0, 8500.0, 8500.0];
      default:
        return [10.0, 20.0, 30.0, 25.0, 35.0, 40.0, 45.0];
    }
  }

  List<String> _getStatsMilestones(String statType) {
    final l10n = AppLocalizations.of(context)!;
    switch (statType) {
      case 'artworks':
        return [
          l10n.homeStatsMilestoneArtworks1,
          l10n.homeStatsMilestoneArtworks2,
          l10n.homeStatsMilestoneArtworks3,
        ];
      case 'followers':
        return [
          l10n.homeStatsMilestoneFollowers1,
          l10n.homeStatsMilestoneFollowers2,
          l10n.homeStatsMilestoneFollowers3,
        ];
      case 'views':
        return [
          l10n.homeStatsMilestoneViews1,
          l10n.homeStatsMilestoneViews2,
          l10n.homeStatsMilestoneViews3,
        ];
      default:
        return [l10n.homeStatsNoMilestonesYet];
    }
  }

  String _getStatDisplayTitle(String statType, AppLocalizations l10n) {
    switch (statType) {
      case 'artworks':
        return l10n.homeStatArtworks;
      case 'followers':
        return l10n.homeStatFollowers;
      case 'views':
        return l10n.homeStatViews;
      default:
        return statType;
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
    required this.onActivitySelected,
    this.showUnreadOnly = false,
  });

  final Future<void> Function(RecentActivity activity) onActivitySelected;
  final bool showUnreadOnly;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
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
                  l10n.commonNotifications,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.commonRefresh,
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

                if (hasError && kDebugMode) {
                  debugPrint(
                      'HomeScreen: notifications load failed: ${activityProvider.error}');
                }

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
                                  ? l10n.homeUnableToLoadNotificationsTitle
                                  : l10n.homeNoNotificationsTitle,
                              description: hasError
                                  ? l10n.commonSomethingWentWrong
                                  : l10n.homeAllCaughtUpDescription,
                              showAction: hasError,
                              actionLabel: hasError ? l10n.commonRetry : null,
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.homeActivityTitle,
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
            if (kDebugMode) {
              debugPrint(
                  'HomeScreen: activity screen load failed: ${activityProvider.error}');
            }
            return RefreshIndicator(
              onRefresh: () => activityProvider.refresh(force: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  EmptyStateCard(
                    icon: Icons.wifi_off,
                    title: l10n.homeUnableToLoadActivityTitle,
                    description: l10n.commonSomethingWentWrong,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => activityProvider.refresh(force: true),
                    child: Text(l10n.commonRetry),
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
                children: [
                  EmptyStateCard(
                    icon: Icons.timeline,
                    title: l10n.homeNoRecentActivityTitle,
                    description: l10n.homeNoRecentActivityDescription,
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
  final Color? accentColor;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const RecentActivityTile({
    super.key,
    required this.activity,
    this.accentColor,
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
    final tileColor = accentColor ??
        AppColorUtils.activityColor(activity.category.name, theme.colorScheme);

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
                    ? tileColor.withValues(alpha: 0.4)
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
                    color: tileColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    activityCategoryIcon(activity.category),
                    color: tileColor,
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
                                color: tileColor,
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
                        formatActivityTime(context, activity.timestamp),
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

/// Returns icon for activity category - delegates to centralized AppColorUtils
IconData activityCategoryIcon(ActivityCategory category) =>
    AppColorUtils.activityIcon(category);

String formatActivityTime(BuildContext context, DateTime timestamp) {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  final diff = now.difference(timestamp);
  if (diff.inMinutes < 1) return l10n.commonJustNow;
  if (diff.inMinutes < 60) return l10n.commonTimeAgoMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l10n.commonTimeAgoHours(diff.inHours);
  if (diff.inDays < 7) return l10n.commonTimeAgoDays(diff.inDays);
  return MaterialLocalizations.of(context).formatShortDate(timestamp);
}
