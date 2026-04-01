import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/themeprovider.dart';
import '../providers/web3provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/artwork_provider.dart';
import '../providers/promotion_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/recent_activity_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/stats_provider.dart';
import '../models/artwork.dart';
import '../models/recent_activity.dart';
import '../models/user_persona.dart';
import '../models/user_profile.dart';
import '../models/promotion.dart';
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
import '../widgets/avatar_widget.dart';
import '../widgets/topbar_icon.dart';
import '../utils/activity_navigation.dart';
import '../widgets/artist_badge.dart';
import '../widgets/institution_badge.dart';
import '../widgets/artwork_creator_byline.dart';
import '../widgets/inline_loading.dart';
import '../widgets/enhanced_stats_chart.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/recent_activity_tile.dart';
import 'activity/advanced_analytics_screen.dart';
import 'map_screen.dart';
import '../services/stats_api_service.dart';
import '../models/stats/stats_models.dart';
import '../utils/app_animations.dart';
import '../utils/app_color_utils.dart';
import '../utils/kubus_color_roles.dart';
import '../utils/artwork_media_resolver.dart';
import '../utils/design_tokens.dart';
import '../utils/keyboard_inset_resolver.dart';
import '../utils/kubus_labs_feature.dart';
import '../utils/user_profile_navigation.dart';
import '../utils/home_search_destination.dart';
import '../widgets/staggered_fade_slide.dart';
import '../utils/artwork_navigation.dart';
import '../services/search_service.dart';
import '../widgets/glass_components.dart';
import '../widgets/common/kubus_labs_adornment.dart';
import '../widgets/common/kubus_screen_header.dart';
import '../widgets/search/kubus_search_bar.dart';
import '../widgets/support/support_section.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import '../features/map/search/map_search_controller.dart';
import '../utils/map_search_suggestion.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late final MapSearchController _homeSearchController;

  @override
  void initState() {
    super.initState();
    _homeSearchController = MapSearchController(
      scope: SearchScope.home,
      limit: 8,
      showOverlayOnFocus: false,
    );
    _animationController = AnimationController(
      duration: AppAnimationTheme.defaults.long,
      vsync: this,
    );
    _animationController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final locale = Localizations.localeOf(context).languageCode;
      unawaited(
        context.read<PromotionProvider>().loadFeaturedHome(locale: locale),
      );
    });
  }

  @override
  void dispose() {
    _homeSearchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animationTheme = context.animationTheme;
    final keyboardVisible = KeyboardInsetResolver.isKeyboardVisible(context);
    final bottomSafeInset = MediaQuery.of(context).padding.bottom;
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
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: fadeAnimation,
                  child: SlideTransition(
                    position: slideAnimation,
                    child: CustomScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        _buildAppBar(),
                        SliverLayoutBuilder(
                          builder: (context, constraints) {
                            final screenWidth = constraints.crossAxisExtent;
                            final isSmallScreen = screenWidth < 375;
                            final padding = isSmallScreen ? 16.0 : 24.0;
                            final spacing = isSmallScreen ? 16.0 : 24.0;

                            return SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                padding,
                                padding,
                                padding,
                                padding +
                                    (keyboardVisible
                                        ? 0
                                        : KubusLayout.mainBottomNavBarHeight +
                                            bottomSafeInset),
                              ),
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
            _buildHomeSearchOverlay(),
          ],
        ),
      ),
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
    sections.add(SizedBox(height: spacing));
    sections.add(animated(_buildFeaturedProfiles()));
    sections.add(SizedBox(height: spacing));
    sections.add(animated(const SupportSectionCard()));

    return sections;
  }

  Widget _buildAppBar() {
    final web3Provider = Provider.of<Web3Provider>(context);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      expandedHeight: 148,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 375;

          return Stack(
            fit: StackFit.expand,
            children: [
              KubusGlassAppBarBackdrop(showBottomDivider: true),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isSmallScreen
                        ? KubusHeaderMetrics.appBarHorizontalPadding
                        : KubusHeaderMetrics.appBarHorizontalPaddingLg,
                    KubusHeaderMetrics.appBarVerticalPadding,
                    isSmallScreen
                        ? KubusHeaderMetrics.appBarHorizontalPadding
                        : KubusHeaderMetrics.appBarHorizontalPaddingLg,
                    KubusHeaderMetrics.appBarVerticalPadding,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          AppLogo(
                            width: isSmallScreen
                                ? KubusHeaderMetrics.compactLogo
                                : KubusHeaderMetrics.logo,
                            height: isSmallScreen
                                ? KubusHeaderMetrics.compactLogo
                                : KubusHeaderMetrics.logo,
                          ),
                          SizedBox(
                              width: isSmallScreen
                                  ? KubusSpacing.sm
                                  : KubusSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                KubusHeaderText(
                                  title: 'art.kubus',
                                  kind: KubusHeaderKind.section,
                                  compact: true,
                                  titleColor: scheme.onSurface,
                                  maxTitleLines: 1,
                                ),
                                if (web3Provider.isConnected)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: KubusSpacing.xxs,
                                    ),
                                    child: Wrap(
                                      spacing: KubusSpacing.sm,
                                      runSpacing: KubusSpacing.xxs,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: KubusSpacing.xxs,
                                                vertical: KubusSpacing.xxs,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    web3Provider.formatAddress(
                                                      web3Provider
                                                          .walletAddress,
                                                    ),
                                                    style:
                                                        GoogleFonts.robotoMono(
                                                      fontSize:
                                                          KubusHeaderMetrics
                                                              .sectionSubtitle,
                                                      color: scheme.onSurface
                                                          .withValues(
                                                        alpha: 0.6,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    width: KubusSpacing.xxs,
                                                  ),
                                                  Icon(
                                                    Icons.copy_rounded,
                                                    size: KubusSpacing.md,
                                                    color: scheme.onSurface
                                                        .withValues(
                                                      alpha: 0.45,
                                                    ),
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
                                            color: Colors.orange
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              KubusRadius.sm,
                                            ),
                                            border: Border.all(
                                              color: Colors.orange
                                                  .withValues(alpha: 0.3),
                                              width: KubusSizes.hairline,
                                            ),
                                          ),
                                          child: Text(
                                            'DEVNET',
                                            style: KubusTypography
                                                .textTheme.labelSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Consumer<NotificationProvider>(
                            builder: (context, np, _) => TopBarIcon(
                              tooltip: l10n.commonNotifications,
                              icon: Icon(
                                Icons.notifications_outlined,
                                color: scheme.onSurface,
                                size: KubusHeaderMetrics.actionIcon,
                              ),
                              onPressed: () {
                                _showNotificationsBottomSheet(context);
                              },
                              badgeCount: np.unreadCount,
                              badgeColor: Provider.of<ThemeProvider>(context)
                                  .accentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KubusSpacing.md),
                      _buildHomeSearchSection(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHomeSearchSection() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = Provider.of<ThemeProvider>(context).accentColor;
    final surfaceStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.button,
      tintBase: scheme.surface,
    );

    return ListenableBuilder(
      listenable: _homeSearchController,
      builder: (context, _) {
        final query = _homeSearchController.state.query;
        final hasText = query.trim().isNotEmpty;

        return CompositedTransformTarget(
          link: _homeSearchController.fieldLink,
          child: SizedBox(
            height: KubusHeaderMetrics.searchBarHeight,
            child: KubusSearchBar(
              semanticsLabel: 'home_search_input',
              hintText: AppLocalizations.of(context)!.commonSearchHint,
              controller: _homeSearchController.textController,
              focusNode: _homeSearchController.focusNode,
              onChanged: (value) =>
                  _homeSearchController.onQueryChanged(context, value),
              onSubmitted: (_) => _handleHomeSearchSubmit(),
              trailingBuilder: (context, _) {
                if (!hasText) return const SizedBox.shrink();
                return IconButton(
                  tooltip:
                      MaterialLocalizations.of(context).deleteButtonTooltip,
                  icon: Icon(
                    Icons.close,
                    color: scheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    _homeSearchController.clearQueryWithContext(context);
                  },
                );
              },
              style: KubusSearchBarStyle(
                borderRadius: BorderRadius.circular(KubusRadius.lg),
                backgroundColor: surfaceStyle.tintColor,
                borderColor: scheme.outline.withValues(alpha: 0.18),
                focusedBorderColor: accent,
                borderWidth: 1,
                focusedBorderWidth: 2,
                blurSigma: null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.md,
                  vertical: KubusSpacing.md - KubusSpacing.xxs,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
                focusedBoxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.14),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
                prefixIconConstraints: const BoxConstraints(
                  minWidth: KubusHeaderMetrics.actionHitArea,
                  minHeight: KubusHeaderMetrics.actionHitArea,
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: KubusHeaderMetrics.actionHitArea,
                  minHeight: KubusHeaderMetrics.actionHitArea,
                ),
                textStyle: KubusTypography.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                ),
                hintStyle: KubusTypography.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHomeSearchOverlay() {
    return ListenableBuilder(
      listenable: _homeSearchController,
      builder: (context, _) {
        final state = _homeSearchController.state;
        if (!state.isOverlayVisible) {
          return const SizedBox.shrink();
        }

        return KubusSearchSuggestionsOverlay(
          link: _homeSearchController.fieldLink,
          query: state.query,
          isFetching: state.isFetching,
          suggestions: state.suggestions,
          accentColor: Provider.of<ThemeProvider>(context).accentColor,
          minCharsHint: AppLocalizations.of(context)!.mapSearchMinCharsHint,
          noResultsText: AppLocalizations.of(context)!.commonNoSuggestions,
          onDismiss: () => _homeSearchController.dismissOverlay(),
          onSuggestionTap: (suggestion) {
            unawaited(_handleHomeSearchSuggestionTap(suggestion));
          },
        );
      },
    );
  }

  void _handleHomeSearchSubmit() {
    final query = _homeSearchController.state.query.trim();
    final suggestions = _homeSearchController.state.suggestions;
    _homeSearchController.onSubmitted();
    if (query.isEmpty) return;
    if (suggestions.isNotEmpty) {
      unawaited(_handleHomeSearchSuggestionTap(suggestions.first));
    }
  }

  Future<void> _handleHomeSearchSuggestionTap(
    MapSearchSuggestion suggestion,
  ) async {
    _homeSearchController.textController.text = suggestion.label;
    _homeSearchController.textController.selection =
        TextSelection.collapsed(offset: suggestion.label.length);
    _homeSearchController.onQueryChanged(context, suggestion.label);
    _homeSearchController.dismissOverlay(unfocus: true);

    final destination = HomeSearchDestination.fromSuggestion(suggestion);
    switch (destination.kind) {
      case HomeSearchDestinationKind.artwork:
        await openArtwork(context, destination.id!, source: 'home_search');
        return;
      case HomeSearchDestinationKind.profile:
        await UserProfileNavigation.open(context, userId: destination.id!);
        return;
      case HomeSearchDestinationKind.map:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MapScreen(
              initialCenter: destination.position!,
              initialZoom: 15,
              autoFollow: false,
            ),
          ),
        );
        return;
      case HomeSearchDestinationKind.none:
        return;
    }
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
        final padding = isSmallScreen
            ? KubusChromeMetrics.compactCardPadding
            : KubusSpacing.lg;
        final iconBox = isSmallScreen
            ? KubusChromeMetrics.heroIconBox - KubusSpacing.sm
            : KubusChromeMetrics.heroIconBox;
        final iconSize = isSmallScreen
            ? KubusChromeMetrics.heroIcon - KubusSpacing.xs
            : KubusChromeMetrics.heroIcon;

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
                                style: KubusTextStyles.heroTitle
                                    .copyWith(color: Colors.white),
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
                          style: KubusTextStyles.heroSubtitle.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: iconBox,
                    height: iconBox,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(KubusRadius.lg),
                    ),
                    child: Icon(
                      Icons.view_in_ar,
                      color: Colors.white,
                      size: iconSize,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: isSmallScreen
                    ? KubusSpacing.md
                    : KubusChromeMetrics.cardPadding,
              ),
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
                    style: KubusTextStyles.actionTileTitle.copyWith(
                      fontSize: isSmallScreen
                          ? KubusChromeMetrics.navMetaLabel
                          : KubusChromeMetrics.navLabel,
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
        padding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.sm + KubusSpacing.xs,
          vertical: KubusSpacing.xs + KubusSpacing.xxs,
        ),
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
                  style: KubusTextStyles.badgeCount.copyWith(
                    color: Provider.of<ThemeProvider>(context).accentColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$amount $symbol',
              style: KubusTextStyles.navMetaLabel.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
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
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final glassTint =
            scheme.surface.withValues(alpha: isDark ? 0.16 : 0.10);
        final frequentScreens =
            navigationProvider.getQuickActionScreens(maxItems: 12);
        final persona = profileProvider.userPersona;
        final suggestedKeys = _suggestedQuickActionKeys(
                persona, profileProvider.currentUser)
            .where(
                (key) => NavigationProvider.screenDefinitions.containsKey(key))
            .toList(growable: false);
        final isCompactLayout = constraints.maxWidth < 640;
        final compactCardWidth =
            ((constraints.maxWidth - KubusSpacing.sm) / 2).clamp(140.0, 220.0);

        Widget buildActionStrip(List<Widget> children) {
          if (!isCompactLayout) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: children),
            );
          }

          return Wrap(
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.sm,
            children: children,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.homeQuickActionsTitle,
                  style: KubusTextStyles.screenTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (frequentScreens.isNotEmpty)
                  Text(
                    l10n.homeRecentlyUsedLabel,
                    style: KubusTextStyles.screenSubtitle.copyWith(
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
                  LiquidGlassPanel(
                    padding:
                        const EdgeInsets.all(KubusChromeMetrics.cardPadding),
                    margin: EdgeInsets.zero,
                    borderRadius: BorderRadius.circular(16),
                    blurSigma: KubusGlassEffects.blurSigmaLight,
                    backgroundColor: glassTint,
                    child: Row(
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            l10n.homeQuickActionsEmptyDescription,
                            style: KubusTextStyles.sectionSubtitle.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (suggestedKeys.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    buildActionStrip(
                      suggestedKeys.map((key) {
                        final def = NavigationProvider.screenDefinitions[key]!;
                        return Padding(
                          padding: EdgeInsets.only(
                            right: isCompactLayout ? 0 : KubusSpacing.sm,
                          ),
                          child: SizedBox(
                            width: isCompactLayout ? compactCardWidth : null,
                            child: _buildActionCard(
                              def.labelKey.resolve(l10n),
                              def.icon,
                              AppColorUtils.featureColor(
                                key,
                                scheme,
                                roles: KubusColorRoles.of(context),
                              ),
                              isCompactLayout,
                              onTap: () => navigationProvider.navigateToScreen(
                                context,
                                key,
                              ),
                              visitCount: 0,
                            ),
                          ),
                        );
                      }).toList(growable: false),
                    ),
                  ],
                ],
              )
            else
              buildActionStrip(
                frequentScreens.map((screen) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: isCompactLayout ? 0 : KubusSpacing.sm,
                    ),
                    child: SizedBox(
                      width: isCompactLayout ? compactCardWidth : null,
                      child: _buildActionCard(
                        screen.labelKey.resolve(l10n),
                        screen.icon,
                        AppColorUtils.featureColor(
                          screen.key,
                          scheme,
                          roles: KubusColorRoles.of(context),
                        ),
                        isCompactLayout,
                        onTap: () => navigationProvider.navigateToScreen(
                            context, screen.key),
                        visitCount: screen.visitCount,
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

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    bool isSmallScreen, {
    required VoidCallback onTap,
    int visitCount = 0,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: scheme.surface,
    );
    final radius = BorderRadius.circular(16);
    final cardWidth = isSmallScreen ? 176.0 : 192.0;
    final cardHeight = isSmallScreen ? 116.0 : 96.0;
    final iconSize = isSmallScreen ? 18.0 : 20.0;
    final iconBoxSize = isSmallScreen ? 44.0 : 40.0;

    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: color.withValues(alpha: 0.22),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.10 : 0.08,
              ),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LiquidGlassCard(
          onTap: onTap,
          padding: EdgeInsets.zero,
          margin: EdgeInsets.zero,
          borderRadius: radius,
          blurSigma: style.blurSigma,
          showBorder: false,
          backgroundColor: style.tintColor,
          fallbackMinOpacity: style.fallbackMinOpacity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? KubusSpacing.md : KubusSpacing.lg,
                  vertical: isSmallScreen ? KubusSpacing.sm : KubusSpacing.md,
                ),
                child: Center(
                  child: isSmallScreen
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildQuickActionIconBadge(
                              color: color,
                              icon: icon,
                              iconBoxSize: iconBoxSize,
                              iconSize: iconSize,
                              visitCount: visitCount,
                            ),
                            const SizedBox(height: KubusSpacing.sm),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: KubusTextStyles.sectionTitle.copyWith(
                                fontSize: KubusHeaderMetrics.sectionSubtitle,
                                color: scheme.onSurface,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildQuickActionIconBadge(
                              color: color,
                              icon: icon,
                              iconBoxSize: iconBoxSize,
                              iconSize: iconSize,
                              visitCount: visitCount,
                            ),
                            const SizedBox(width: 14),
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: KubusTextStyles.sectionTitle.copyWith(
                                  fontSize: KubusHeaderMetrics.sectionTitle,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
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

  Widget _buildQuickActionIconBadge({
    required Color color,
    required IconData icon,
    required double iconBoxSize,
    required double iconSize,
    required int visitCount,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: iconBoxSize,
          height: iconBoxSize,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.26),
                color.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: iconSize,
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
                style: KubusTextStyles.badgeCount.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatIconBadge(Color statColor, IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statColor.withValues(alpha: 0.24),
            statColor.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(
          color: statColor.withValues(alpha: 0.22),
          width: KubusSizes.hairline,
        ),
      ),
      child: Icon(icon, color: statColor, size: 20),
    );
  }

  Widget _buildStatsCards() {
    return Consumer2<ProfileProvider, StatsProvider>(
      builder: (context, profileProvider, statsProvider, child) {
        final l10n = AppLocalizations.of(context)!;
        final wallet =
            (profileProvider.currentUser?.walletAddress ?? '').trim();

        if (wallet.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.homeYourStatsTitle,
                style: KubusTextStyles.screenTitle.copyWith(
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

        // Best-effort: trigger snapshot fetch and render cached values immediately.
        statsProvider.ensureSnapshot(
          entityType: 'user',
          entityId: wallet,
          metrics: const ['artworks', 'followers', 'viewsReceived'],
          scope: 'public',
        );

        final snapshot = statsProvider.getSnapshot(
          entityType: 'user',
          entityId: wallet,
          metrics: const ['artworks', 'followers', 'viewsReceived'],
          scope: 'public',
        );

        final isLoading = statsProvider.isSnapshotLoading(
          entityType: 'user',
          entityId: wallet,
          metrics: const ['artworks', 'followers', 'viewsReceived'],
          scope: 'public',
        );

        final error = statsProvider.snapshotError(
          entityType: 'user',
          entityId: wallet,
          metrics: const ['artworks', 'followers', 'viewsReceived'],
          scope: 'public',
        );

        String displayCounter(String key) {
          if (snapshot != null) {
            final v = (snapshot.counters[key] ?? 0);
            return _formatCompactCount(v);
          }
          if (isLoading) return 'â€¦';
          if (error != null) return 'â€”';
          return '0';
        }

        final stats = [
          ('artworks', displayCounter('artworks'), Icons.image),
          ('followers', displayCounter('followers'), Icons.people),
          ('views', displayCounter('viewsReceived'), Icons.visibility),
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
                  style: KubusTextStyles.screenTitle.copyWith(
                    fontSize: isSmallScreen
                        ? KubusHeaderMetrics.sectionTitle + KubusSpacing.xxs
                        : KubusHeaderMetrics.screenTitle,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(
                  height: isSmallScreen
                      ? KubusSpacing.sm + KubusSpacing.xs
                      : KubusSpacing.md,
                ),
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
                          padding: EdgeInsets.only(
                            right: entry.key < stats.length - 1
                                ? KubusSpacing.sm
                                : KubusSpacing.none,
                          ),
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

  String _formatCompactCount(int value) {
    if (value >= 1000000) {
      final v = (value / 1000000.0);
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      final v = (value / 1000.0);
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}k';
    }
    return value.toString();
  }

  double _statCardHeight({
    required bool showIconOnly,
    required bool isVerticalLayout,
  }) {
    if (isVerticalLayout) return 84;
    if (showIconOnly) return 112;
    return 104;
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      {Color? color,
      bool showIconOnly = false,
      bool isVerticalLayout = false}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statColor = color ?? AppColorUtils.featureColor(title, scheme);
    final l10n = AppLocalizations.of(context)!;
    final displayTitle = _getStatDisplayTitle(title, l10n);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 375;
        final radius = BorderRadius.circular(isSmallScreen ? 10 : 12);
        final style = KubusGlassStyle.resolve(
          context,
          surfaceType: KubusGlassSurfaceType.card,
          tintBase: scheme.surface,
        );

        return SizedBox(
          width: isVerticalLayout ? double.infinity : null,
          height: _statCardHeight(
            showIconOnly: showIconOnly,
            isVerticalLayout: isVerticalLayout,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: statColor.withValues(alpha: 0.22),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: statColor.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.10 : 0.08,
                  ),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: LiquidGlassCard(
              onTap: () => _showStatsDialog(title, icon),
              padding: EdgeInsets.zero,
              margin: EdgeInsets.zero,
              borderRadius: radius,
              blurSigma: style.blurSigma,
              showBorder: false,
              backgroundColor: style.tintColor,
              fallbackMinOpacity: style.fallbackMinOpacity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              statColor.withValues(alpha: 0.14),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                    child: Center(
                      child: showIconOnly
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildStatIconBadge(statColor, icon),
                                SizedBox(height: isSmallScreen ? 4 : 6),
                                Text(
                                  displayTitle,
                                  style: KubusTextStyles.compactBadge.copyWith(
                                    fontSize: isSmallScreen
                                        ? KubusChromeMetrics.navBadgeLabel - 1
                                        : KubusChromeMetrics.navBadgeLabel,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.68),
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: KubusSpacing.xxs),
                                Text(
                                  value,
                                  style: KubusTextStyles.badgeCount.copyWith(
                                    fontSize: isSmallScreen
                                        ? KubusChromeMetrics.navMetaLabel
                                        : KubusChromeMetrics.navLabel,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ],
                            )
                          : isVerticalLayout
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _buildStatIconBadge(statColor, icon),
                                    SizedBox(width: isSmallScreen ? 8 : 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            value,
                                            style: KubusTextStyles.badgeCount
                                                .copyWith(
                                              fontSize: isSmallScreen
                                                  ? KubusChromeMetrics
                                                      .navBadgeLabel
                                                  : KubusChromeMetrics
                                                      .navMetaLabel,
                                              color: scheme.onSurface,
                                            ),
                                          ),
                                          Text(
                                            displayTitle,
                                            style: KubusTextStyles.compactBadge
                                                .copyWith(
                                              fontSize: isSmallScreen
                                                  ? KubusChromeMetrics
                                                          .navBadgeLabel -
                                                      2
                                                  : KubusChromeMetrics
                                                          .navBadgeLabel -
                                                      1,
                                              color: scheme.onSurface
                                                  .withValues(alpha: 0.65),
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
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildStatIconBadge(statColor, icon),
                                    SizedBox(height: isSmallScreen ? 4 : 6),
                                    Text(
                                      displayTitle,
                                      style:
                                          KubusTextStyles.compactBadge.copyWith(
                                        fontSize: isSmallScreen
                                            ? KubusChromeMetrics.navBadgeLabel -
                                                1
                                            : KubusChromeMetrics.navBadgeLabel,
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.68),
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: KubusSpacing.xxs),
                                    Text(
                                      value,
                                      style:
                                          KubusTextStyles.badgeCount.copyWith(
                                        fontSize: isSmallScreen
                                            ? KubusChromeMetrics.navMetaLabel
                                            : KubusChromeMetrics.navLabel,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                  ],
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
                  style: KubusTextStyles.screenTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (!isEffectivelyConnected)
                  Builder(
                    builder: (context) {
                      final roles = KubusColorRoles.of(context);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: KubusSpacing.sm,
                          vertical: KubusSpacing.xs,
                        ),
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
                              style: KubusTextStyles.badgeCount.copyWith(
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
                    KubusLabsFeature.dao.screenIcon,
                    KubusColorRoles.of(context).web3DaoAccent,
                    isEffectivelyConnected
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const GovernanceHub()),
                            )
                        : () => _showWalletOnboarding(context),
                    isLocked: !isEffectivelyConnected,
                    labsFeature: KubusLabsFeature.dao,
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
                    KubusLabsFeature.marketplace.screenIcon,
                    KubusColorRoles.of(context).web3MarketplaceAccent,
                    isEffectivelyConnected
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const Marketplace()),
                            )
                        : () => _showWalletOnboarding(context),
                    isLocked: !isEffectivelyConnected,
                    labsFeature: KubusLabsFeature.marketplace,
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
      {bool isLocked = false, KubusLabsFeature? labsFeature}) {
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
            if (labsFeature?.showLabsMarker ?? false)
              Positioned(
                top: 0,
                left: 0,
                child: KubusLabsAdornment.inlinePill(
                  feature: labsFeature!,
                  emphasized: !isLocked,
                ),
              ),
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
                      style: KubusTextStyles.navLabel.copyWith(
                        fontSize: KubusChromeMetrics.navMetaLabel + 1,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: KubusSpacing.xxs),
                    Text(
                      subtitle,
                      style: KubusTextStyles.compactBadge.copyWith(
                        fontSize: KubusChromeMetrics.navBadgeLabel + 2,
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
                        style: KubusTextStyles.navLabel.copyWith(
                          fontSize: KubusChromeMetrics.navMetaLabel + 1,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: KubusSpacing.xxs),
                      Text(
                        subtitle,
                        style: KubusTextStyles.compactBadge.copyWith(
                          fontSize: KubusChromeMetrics.navBadgeLabel + 2,
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
                  style: KubusTextStyles.screenTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: _showFullActivity,
                  child: Text(
                    l10n.commonViewAll,
                    style: KubusTextStyles.navLabel.copyWith(
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
    return Consumer2<ArtworkProvider, PromotionProvider>(
      builder: (context, artworkProvider, promotionProvider, child) {
        final l10n = AppLocalizations.of(context)!;
        final featuredArtworks = (promotionProvider.featuredArtworks.isNotEmpty
                ? promotionProvider.featuredArtworks
                : artworkProvider.artworks)
            .take(6)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.homeFeaturedArtworksTitle,
                  style: KubusTextStyles.screenTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _navigateToGallery();
                  },
                  child: Text(
                    l10n.commonExplore,
                    style: KubusTextStyles.navLabel.copyWith(
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
                        return _buildArtworkCard(featuredArtworks[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedProfiles() {
    return Consumer<PromotionProvider>(
      builder: (context, promotionProvider, _) {
        final profiles = promotionProvider.featuredProfiles.take(6).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Featured Artists & Institutions',
              style: KubusTextStyles.screenTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 148,
              child: profiles.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: profiles.length,
                      itemBuilder: (context, index) =>
                          _buildFeaturedProfileCard(profiles[index]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildArtworkCard(Artwork artwork) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scheme = Theme.of(context).colorScheme;
    final style = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: scheme.surface,
    );

    return GestureDetector(
      onTap: () {
        _showArtworkDetail(artwork);
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.32),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: LiquidGlassCard(
          padding: EdgeInsets.zero,
          margin: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(16),
          showBorder: false,
          blurSigma: style.blurSigma,
          backgroundColor: style.tintColor,
          fallbackMinOpacity: style.fallbackMinOpacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 110,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildCardCover(artwork, themeProvider),
                      if (artwork.promotion.isPromoted)
                        const Positioned(
                          top: 8,
                          left: 8,
                          child:
                              Icon(Icons.star, color: Colors.amber, size: 18),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(KubusSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        artwork.title,
                        style: KubusTextStyles.sectionTitle.copyWith(
                          fontSize: KubusHeaderMetrics.screenSubtitle,
                          color: scheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: KubusSpacing.xxs),
                      ArtworkCreatorByline(
                        artwork: artwork,
                        style: KubusTextStyles.navMetaLabel.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                      ),
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

  Widget _buildFeaturedProfileCard(FeaturedPromotionItem item) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = (item.subtitle ?? '').trim();
    final style = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: scheme.surface,
    );

    return GestureDetector(
      onTap: () {
        final wallet = (item.walletAddress ?? '').trim();
        final target = wallet.isNotEmpty ? wallet : item.id;
        if (target.trim().isEmpty) return;
        unawaited(UserProfileNavigation.open(context, userId: target));
      },
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: LiquidGlassCard(
          padding: const EdgeInsets.all(KubusSpacing.md),
          margin: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(16),
          showBorder: false,
          blurSigma: style.blurSigma,
          backgroundColor: style.tintColor,
          fallbackMinOpacity: style.fallbackMinOpacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarWidget(
                    wallet: (item.walletAddress ?? item.id).trim(),
                    avatarUrl: item.imageUrl,
                    radius: 18,
                    enableProfileNavigation: false,
                    allowFabricatedFallback: true,
                  ),
                  const Spacer(),
                  if (item.promotion.isPromoted)
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KubusTextStyles.actionTileTitle.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTextStyles.navMetaLabel.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ],
          ),
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
    openArtwork(context, artwork.id, source: 'home');
  }

  void _showStatsDialog(String statType, IconData icon) {
    final l10n = AppLocalizations.of(context)!;
    final displayTitle = _getStatDisplayTitle(statType, l10n);
    final wallet =
        (context.read<ProfileProvider>().currentUser?.walletAddress ?? '')
            .trim();
    showKubusDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => KubusAlertDialog(
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
                  Consumer<StatsProvider>(
                    builder: (context, statsProvider, _) {
                      final accent =
                          Provider.of<ThemeProvider>(dialogContext).accentColor;

                      if (wallet.isEmpty) {
                        return EmptyStateCard(
                          icon: Icons.analytics_outlined,
                          title: l10n.commonNotAvailable,
                          description: l10n.homeNoStatsAvailableDescription,
                          showAction: false,
                        );
                      }

                      if (!statsProvider.analyticsEnabled) {
                        return Container(
                          height: 200,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(dialogContext)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              l10n.commonNotAvailable,
                              style: KubusTextStyles.navLabel.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(dialogContext)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        );
                      }

                      final metric =
                          StatsApiService.metricFromUiStatType(statType);
                      const bucket = 'day';
                      const timeframe = '7d';
                      final now = DateTime.now().toUtc();
                      final today = DateTime.utc(now.year, now.month, now.day);
                      final currentTo = today.add(const Duration(days: 1));
                      final currentFrom =
                          currentTo.subtract(const Duration(days: 7));

                      statsProvider.ensureSeries(
                        entityType: 'user',
                        entityId: wallet,
                        metric: metric,
                        bucket: bucket,
                        timeframe: timeframe,
                        from: currentFrom.toIso8601String(),
                        to: currentTo.toIso8601String(),
                        scope: 'private',
                      );

                      final series = statsProvider.getSeries(
                        entityType: 'user',
                        entityId: wallet,
                        metric: metric,
                        bucket: bucket,
                        timeframe: timeframe,
                        from: currentFrom.toIso8601String(),
                        to: currentTo.toIso8601String(),
                        scope: 'private',
                      );
                      final isLoading = statsProvider.isSeriesLoading(
                        entityType: 'user',
                        entityId: wallet,
                        metric: metric,
                        bucket: bucket,
                        timeframe: timeframe,
                        from: currentFrom.toIso8601String(),
                        to: currentTo.toIso8601String(),
                        scope: 'private',
                      );
                      final error = statsProvider.seriesError(
                        entityType: 'user',
                        entityId: wallet,
                        metric: metric,
                        bucket: bucket,
                        timeframe: timeframe,
                        from: currentFrom.toIso8601String(),
                        to: currentTo.toIso8601String(),
                        scope: 'private',
                      );

                      if ((isLoading && series == null) ||
                          (error != null && series == null)) {
                        return Container(
                          height: 200,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(dialogContext)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: isLoading
                                ? InlineLoading(
                                    tileSize: 8.0,
                                    color: accent,
                                  )
                                : Text(
                                    l10n.commonNotAvailable,
                                    style: KubusTextStyles.navLabel.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(dialogContext)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                          ),
                        );
                      }

                      final buckets = List<DateTime>.generate(
                        7,
                        (i) => today.subtract(Duration(days: 6 - i)),
                      );
                      final valuesByDay = <String, int>{};
                      for (final point
                          in series?.series ?? const <StatsSeriesPoint>[]) {
                        final dt = point.t.toUtc();
                        final key =
                            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                        valuesByDay[key] = (valuesByDay[key] ?? 0) + point.v;
                      }

                      final data = buckets.map((d) {
                        final key =
                            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                        return (valuesByDay[key] ?? 0).toDouble();
                      }).toList(growable: false);

                      String weekdayLabel(int weekday) {
                        switch (weekday) {
                          case DateTime.monday:
                            return l10n.commonWeekdayMonShort;
                          case DateTime.tuesday:
                            return l10n.commonWeekdayTueShort;
                          case DateTime.wednesday:
                            return l10n.commonWeekdayWedShort;
                          case DateTime.thursday:
                            return l10n.commonWeekdayThuShort;
                          case DateTime.friday:
                            return l10n.commonWeekdayFriShort;
                          case DateTime.saturday:
                            return l10n.commonWeekdaySatShort;
                          case DateTime.sunday:
                            return l10n.commonWeekdaySunShort;
                          default:
                            return '';
                        }
                      }

                      final labels = buckets
                          .map((d) => weekdayLabel(d.weekday))
                          .toList(growable: false);

                      return EnhancedBarChart(
                        title: l10n.homeStatsTrendTitle(displayTitle),
                        data: data,
                        accentColor: accent,
                        labels: labels,
                      );
                    },
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
          style: KubusTextStyles.sectionTitle.copyWith(
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
                      style: KubusTextStyles.navMetaLabel.copyWith(
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
  final bool embedded;

  const ActivityScreen({
    super.key,
    this.embedded = false,
  });

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

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: BackdropGlassSheet(
        showHandle: false,
        showBorder: false,
        padding: EdgeInsets.zero,
        backgroundColor: colorScheme.surface,
        child: Column(
          children: [
            KubusSheetHeader(
              title: l10n.commonNotifications,
              trailing: TopBarIcon(
                tooltip: l10n.commonRefresh,
                icon: Icon(
                  Icons.refresh,
                  color: colorScheme.onSurface,
                ),
                onPressed: () => provider.refresh(force: true),
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
                              horizontal: KubusSpacing.xl + KubusSpacing.sm,
                              vertical: KubusSpacing.xxl,
                            ),
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
                                    ? () =>
                                        activityProvider.refresh(force: true)
                                    : null,
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: KubusSpacing.lg,
                              vertical: KubusSpacing.sm + KubusSpacing.xxs,
                            ),
                            itemCount: activities.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: KubusSpacing.sm),
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
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              flexibleSpace: const KubusGlassAppBarBackdrop(
                showBottomDivider: true,
              ),
              title: Text(
                l10n.homeActivityTitle,
                style: KubusTextStyles.screenTitle,
              ),
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
                padding: const EdgeInsets.all(KubusSpacing.lg),
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
                padding: const EdgeInsets.all(KubusSpacing.lg),
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
              padding: const EdgeInsets.all(KubusSpacing.lg),
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
