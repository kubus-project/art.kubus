import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
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
import '../../config/config.dart';
import '../../models/artwork.dart';
import '../../models/recent_activity.dart';
import '../../models/user_persona.dart';
import '../../models/wallet.dart';
import '../../community/community_interactions.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/artist_badge.dart';
import '../../widgets/institution_badge.dart';
import '../../widgets/inline_loading.dart';
import '../../utils/app_animations.dart';
import '../../utils/activity_navigation.dart';
import '../../utils/artwork_media_resolver.dart';
import 'components/desktop_widgets.dart';
import '../web3/wallet/connectwallet_screen.dart';
import 'web3/desktop_wallet_screen.dart';
import '../onboarding/web3/web3_onboarding.dart' as web3;
import '../onboarding/web3/onboarding_data.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../art/art_detail_screen.dart';
import 'community/desktop_user_profile_screen.dart';
import 'desktop_settings_screen.dart';
import 'desktop_shell.dart';
import '../activity/advanced_analytics_screen.dart';
import '../../services/search_service.dart';
import '../home_screen.dart' show ActivityScreen;
import '../../services/backend_api_service.dart';

/// Desktop home screen with spacious layout and proper grid systems
/// Inspired by Twitter/X feed presentation and Google Maps panels
class DesktopHomeScreen extends StatefulWidget {
  const DesktopHomeScreen({super.key});

  @override
  State<DesktopHomeScreen> createState() => _DesktopHomeScreenState();
}

