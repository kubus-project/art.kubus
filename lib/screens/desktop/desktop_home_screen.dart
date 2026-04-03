import 'dart:async';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/themeprovider.dart';
import '../../providers/web3provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/promotion_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/recent_activity_provider.dart';
import '../../providers/community_hub_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/stats_provider.dart';
import '../../config/config.dart';
import '../../models/artwork.dart';
import '../../models/recent_activity.dart';
import '../../models/user_persona.dart';
import '../../models/user_profile.dart';
import '../../models/wallet.dart';
import '../../models/promotion.dart';
import '../../community/community_interactions.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/artist_badge.dart';
import '../../widgets/institution_badge.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/inline_loading.dart';
import '../../widgets/topbar_icon.dart';
import '../../widgets/common/kubus_screen_header.dart';
import '../../widgets/detail/detail_shell_components.dart';
import '../../widgets/glass_components.dart';
import '../../widgets/profile_identity_summary.dart';
import '../../utils/app_animations.dart';
import '../../utils/activity_navigation.dart';
import '../../utils/artwork_navigation.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/design_tokens.dart';
import '../../utils/home_search_destination.dart';
import '../../utils/home_rail_creator_identity.dart';
import '../../utils/institution_navigation.dart';
import '../../utils/map_navigation.dart';
import '../../utils/media_url_resolver.dart';
import '../../utils/user_profile_navigation.dart';
import 'components/desktop_widgets.dart';
import 'components/desktop_notifications_panel.dart';
import '../web3/wallet/connectwallet_screen.dart';
import 'web3/desktop_wallet_screen.dart';
import '../onboarding/web3/web3_onboarding.dart' as web3;
import '../onboarding/web3/onboarding_data.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'community/desktop_profile_screen.dart';
import 'desktop_shell.dart';
import '../activity/advanced_analytics_screen.dart';
import '../home_screen.dart' show ActivityScreen;
import '../events/event_detail_screen.dart';
import '../events/exhibition_detail_screen.dart';
import '../../services/backend_api_service.dart';
import '../../services/share/share_deep_link_parser.dart';
import '../../services/share/share_types.dart';
import '../../services/user_service.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/creator_display_format.dart';
import '../../utils/share_deep_link_navigation.dart';
import '../../utils/wallet_utils.dart';
import '../../widgets/support/support_section.dart';
import '../../widgets/search/kubus_general_search.dart';
import '../../widgets/search/kubus_search_config.dart';
import '../../widgets/search/kubus_search_controller.dart';
import '../../widgets/search/kubus_search_result.dart';

@visibleForTesting
int resolveArtworksDiscoveredCount({
  required int statsCounterValue,
  required int profileCounterValue,
  required int localFallbackValue,
}) {
  final bestRemote = profileCounterValue > statsCounterValue
      ? profileCounterValue
      : statsCounterValue;
  if (bestRemote > 0) return bestRemote;
  return localFallbackValue;
}

/// Desktop home screen with spacious layout and proper grid systems
/// Inspired by Twitter/X feed presentation and Google Maps panels
class DesktopHomeScreen extends StatefulWidget {
  const DesktopHomeScreen({super.key});

  @override
  State<DesktopHomeScreen> createState() => _DesktopHomeScreenState();
}