class _DesktopHomeScreenState extends State<DesktopHomeScreen> 
    with TickerProviderStateMixin {
  // Semantic color palette for varied UI elements (matches governance/artist/institution screens)
  static const Color _tealAccent = Color(0xFF4ECDC4);
  static const Color _coralAccent = Color(0xFFFF6B6B);
  static const Color _greenAccent = Color(0xFF4CAF50);
  static const Color _amberAccent = Color(0xFFFFB300);
  static const Color _purpleAccent = Color(0xFF9575CD);
  
  static const double _searchBarWidth = 280;
  late AnimationController _animationController;
  late ScrollController _scrollController;
  bool _showFloatingHeader = false;
  final BackendApiService _backendApi = BackendApiService();
  final LayerLink _searchFieldLink = LayerLink();
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _isFetchingSuggestions = false;
  List<_SearchSuggestion> _searchSuggestions = const [];
  OverlayEntry? _searchOverlayEntry;
  final SearchService _searchService = SearchService();
  bool _isResolvingLocation = false;
  List<CommunityPost> _popularCommunityPosts = const [];
  bool _popularCommunityLoading = false;
  bool _popularCommunityFetchFailed = false;
  bool _artFeedLoadQueued = false;

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
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _searchFocusNode.addListener(_handleSearchFocusChange);

    // Initialize providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final recentActivity = Provider.of<RecentActivityProvider>(context, listen: false);
      if (!recentActivity.initialized) {
        recentActivity.initialize();
      }
      final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
      navigationProvider.initialize();
      _loadInitialData();
    });
  }

  void _queueArtFeedLoad({
    double? lat,
    double? lng,
    double? radiusKm,
    int? limit,
  }) {
    if (_artFeedLoadQueued) return;
    _artFeedLoadQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _artFeedLoadQueued = false;
      final provider = context.read<CommunityHubProvider>();
      unawaited(provider.loadArtFeed(
        latitude: lat ?? provider.artFeedCenter?.lat ?? 46.05,
        longitude: lng ?? provider.artFeedCenter?.lng ?? 14.50,
        radiusKm: radiusKm ?? provider.artFeedRadiusKm,
        limit: limit ?? 20,
      ));
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _searchOverlayEntry?.remove();
    _searchController.dispose();
    _searchFocusNode
      ..removeListener(_handleSearchFocusChange)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShowHeader = _scrollController.offset > 100;
    if (shouldShowHeader != _showFloatingHeader) {
      setState(() => _showFloatingHeader = shouldShowHeader);
    }
  }

  Future<void> _loadInitialData() async {
    final artworkProvider = context.read<ArtworkProvider>();
    final communityProvider = context.read<CommunityHubProvider>();
    final configProvider = context.read<ConfigProvider>();

    if (artworkProvider.artworks.isEmpty &&
        !artworkProvider.isLoading('load_artworks')) {
      await artworkProvider.loadArtworks();
    }

    if (!communityProvider.groupsInitialized && !communityProvider.groupsLoading) {
      await communityProvider.loadGroups();
    }

    if (communityProvider.artFeedPosts.isEmpty && !communityProvider.artFeedLoading) {
      final center = await _resolveArtFeedLocation(configProvider);
      await communityProvider.loadArtFeed(
        latitude: center.lat ?? 46.05,
        longitude: center.lng ?? 14.50,
        radiusKm: configProvider.useMockData ? 200 : 50,
        limit: 50,
      );
    }

    await _loadPopularCommunityPosts();
  }

  Future<void> _loadPopularCommunityPosts({bool force = false}) async {
    if (_popularCommunityLoading) return;
    if (!force && _popularCommunityPosts.isNotEmpty) return;

    final communityProvider = context.read<CommunityHubProvider>();
    final configProvider = context.read<ConfigProvider>();

    if (configProvider.useMockData) {
      if (!mounted) return;
      setState(() {
        _popularCommunityPosts = communityProvider.artFeedPosts;
        _popularCommunityFetchFailed = false;
      });
      return;
    }

    setState(() {
      _popularCommunityLoading = true;
      _popularCommunityFetchFailed = false;
    });

    try {
      final posts = await _backendApi.getCommunityPosts(limit: 50, sort: 'popularity');
      if (!mounted) return;
      setState(() {
        _popularCommunityPosts = posts;
        _popularCommunityFetchFailed = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DesktopHomeScreen: failed to load popular community posts: $e');
      }
      if (!mounted) return;
      setState(() {
        _popularCommunityFetchFailed = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _popularCommunityLoading = false;
        });
      }
    }
  }

  Future<CommunityLocation> _resolveArtFeedLocation(ConfigProvider configProvider) async {
    if (_isResolvingLocation) return CommunityLocation(lat: 46.05, lng: 14.50);
    _isResolvingLocation = true;
    try {
      if (!AppConfig.enableLocationServices || configProvider.useMockData) {
        return CommunityLocation(lat: 46.05, lng: 14.50);
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return CommunityLocation(lat: 46.05, lng: 14.50);
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return CommunityLocation(lat: 46.05, lng: 14.50);
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.lowest,
        timeLimit: const Duration(seconds: 4),
      );

      return CommunityLocation(lat: position.latitude, lng: position.longitude);
    } catch (_) {
      return CommunityLocation(lat: 46.05, lng: 14.50);
    } finally {
      _isResolvingLocation = false;
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
    final l10n = AppLocalizations.of(context)!;
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
                            _getGreeting(l10n),
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
                                  user?.displayName ?? l10n.desktopHomeWelcomeFallbackName,
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
              CompositedTransformTarget(
                link: _searchFieldLink,
                child: SizedBox(
                  width: _searchBarWidth,
                  child: DesktopSearchBar(
                    hintText: l10n.mapSearchHint,
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _handleSearchChange,
                    onSubmitted: _handleSearchSubmit,
                    autofocus: false,
                  ),
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
    final l10n = AppLocalizations.of(context)!;

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
                    l10n.desktopHomeDiscoverArtTitle,
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.desktopHomeDiscoverArtDescription,
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
                      label: Text(l10n.authConnectWalletButton),
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
    final profileProvider = Provider.of<ProfileProvider>(context);
    final activityProvider = Provider.of<RecentActivityProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isLoadingArtworks = artworkProvider.isLoading('load_artworks');
    final isLoadingActivity =
        activityProvider.isLoading && activityProvider.activities.isEmpty;

    final discoveredCount = profileProvider.artworksCount > 0
      ? profileProvider.artworksCount
      : artworkProvider.artworks.where((a) => a.isDiscovered).length;
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
        DesktopSectionHeader(
          title: l10n.desktopHomeYourActivityTitle,
          subtitle: l10n.desktopHomeYourActivitySubtitle,
          icon: Icons.analytics_outlined,
          iconColor: _coralAccent,
        ),
        const SizedBox(height: 16),
        if (isLoadingArtworks || isLoadingActivity)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: InlineLoading(),
            ),
          ),
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
                    label: l10n.desktopHomeStatArtworksDiscovered,
                    value: discoveredCount.toString(),
                    icon: Icons.explore,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  height: 160,
                  child: DesktopStatCard(
                    label: l10n.desktopHomeStatArSessions,
                    value: arSessions.toString(),
                    icon: Icons.view_in_ar,
                    color: scheme.tertiary,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  height: 160,
                  child: DesktopStatCard(
                    label: l10n.desktopHomeStatNftsCollected,
                    value: web3Provider.isConnected ? nftCount.toString() : '0',
                    icon: Icons.collections,
                    color: scheme.secondary,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  height: 160,
                  child: DesktopStatCard(
                    label: l10n.desktopHomeStatKub8Earned,
                    value: kub8Earned,
                    icon: Icons.monetization_on,
                    color: scheme.primary,
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
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final profileProvider = context.watch<ProfileProvider>();
    final l10n = AppLocalizations.of(context)!;
    final quickScreens = navigationProvider.getQuickActionScreens(maxItems: 12);
    final persona = profileProvider.userPersona;
    final suggestedKeys = _suggestedQuickActionKeys(persona)
        .where((key) => NavigationProvider.screenDefinitions.containsKey(key))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: l10n.homeQuickActionsTitle,
          subtitle: quickScreens.isEmpty 
              ? l10n.desktopHomeQuickActionsEmptySubtitle
              : l10n.desktopHomeQuickActionsSubtitle,
          icon: Icons.flash_on,
          iconColor: _amberAccent,
        ),
        const SizedBox(height: 16),
        if (quickScreens.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                            l10n.desktopHomeQuickActionsEmptyTitle,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.desktopHomeQuickActionsEmptyDescription,
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
              ),
              if (suggestedKeys.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: suggestedKeys.map((key) {
                    final def = NavigationProvider.screenDefinitions[key]!;
                    return _buildQuickActionCard(
                      def.name,
                      def.icon,
                      _getScreenColor(key, Theme.of(context).colorScheme),
                      () => _handleQuickAction(key),
                      visitCount: 0,
                    );
                  }).toList(growable: false),
                ),
              ],
            ],
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: quickScreens.map((screen) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildQuickActionCard(
                    screen.name,
                    screen.icon,
                    _getScreenColor(screen.key, Theme.of(context).colorScheme),
                    () => _handleQuickAction(screen.key),
                    visitCount: screen.visitCount,
                  ),
                );
              }).toList(),
            ),
          ),
      ],
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

  void _handleQuickAction(String screenKey) {
    if (screenKey.isEmpty) return;
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);

    switch (screenKey) {
      case 'map':
        _openShellTab(1); // Explore
        return;
      case 'community':
        _openShellTab(2); // Connect
        return;
      case 'studio':
        _openShellTab(3); // Create (Artist Studio)
        return;
      case 'institution_hub':
        _openShellTab(4); // Organize (Institution)
        return;
      case 'dao_hub':
        _openShellTab(5); // Govern (DAO)
        return;
      case 'marketplace':
        _openShellTab(6); // Trade
        return;
      case 'wallet':
        navigationProvider.trackScreenVisit('wallet');
        final shellScope = DesktopShellScope.of(context);
        if (shellScope != null) {
          shellScope.navigateToRoute('/wallet');
        } else {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const DesktopWalletScreen(),
          ));
        }
        return;
      case 'profile':
        _pushScreen(const DesktopSettingsScreen(), screenKey);
        return;
      case 'analytics':
        _pushScreen(const AdvancedAnalyticsScreen(statType: ''), screenKey);
        return;
      case 'achievements':
        // Reuse onboarding to surface achievements context
        final l10n = AppLocalizations.of(context)!;
        final screen = web3.Web3OnboardingScreen(
          featureKey: 'Achievements',
          featureTitle: l10n.userProfileAchievementsTitle,
          pages: _getWeb3OnboardingPages(l10n),
          onComplete: () {},
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
    // Use in-shell navigation if available, otherwise fallback to fullscreen
    final shellScope = DesktopShellScope.of(context);
    if (shellScope != null) {
      shellScope.pushScreen(
        DesktopSubScreen(
          title: _screenKeyToTitle(screenKey),
          child: screen,
        ),
      );
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }
  }

  String _screenKeyToTitle(String key) {
    switch (key) {
      case 'profile':
        return 'Settings';
      case 'analytics':
        return 'Analytics';
      case 'achievements':
        return 'Achievements';
      case 'wallet':
        return 'Wallet';
      default:
        return key.split('_').map((w) => w.isNotEmpty 
            ? '${w[0].toUpperCase()}${w.substring(1)}' 
            : w).join(' ');
    }
  }

  void _openShellTab(int index) {
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    navigationProvider.trackScreenVisit(_indexToKey(index));
    
    // Use shell scope navigation if available, otherwise fallback to pushing new shell
    final shellScope = DesktopShellScope.of(context);
    if (shellScope != null) {
      shellScope.navigateToRoute(_indexToRoute(index));
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DesktopShell(initialIndex: index),
      ));
    }
  }

  String _indexToRoute(int index) {
    switch (index) {
      case 1:
        return '/explore';
      case 2:
        return '/community';
      case 3:
        return '/artist-studio';
      case 4:
        return '/institution';
      case 5:
        return '/governance';
      case 6:
        return '/marketplace';
      default:
        return '/home';
    }
  }

  String _indexToKey(int index) {
    switch (index) {
      case 1:
        return 'map'; // Explore
      case 2:
        return 'community'; // Connect
      case 3:
        return 'studio'; // Create
      case 4:
        return 'institution_hub'; // Organize
      case 5:
        return 'dao_hub'; // Govern
      case 6:
        return 'marketplace'; // Trade
      default:
        return 'home';
    }
  }

  void _navigateToTab(int tabIndex) {
    switch (tabIndex) {
      case 2:
        _handleQuickAction('community');
        break;
      case 6:
        _handleQuickAction('marketplace');
        break;
      default:
        _openShellTab(tabIndex);
        break;
    }
  }

  /// Get semantic color for a screen/section key (varied palette like governance/artist screens)
  Color _getScreenColor(String key, ColorScheme scheme) {
    switch (key.toLowerCase()) {
      case 'map':
      case 'explore':
        return _tealAccent;
      case 'community':
      case 'connect':
        return scheme.secondary;
      case 'studio':
      case 'artist':
      case 'create':
        return scheme.tertiary;
      case 'institution_hub':
      case 'institution':
      case 'organize':
        return scheme.primary;
      case 'dao_hub':
      case 'dao':
      case 'govern':
        return _purpleAccent;
      case 'marketplace':
      case 'trade':
        return _greenAccent;
      case 'wallet':
        return _amberAccent;
      case 'profile':
      case 'settings':
        return scheme.onSurface.withValues(alpha: 0.7);
      case 'analytics':
        return _coralAccent;
      case 'achievements':
        return Colors.amber;
      case 'ar':
        return _tealAccent;
      default:
        return scheme.primary;
    }
  }

  void _openFullActivity() {
    final shellScope = DesktopShellScope.of(context);
    if (shellScope != null) {
      shellScope.pushScreen(
        DesktopSubScreen(
          title: 'Activity',
          child: const ActivityScreen(),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ActivityScreen()),
      );
    }
  }

  void _showARInfo() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.view_in_ar, color: Theme.of(context).colorScheme.tertiary),
            const SizedBox(width: 12),
            Text(
              l10n.arWebFallbackFeature,
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
              l10n.arWebFallbackDescription,
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonGotIt),
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
        final l10n = AppLocalizations.of(context)!;
        final artworks = artworkProvider.artworks.take(6).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DesktopSectionHeader(
              title: l10n.homeFeaturedArtworksTitle,
              subtitle: l10n.desktopHomeFeaturedArtworksSubtitle,
              icon: Icons.auto_awesome,
              iconColor: _tealAccent,
              action: TextButton.icon(
                onPressed: () => _openShellTab(1), // Explore tab
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(l10n.commonViewAll),
              ),
            ),
            const SizedBox(height: 16),
            if (artworks.isEmpty)
              EmptyStateCard(
                icon: Icons.image_not_supported,
                title: l10n.homeNoFeaturedArtworksTitle,
                description: l10n.homeNoFeaturedArtworksDescription,
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
    final l10n = AppLocalizations.of(context)!;

    return DesktopCard(
      width: 200,
      margin: EdgeInsets.only(right: index < 5 ? 16 : 0),
      padding: EdgeInsets.zero,
      onTap: () {
        final shellScope = DesktopShellScope.of(context);
        if (shellScope != null) {
          shellScope.pushScreen(
            DesktopSubScreen(
              title: artwork.title,
              child: ArtDetailScreen(artworkId: artwork.id),
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ArtDetailScreen(artworkId: artwork.id),
            ),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          SizedBox(
            height: 140,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: _buildDesktopCardCover(artwork, themeProvider),
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
                  l10n.commonByArtist(artwork.artist),
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

  Widget _buildDesktopCardCover(Artwork artwork, ThemeProvider themeProvider) {
    final imageUrl = ArtworkMediaResolver.resolveCover(artwork: artwork);
    final placeholder = _desktopCoverPlaceholder(themeProvider);
    final l10n = AppLocalizations.of(context)!;

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
                  width: 32,
                  height: 32,
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
                color: themeProvider.accentColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.view_in_ar, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    l10n.commonArShort,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _desktopCoverPlaceholder(ThemeProvider themeProvider) {
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
          size: 36,
        ),
      ),
    );
  }

  Widget _buildWeb3Section() {
    final web3Provider = Provider.of<Web3Provider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isConnected = web3Provider.isConnected;
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: l10n.desktopHomeWeb3HubTitle,
          subtitle: l10n.desktopHomeWeb3HubSubtitle,
          icon: Icons.hub,
          iconColor: _purpleAccent,
          action: isConnected ? null : TextButton.icon(
            onPressed: _showWalletOnboarding,
            icon: const Icon(Icons.link, size: 18),
            label: Text(l10n.authConnectWalletButton),
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
                    l10n.homeWeb3DaoTitle,
                    l10n.homeWeb3DaoSubtitle,
                    Icons.how_to_vote,
                    scheme.tertiary,
                    isConnected,
                    () => _navigateToWeb3Tab(5, isConnected), // Govern tab
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildWeb3Card(
                    l10n.homeWeb3ArtistTitle,
                    l10n.homeWeb3ArtistSubtitle,
                    Icons.palette,
                    scheme.secondary,
                    isConnected,
                    () => _navigateToWeb3Tab(3, isConnected), // Create tab
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildWeb3Card(
                    l10n.homeWeb3InstitutionTitle,
                    l10n.homeWeb3InstitutionSubtitle,
                    Icons.museum,
                    scheme.primary,
                    isConnected,
                    () => _navigateToWeb3Tab(4, isConnected), // Organize tab
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildWeb3Card(
                    l10n.homeWeb3MarketplaceTitle,
                    l10n.homeWeb3MarketplaceSubtitle,
                    Icons.store,
                    themeProvider.accentColor,
                    isConnected,
                    () => _navigateToWeb3Tab(6, isConnected), // Trade tab
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _navigateToWeb3Tab(int tabIndex, bool isConnected) {
    if (isConnected) {
      _openShellTab(tabIndex);
    } else {
      _showWalletOnboarding();
    }
  }

  void _showWalletOnboarding() {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => web3.Web3OnboardingScreen(
          featureKey: Web3FeaturesOnboardingData.featureKey,
          featureTitle: Web3FeaturesOnboardingData.featureTitle(l10n),
          pages: _getWeb3OnboardingPages(l10n),
          onComplete: () {
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
                    color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.lock,
                    size: 14,
                    color: Theme.of(context).colorScheme.tertiary,
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
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            l10n.homeActivityTitle,
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
    return Consumer2<ArtworkProvider, CommunityHubProvider>(
      builder: (context, artworkProvider, communityProvider, _) {
        final l10n = AppLocalizations.of(context)!;
        final communityPosts = _popularCommunityPosts.isNotEmpty
            ? _popularCommunityPosts
            : communityProvider.artFeedPosts;

        if (communityPosts.isEmpty && !communityProvider.artFeedLoading && !_popularCommunityLoading) {
          // Ensure we have some data to show
          _queueArtFeedLoad(
            lat: communityProvider.artFeedCenter?.lat,
            lng: communityProvider.artFeedCenter?.lng,
            radiusKm: communityProvider.artFeedRadiusKm,
            limit: 50,
          );
          unawaited(_loadPopularCommunityPosts());
        }

        final trendingEntries = _getTrendingEntries(artworkProvider, communityPosts);
        final isLoading =
            (artworkProvider.isLoading('load_artworks') ||
                    (_popularCommunityLoading && _popularCommunityPosts.isEmpty) ||
                    (communityProvider.artFeedLoading && communityPosts.isEmpty)) &&
                trendingEntries.isEmpty;
        final hasPopularError = _popularCommunityFetchFailed && _popularCommunityPosts.isEmpty;
        final hasArtFeedError = communityProvider.artFeedError != null && trendingEntries.isEmpty;
        final hasError = hasPopularError || hasArtFeedError;

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
                      l10n.desktopHomeTrendingArtTitle,
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
                    l10n.commonViewAll,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: themeProvider.accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isLoading)
              const InlineLoading()
            else if (hasError && trendingEntries.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.desktopHomeTrendingArtLoadFailed,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => hasPopularError
                          ? _loadPopularCommunityPosts(force: true)
                          : _queueArtFeedLoad(
                              lat: communityProvider.artFeedCenter?.lat,
                              lng: communityProvider.artFeedCenter?.lng,
                              radiusKm: communityProvider.artFeedRadiusKm,
                              limit: 50,
                            ),
                      child: Text(
                        l10n.commonRetry,
                        style: GoogleFonts.inter(
                          color: themeProvider.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (trendingEntries.isEmpty)
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
                      l10n.desktopHomeTrendingArtEmpty,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...trendingEntries.map((entry) => _buildTrendingArtItem(entry, themeProvider)),
          ],
        );
      },
    );
  }

  Widget _buildTrendingArtItem(_TrendingArtEntry entry, ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (entry.artworkId != null && entry.artworkId!.isNotEmpty) {
            final shellScope = DesktopShellScope.of(context);
            if (shellScope != null) {
              shellScope.pushScreen(
                DesktopSubScreen(
                  title: entry.title,
                  child: ArtDetailScreen(artworkId: entry.artworkId!),
                ),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ArtDetailScreen(artworkId: entry.artworkId!),
                ),
              );
            }
          }
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
                      _tealAccent.withValues(alpha: 0.4),
                      _tealAccent.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(Icons.view_in_ar, color: _tealAccent, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      entry.subtitle ?? '—',
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
                          entry.likes.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                    if (entry.hasAR)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _tealAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.commonArShort,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _tealAccent,
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
        final l10n = AppLocalizations.of(context)!;
        final communityPosts = _popularCommunityPosts.isNotEmpty
            ? _popularCommunityPosts
            : communityProvider.artFeedPosts;
        if (communityPosts.isEmpty && !communityProvider.artFeedLoading && !_popularCommunityLoading) {
          _queueArtFeedLoad(
            lat: communityProvider.artFeedCenter?.lat,
            lng: communityProvider.artFeedCenter?.lng,
            radiusKm: communityProvider.artFeedRadiusKm,
            limit: 50,
          );
          unawaited(_loadPopularCommunityPosts());
        }

        final creators = _buildTopCreatorSummaries(communityPosts);
        final isLoading =
            ((communityProvider.artFeedLoading && communityPosts.isEmpty) ||
                    (_popularCommunityLoading && _popularCommunityPosts.isEmpty)) &&
                creators.isEmpty;
        final hasPopularError = _popularCommunityFetchFailed && _popularCommunityPosts.isEmpty;
        final hasArtFeedError = communityProvider.artFeedError != null && creators.isEmpty;
        final hasError = hasPopularError || hasArtFeedError;

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
                      l10n.desktopHomeTopCreatorsTitle,
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
                    l10n.commonExplore,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: themeProvider.accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isLoading)
              const InlineLoading()
            else if (hasError && creators.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.desktopHomeTopCreatorsLoadFailed,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => hasPopularError
                          ? _loadPopularCommunityPosts(force: true)
                          : _queueArtFeedLoad(
                              lat: communityProvider.artFeedCenter?.lat,
                              lng: communityProvider.artFeedCenter?.lng,
                              radiusKm: communityProvider.artFeedRadiusKm,
                              limit: 50,
                            ),
                      child: Text(
                        l10n.commonRetry,
                        style: GoogleFonts.inter(
                          color: themeProvider.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (creators.isEmpty)
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
                      l10n.desktopHomeTopCreatorsEmpty,
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
    final l10n = AppLocalizations.of(context)!;
    final userId = (creator['id'] ?? creator['wallet'] ?? '').toString();
    final wallet = (creator['wallet'] ?? '').toString().isNotEmpty
        ? creator['wallet'].toString()
        : userId;
    final avatarUrl = creator['avatar'] ?? creator['avatarUrl'];
    final displayName = (creator['displayName'] ?? creator['username'] ?? 'Artist').toString();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (userId.isNotEmpty) {
            final shellScope = DesktopShellScope.of(context);
            if (shellScope != null) {
              shellScope.pushScreen(
                DesktopSubScreen(
                  title: displayName,
                  child: UserProfileScreen(userId: userId),
                ),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(userId: userId),
                ),
              );
            }
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
                avatarUrl: avatarUrl,
                wallet: wallet,
                radius: 20,
                allowFabricatedFallback: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (creator['name'] ?? l10n.desktopHomeCreatorFallbackName).toString(),
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
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.desktopHomePostsCount(creator['postCount'] as int? ?? 0),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.secondary,
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
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final communityPostsCount = _popularCommunityPosts.isNotEmpty
        ? _popularCommunityPosts.length
        : communityProvider.artFeedPosts.length;
    final isLoading = (artworkProvider.isLoading('load_artworks') ||
      ((_popularCommunityLoading && _popularCommunityPosts.isEmpty) ||
        (communityProvider.artFeedLoading && communityPostsCount == 0)));

    // Ensure feed data is requested if missing
    if (communityPostsCount == 0 && !communityProvider.artFeedLoading && !_popularCommunityLoading) {
      // Fire and forget with a safe fallback location
      _queueArtFeedLoad(
        lat: communityProvider.artFeedCenter?.lat,
        lng: communityProvider.artFeedCenter?.lng,
        radiusKm: communityProvider.artFeedRadiusKm,
        limit: 50,
      );
      unawaited(_loadPopularCommunityPosts());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.analytics,
              color: _coralAccent,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
                  l10n.desktopHomePlatformStatsTitle,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isLoading)
          const InlineLoading()
        else if ((_popularCommunityFetchFailed && _popularCommunityPosts.isEmpty) ||
            (communityProvider.artFeedError != null && communityPostsCount == 0))
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.desktopHomePlatformStatsLoadFailed,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _popularCommunityFetchFailed
                      ? _loadPopularCommunityPosts(force: true)
                      : _queueArtFeedLoad(
                          lat: communityProvider.artFeedCenter?.lat,
                          lng: communityProvider.artFeedCenter?.lng,
                          radiusKm: communityProvider.artFeedRadiusKm,
                          limit: 50,
                        ),
                  child: Text(l10n.commonRetry, style: GoogleFonts.inter(color: themeProvider.accentColor)),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildPlatformStatRow(
                  l10n.desktopHomePlatformStatsTotalArtworks,
                  artworkProvider.artworks.length.toString(),
                  Icons.view_in_ar,
                  _tealAccent,
                ),
                const Divider(height: 24),
                _buildPlatformStatRow(
                  l10n.desktopHomePlatformStatsArEnabled,
                  artworkProvider.artworks.where((a) => a.arEnabled).length.toString(),
                  Icons.visibility,
                  scheme.tertiary,
                ),
                const Divider(height: 24),
                _buildPlatformStatRow(
                  l10n.desktopHomePlatformStatsCommunityPosts,
                  communityPostsCount.toString(),
                  Icons.forum,
                  scheme.secondary,
                ),
                const Divider(height: 24),
                _buildPlatformStatRow(
                  l10n.desktopHomePlatformStatsActiveGroups,
                  communityProvider.groups.length.toString(),
                  Icons.groups,
                  _purpleAccent,
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
        final l10n = AppLocalizations.of(context)!;
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
                  l10n.homeRecentActivityTitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                TextButton(
                  onPressed: _openFullActivity,
                  child: Text(
                    l10n.commonViewAll,
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
    final l10n = AppLocalizations.of(context)!;
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
            l10n.homeUnableToLoadActivityTitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.commonSomethingWentWrong,
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
            child: Text(l10n.commonRetry),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityEmpty(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          l10n.homeNoRecentActivityTitle,
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

  /// Get semantic color for activity/notification category
  Color _getActivityColor(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.discovery:
        return _tealAccent;
      case ActivityCategory.like:
        return _coralAccent;
      case ActivityCategory.comment:
        return Theme.of(context).colorScheme.secondary;
      case ActivityCategory.follow:
        return _purpleAccent;
      case ActivityCategory.nft:
        return _amberAccent;
      case ActivityCategory.ar:
        return _tealAccent;
      case ActivityCategory.reward:
        return _greenAccent;
      case ActivityCategory.share:
        return Theme.of(context).colorScheme.tertiary;
      case ActivityCategory.mention:
        return Theme.of(context).colorScheme.primary;
      case ActivityCategory.achievement:
        return Colors.amber;
      case ActivityCategory.save:
        return Theme.of(context).colorScheme.secondary;
      case ActivityCategory.system:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    }
  }

  Widget _buildFloatingHeader(ThemeProvider themeProvider, AppAnimationTheme animationTheme) {
    final l10n = AppLocalizations.of(context)!;
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
                hintText: l10n.commonSearch,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return '${l10n.commonGreetingMorning},';
    if (hour < 17) return '${l10n.commonGreetingAfternoon},';
    return '${l10n.commonGreetingEvening},';
  }

  Future<void> _showNotificationsPanel(
    ThemeProvider themeProvider,
    NotificationProvider np,
  ) async {
    final l10n = AppLocalizations.of(context)!;
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
                      l10n.commonNotifications,
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
                          l10n.homeMarkAllReadButton,
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
                              l10n.homeNoNotificationsTitle,
                              style: GoogleFonts.inter(
                                color: Theme.of(dialogContext).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.homeAllCaughtUpDescription,
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
                                    l10n.desktopHomeUnreadNotificationsLabel,
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
                                            color: _getActivityColor(activity.category).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            _getActivityIcon(activity.category),
                                            color: _getActivityColor(activity.category),
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
    final l10n = AppLocalizations.of(context)!;
    final mockNotifications = [
      {
        'title': l10n.homeMockNotificationNewArtworkTitle,
        'description': l10n.homeMockNotificationNewArtworkBody,
        'icon': Icons.location_on,
        'time': l10n.commonTimeAgoMinutes(5),
        'color': _tealAccent, // Discovery
      },
      {
        'title': l10n.homeMockNotificationRewardsTitle,
        'description': l10n.homeMockNotificationRewardsBody,
        'icon': Icons.account_balance_wallet,
        'time': l10n.commonTimeAgoHours(1),
        'color': _greenAccent, // Reward
      },
      {
        'title': l10n.homeMockNotificationFriendRequestTitle,
        'description': l10n.homeMockNotificationFriendRequestBody,
        'icon': Icons.person_add,
        'time': l10n.commonTimeAgoHours(2),
        'color': _purpleAccent, // Follow
      },
      {
        'title': l10n.homeMockNotificationFeaturedTitle,
        'description': l10n.homeMockNotificationFeaturedBody,
        'icon': Icons.star,
        'time': l10n.commonTimeAgoHours(4),
        'color': Colors.amber, // Achievement
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
                      l10n.commonNotifications,
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
              color: (notification['color'] as Color? ?? themeProvider.accentColor).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              notification['icon'] as IconData,
              color: notification['color'] as Color? ?? themeProvider.accentColor,
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

  void _handleSearchFocusChange() {
    if (!_searchFocusNode.hasFocus) {
      _hideSearchOverlay();
    } else {
      _showSearchOverlay();
    }
  }

  void _handleSearchChange(String value) {
    setState(() {
      _searchQuery = value;
    });

    _searchDebounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _searchSuggestions = const [];
        _isFetchingSuggestions = false;
      });
      _showSearchOverlay();
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 275), () async {
      setState(() {
        _isFetchingSuggestions = true;
      });
      _showSearchOverlay();

      try {
        List<_SearchSuggestion> suggestions;
        final remote = await _searchService.fetchSuggestions(
          context: context,
          query: value,
          scope: SearchScope.home,
          limit: 8,
        );
        suggestions = remote
            .map((s) => _SearchSuggestion(
                  label: s.label,
                  type: s.type,
                  subtitle: s.subtitle,
                  id: s.id,
                  position: s.position,
                ))
            .toList(growable: false);
        if (suggestions.isEmpty) {
          suggestions = _buildLocalSearchSuggestions(value);
        }

        if (!mounted) return;
        setState(() {
          _searchSuggestions = suggestions;
          _isFetchingSuggestions = false;
        });
        _showSearchOverlay();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _searchSuggestions = _buildLocalSearchSuggestions(value);
          _isFetchingSuggestions = false;
        });
      }
    });
  }

  List<_SearchSuggestion> _buildLocalSearchSuggestions(String query) {
    final normalized = query.toLowerCase();
    final artworkProvider = context.read<ArtworkProvider>();
    return artworkProvider.artworks
        .where((artwork) =>
            artwork.title.toLowerCase().contains(normalized) ||
            artwork.artist.toLowerCase().contains(normalized) ||
            artwork.category.toLowerCase().contains(normalized))
        .map((art) => _SearchSuggestion(
              label: art.title,
              type: 'artwork',
              subtitle: art.artist,
              id: art.id,
            ))
        .take(8)
        .toList(growable: false);
  }

  Future<void> _handleSearchSubmit(String value) async {
    if (value.trim().isEmpty) return;
    if (_searchSuggestions.isNotEmpty) {
      await _handleSuggestionTap(_searchSuggestions.first);
    } else {
      _handleSearchChange(value);
    }
  }

  Future<void> _handleSuggestionTap(_SearchSuggestion suggestion) async {
    setState(() {
      _searchQuery = suggestion.label;
      _searchController.text = suggestion.label;
      _searchSuggestions = const [];
    });
    _hideSearchOverlay();

    // If the suggestion has a location, refresh the community feed around it
    if (suggestion.position != null) {
      final communityProvider = context.read<CommunityHubProvider>();
      _queueArtFeedLoad(
        lat: suggestion.position!.latitude,
        lng: suggestion.position!.longitude,
        radiusKm: communityProvider.artFeedRadiusKm,
        limit: 50,
      );
    }

    if (suggestion.type == 'artwork' && suggestion.id != null) {
      final shellScope = DesktopShellScope.of(context);
      if (shellScope != null) {
        shellScope.pushScreen(
          DesktopSubScreen(
            title: suggestion.label,
            child: ArtDetailScreen(artworkId: suggestion.id!),
          ),
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArtDetailScreen(artworkId: suggestion.id!),
          ),
        );
      }
      return;
    }

    if (suggestion.type == 'profile' && suggestion.id != null) {
      final shellScope = DesktopShellScope.of(context);
      if (shellScope != null) {
        shellScope.pushScreen(
          DesktopSubScreen(
            title: suggestion.subtitle ?? suggestion.label,
            child: UserProfileScreen(userId: suggestion.id!),
          ),
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: suggestion.id!),
          ),
        );
      }
      return;
    }

    _openShellTab(1);
  }

  void _showSearchOverlay() {
    if (!_searchFocusNode.hasFocus) return;
    if (_searchOverlayEntry != null) {
      _searchOverlayEntry!.markNeedsBuild();
      return;
    }

    _searchOverlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _hideSearchOverlay,
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.transparent)),
            CompositedTransformFollower(
              link: _searchFieldLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 48),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                elevation: 10,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 320,
                  ),
                  child: SizedBox(
                    width: _searchBarWidth,
                    child: _buildSearchSuggestionContent(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_searchOverlayEntry!);
  }

  void _hideSearchOverlay() {
    _searchOverlayEntry?.remove();
    _searchOverlayEntry = null;
  }

  Widget _buildSearchSuggestionContent() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (_searchQuery.trim().length < 2) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          l10n.mapSearchMinCharsHint,
          style: GoogleFonts.inter(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (_isFetchingSuggestions) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_searchSuggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          l10n.commonNoSuggestions,
          style: GoogleFonts.inter(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: _searchSuggestions.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: scheme.outlineVariant,
      ),
      itemBuilder: (context, index) {
        final suggestion = _searchSuggestions[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            child: Icon(
              suggestion.icon,
              color: scheme.primary,
            ),
          ),
          title: Text(
            suggestion.label,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          subtitle: suggestion.subtitle == null
              ? null
              : Text(
                  suggestion.subtitle!,
                  style: GoogleFonts.inter(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
          onTap: () => _handleSuggestionTap(suggestion),
        );
      },
    );
  }

  List<_TrendingArtEntry> _getTrendingEntries(
    ArtworkProvider artworkProvider,
    List<CommunityPost> communityPosts,
  ) {
    final entries = <_TrendingArtEntry>[];
    final artworkMap = {for (final art in artworkProvider.artworks) art.id: art};

    for (final art in artworkProvider.artworks) {
      entries.add(_TrendingArtEntry(
        id: art.id,
        artworkId: art.id,
        title: art.title,
        subtitle: AppLocalizations.of(context)!.commonByArtist(art.artist),
        likes: art.likesCount,
        hasAR: art.arEnabled,
        score: _trendingScore(art),
      ));
    }

    for (final post in communityPosts) {
      final ref = post.artwork;
      if (ref?.id == null) continue;
      final artId = ref!.id;
      final boost = _communityEngagementScore(post);
      final idx = entries.indexWhere((e) => e.id == artId);
      if (idx != -1) {
        final existing = entries[idx];
        entries[idx] = existing.copyWith(
          score: existing.score + boost,
          likes: post.likeCount > 0 ? post.likeCount : existing.likes,
          subtitle: existing.subtitle?.isNotEmpty == true
              ? existing.subtitle
              : (post.authorUsername != null && post.authorUsername!.isNotEmpty
                  ? '@${post.authorUsername}'
                  : post.authorName),
        );
      } else {
        entries.add(
          _TrendingArtEntry(
            id: artId,
            artworkId: artId,
            title: ref.title,
            subtitle: post.authorUsername != null && post.authorUsername!.isNotEmpty
                ? '@${post.authorUsername}'
                : post.authorName,
            likes: post.likeCount,
            hasAR: artworkMap[artId]?.arEnabled ?? true,
            score: boost,
          ),
        );
      }
    }

    entries.sort((a, b) => b.score.compareTo(a.score));
    return entries.take(5).toList();
  }

  double _trendingScore(Artwork artwork) {
    final recencyDays = DateTime.now().difference(artwork.createdAt).inDays.clamp(0, 30);
    final recencyBoost = 1 + (30 - recencyDays) / 30;
    return (artwork.likesCount * 2 +
            artwork.viewsCount +
            artwork.discoveryCount * 1.5 +
            (artwork.averageRating ?? 0) * 10) *
        recencyBoost;
  }

  double _communityEngagementScore(CommunityPost post) {
    final recencyDays = DateTime.now().difference(post.timestamp).inDays.clamp(0, 30);
    final recencyBoost = 1 + (30 - recencyDays) / 30;
    return (post.likeCount * 2 +
            post.shareCount * 3 +
            post.commentCount * 1.5 +
            post.viewCount * 0.5) *
        recencyBoost;
  }

  List<Map<String, dynamic>> _buildTopCreatorSummaries(List<CommunityPost> communityPosts) {
    final creatorsMap = <String, _CreatorStats>{};
    final posts = communityPosts.take(50);

    for (final post in posts) {
      final key = post.authorWallet ?? post.authorId;
      if (key.isEmpty) continue;
      final stats = creatorsMap.putIfAbsent(
        key,
        () => _CreatorStats(
          id: post.authorId,
          wallet: post.authorWallet,
          name: post.authorName,
          avatar: post.authorAvatar,
          username: post.authorUsername,
        ),
      );
      stats.postCount += 1;
      stats.likeCount += post.likeCount;
      stats.shareCount += post.shareCount;
    }

    // Fallback when no community posts: derive creators from artworks
    if (creatorsMap.isEmpty) {
      final artworkProvider = context.read<ArtworkProvider>();
      for (final art in artworkProvider.artworks) {
        final key = art.artist;
        final stats = creatorsMap.putIfAbsent(
          key,
          () => _CreatorStats(
            id: key,
            name: art.artist,
            username: art.artist.toLowerCase().replaceAll(' ', '_'),
          ),
        );
        stats.postCount += 1;
        stats.likeCount += art.likesCount;
        stats.shareCount += art.viewsCount;
      }
    }

    final creators = creatorsMap.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return creators.take(5).map((c) => c.toMap()).toList();
  }
}

class _TrendingArtEntry {
  final String id;
  final String? artworkId;
  final String title;
  final String? subtitle;
  final int likes;
  final bool hasAR;
  final double score;

  const _TrendingArtEntry({
    required this.id,
    this.artworkId,
    required this.title,
    this.subtitle,
    required this.likes,
    this.hasAR = false,
    required this.score,
  });

  _TrendingArtEntry copyWith({
    String? title,
    String? subtitle,
    int? likes,
    bool? hasAR,
    double? score,
  }) {
    return _TrendingArtEntry(
      id: id,
      artworkId: artworkId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      likes: likes ?? this.likes,
      hasAR: hasAR ?? this.hasAR,
      score: score ?? this.score,
    );
  }
}

class _SearchSuggestion {
  final String label;
  final String type;
  final String? subtitle;
  final String? id;
  final LatLng? position;

  const _SearchSuggestion({
    required this.label,
    required this.type,
    this.subtitle,
    this.id,
    this.position,
  });

  IconData get icon {
    switch (type) {
      case 'profile':
        return Icons.account_circle_outlined;
      case 'institution':
        return Icons.museum_outlined;
      case 'event':
        return Icons.event_available;
      case 'marker':
        return Icons.location_on_outlined;
      case 'artwork':
      default:
        return Icons.auto_awesome;
    }
  }
}

class _CreatorStats {
  final String id;
  final String? wallet;
  final String name;
  final String? avatar;
  final String? username;
  int postCount;
  int likeCount;
  int shareCount;

  _CreatorStats({
    required this.id,
    this.wallet,
    required this.name,
    this.avatar,
    this.username,
  })  : postCount = 0,
        likeCount = 0,
        shareCount = 0;

  int get score => postCount * 2 + likeCount + shareCount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wallet': wallet,
      'name': name,
      'avatar': avatar,
      'username': username,
      'postCount': postCount,
    };
  }
}