class _DesktopHomeScreenState extends State<DesktopHomeScreen>
    with TickerProviderStateMixin {
  // Semantic colors now come from AppColorUtils - use:
  // AppColorUtils.tealAccent, .coralAccent, .greenAccent, .amberAccent, .purpleAccent

  static const double _searchBarWidth = 280;
  static const double _floatingSearchBarWidth = 240;
  late AnimationController _animationController;
  late ScrollController _scrollController;
  bool _showFloatingHeader = false;
  final BackendApiService _backendApi = BackendApiService();
  late final KubusSearchController _searchController;
  late FocusNode _primarySearchFocusNode;
  late FocusNode _floatingSearchFocusNode;
  bool _isResolvingLocation = false;
  List<CommunityPost> _popularCommunityPosts = const [];
  bool _popularCommunityLoading = false;
  bool _popularCommunityFetchFailed = false;
  bool _artFeedLoadQueued = false;
  bool _platformStatsPrefetchQueued = false;
  String _lastDiscoveredStatsWallet = '';
  String? _queuedDiscoveredStatsWallet;
  String _lastHomeRailsLocaleRefresh = '';

  final Map<String, ({String displayName, String? username})>
      _resolvedCreatorIdentityByWallet =
      <String, ({String displayName, String? username})>{};
  final Set<String> _creatorIdentityInFlight = <String>{};
  final Set<String> _pendingCreatorWallets = <String>{};
  Timer? _creatorResolveDebounce;

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
    _searchController = KubusSearchController(
      config: const KubusSearchConfig(
        scope: KubusSearchScope.home,
        limit: 8,
      ),
    );
    _primarySearchFocusNode = FocusNode();
    _floatingSearchFocusNode = FocusNode();

    // Initialize providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final recentActivity =
          Provider.of<RecentActivityProvider>(context, listen: false);
      if (!recentActivity.initialized) {
        recentActivity.initialize();
      }
      final navigationProvider =
          Provider.of<NavigationProvider>(context, listen: false);
      navigationProvider.initialize();
      _refreshHomeRails();
      _loadInitialData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedulePlatformStatsPrefetch();
    _refreshHomeRails();

    final walletAddress =
        (context.watch<WalletProvider>().currentWalletAddress ?? '').trim();
    if (walletAddress.isEmpty) {
      _lastDiscoveredStatsWallet = '';
      return;
    }
    if (walletAddress == _lastDiscoveredStatsWallet) return;
    _lastDiscoveredStatsWallet = walletAddress;
    _scheduleDiscoveredStatsPrefetch(walletAddress);
  }

  void _refreshHomeRails({bool force = false}) {
    if (!mounted) return;
    final locale = Localizations.localeOf(context).languageCode;
    final shouldForce = force || _lastHomeRailsLocaleRefresh != locale;
    _lastHomeRailsLocaleRefresh = locale;
    unawaited(
      context
          .read<PromotionProvider>()
          .loadHomeRails(locale: locale, force: shouldForce),
    );
  }

  Future<void> _copyWalletAddress(String walletAddress) async {
    if (walletAddress.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: walletAddress.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showKubusSnackBar(
      const SnackBar(content: Text('Wallet address copied')),
    );
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
      if (!mounted) return;
      _artFeedLoadQueued = false;
      final provider = context.read<CommunityHubProvider>();
      unawaited(provider.loadArtFeed(
        latitude: lat ?? provider.artFeedCenter?.lat ?? 46.05,
        longitude: lng ?? provider.artFeedCenter?.lng ?? 14.50,
        radiusKm: radiusKm ?? provider.artFeedRadiusKm,
        limit: limit ?? 20,
        refresh: true,
      ));
    });
  }

  void _schedulePlatformStatsPrefetch() {
    if (_platformStatsPrefetchQueued) return;
    _platformStatsPrefetchQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _platformStatsPrefetchQueued = false;
      if (!mounted) return;
      final statsProvider = context.read<StatsProvider>();
      unawaited(statsProvider.ensureSnapshot(
        entityType: 'platform',
        entityId: 'global',
        metrics: const <String>[
          'artworks',
          'arEnabledArtworks',
          'posts',
          'groups',
        ],
        scope: 'public',
      ));
    });
  }

  void _scheduleDiscoveredStatsPrefetch(String walletAddress) {
    final normalizedWallet = walletAddress.trim();
    if (normalizedWallet.isEmpty) return;
    if (_queuedDiscoveredStatsWallet == normalizedWallet) return;
    _queuedDiscoveredStatsWallet = normalizedWallet;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_queuedDiscoveredStatsWallet == normalizedWallet) {
        _queuedDiscoveredStatsWallet = null;
      }
      if (!mounted) return;
      final statsProvider = context.read<StatsProvider>();
      unawaited(statsProvider.ensureSnapshot(
        entityType: 'user',
        entityId: normalizedWallet,
        metrics: const <String>['artworksDiscovered'],
        scope: 'private',
      ));
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _creatorResolveDebounce?.cancel();
    _searchController.dispose();
    _primarySearchFocusNode.dispose();
    _floatingSearchFocusNode.dispose();
    super.dispose();
  }

  void _scheduleCreatorIdentityResolution(
    Iterable<String?> wallets, {
    bool forceRefresh = false,
  }) {
    final toAdd = <String>[];
    for (final raw in wallets) {
      final w = WalletUtils.canonical(raw);
      if (w.isEmpty) continue;
      if (!WalletUtils.looksLikeWallet(w)) continue;
      if (!forceRefresh && _resolvedCreatorIdentityByWallet.containsKey(w)) {
        continue;
      }
      if (_creatorIdentityInFlight.contains(w)) continue;
      toAdd.add(w);
    }

    if (toAdd.isEmpty) return;

    _pendingCreatorWallets.addAll(toAdd);
    _creatorResolveDebounce?.cancel();
    _creatorResolveDebounce = Timer(const Duration(milliseconds: 90), () {
      if (!mounted) return;
      final batch = _pendingCreatorWallets.toList(growable: false);
      _pendingCreatorWallets.clear();
      unawaited(_resolveCreatorIdentities(batch, forceRefresh: forceRefresh));
    });
  }

  Future<void> _resolveCreatorIdentities(
    List<String> wallets, {
    required bool forceRefresh,
  }) async {
    if (wallets.isEmpty) return;

    final targets = <String>[];
    for (final raw in wallets) {
      final w = WalletUtils.canonical(raw);
      if (w.isEmpty) continue;
      if (!forceRefresh && _resolvedCreatorIdentityByWallet.containsKey(w)) {
        continue;
      }
      if (_creatorIdentityInFlight.contains(w)) continue;
      _creatorIdentityInFlight.add(w);
      targets.add(w);
    }
    if (targets.isEmpty) return;

    if (kDebugMode) {
      debugPrint(
          'DesktopHomeScreen: resolving creator identities for ${targets.length} wallet(s)');
    }

    final updates = <String, ({String displayName, String? username})>{};
    try {
      final futures = targets.map((wallet) async {
        try {
          final user =
              await UserService.getUserById(wallet, forceRefresh: forceRefresh);
          final displayName = (user?.name ?? '').trim();
          var username = (user?.username ?? '').trim();
          if (username.startsWith('@')) username = username.substring(1);
          username = username.trim();
          if (displayName.isEmpty) return;
          updates[wallet] = (
            displayName: displayName,
            username: username.isEmpty ? null : username,
          );
        } catch (_) {}
      });
      await Future.wait(futures);
    } finally {
      for (final w in targets) {
        _creatorIdentityInFlight.remove(w);
      }
    }

    if (!mounted) return;
    if (updates.isEmpty) return;
    setState(() {
      _resolvedCreatorIdentityByWallet.addAll(updates);
    });
  }

  void _onScroll() {
    final shouldShowHeader = _scrollController.offset > 100;
    if (shouldShowHeader != _showFloatingHeader) {
      setState(() => _showFloatingHeader = shouldShowHeader);
    }
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    final artworkProvider = context.read<ArtworkProvider>();
    final communityProvider = context.read<CommunityHubProvider>();

    if (artworkProvider.artworks.isEmpty &&
        !artworkProvider.isLoading('load_artworks')) {
      await artworkProvider.loadArtworks();
    }

    if (!mounted) return;

    if (!communityProvider.groupsInitialized &&
        !communityProvider.groupsLoading) {
      await communityProvider.loadGroups();
    }

    if (!mounted) return;

    if (communityProvider.artFeedPosts.isEmpty &&
        !communityProvider.artFeedLoading) {
      final center = await _resolveArtFeedLocation();
      if (!mounted) return;
      await communityProvider.loadArtFeed(
        latitude: center.lat ?? 46.05,
        longitude: center.lng ?? 14.50,
        radiusKm: 50,
        limit: 50,
        refresh: true,
      );
    }

    await _loadPopularCommunityPosts();
  }

  Future<void> _loadPopularCommunityPosts({bool force = false}) async {
    if (_popularCommunityLoading) return;
    if (!force && _popularCommunityPosts.isNotEmpty) return;

    // This method can be awaited from other long async chains.
    // Guard before touching context to avoid "State no longer has a context"
    // crashes when the widget is disposed mid-flight (common on web routing).
    if (!mounted) return;

    setState(() {
      _popularCommunityLoading = true;
      _popularCommunityFetchFailed = false;
    });

    try {
      final posts =
          await _backendApi.getCommunityPosts(limit: 50, sort: 'popularity');
      if (!mounted) return;
      setState(() {
        _popularCommunityPosts = posts;
        _popularCommunityFetchFailed = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'DesktopHomeScreen: failed to load popular community posts: $e');
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

  void _refreshTrendingArtFeed() {
    final communityProvider = context.read<CommunityHubProvider>();
    _queueArtFeedLoad(
      lat: communityProvider.artFeedCenter?.lat,
      lng: communityProvider.artFeedCenter?.lng,
      radiusKm: communityProvider.artFeedRadiusKm,
      limit: 50,
    );
  }

  void _refreshTopCreators() {
    unawaited(_loadPopularCommunityPosts(force: true));
  }

  void _refreshPlatformStats() {
    final communityProvider = context.read<CommunityHubProvider>();
    unawaited(communityProvider.loadGroups(refresh: true));
    unawaited(_loadPopularCommunityPosts(force: true));

    final statsProvider = context.read<StatsProvider>();
    unawaited(statsProvider.ensureSnapshot(
      entityType: 'platform',
      entityId: 'global',
      metrics: const <String>[
        'artworks',
        'arEnabledArtworks',
        'posts',
        'groups',
      ],
      scope: 'public',
      forceRefresh: true,
    ));
  }

  Future<CommunityLocation> _resolveArtFeedLocation() async {
    if (_isResolvingLocation) return CommunityLocation(lat: 46.05, lng: 14.50);
    _isResolvingLocation = true;
    try {
      if (!AppConfig.enableLocationServices) {
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.lowest,
          timeLimit: Duration(seconds: 4),
        ),
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;
    final isMedium = screenWidth >= 900 && screenWidth < 1200;

    return Scaffold(
      backgroundColor: Colors.transparent,
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

              // Right sidebar (activity feed, trending, etc.) with glass effect
              if (isMedium || isLarge)
                SizedBox(
                  width: isLarge ? 380 : 320,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : scheme.outline.withValues(alpha: 0.10),
                          width: 1,
                        ),
                      ),
                    ),
                    child: LiquidGlassPanel(
                      padding: EdgeInsets.zero,
                      margin: EdgeInsets.zero,
                      borderRadius: BorderRadius.zero,
                      blurSigma: KubusGlassEffects.blurSigmaLight,
                      showBorder: false,
                      backgroundColor: scheme.surface
                          .withValues(alpha: isDark ? 0.16 : 0.10),
                      child: _buildRightSidebar(themeProvider),
                    ),
                  ),
                ),
            ],
          ),

          // Floating header on scroll
          if (_showFloatingHeader)
            _buildFloatingHeader(themeProvider, animationTheme),
          KubusSearchResultsOverlay(
            controller: _searchController,
            accentColor: themeProvider.accentColor,
            minCharsHint: AppLocalizations.of(context)!.mapSearchMinCharsHint,
            noResultsText: AppLocalizations.of(context)!.commonNoSuggestions,
            maxWidth: _searchBarWidth,
            onResultTap: (result) {
              unawaited(_handleSearchResultTap(result));
            },
          ),
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
                    padding: const EdgeInsets.fromLTRB(DetailSpacing.xxl, 0,
                        DetailSpacing.xxl, DetailSpacing.xl),
                    child: _buildWelcomeCard(),
                  ),
                ),

                // Stats grid
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(DetailSpacing.xxl, 0,
                        DetailSpacing.xxl, DetailSpacing.xxl),
                    child: _buildStatsGrid(),
                  ),
                ),

                // Quick actions
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(DetailSpacing.xxl, 0,
                        DetailSpacing.xxl, DetailSpacing.xxl),
                    child: _buildQuickActions(),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        DetailSpacing.xxl, 0, DetailSpacing.xxl, 56),
                    child: _buildHomeRails(),
                  ),
                ),

                // Support / Donate
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(DetailSpacing.xxl, 0,
                        DetailSpacing.xxl, DetailSpacing.xxl),
                    child: const SupportSectionCard(),
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
    final web3Provider = Provider.of<Web3Provider>(context);
    final user = profileProvider.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final isArtist = user?.isArtist ?? false;
    final isInstitution = user?.isInstitution ?? false;

    return Container(
      padding: const EdgeInsets.all(DetailSpacing.xxl),
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
                      const SizedBox(width: DetailSpacing.lg),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(l10n),
                            style: DetailTypography.caption(context),
                          ),
                          const SizedBox(height: DetailSpacing.xs),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                fit: FlexFit.loose,
                                child: Text(
                                  user?.displayName ??
                                      l10n.desktopHomeWelcomeFallbackName,
                                  style: KubusTextStyles.heroTitle.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                              if (isArtist) ...[
                                const SizedBox(width: DetailSpacing.sm),
                                const ArtistBadge(),
                              ],
                              if (isInstitution) ...[
                                const SizedBox(width: DetailSpacing.sm),
                                const InstitutionBadge(),
                              ],
                            ],
                          ),
                          if (web3Provider.isConnected) ...[
                            const SizedBox(height: KubusSpacing.xs),
                            Wrap(
                              spacing: KubusSpacing.sm,
                              runSpacing: KubusSpacing.xxs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(
                                      KubusRadius.sm,
                                    ),
                                    onTap: () => _copyWalletAddress(
                                      web3Provider.walletAddress,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: KubusSpacing.xxs,
                                        vertical: KubusSpacing.xxs,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            web3Provider.formatAddress(
                                              web3Provider.walletAddress,
                                            ),
                                            style: KubusTextStyles
                                                .screenSubtitle
                                                .copyWith(
                                              fontFamily: 'RobotoMono',
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.62),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: KubusSpacing.xxs,
                                          ),
                                          Icon(
                                            Icons.copy_rounded,
                                            size: KubusSpacing.md,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.45),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: KubusSpacing.sm,
                                    vertical: KubusSpacing.xxs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      KubusRadius.sm,
                                    ),
                                    border: Border.all(
                                      color:
                                          Colors.orange.withValues(alpha: 0.3),
                                      width: KubusSizes.hairline,
                                    ),
                                  ),
                                  child: Text(
                                    'DEVNET',
                                    style: KubusTypography.textTheme.labelSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                width: _searchBarWidth,
                child: KubusGeneralSearch(
                  controller: _searchController,
                  focusNode: _primarySearchFocusNode,
                  hintText: l10n.mapSearchHint,
                  semanticsLabel: 'desktop_home_search_input',
                  onSubmitted: _handleSearchSubmit,
                  autofocus: false,
                ),
              ),
              const SizedBox(width: DetailSpacing.lg),
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
        return TopBarIcon(
          tooltip: AppLocalizations.of(context)!.commonNotifications,
          badgeCount: np.unreadCount,
          badgeColor: AppColorUtils.amberAccent,
          size: KubusHeaderMetrics.actionHitArea,
          icon: Icon(
            Icons.notifications_outlined,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => _showNotificationsPanel(themeProvider, np),
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
        padding: const EdgeInsets.all(KubusSpacing.xxl),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              themeProvider.accentColor,
              themeProvider.accentColor.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(DetailRadius.xl),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.desktopHomeDiscoverArtTitle,
                    style: KubusTextStyles.heroTitle.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: DetailSpacing.md),
                  Text(
                    l10n.desktopHomeDiscoverArtDescription,
                    style: KubusTextStyles.heroSubtitle.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: DetailSpacing.xl),
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
                          horizontal: DetailSpacing.xl,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DetailRadius.md),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 56),
            // Decorative 3D cube/AR icon
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(DetailRadius.xl),
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
            _buildBalanceChip(
                'KUB8', kub8?.balance.toStringAsFixed(2) ?? '0.00'),
            const SizedBox(width: 16),
            _buildBalanceChip(
                'SOL', sol?.balance.toStringAsFixed(3) ?? '0.000'),
          ],
        );
      },
    );
  }

  Widget _buildBalanceChip(String symbol, String amount) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DetailSpacing.lg,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(DetailRadius.md),
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
                style: KubusTextStyles.navLabel.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Provider.of<ThemeProvider>(context).accentColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$amount $symbol',
            style: KubusTextStyles.actionTileTitle.copyWith(
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
    final statsProvider = context.watch<StatsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final isLoadingArtworks = artworkProvider.isLoading('load_artworks');
    final isLoadingActivity =
        activityProvider.isLoading && activityProvider.activities.isEmpty;

    final walletAddress = (walletProvider.currentWalletAddress ?? '').trim();
    const discoveredMetrics = <String>['artworksDiscovered'];
    final discoveredSnapshot = walletAddress.isEmpty
        ? null
        : statsProvider.getSnapshot(
            entityType: 'user',
            entityId: walletAddress,
            metrics: discoveredMetrics,
            scope: 'private',
          );
    final discoveredError = walletAddress.isEmpty
        ? null
        : statsProvider.snapshotError(
            entityType: 'user',
            entityId: walletAddress,
            metrics: discoveredMetrics,
            scope: 'private',
          );
    final discoveredLoading = walletAddress.isNotEmpty &&
        statsProvider.isSnapshotLoading(
          entityType: 'user',
          entityId: walletAddress,
          metrics: discoveredMetrics,
          scope: 'private',
        ) &&
        discoveredSnapshot == null &&
        discoveredError == null;
    if (walletAddress.isNotEmpty &&
        discoveredSnapshot == null &&
        !discoveredLoading) {
      _scheduleDiscoveredStatsPrefetch(walletAddress);
    }

    final discoveredFromStats =
        discoveredSnapshot?.counters['artworksDiscovered'] ?? 0;
    final discoveredFromProfile = profileProvider.artworksCount;
    final discoveredFromLocal =
        (discoveredFromStats == 0 && discoveredFromProfile == 0)
            ? artworkProvider.artworks.where((a) => a.isDiscovered).length
            : 0;

    final discoveredCount = resolveArtworksDiscoveredCount(
      statsCounterValue: discoveredFromStats,
      profileCounterValue: discoveredFromProfile,
      localFallbackValue: discoveredFromLocal,
    );

    final discoveredDisplayLoading = discoveredLoading &&
        discoveredFromProfile == 0 &&
        discoveredFromLocal == 0;

    final arSessions = activityProvider.activities
        .where((a) => a.category == ActivityCategory.ar)
        .length;
    final nftCount =
        walletProvider.tokens.where((t) => t.type == TokenType.nft).length;
    final kub8Token = walletProvider.tokens
        .where((t) => t.symbol.toUpperCase() == 'KUB8')
        .cast<Token?>()
        .firstWhere((_) => true, orElse: () => null);
    final kub8Earned = kub8Token != null
        ? kub8Token.formattedBalance
        : walletProvider.achievementTokenTotal.toStringAsFixed(2);

    final roles = KubusColorRoles.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: l10n.desktopHomeYourActivityTitle,
          subtitle: l10n.desktopHomeYourActivitySubtitle,
          icon: Icons.analytics_outlined,
          iconColor: AppColorUtils.coralAccent,
        ),
        const SizedBox(height: DetailSpacing.xl),
        if (isLoadingArtworks || isLoadingActivity)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: DetailSpacing.xl),
              child: InlineLoading(),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 48) / 4;

            return Wrap(
              spacing: DetailSpacing.lg,
              runSpacing: DetailSpacing.lg,
              children: [
                SizedBox(
                  width: cardWidth,
                  height: 160,
                  child: DesktopStatCard(
                    label: l10n.desktopHomeStatArtworksDiscovered,
                    value: discoveredDisplayLoading
                        ? '\u2026'
                        : discoveredCount.toString(),
                    icon: Icons.explore,
                    color: AppColorUtils.tealAccent,
                    centeredWatermarkAlignment: Alignment.center,
                    centeredWatermarkScale: 0.84,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  height: 160,
                  child: DesktopStatCard(
                    label: l10n.desktopHomeStatArSessions,
                    value: arSessions.toString(),
                    icon: Icons.view_in_ar,
                    color: AppColorUtils.purpleAccent,
                    centeredWatermarkAlignment: Alignment.center,
                    centeredWatermarkScale: 0.84,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  height: 160,
                  child: DesktopStatCard(
                    label: l10n.desktopHomeStatNftsCollected,
                    value: web3Provider.isConnected ? nftCount.toString() : '0',
                    icon: Icons.collections,
                    color: AppColorUtils.coralAccent,
                    centeredWatermarkAlignment: Alignment.center,
                    centeredWatermarkScale: 0.84,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  height: 160,
                  child: DesktopStatCard(
                    label: l10n.desktopHomeStatKub8Earned,
                    value: kub8Earned,
                    icon: Icons.monetization_on,
                    color: roles.achievementGold,
                    centeredWatermarkAlignment: Alignment.center,
                    centeredWatermarkScale: 0.84,
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
    final suggestedKeys = _suggestedQuickActionKeys(
            persona, profileProvider.currentUser)
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
          iconColor: AppColorUtils.amberAccent,
        ),
        const SizedBox(height: DetailSpacing.xl),
        if (quickScreens.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DesktopCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.touch_app,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      size: 40,
                    ),
                    const SizedBox(width: DetailSpacing.xl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.desktopHomeQuickActionsEmptyTitle,
                            style: DetailTypography.cardTitle(context),
                          ),
                          const SizedBox(height: DetailSpacing.xs),
                          Text(
                            l10n.desktopHomeQuickActionsEmptyDescription,
                            style: DetailTypography.body(context).copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (suggestedKeys.isNotEmpty) ...[
                const SizedBox(height: DetailSpacing.lg),
                Wrap(
                  spacing: DetailSpacing.md,
                  runSpacing: DetailSpacing.md,
                  children: suggestedKeys.map((key) {
                    final def = NavigationProvider.screenDefinitions[key]!;
                    return _buildQuickActionCard(
                      def.labelKey.resolve(l10n),
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
                  padding: const EdgeInsets.only(right: DetailSpacing.md),
                  child: _buildQuickActionCard(
                    screen.labelKey.resolve(l10n),
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

  List<String> _suggestedQuickActionKeys(
      UserPersona? persona, UserProfile? currentUser) {
    // Base suggestions by persona
    List<String> suggestions;
    switch (persona) {
      case UserPersona.lover:
        suggestions = const ['map', 'community', 'marketplace'];
        break;
      case UserPersona.creator:
        suggestions = const ['studio', 'ar', 'map'];
        break;
      case UserPersona.institution:
        suggestions = const ['institution_hub', 'map', 'community'];
        break;
      case null:
        suggestions = const ['map', 'studio', 'institution_hub'];
        break;
    }

    // If user has both badges, hide the one not currently active
    // If only one badge is active, show it; if both active, show the first one they earned
    final isArtist = currentUser?.isArtist ?? false;
    final isInstitution = currentUser?.isInstitution ?? false;

    if (isArtist && isInstitution) {
      // Both badges are active - hide institution_hub, keep studio
      suggestions =
          suggestions.where((key) => key != 'institution_hub').toList();
    } else if (isInstitution && !isArtist) {
      // Only institution badge is active - hide studio
      suggestions = suggestions.where((key) => key != 'studio').toList();
    } else if (isArtist && !isInstitution) {
      // Only artist badge is active - hide institution_hub
      suggestions =
          suggestions.where((key) => key != 'institution_hub').toList();
    }

    return suggestions;
  }

  void _handleQuickAction(String screenKey) {
    if (screenKey.isEmpty) return;
    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);

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
        _pushScreen(const ProfileScreen(), screenKey);
        return;
      case 'analytics':
        final shellScope = DesktopShellScope.of(context);
        Provider.of<NavigationProvider>(context, listen: false)
            .trackScreenVisit(screenKey);
        if (shellScope != null) {
          shellScope.pushSubScreen(
            title: _screenKeyToTitle(screenKey),
            child: const AdvancedAnalyticsScreen(
              statType: 'Engagement',
              embedded: true,
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AdvancedAnalyticsScreen(
                statType: 'Engagement',
              ),
            ),
          );
        }
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
    Provider.of<NavigationProvider>(context, listen: false)
        .trackScreenVisit(screenKey);
    // Use in-shell navigation if available, otherwise fallback to fullscreen
    final shellScope = DesktopShellScope.of(context);
    if (shellScope != null) {
      shellScope.pushSubScreen(
        title: _screenKeyToTitle(screenKey),
        child: screen,
      );
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }
  }

  void _pushDesktopSubScreen(String title, Widget screen) {
    final shellScope = DesktopShellScope.of(context);
    if (shellScope != null) {
      shellScope.pushSubScreen(title: title, child: screen);
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }
  }

  String _screenKeyToTitle(String key) {
    switch (key) {
      case 'profile':
        return AppLocalizations.of(context)!.navigationScreenProfile;
      case 'analytics':
        return 'Analytics';
      case 'achievements':
        return 'Achievements';
      case 'wallet':
        return 'Wallet';
      default:
        return key
            .split('_')
            .map((w) =>
                w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
            .join(' ');
    }
  }

  void _openShellTab(int index) {
    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);
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

  void _openUserProfile(String userId, String title) {
    unawaited(UserProfileNavigation.open(
      context,
      userId: userId,
      username: title,
    ));
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
    final lower = key.toLowerCase();
    if (lower == 'achievements') {
      return KubusColorRoles.of(context).achievementGold;
    }
    return AppColorUtils.featureColor(
      key,
      scheme,
      roles: KubusColorRoles.of(context),
    );
  }

  void _showARInfo() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DetailRadius.xl),
        ),
        title: Row(
          children: [
            Icon(Icons.view_in_ar,
                color: Theme.of(context).colorScheme.tertiary),
            const SizedBox(width: DetailSpacing.md),
            Text(
              l10n.arWebFallbackFeature,
              style: DetailTypography.cardTitle(context).copyWith(
                fontWeight: FontWeight.bold,
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
              style: DetailTypography.body(context).copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
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
                  borderRadius: BorderRadius.circular(DetailRadius.md),
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
                      style: KubusTextStyles.badgeCount.copyWith(
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: DetailSpacing.md),
          Text(
            title,
            style: KubusTextStyles.detailCardTitle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: DetailSpacing.sm),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeRails() {
    return Consumer<PromotionProvider>(
      builder: (context, promotionProvider, _) {
        final rails = promotionProvider.homeRails
            .map((rail) => MapEntry(rail, _renderableHomeRailItems(rail)))
            .where((entry) => entry.value.isNotEmpty)
            .toList(growable: false);
        if (promotionProvider.featuredLoading &&
            promotionProvider.homeRails.isEmpty) {
          return const SizedBox(
            height: 220,
            child: Center(
              child: InlineLoading(expand: false),
            ),
          );
        }
        if (rails.isEmpty) {
          final locale = Localizations.localeOf(context).languageCode;
          final hasError = (promotionProvider.error ?? '').trim().isNotEmpty;
          return EmptyStateCard(
            icon: hasError
                ? Icons.campaign_outlined
                : Icons.auto_awesome_mosaic_outlined,
            title: hasError
                ? 'Home rails unavailable'
                : 'Discovery rails are warming up',
            description: hasError
                ? 'We could not load ranked home rails right now.'
                : 'Featured artworks, artists, institutions, events, and exhibitions will appear here once ranked content is available.',
            showAction: hasError,
            actionLabel: hasError ? 'Retry' : null,
            onAction: hasError
                ? () {
                    context.read<PromotionProvider>().loadHomeRails(
                          locale: locale,
                          force: true,
                        );
                  }
                : null,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rails
              .map((entry) => Padding(
                    padding: EdgeInsets.only(
                      bottom: entry == rails.last ? 0 : DetailSpacing.xxl,
                    ),
                    child: _buildHomeRailSection(
                      entry.key,
                      entry.value,
                    ),
                  ))
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildHomeRailSection(
    HomeRail rail,
    List<HomeRailItem> items,
  ) {
    final title = switch (rail.entityType) {
      PromotionEntityType.artwork => 'Artworks',
      PromotionEntityType.profile => 'Artists',
      PromotionEntityType.institution => 'Institutions',
      PromotionEntityType.event => 'Events',
      PromotionEntityType.exhibition => 'Exhibitions',
    };
    final subtitle = switch (rail.entityType) {
      PromotionEntityType.artwork =>
        'Most viewed, interacted, and promoted artworks',
      PromotionEntityType.profile =>
        'Artist profiles ranked by activity and promotion',
      PromotionEntityType.institution =>
        'Institutions with active momentum and promotion',
      PromotionEntityType.event => 'Upcoming and promoted events',
      PromotionEntityType.exhibition => 'Upcoming and promoted exhibitions',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopSectionHeader(
          title: title,
          subtitle: subtitle,
          icon: _iconForHomeRail(rail.entityType),
          iconColor: rail.entityType == PromotionEntityType.artwork
              ? AppColorUtils.tealAccent
              : Colors.amber,
        ),
        const SizedBox(height: DetailSpacing.xl),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) =>
                _buildHomeRailCard(items[index], index, items.length),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeRailCard(HomeRailItem item, int index, int total) {
    if (item.entityType == PromotionEntityType.profile) {
      return _buildProfileHomeRailCard(item, index, total);
    }
    final subtitle = _buildHomeRailCardSubtitle(item);
    final canOpen = _hasHomeRailDestination(item);
    return DesktopCard(
      width: 240,
      margin: EdgeInsets.only(right: index < total - 1 ? DetailSpacing.lg : 0),
      padding: EdgeInsets.zero,
      onTap: canOpen ? () => _openHomeRailItem(item) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 140,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.22),
                        Theme.of(context)
                            .colorScheme
                            .secondary
                            .withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                  child: (() {
                    final resolvedImage =
                        MediaUrlResolver.resolve(item.imageUrl);
                    if (resolvedImage == null || resolvedImage.isEmpty) {
                      return Center(
                        child: Icon(
                          _iconForHomeRail(item.entityType),
                          size: 30,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.68),
                        ),
                      );
                    }
                    return Image.network(
                      resolvedImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    );
                  })(),
                ),
                if (item.promotion.isPromoted)
                  const Positioned(
                    top: 10,
                    left: 10,
                    child: Icon(Icons.star, color: Colors.amber, size: 18),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DetailSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTextStyles.detailCardTitle,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: DetailSpacing.xs),
                  subtitle,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHomeRailCard(HomeRailItem item, int index, int total) {
    final l10n = AppLocalizations.of(context)!;
    final identity = ProfileIdentityData.fromHomeRailItem(
      item,
      fallbackLabel: l10n.desktopHomeCreatorFallbackName,
    );
    final scheme = Theme.of(context).colorScheme;
    final canOpen = _hasHomeRailDestination(item);
    return DesktopCard(
      width: 240,
      margin: EdgeInsets.only(right: index < total - 1 ? DetailSpacing.lg : 0),
      padding: const EdgeInsets.all(DetailSpacing.lg),
      onTap: canOpen ? () => _openHomeRailItem(item) : null,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: ProfileIdentitySummary(
              identity: identity,
              layout: ProfileIdentityLayout.stacked,
              avatarRadius: 34,
              allowFabricatedFallback: true,
              titleStyle: KubusTextStyles.detailCardTitle,
              subtitleStyle: KubusTextStyles.navMetaLabel.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ),
          if (item.promotion.isPromoted)
            const Positioned(
              top: 0,
              left: 0,
              child: Icon(Icons.star, color: Colors.amber, size: 18),
            ),
        ],
      ),
    );
  }

  Widget? _buildHomeRailCardSubtitle(HomeRailItem item) {
    final scheme = Theme.of(context).colorScheme;
    final baseStyle = KubusTextStyles.navMetaLabel;
    if (item.entityType == PromotionEntityType.artwork) {
      final creatorIdentity = resolveArtworkHomeRailCreator(
        item,
        fallbackLabel:
            AppLocalizations.of(context)?.desktopHomeCreatorFallbackName ??
                'Creator',
      );
      if (creatorIdentity == null) return null;

      final creatorText = Text(
        creatorIdentity.label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: creatorIdentity.canOpenProfile
            ? baseStyle.copyWith(
                color: scheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: scheme.primary,
              )
            : baseStyle,
      );
      if (!creatorIdentity.canOpenProfile) {
        return creatorText;
      }
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(
            UserProfileNavigation.open(
              context,
              userId: creatorIdentity.userId!,
              username: creatorIdentity.username,
            ),
          ),
          child: creatorText,
        ),
      );
    }

    final subtitle = (item.subtitle ?? '').trim();
    if (subtitle.isEmpty) return null;
    return Text(
      subtitle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: baseStyle,
    );
  }

  IconData _iconForHomeRail(PromotionEntityType entityType) {
    return switch (entityType) {
      PromotionEntityType.artwork => Icons.palette_outlined,
      PromotionEntityType.profile => Icons.person_outline,
      PromotionEntityType.institution => Icons.apartment_outlined,
      PromotionEntityType.event => Icons.event_outlined,
      PromotionEntityType.exhibition => Icons.museum_outlined,
    };
  }

  List<HomeRailItem> _renderableHomeRailItems(HomeRail rail) {
    return rail.items.where(_canRenderHomeRailItem).toList(growable: false);
  }

  bool _canRenderHomeRailItem(HomeRailItem item) {
    return item.id.trim().isNotEmpty;
  }

  bool _hasHomeRailDestination(HomeRailItem item) {
    switch (item.entityType) {
      case PromotionEntityType.artwork:
      case PromotionEntityType.profile:
      case PromotionEntityType.event:
      case PromotionEntityType.exhibition:
        return item.id.trim().isNotEmpty;
      case PromotionEntityType.institution:
        return item.id.trim().isNotEmpty;
    }
  }

  Future<void> _openHomeRailItem(HomeRailItem item) async {
    switch (item.entityType) {
      case PromotionEntityType.artwork:
        await openArtwork(context, item.id, source: 'desktop_home_rail');
        return;
      case PromotionEntityType.profile:
        _openUserProfile(item.id, item.title);
        return;
      case PromotionEntityType.institution:
        await InstitutionNavigation.open(
          context,
          institutionId: item.id,
          profileTargetId: item.profileTargetId,
          data: item.raw,
          title: item.title,
        );
        return;
      case PromotionEntityType.event:
        _pushDesktopSubScreen(
          item.title,
          EventDetailScreen(eventId: item.id),
        );
        return;
      case PromotionEntityType.exhibition:
        _pushDesktopSubScreen(
          item.title,
          ExhibitionDetailScreen(exhibitionId: item.id),
        );
        return;
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

  Widget _buildRightSidebar(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(KubusSpacing.xxl),
      children: [
        Text(
          l10n.homeActivityTitle,
          style: KubusTextStyles.screenTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: DetailSpacing.xl),

        // Recent activity from provider
        _buildRecentActivitySection(themeProvider),
        const SizedBox(height: DetailSpacing.xxl),

        // Trending Art Section
        _buildTrendingArtSection(themeProvider),
        const SizedBox(height: DetailSpacing.xxl),

        // Top Creators Section
        _buildTopCreatorsSection(themeProvider),
        const SizedBox(height: DetailSpacing.xxl),

        // Platform Stats Section
        _buildPlatformStatsSection(themeProvider),
        const SizedBox(height: DetailSpacing.xl),
      ],
    );
  }

  Widget _buildSidebarSectionHeader({
    required String title,
    required VoidCallback onRefresh,
    bool isLoading = false,
    VoidCallback? onTitleTap,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final titleWidget = KubusHeaderText(
      title: title,
      kind: KubusHeaderKind.section,
      titleColor: scheme.onSurface,
    );

    return Row(
      children: [
        Expanded(
          child: onTitleTap == null
              ? titleWidget
              : InkWell(
                  onTap: onTitleTap,
                  borderRadius: BorderRadius.circular(DetailRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: DetailSpacing.xs,
                    ),
                    child: titleWidget,
                  ),
                ),
        ),
        IconButton(
          tooltip: l10n.commonRefresh,
          onPressed: isLoading ? null : onRefresh,
          icon: Icon(
            Icons.refresh,
            size: KubusHeaderMetrics.actionIcon,
            color: scheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  void _openFullActivity() {
    final shellScope = DesktopShellScope.of(context);
    if (shellScope != null) {
      shellScope.pushSubScreen(
        title: AppLocalizations.of(context)!.homeActivityTitle,
        child: const ActivityScreen(embedded: true),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ActivityScreen()),
      );
    }
  }

  Widget _buildTrendingArtSection(ThemeProvider themeProvider) {
    return Consumer2<ArtworkProvider, CommunityHubProvider>(
      builder: (context, artworkProvider, communityProvider, _) {
        final l10n = AppLocalizations.of(context)!;
        final feedPosts = communityProvider.artFeedPosts;

        final trendingEntries = _getTrendingEntries(artworkProvider, feedPosts);
        _scheduleCreatorIdentityResolution(
          trendingEntries.map((e) => e.creatorWallet),
        );
        final isLoading = (artworkProvider.isLoading('load_artworks') ||
                communityProvider.artFeedLoading) &&
            trendingEntries.isEmpty;
        final hasError = communityProvider.artFeedError != null &&
            feedPosts.isEmpty &&
            trendingEntries.isEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSidebarSectionHeader(
              title: l10n.desktopHomeTrendingArtTitle,
              isLoading: communityProvider.artFeedLoading,
              onRefresh: _refreshTrendingArtFeed,
              onTitleTap: () => _navigateToTab(6),
            ),
            const SizedBox(height: 12),
            if (isLoading)
              Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: themeProvider.accentColor,
                ),
              )
            else if (hasError)
              DesktopCard(
                onTap: _refreshTrendingArtFeed,
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.desktopHomeTrendingArtLoadFailed,
                        style: KubusTextStyles.sectionSubtitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (trendingEntries.isEmpty)
              DesktopCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.view_in_ar_outlined,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: DetailSpacing.md),
                    Expanded(
                      child: Text(
                        l10n.desktopHomeTrendingArtEmpty,
                        style: DetailTypography.body(context).copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...trendingEntries
                  .map((entry) => _buildTrendingArtItem(entry, themeProvider)),
          ],
        );
      },
    );
  }

  Widget _buildTrendingArtItem(
      _TrendingArtEntry entry, ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return DesktopCard(
      onTap: () {
        if (entry.artworkId != null && entry.artworkId!.isNotEmpty) {
          openArtwork(context, entry.artworkId!,
              source: 'desktop_home_trending');
        }
      },
      padding: const EdgeInsets.all(DetailSpacing.md),
      margin: const EdgeInsets.only(bottom: DetailSpacing.sm),
      borderRadius: BorderRadius.circular(DetailRadius.md),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColorUtils.tealAccent.withValues(alpha: 0.4),
                  AppColorUtils.tealAccent.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(DetailRadius.sm),
            ),
            child: Center(
              child: Icon(
                Icons.view_in_ar,
                color: AppColorUtils.tealAccent,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: DetailSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: KubusTextStyles.detailCardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  entry.subtitle ?? l10n.commonNotAvailableShort,
                  style: KubusTextStyles.navMetaLabel,
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
                  Icon(
                    Icons.favorite,
                    size: 14,
                    color: KubusColorRoles.of(context)
                        .likeAction
                        .withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: DetailSpacing.xs),
                  Text(
                    entry.likes.toString(),
                    style: KubusTextStyles.navMetaLabel.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (entry.hasAR)
                Container(
                  margin: const EdgeInsets.only(top: DetailSpacing.xs),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColorUtils.tealAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(DetailRadius.xs),
                  ),
                  child: Text(
                    l10n.commonArShort,
                    style: KubusTextStyles.compactBadge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColorUtils.tealAccent,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopCreatorsSection(ThemeProvider themeProvider) {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, _) {
        final l10n = AppLocalizations.of(context)!;
        final communityPosts = _popularCommunityPosts;

        final creators =
            _buildTopCreatorSummaries(communityPosts, artworkProvider);
        _scheduleCreatorIdentityResolution(
          creators.map((c) {
            final raw = c['wallet'] ?? c['id'];
            return raw?.toString();
          }),
        );
        final isLoading = _popularCommunityLoading &&
            _popularCommunityPosts.isEmpty &&
            creators.isEmpty;
        final hasError = _popularCommunityFetchFailed &&
            _popularCommunityPosts.isEmpty &&
            creators.isEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSidebarSectionHeader(
              title: l10n.desktopHomeTopCreatorsTitle,
              isLoading: _popularCommunityLoading,
              onRefresh: _refreshTopCreators,
              onTitleTap: () => _navigateToTab(2),
            ),
            const SizedBox(height: DetailSpacing.md),
            if (isLoading)
              Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: themeProvider.accentColor,
                ),
              )
            else if (hasError)
              DesktopCard(
                onTap: _refreshTopCreators,
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: DetailSpacing.md),
                    Expanded(
                      child: Text(
                        l10n.desktopHomeTopCreatorsLoadFailed,
                        style: DetailTypography.body(context),
                      ),
                    ),
                  ],
                ),
              )
            else if (creators.isEmpty)
              DesktopCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.people_outline,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: DetailSpacing.md),
                    Expanded(
                      child: Text(
                        l10n.desktopHomeTopCreatorsEmpty,
                        style: DetailTypography.body(context).copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...creators.map((creator) => _buildCreatorItem(creator)),
          ],
        );
      },
    );
  }

  Widget _buildCreatorItem(Map<String, dynamic> creator) {
    final l10n = AppLocalizations.of(context)!;
    final userId = (creator['id'] ?? creator['wallet'] ?? '').toString();
    final wallet = (creator['wallet'] ?? '').toString().isNotEmpty
        ? creator['wallet'].toString()
        : userId;
    final avatarUrl = creator['avatar'] ?? creator['avatarUrl'];

    final canonicalWallet = WalletUtils.canonical(wallet);
    final resolved = canonicalWallet.isNotEmpty
        ? _resolvedCreatorIdentityByWallet[canonicalWallet]
        : null;

    final formatted = CreatorDisplayFormat.format(
      fallbackLabel: l10n.desktopHomeCreatorFallbackName,
      displayName: resolved?.displayName ?? creator['name']?.toString(),
      username: resolved?.username ?? creator['username']?.toString(),
      wallet: canonicalWallet,
    );
    final displayName = formatted.primary;
    final handle = formatted.secondary;

    _scheduleCreatorIdentityResolution([canonicalWallet]);
    return DesktopCard(
      onTap: () {
        if (userId.isNotEmpty) {
          unawaited(UserProfileNavigation.open(context, userId: userId));
        }
      },
      padding: const EdgeInsets.all(DetailSpacing.sm + 2),
      margin: const EdgeInsets.only(bottom: DetailSpacing.sm),
      borderRadius: BorderRadius.circular(DetailRadius.md),
      child: ProfileIdentitySummary(
        identity: ProfileIdentityData.fromValues(
          fallbackLabel: l10n.desktopHomeCreatorFallbackName,
          displayName: displayName,
          username: handle,
          userId: userId,
          wallet: wallet,
          avatarUrl: avatarUrl?.toString(),
        ),
        layout: ProfileIdentityLayout.row,
        avatarRadius: 20,
        allowFabricatedFallback: true,
        titleStyle: KubusTextStyles.detailCardTitle,
        subtitleStyle: KubusTextStyles.navMetaLabel,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(DetailRadius.md),
          ),
          child: Text(
            l10n.desktopHomePostsCount(creator['postCount'] as int? ?? 0),
            style: KubusTextStyles.navMetaLabel.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformStatsSection(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;

    final statsProvider = context.watch<StatsProvider>();
    const metrics = <String>[
      'artworks',
      'arEnabledArtworks',
      'posts',
      'groups',
    ];

    final snapshot = statsProvider.getSnapshot(
      entityType: 'platform',
      entityId: 'global',
      metrics: metrics,
      scope: 'public',
    );
    final statsError = statsProvider.snapshotError(
      entityType: 'platform',
      entityId: 'global',
      metrics: metrics,
      scope: 'public',
    );
    final isRefreshing = statsProvider.isSnapshotLoading(
      entityType: 'platform',
      entityId: 'global',
      metrics: metrics,
      scope: 'public',
    );
    if (snapshot == null && !isRefreshing) {
      _schedulePlatformStatsPrefetch();
    }
    final isLoading = isRefreshing && snapshot == null;
    final hasError = statsError != null && snapshot == null;

    final counters = snapshot?.counters ?? const <String, int>{};
    final totalArtworks = counters['artworks'] ?? 0;
    final arEnabled = counters['arEnabledArtworks'] ?? 0;
    final posts = counters['posts'] ?? 0;
    final groups = counters['groups'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarSectionHeader(
          title: l10n.desktopHomePlatformStatsTitle,
          isLoading: isRefreshing,
          onRefresh: _refreshPlatformStats,
          onTitleTap: () => _navigateToTab(2),
        ),
        const SizedBox(height: DetailSpacing.md),
        if (isLoading)
          Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: themeProvider.accentColor,
            ),
          )
        else if (hasError)
          DesktopCard(
            onTap: _refreshPlatformStats,
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: DetailSpacing.md),
                Expanded(
                  child: Text(
                    l10n.desktopHomePlatformStatsLoadFailed,
                    style: DetailTypography.body(context),
                  ),
                ),
              ],
            ),
          )
        else
          DesktopCard(
            padding: const EdgeInsets.all(DetailSpacing.lg),
            child: Column(
              children: [
                _buildPlatformStatRow(
                  l10n.desktopHomePlatformStatsTotalArtworks,
                  totalArtworks.toString(),
                  Icons.view_in_ar,
                  AppColorUtils.tealAccent,
                ),
                const Divider(height: DetailSpacing.xl),
                _buildPlatformStatRow(
                  l10n.desktopHomePlatformStatsArEnabled,
                  arEnabled.toString(),
                  Icons.visibility,
                  AppColorUtils.purpleAccent,
                ),
                const Divider(height: DetailSpacing.xl),
                _buildPlatformStatRow(
                  l10n.desktopHomePlatformStatsCommunityPosts,
                  posts.toString(),
                  Icons.forum,
                  AppColorUtils.coralAccent,
                ),
                const Divider(height: DetailSpacing.xl),
                _buildPlatformStatRow(
                  l10n.desktopHomePlatformStatsActiveGroups,
                  groups.toString(),
                  Icons.groups,
                  themeProvider.accentColor,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPlatformStatRow(
      String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(DetailRadius.sm),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: DetailSpacing.md),
        Expanded(
          child: Text(
            label,
            style: KubusTextStyles.detailCaption.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
        ),
        Text(
          value,
          style: KubusTextStyles.actionTileTitle.copyWith(
            fontWeight: FontWeight.w700,
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
        final error = activityProvider.error;
        final isLoading = activityProvider.isLoading && activities.isEmpty;

        Widget content;
        if (isLoading) {
          content = Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: themeProvider.accentColor,
            ),
          );
        } else if (error != null && activities.isEmpty) {
          content = DesktopCard(
            onTap: () => unawaited(activityProvider.refresh(force: true)),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: DetailSpacing.md),
                Expanded(
                  child: Text(
                    l10n.homeUnableToLoadActivityTitle,
                    style: DetailTypography.body(context),
                  ),
                ),
              ],
            ),
          );
        } else if (activities.isEmpty) {
          content = DesktopCard(
            child: Row(
              children: [
                Icon(
                  Icons.timeline,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(width: DetailSpacing.md),
                Expanded(
                  child: Text(
                    l10n.homeNoRecentActivityDescription,
                    style: DetailTypography.body(context).copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          content = Column(
            children: activities
                .map((activity) => _buildActivityItem(activity))
                .toList(),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSidebarSectionHeader(
              title: l10n.homeRecentActivityTitle,
              isLoading: activityProvider.isLoading,
              onRefresh: () => unawaited(activityProvider.refresh(force: true)),
              onTitleTap: _openFullActivity,
            ),
            const SizedBox(height: DetailSpacing.md),
            content,
          ],
        );
      },
    );
  }

  Widget _buildActivityItem(RecentActivity activity) {
    final activityColor = _getActivityColor(activity.category);
    return DesktopCard(
      onTap: () => ActivityNavigation.open(context, activity),
      padding: const EdgeInsets.all(DetailSpacing.md),
      margin: const EdgeInsets.only(bottom: DetailSpacing.md),
      borderRadius: BorderRadius.circular(DetailRadius.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: activityColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(DetailRadius.sm),
            ),
            child: Icon(
              _getActivityIcon(activity.category),
              color: activityColor,
              size: 18,
            ),
          ),
          const SizedBox(width: DetailSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: KubusTextStyles.detailCaption.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  activity.description,
                  style: KubusTextStyles.detailCaption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns icon for activity category - delegates to centralized AppColorUtils
  /// Returns icon for activity category - delegates to centralized AppColorUtils
  IconData _getActivityIcon(ActivityCategory category) =>
      AppColorUtils.activityIcon(category);

  /// Get semantic color for activity/notification category - delegates to AppColorUtils
  Color _getActivityColor(ActivityCategory category) =>
      AppColorUtils.activityColorFor(category, Theme.of(context).colorScheme);

  Widget _buildFloatingHeader(
      ThemeProvider themeProvider, AppAnimationTheme animationTheme) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedPositioned(
      duration: animationTheme.short,
      curve: animationTheme.defaultCurve,
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.xl,
          vertical: KubusSpacing.md,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
          border: Border(
            bottom: BorderSide(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
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
              style: KubusTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: _floatingSearchBarWidth,
              child: KubusGeneralSearch(
                controller: _searchController,
                focusNode: _floatingSearchFocusNode,
                hintText: l10n.commonSearch,
                semanticsLabel: 'desktop_home_floating_search_input',
                onSubmitted: _handleSearchSubmit,
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
    final shellScope = DesktopShellScope.of(context);
    if (shellScope != null) {
      // Prefer the in-sidebar notifications panel on desktop.
      shellScope.openNotifications();
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

    await showKubusDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (dialogContext) {
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(
              top: KubusSpacing.xxl + KubusSpacing.xl,
              right: KubusSpacing.xl,
            ),
            child: SizedBox(
              width: 400,
              height: MediaQuery.of(dialogContext).size.height * 0.72,
              child: DesktopNotificationsPanel(
                onClose: () => Navigator.pop(dialogContext),
                onRefresh: () => activityProvider.refresh(force: true),
                onMarkAllRead: () => np.markViewed(),
                unreadOnly: true,
                visibleLimit: 10,
                onActivitySelected: (activity) async {
                  Navigator.pop(dialogContext);
                  await ActivityNavigation.open(context, activity);
                },
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    activityProvider.markAllReadLocally();
  }

  Future<void> _handleSearchSubmit(String value) async {
    final results = _searchController.state.results;
    if (value.trim().isEmpty || results.isEmpty) return;
    await _handleSearchResultTap(results.first);
  }

  Future<void> _handleSearchResultTap(KubusSearchResult result) async {
    _searchController.setQuery(context, result.label);
    _searchController.dismissOverlay();
    FocusScope.of(context).unfocus();

    if (result.position != null) {
      final communityProvider = context.read<CommunityHubProvider>();
      _queueArtFeedLoad(
        lat: result.position!.latitude,
        lng: result.position!.longitude,
        radiusKm: communityProvider.artFeedRadiusKm,
        limit: 50,
      );
    }

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    void showInvalidSelection() {
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(
            l10n?.activityNavigationUnableToOpenToast ??
                'Unable to open this item right now.',
          ),
        ),
      );
    }

    final markerId = result.markerId?.trim() ?? '';
    if (result.kind == KubusSearchResultKind.marker && markerId.isNotEmpty) {
      await ShareDeepLinkNavigation.open(
        context,
        ShareDeepLinkTarget(
          type: ShareEntityType.marker,
          id: markerId,
        ),
      );
      return;
    }

    final isMapSubjectResult =
        result.kind == KubusSearchResultKind.institution ||
            result.kind == KubusSearchResultKind.event;
    if (isMapSubjectResult && markerId.isNotEmpty && result.position == null) {
      await ShareDeepLinkNavigation.open(
        context,
        ShareDeepLinkTarget(
          type: ShareEntityType.marker,
          id: markerId,
        ),
      );
      return;
    }

    if (isMapSubjectResult && result.position != null) {
      MapNavigation.open(
        context,
        center: result.position!,
        zoom: 15,
        autoFollow: false,
        initialMarkerId: result.markerId,
        initialArtworkId: result.artworkId,
        initialSubjectId: result.subjectId,
        initialSubjectType: result.subjectType,
        initialTargetLabel: result.label,
      );
      return;
    }

    if (result.kind == KubusSearchResultKind.institution) {
      final institutionId = result.id?.trim() ?? '';
      final profileTargetId = InstitutionNavigation.resolveProfileTargetId(
        institutionId: institutionId,
        data: result.data,
      );
      if (institutionId.isNotEmpty || profileTargetId != null) {
        await InstitutionNavigation.open(
          context,
          institutionId: institutionId,
          profileTargetId: profileTargetId,
          data: result.data,
          title: result.label,
        );
        return;
      }
      if (result.position != null) {
        MapNavigation.open(
          context,
          center: result.position!,
          zoom: 15,
          autoFollow: false,
          initialSubjectId: institutionId.isNotEmpty ? institutionId : null,
          initialSubjectType: 'institution',
          initialTargetLabel: result.label,
        );
        return;
      }
    }

    final destination = HomeSearchDestination.fromResult(result);
    switch (destination.kind) {
      case HomeSearchDestinationKind.artwork:
        final resolvedId = destination.id?.trim() ?? '';
        if (resolvedId.isEmpty) {
          showInvalidSelection();
          return;
        }
        await openArtwork(context, resolvedId, source: 'desktop_home_search');
        return;
      case HomeSearchDestinationKind.profile:
        final resolvedId = destination.id?.trim() ?? '';
        if (resolvedId.isEmpty) {
          showInvalidSelection();
          return;
        }
        await UserProfileNavigation.open(context, userId: resolvedId);
        return;
      case HomeSearchDestinationKind.map:
        final position = destination.position;
        if (position == null) {
          showInvalidSelection();
          return;
        }
        MapNavigation.open(
          context,
          center: position,
          zoom: 15,
          autoFollow: false,
        );
        return;
      case HomeSearchDestinationKind.none:
        showInvalidSelection();
        return;
    }
  }

  List<_TrendingArtEntry> _getTrendingEntries(
    ArtworkProvider artworkProvider,
    List<CommunityPost> communityPosts,
  ) {
    final entries = <_TrendingArtEntry>[];
    final artworkMap = {
      for (final art in artworkProvider.artworks) art.id: art
    };

    for (final art in artworkProvider.artworks) {
      final walletFromField = WalletUtils.canonical(art.walletAddress);
      final wallet = walletFromField.isNotEmpty
          ? walletFromField
          : (WalletUtils.looksLikeWallet(art.artist)
              ? WalletUtils.canonical(art.artist)
              : '');
      final resolved =
          wallet.isNotEmpty ? _resolvedCreatorIdentityByWallet[wallet] : null;
      final formatted = CreatorDisplayFormat.format(
        fallbackLabel:
            AppLocalizations.of(context)!.desktopHomeCreatorFallbackName,
        displayName: resolved?.displayName ?? art.artist,
        username: resolved?.username,
        wallet: wallet,
      );
      final creatorLine = formatted.secondary == null
          ? formatted.primary
          : '${formatted.primary} • ${formatted.secondary!}';
      entries.add(_TrendingArtEntry(
        id: art.id,
        artworkId: art.id,
        title: art.title,
        subtitle: creatorLine.isNotEmpty
            ? creatorLine
            : AppLocalizations.of(context)!.commonNotAvailableShort,
        likes: art.likesCount,
        hasAR: art.arEnabled,
        score: _trendingScore(art),
        creatorWallet: wallet.isEmpty ? null : wallet,
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
        final wallet = WalletUtils.canonical(post.authorWallet);
        final resolved =
            wallet.isNotEmpty ? _resolvedCreatorIdentityByWallet[wallet] : null;
        final formatted = CreatorDisplayFormat.format(
          fallbackLabel:
              AppLocalizations.of(context)!.desktopHomeCreatorFallbackName,
          displayName: resolved?.displayName ?? post.authorName,
          username: resolved?.username ?? post.authorUsername,
          wallet: wallet,
        );
        final authorLine = formatted.secondary == null
            ? formatted.primary
            : '${formatted.primary} • ${formatted.secondary!}';
        entries[idx] = existing.copyWith(
          score: existing.score + boost,
          likes: post.likeCount > 0 ? post.likeCount : existing.likes,
          subtitle: existing.subtitle?.isNotEmpty == true
              ? existing.subtitle
              : authorLine,
          creatorWallet:
              existing.creatorWallet ?? (wallet.isEmpty ? null : wallet),
        );
      } else {
        final wallet = WalletUtils.canonical(post.authorWallet);
        final resolved =
            wallet.isNotEmpty ? _resolvedCreatorIdentityByWallet[wallet] : null;
        final formatted = CreatorDisplayFormat.format(
          fallbackLabel:
              AppLocalizations.of(context)!.desktopHomeCreatorFallbackName,
          displayName: resolved?.displayName ?? post.authorName,
          username: resolved?.username ?? post.authorUsername,
          wallet: wallet,
        );
        final authorLine = formatted.secondary == null
            ? formatted.primary
            : '${formatted.primary} • ${formatted.secondary!}';
        entries.add(
          _TrendingArtEntry(
            id: artId,
            artworkId: artId,
            title: ref.title,
            subtitle: authorLine,
            likes: post.likeCount,
            hasAR: artworkMap[artId]?.arEnabled ?? true,
            score: boost,
            creatorWallet: wallet.isEmpty ? null : wallet,
          ),
        );
      }
    }

    entries.sort((a, b) => b.score.compareTo(a.score));
    return entries.take(5).toList();
  }

  double _trendingScore(Artwork artwork) {
    final recencyDays =
        DateTime.now().difference(artwork.createdAt).inDays.clamp(0, 30);
    final recencyBoost = 1 + (30 - recencyDays) / 30;
    return (artwork.likesCount * 2 +
            artwork.viewsCount +
            artwork.discoveryCount * 1.5 +
            (artwork.averageRating ?? 0) * 10) *
        recencyBoost;
  }

  double _communityEngagementScore(CommunityPost post) {
    final recencyDays =
        DateTime.now().difference(post.timestamp).inDays.clamp(0, 30);
    final recencyBoost = 1 + (30 - recencyDays) / 30;
    return (post.likeCount * 2 +
            post.shareCount * 3 +
            post.commentCount * 1.5 +
            post.viewCount * 0.5) *
        recencyBoost;
  }

  List<Map<String, dynamic>> _buildTopCreatorSummaries(
      List<CommunityPost> communityPosts, ArtworkProvider artworkProvider) {
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
      final l10n = AppLocalizations.of(context)!;
      for (final art in artworkProvider.artworks) {
        final walletFromField = WalletUtils.canonical(art.walletAddress);
        final wallet = walletFromField.isNotEmpty
            ? walletFromField
            : (WalletUtils.looksLikeWallet(art.artist)
                ? WalletUtils.canonical(art.artist)
                : '');
        final resolved =
            wallet.isNotEmpty ? _resolvedCreatorIdentityByWallet[wallet] : null;
        final formatted = CreatorDisplayFormat.format(
          fallbackLabel: l10n.desktopHomeCreatorFallbackName,
          displayName: resolved?.displayName ?? art.artist,
          username: resolved?.username,
          wallet: wallet,
        );

        final key = wallet.isNotEmpty ? wallet : formatted.primary;
        final stats = creatorsMap.putIfAbsent(
          key,
          () => _CreatorStats(
            id: wallet.isNotEmpty ? wallet : key,
            wallet: wallet.isEmpty ? null : wallet,
            name: formatted.primary,
            username: resolved?.username,
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
  final String? creatorWallet;

  const _TrendingArtEntry({
    required this.id,
    this.artworkId,
    required this.title,
    this.subtitle,
    required this.likes,
    this.hasAR = false,
    required this.score,
    this.creatorWallet,
  });

  _TrendingArtEntry copyWith({
    String? title,
    String? subtitle,
    int? likes,
    bool? hasAR,
    double? score,
    String? creatorWallet,
  }) {
    return _TrendingArtEntry(
      id: id,
      artworkId: artworkId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      likes: likes ?? this.likes,
      hasAR: hasAR ?? this.hasAR,
      score: score ?? this.score,
      creatorWallet: creatorWallet ?? this.creatorWallet,
    );
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
