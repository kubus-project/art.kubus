import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../config/config.dart';
import '../../../widgets/inline_loading.dart';
import '../../../widgets/app_loading.dart';
import 'package:provider/provider.dart';
import '../../onboarding/web3/web3_onboarding.dart';
import '../../onboarding/web3/onboarding_data.dart';
import '../../../providers/collectibles_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../models/collectible.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../utils/marketplace_value_formatter.dart';
import '../../../utils/rarity_ui.dart';
import '../../../utils/wallet_action_guard.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/kubus_labs_feature.dart';
import '../../../utils/design_tokens.dart';
import '../../../services/share/share_service.dart';
import '../../../services/share/share_types.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/common/kubus_labs_adornment.dart';
import 'package:art_kubus/widgets/common/kubus_stat_card.dart';
import 'package:art_kubus/widgets/glass_components.dart';

class Marketplace extends StatefulWidget {
  const Marketplace({super.key});

  @override
  State<Marketplace> createState() => _MarketplaceState();
}

class _MarketplaceState extends State<Marketplace>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _showArOnly = false;
  bool _didRequestCollectiblesInit = false;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      _buildFeaturedNFTs(),
      _buildTrendingNFTs(),
      _buildMyListings(),
    ]);
    _checkOnboarding();

    // Track this screen visit for quick actions
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<NavigationProvider>().trackScreenVisit('marketplace');

      if (_didRequestCollectiblesInit) return;
      _didRequestCollectiblesInit = true;

      final collectiblesProvider = context.read<CollectiblesProvider>();
      if (!collectiblesProvider.isLoading &&
          collectiblesProvider.allSeries.isEmpty) {
        await collectiblesProvider.initialize(
          loadMockIfEmpty: AppConfig.isDevelopment,
        );
      }
    });
  }

  Future<void> _checkOnboarding() async {
    if (await isOnboardingNeeded(MarketplaceOnboardingData.featureKey)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOnboarding();
      });
    }
  }

  void _showOnboarding() {
    final l10n = AppLocalizations.of(context)!;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Web3OnboardingScreen(
          featureKey: MarketplaceOnboardingData.featureKey,
          featureTitle: MarketplaceOnboardingData.featureTitle(l10n),
          pages: MarketplaceOnboardingData.pages(l10n),
          onComplete: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                l10n.navigationScreenMarketplace,
                style: KubusTypography.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: KubusSpacing.sm),
            const KubusLabsAdornment.inlinePill(
              feature: KubusLabsFeature.marketplace,
              emphasized: true,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline,
                color: Theme.of(context).colorScheme.onSurface),
            onPressed: _showOnboarding,
          ),
          IconButton(
            icon: Icon(Icons.settings,
                color: Theme.of(context).colorScheme.onSurface),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildMarketplaceHeader(),
                  _buildNavigationTabs(),
                ],
              ),
            ),
          ];
        },
        body: _pages[_selectedIndex],
      ),
    );
  }

  void _showSettings() {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = context.read<ThemeProvider>();
    final web3Provider = context.read<Web3Provider>();
    final colorScheme = Theme.of(context).colorScheme;

    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KubusRadius.lg)),
        title: Text(
          '${l10n.navigationScreenMarketplace} ${l10n.settingsTitle}',
          style: KubusTypography.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: _showArOnly,
                onChanged: (value) {
                  setState(() => _showArOnly = value);
                  setDialogState(() {});
                },
                activeThumbColor: themeProvider.accentColor,
                title: Text(
                  l10n.marketplaceSettingsShowArOnlyTitle,
                  style: KubusTypography.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  l10n.marketplaceSettingsShowArOnlyDescription,
                  style: KubusTypography.inter(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.public,
                      size: 16,
                      color: colorScheme.onSurface.withValues(alpha: 0.7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!
                          .marketplaceNetworkLabel(web3Provider.currentNetwork),
                      style: KubusTypography.inter(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (web3Provider.walletAddress.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet,
                        size: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.7)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!
                            .marketplaceWalletLabel(web3Provider.walletAddress),
                        style: KubusTypography.inter(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.commonClose,
              style: KubusTypography.inter(color: themeProvider.accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplaceHeader() {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final labsFeature = KubusLabsFeature.marketplace;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm,
      ),
      padding: const EdgeInsets.all(KubusSpacing.md - KubusSpacing.xs),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            roles.web3MarketplaceAccent,
            roles.web3MarketplaceAccent.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(KubusRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onPrimary
                  .withValues(alpha: 0.2),
              borderRadius:
                  BorderRadius.circular(KubusRadius.lg + KubusRadius.xs),
            ),
            child: Icon(
              labsFeature.screenIcon,
              color: Theme.of(context).colorScheme.onSurface,
              size: 22,
            ),
          ),
          const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: KubusSpacing.sm,
                  runSpacing: KubusSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l10n.navigationScreenMarketplace,
                      style: KubusTypography.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const KubusLabsAdornment.inlinePill(
                      feature: KubusLabsFeature.marketplace,
                      emphasized: true,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.homeWeb3MarketplaceSubtitle,
                  style: KubusTypography.inter(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(KubusRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              AppLocalizations.of(context)!.marketplaceFeaturedTab,
              Icons.star,
              0,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              AppLocalizations.of(context)!.marketplaceTrendingTab,
              Icons.trending_up,
              1,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              AppLocalizations.of(context)!.marketplaceMyListingsTab,
              Icons.account_balance_wallet,
              2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int index) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? themeProvider.accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(KubusRadius.sm),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: KubusTypography.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedNFTs() {
    return Consumer2<CollectiblesProvider, ThemeProvider>(
      builder: (context, collectiblesProvider, themeProvider, child) {
        final l10n = AppLocalizations.of(context)!;
        var featuredEntries =
            collectiblesProvider.getFeaturedMarketplaceEntries();
        if (_showArOnly) {
          featuredEntries = featuredEntries
              .where((entry) => entry.requiresArInteraction)
              .toList();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(KubusSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.marketplaceFeaturedCollectionsTitle,
                          style: KubusTypography.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: KubusSpacing.xs),
                        Text(
                          l10n.marketplaceFeaturedCollectionsSubtitle,
                          style: KubusTypography.inter(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.68),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColorUtils.tealAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(KubusRadius.md),
                      border:
                          Border.all(color: AppColorUtils.tealAccent, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility,
                          size: 12,
                          color: AppColorUtils.tealAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.marketplaceArBadgeLabel,
                          style: KubusTypography.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColorUtils.tealAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (collectiblesProvider.isLoading)
                const AppLoading()
              else if (featuredEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: EmptyStateCard(
                    icon: Icons.storefront_outlined,
                    title: l10n.marketplaceNoMintedNftsTitle,
                    description: l10n.marketplaceNoMintedNftsDescription,
                    showAction: false,
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                    final childAspectRatio =
                        constraints.maxWidth > 600 ? 0.8 : 0.75;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: KubusSpacing.md,
                        mainAxisSpacing: KubusSpacing.md,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: featuredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = featuredEntries[index];
                        return _buildMarketplaceEntryCard(entry);
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrendingNFTs() {
    return Consumer2<CollectiblesProvider, ThemeProvider>(
      builder: (context, collectiblesProvider, themeProvider, child) {
        final l10n = AppLocalizations.of(context)!;
        var trendingEntries =
            collectiblesProvider.getTrendingMarketplaceEntries();
        if (_showArOnly) {
          trendingEntries = trendingEntries
              .where((entry) => entry.requiresArInteraction)
              .toList();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(KubusSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.marketplaceTrendingThisWeekTitle,
                    style: KubusTypography.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.xs),
                  Text(
                    l10n.marketplaceTrendingThisWeekSubtitle,
                    style: KubusTypography.inter(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (trendingEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: EmptyStateCard(
                    icon: Icons.trending_up,
                    title: l10n.marketplaceNoTrendingNftsTitle,
                    description: l10n.marketplaceNoTrendingNftsDescription,
                    showAction: false,
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                    final childAspectRatio =
                        constraints.maxWidth > 600 ? 0.8 : 0.75;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: KubusSpacing.md,
                        mainAxisSpacing: KubusSpacing.md,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: trendingEntries.length,
                      itemBuilder: (context, index) {
                        final entry = trendingEntries[index];
                        return _buildMarketplaceEntryCard(entry);
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyListings() {
    return Consumer3<CollectiblesProvider, Web3Provider, ThemeProvider>(
      builder:
          (context, collectiblesProvider, web3Provider, themeProvider, child) {
        final l10n = AppLocalizations.of(context)!;
        final profileProvider = context.watch<ProfileProvider>();
        final walletProvider = context.watch<WalletProvider>();
        final access = WalletSessionAccessSnapshot.fromProviders(
          profileProvider: profileProvider,
          walletProvider: walletProvider,
        );
        // Show user's collectibles using real wallet address
        final walletAddress = web3Provider.walletAddress;
        final myCollectibles = walletAddress.isNotEmpty
            ? collectiblesProvider.getCollectiblesByOwner(walletAddress)
            : <dynamic>[];
        final myCollectiblesForSale = walletAddress.isNotEmpty
            ? collectiblesProvider
                .getCollectiblesForSale()
                .where((c) => c.ownerAddress == walletAddress)
                .toList()
            : <dynamic>[];

        // Check if wallet is connected
        if (!access.hasWalletIdentity) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 100,
                  color: AppColorUtils.amberAccent.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context)!.marketplaceConnectWalletTitle,
                  style: KubusTypography.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!
                      .marketplaceConnectWalletDescription,
                  style: KubusTypography.inter(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/connect-wallet'),
                  icon: const Icon(Icons.link),
                  label: Text(
                      AppLocalizations.of(context)!.authConnectWalletButton),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.accentColor,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                  ),
                ),
              ],
            ),
          );
        }

        if (myCollectibles.isEmpty) {
          return Center(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: EmptyStateCard(
                icon: Icons.inventory_2_outlined,
                title: AppLocalizations.of(context)!
                    .marketplaceEmptyCollectionTitle,
                description: AppLocalizations.of(context)!
                    .marketplaceEmptyCollectionDescription,
                showAction: true,
                actionLabel:
                    AppLocalizations.of(context)!.marketplaceExploreArArtButton,
                onAction: () => Navigator.of(context).pushNamed('/ar'),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(KubusSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (access.isReadOnlySession)
                Container(
                  margin: const EdgeInsets.only(bottom: KubusSpacing.md),
                  padding: const EdgeInsets.all(KubusSpacing.md),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!
                              .walletReconnectManualRequiredToast,
                          style: KubusTypography.inter(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      const SizedBox(width: KubusSpacing.md),
                      ElevatedButton(
                        onPressed: () async {
                          await WalletActionGuard.ensureSignerAccess(
                            context: context,
                            profileProvider: profileProvider,
                            walletProvider: walletProvider,
                          );
                        },
                        child:
                            Text(AppLocalizations.of(context)!.commonReconnect),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.marketplaceMyCollectionTitle,
                      style: KubusTypography.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColorUtils.amberAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(
                          KubusRadius.lg + KubusRadius.xs),
                      border: Border.all(
                          color: AppColorUtils.amberAccent, width: 1),
                    ),
                    child: Text(
                      l10n.marketplaceMyCollectionCount(
                        myCollectibles.length,
                      ),
                      style: KubusTypography.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColorUtils.amberAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Listed for sale section
              if (myCollectiblesForSale.isNotEmpty) ...[
                Text(
                  l10n.marketplaceListedForSaleTitle,
                  style: KubusTypography.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: myCollectiblesForSale.length,
                    itemBuilder: (context, index) {
                      final collectible = myCollectiblesForSale[index];
                      final entry = collectiblesProvider
                          .getMarketplaceEntryForCollectible(collectible);
                      if (entry == null) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        width: 150,
                        margin: const EdgeInsets.only(right: 12),
                        child: _buildCollectibleCard(collectible, entry,
                            isForSale: true),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // All owned NFTs
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                  final childAspectRatio =
                      constraints.maxWidth > 600 ? 0.8 : 0.75;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: KubusSpacing.md,
                      mainAxisSpacing: KubusSpacing.md,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount: myCollectibles.length,
                    itemBuilder: (context, index) {
                      final collectible = myCollectibles[index];
                      final entry = collectiblesProvider
                          .getMarketplaceEntryForCollectible(collectible);
                      if (entry == null) {
                        return const SizedBox.shrink();
                      }
                      return _buildCollectibleCard(collectible, entry);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCollectibleCard(
      Collectible collectible, MarketplaceArtworkEntry entry,
      {bool isForSale = false}) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final series = entry.series;
    final coverUrl = entry.coverUrl;
    final collectiblesProvider =
        Provider.of<CollectiblesProvider>(context, listen: false);
    final value =
        collectiblesProvider.getDisplayValueForCollectible(collectible) ??
            entry.displayValue;
    return GestureDetector(
      onTap: () => _showCollectibleDetails(collectible, entry),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(KubusRadius.lg),
          border: Border.all(
            color: isForSale
                ? roles.warningAction
                : Theme.of(context).colorScheme.outline,
            width: isForSale ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _getSeriesGradientColors(series?.rarity),
                  ),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(KubusRadius.lg)),
                ),
                child: Stack(
                  children: [
                    // NFT image
                    if (coverUrl != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(KubusRadius.lg)),
                        child: Image.network(
                          coverUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildDefaultSeriesIcon(entry),
                        ),
                      )
                    else
                      _buildDefaultSeriesIcon(entry),

                    // For sale badge
                    if (isForSale)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: roles.warningAction,
                            borderRadius: BorderRadius.circular(KubusRadius.md),
                          ),
                          child: Text(
                            l10n.commonForSale,
                            style: KubusTypography.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),

                    // Token ID
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(KubusRadius.sm),
                        ),
                        child: Text(
                          '#${collectible.tokenId}',
                          style: KubusTypography.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: KubusTypography.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.marketplaceTokenNumberLabel(collectible.tokenId),
                      style: KubusTypography.inter(
                        fontSize: 10,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Price or status
                    if (isForSale && collectible.currentListingPrice != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.marketplaceListedForLabel,
                                  style: KubusTypography.inter(
                                    fontSize: 9,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                Text(
                                  MarketplaceValueFormatter.formatDisplayValue(
                                    value,
                                    fallback:
                                        '${collectible.currentListingPrice} KUB8',
                                  ),
                                  style: KubusTypography.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: roles.warningAction,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _removeFromSale(collectible),
                            icon: Icon(
                              Icons.remove_circle,
                              color: roles.negativeAction,
                              size: 16,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  value?.label ?? l10n.marketplaceOwnedLabel,
                                  style: KubusTypography.inter(
                                    fontSize: 9,
                                    color: AppColorUtils.amberAccent,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  MarketplaceValueFormatter.formatDisplayValue(
                                    value,
                                  ),
                                  style: KubusTypography.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                _listForSale(collectible, entry.title),
                            icon: Icon(
                              Icons.sell,
                              color: roles.warningAction,
                              size: 16,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            padding: EdgeInsets.zero,
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

  void _showCollectibleDetails(
      Collectible collectible, MarketplaceArtworkEntry entry) {
    final series = entry.series;
    final collectiblesProvider =
        Provider.of<CollectiblesProvider>(context, listen: false);
    final collectibleValue =
        collectiblesProvider.getDisplayValueForCollectible(collectible) ??
            entry.displayValue;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(KubusRadius.lg + KubusRadius.xs)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(KubusSpacing.md),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${entry.title} #${collectible.tokenId}',
                    style: KubusTypography.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    collectible.isForSale
                        ? AppLocalizations.of(context)!
                            .marketplaceOwnedNftListedStatus
                        : AppLocalizations.of(context)!
                            .marketplaceOwnedNftStatus,
                    textAlign: TextAlign.center,
                    style: KubusTypography.inter(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Properties
                    if (collectible.properties.isNotEmpty) ...[
                      Text(
                        AppLocalizations.of(context)!
                            .marketplacePropertiesTitle,
                        style: KubusTypography.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: collectible.properties.entries.map((entry) {
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              borderRadius:
                                  BorderRadius.circular(KubusRadius.sm),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  entry.key.replaceAll('_', ' ').toUpperCase(),
                                  style: KubusTypography.inter(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.value.toString(),
                                  style: KubusTypography.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Details
                    Text(
                      AppLocalizations.of(context)!.commonDetails,
                      style: KubusTypography.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (series != null)
                      _buildDetailRow(
                        AppLocalizations.of(context)!
                            .marketplaceDetailCollectionLabel,
                        series.name,
                      ),
                    _buildDetailRow(
                      AppLocalizations.of(context)!
                          .marketplaceDetailArtworkLabel,
                      entry.artwork.title,
                    ),
                    _buildDetailRow(
                      AppLocalizations.of(context)!.marketplaceTokenIdLabel,
                      '#${collectible.tokenId}',
                    ),
                    _buildDetailRow(
                      AppLocalizations.of(context)!.marketplaceMintedLabel,
                      _formatDate(collectible.mintedAt),
                    ),
                    if (collectibleValue != null)
                      _buildDetailRow(
                        collectibleValue.label,
                        MarketplaceValueFormatter.formatDisplayValue(
                          collectibleValue,
                        ),
                      ),
                    _buildDetailRow(
                      AppLocalizations.of(context)!.commonStatus,
                      collectible.status.name.toUpperCase(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: KubusTypography.inter(
              fontSize: 14,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: KubusTypography.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _listForSale(Collectible collectible, String entryTitle) async {
    final profileProvider = context.read<ProfileProvider>();
    final walletProvider = context.read<WalletProvider>();
    final canProceed = await WalletActionGuard.ensureSignerAccess(
      context: context,
      profileProvider: profileProvider,
      walletProvider: walletProvider,
    );
    if (!mounted || !canProceed) {
      return;
    }

    final priceController = TextEditingController();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KubusRadius.lg),
        ),
        title: Text(
          AppLocalizations.of(context)!.marketplaceListNftForSaleTitle,
          style: KubusTypography.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entryTitle.isEmpty
                  ? 'Token #${collectible.tokenId}'
                  : '$entryTitle #${collectible.tokenId}',
              style: KubusTypography.inter(
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              style: KubusTypography.inter(
                  color: Theme.of(context).colorScheme.onPrimary),
              decoration: InputDecoration(
                labelText:
                    AppLocalizations.of(context)!.marketplacePriceKub8Label,
                labelStyle: KubusTypography.inter(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(KubusRadius.sm),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: themeProvider.accentColor),
                  borderRadius:
                      const BorderRadius.all(Radius.circular(KubusRadius.sm)),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.commonCancel,
              style: KubusTypography.inter(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (priceController.text.isNotEmpty) {
                Navigator.of(context).pop();
                _processListForSale(collectible, priceController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Provider.of<ThemeProvider>(context, listen: false)
                      .accentColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: Text(
              AppLocalizations.of(context)!.marketplaceListForSaleButton,
              style: KubusTypography.inter(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processListForSale(
      Collectible collectible, String price) async {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final profileProvider = context.read<ProfileProvider>();
    final walletProvider = context.read<WalletProvider>();
    final canProceed = await WalletActionGuard.ensureSignerAccess(
      context: context,
      profileProvider: profileProvider,
      walletProvider: walletProvider,
    );
    if (!mounted || !canProceed) {
      return;
    }

    try {
      final collectiblesProvider = context.read<CollectiblesProvider>();
      await collectiblesProvider.listCollectibleForSale(
        collectibleId: collectible.id,
        price: price,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.marketplaceListForSaleSuccessToast),
          backgroundColor: scheme.primary,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Marketplace: list for sale failed: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.marketplaceListForSaleFailedToast),
          backgroundColor: scheme.error,
        ),
      );
    }
  }

  void _removeFromSale(Collectible collectible) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KubusRadius.lg),
        ),
        title: Text(
          l10n.marketplaceRemoveFromSaleTitle,
          style: KubusTypography.inter(
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.marketplaceRemoveFromSaleConfirmBody,
          style: KubusTypography.inter(
            color: scheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              l10n.commonCancel,
              style: KubusTypography.inter(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // In real app, implement remove from sale logic
              ScaffoldMessenger.of(context).showKubusSnackBar(
                SnackBar(
                  content: Text(l10n.marketplaceRemoveFromSaleSuccessToast),
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            child: Text(
              l10n.commonRemove,
              style: KubusTypography.inter(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplaceEntryCard(MarketplaceArtworkEntry entry) {
    final l10n = AppLocalizations.of(context)!;
    final series = entry.series;
    final progress = entry.mintProgress ?? 0;
    final progressPercentage = (progress * 100).toInt();
    final isNearSoldOut = progress > 0.8;
    final hasARFeature = entry.requiresArInteraction;
    final value = entry.displayValue;

    return GestureDetector(
      onTap: () => _showNFTSeriesDetails(entry),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(KubusRadius.lg),
          border: Border.all(
            color: hasARFeature
                ? AppColorUtils.tealAccent
                : Theme.of(context).colorScheme.outline,
            width: hasARFeature ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _getSeriesGradientColors(entry.rarity),
                  ),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(KubusRadius.lg)),
                ),
                child: Stack(
                  children: [
                    if (entry.coverUrl != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(KubusRadius.lg)),
                        child: Image.network(
                          entry.coverUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildDefaultSeriesIcon(entry),
                        ),
                      )
                    else
                      _buildDefaultSeriesIcon(entry),
                    if (hasARFeature)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColorUtils.tealAccent,
                            borderRadius: BorderRadius.circular(KubusRadius.md),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.view_in_ar,
                                size: 12,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.marketplaceArBadgeLabel,
                                style: KubusTypography.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (entry.isSoldOut)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: KubusColorRoles.of(context).negativeAction,
                            borderRadius: BorderRadius.circular(KubusRadius.md),
                          ),
                          child: Text(
                            l10n.marketplaceSoldOutBadgeLabel,
                            style: KubusTypography.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    if (entry.rarity != null)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(KubusRadius.sm),
                          ),
                          child: Text(
                            entry.rarity!.name.toUpperCase(),
                            style: KubusTypography.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: RarityUi.collectibleColor(
                                  context, entry.rarity!),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      style: KubusTypography.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.commonByArtist(entry.artistName),
                      style: KubusTypography.inter(
                        fontSize: 9,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (series != null) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  '${entry.mintedCount}/${entry.totalSupply}',
                                  style: KubusTypography.inter(
                                    fontSize: 8,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '$progressPercentage%',
                                style: KubusTypography.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                  color: isNearSoldOut
                                      ? KubusColorRoles.of(context)
                                          .warningAction
                                      : KubusColorRoles.of(context)
                                          .web3MarketplaceAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          SizedBox(
                            height: 8,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: InlineLoading(
                                tileSize: 3.0,
                                progress: progress,
                                color: isNearSoldOut
                                    ? KubusColorRoles.of(context).warningAction
                                    : KubusColorRoles.of(context)
                                        .web3MarketplaceAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                value?.label ??
                                    AppLocalizations.of(context)!.commonStatus,
                                style: KubusTypography.inter(
                                  fontSize: 7,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              Text(
                                MarketplaceValueFormatter.formatDisplayValue(
                                  value,
                                ),
                                style: KubusTypography.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: entry.isListed
                                ? KubusColorRoles.of(context).warningAction
                                : (entry.isSoldOut
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.3)
                                    : KubusColorRoles.of(context)
                                        .web3MarketplaceAccent),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            entry.isListed
                                ? l10n.marketplaceCardActionListed
                                : (series != null && !entry.isSoldOut
                                    ? l10n.marketplaceCardActionMint
                                    : l10n.marketplaceCardActionView),
                            style: KubusTypography.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
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

  Widget _buildDefaultSeriesIcon(MarketplaceArtworkEntry entry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            entry.requiresArInteraction ? Icons.view_in_ar : Icons.collections,
            size: 48,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            entry.title,
            style: KubusTypography.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  List<Color> _getSeriesGradientColors(CollectibleRarity? rarity) {
    final base = rarity == null
        ? KubusColorRoles.of(context).web3MarketplaceAccent
        : RarityUi.collectibleColor(context, rarity);
    return [
      base.withValues(alpha: 0.22),
      base.withValues(alpha: 0.5),
    ];
  }

  void _showNFTSeriesDetails(MarketplaceArtworkEntry entry) {
    final series = entry.series;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(KubusRadius.lg + KubusRadius.xs)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(KubusSpacing.md),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    entry.title,
                    style: KubusTypography.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.requiresArInteraction
                        ? l10n.marketplaceNftArtworkStatusArEnabled
                        : l10n.marketplaceNftArtworkStatus,
                    textAlign: TextAlign.center,
                    style: KubusTypography.inter(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.commonDescription,
                      style: KubusTypography.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      series != null && series.description.isNotEmpty
                          ? series.description
                          : entry.artwork.description,
                      style: KubusTypography.inter(
                        fontSize: 14,
                        color: Colors.grey[300],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (series != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              AppLocalizations.of(context)!
                                  .marketplaceTotalSupplyLabel,
                              '${series.totalSupply}',
                              icon: Icons.layers_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              AppLocalizations.of(context)!
                                  .marketplaceMintedLabel,
                              '${series.mintedCount}',
                              icon: Icons.check_circle_outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              AppLocalizations.of(context)!.commonAvailable,
                              '${series.totalSupply - series.mintedCount}',
                              icon: Icons.storefront_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            entry.displayValue?.label ??
                                AppLocalizations.of(context)!.commonStatus,
                            MarketplaceValueFormatter.formatDisplayValue(
                              entry.displayValue,
                            ),
                            icon: Icons.sell_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            AppLocalizations.of(context)!
                                .marketplaceRarityLabel,
                            entry.rarity?.name.toUpperCase() ?? 'NFT',
                            icon: Icons.auto_awesome_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: series == null || series.isSoldOut
                                ? null
                                : () {
                                    Navigator.of(context).pop();
                                    _mintNFT(series);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeProvider.accentColor,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(KubusRadius.md),
                              ),
                            ),
                            child: Text(
                              series == null
                                  ? l10n.marketplaceMintUnavailableLabel
                                  : (series.isSoldOut
                                      ? l10n.marketplaceSoldOutLabel
                                      : l10n.marketplaceMintNftButtonLabel),
                              style: KubusTypography.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () {
                            ShareService().showShareSheet(
                              context,
                              target: ShareTarget.artwork(
                                artworkId: entry.artwork.id,
                                title: entry.title,
                              ),
                              sourceScreen: 'marketplace_series',
                            );
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(
                                KubusSpacing.sm + KubusSpacing.xs),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius:
                                  BorderRadius.circular(KubusRadius.md),
                            ),
                            child: Icon(
                              Icons.share,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, {IconData? icon}) {
    final scheme = Theme.of(context).colorScheme;
    return KubusStatCard(
      title: label,
      value: value,
      icon: icon,
      layout: KubusStatCardLayout.centered,
      showIcon: icon != null,
      accent: scheme.secondary,
      tintBase: scheme.surface,
      minHeight: 88,
      padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
      titleMaxLines: 2,
      titleStyle: KubusTextStyles.detailCaption.copyWith(
        fontSize: 11,
        color: scheme.onSurface.withValues(alpha: 0.66),
      ),
      valueStyle: KubusTextStyles.detailCardTitle.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Future<void> _mintNFT(CollectibleSeries series) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    final profileProvider = context.read<ProfileProvider>();
    final walletProvider = context.read<WalletProvider>();

    final canProceed = await WalletActionGuard.ensureSignerAccess(
      context: context,
      profileProvider: profileProvider,
      walletProvider: walletProvider,
    );
    if (!mounted || !canProceed) {
      return;
    }

    if (series.requiresARInteraction) {
      showKubusDialog(
        context: context,
        builder: (context) => KubusAlertDialog(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KubusRadius.lg),
          ),
          title: Row(
            children: [
              Icon(
                Icons.view_in_ar,
                color: AppColorUtils.tealAccent,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.marketplaceArRequiredTitle,
                style: KubusTypography.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            l10n.marketplaceArRequiredDescription,
            style: KubusTypography.inter(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l10n.commonCancel,
                style: KubusTypography.inter(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to AR screen or map
                Navigator.of(context).pushNamed('/ar');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.accentColor,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: Text(
                l10n.marketplaceGoToArButton,
                style: KubusTypography.inter(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Show regular mint dialog
      _showMintDialog(series);
    }
  }

  void _showMintDialog(CollectibleSeries series) {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KubusRadius.lg),
        ),
        title: Text(
          l10n.marketplaceMintDialogTitle,
          style: KubusTypography.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.marketplaceMintConfirmCollectionDescription(series.name),
              style: KubusTypography.inter(
                color: Colors.grey[300],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(KubusRadius.sm),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.marketplaceMintPriceLabel,
                    style: KubusTypography.inter(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    '${series.mintPrice.toInt()} KUB8',
                    style: KubusTypography.inter(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              l10n.commonCancel,
              style: KubusTypography.inter(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processMint(series);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.accentColor,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: Text(
                l10n.marketplaceConfirmMintButton,
                style: KubusTypography.inter(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processMint(CollectibleSeries series) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    var loadingShown = false;
    final profileProvider = context.read<ProfileProvider>();
    final walletProvider = context.read<WalletProvider>();

    final canProceed = await WalletActionGuard.ensureSignerAccess(
      context: context,
      profileProvider: profileProvider,
      walletProvider: walletProvider,
    );
    if (!mounted || !canProceed) {
      return;
    }

    try {
      final collectiblesProvider = context.read<CollectiblesProvider>();
      final walletAddress = (walletProvider.currentWalletAddress ?? '').trim();
      if (walletAddress.isEmpty) {
        throw Exception('Connect wallet to mint');
      }

      // Show loading
      showKubusDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: SizedBox(
              width: 72,
              height: 72,
              child: InlineLoading(
                  shape: BoxShape.circle,
                  color: themeProvider.accentColor,
                  tileSize: 8.0)),
        ),
      );
      loadingShown = true;

      await collectiblesProvider.mintCollectible(
        seriesId: series.id,
        ownerAddress: walletAddress,
        transactionHash: 'local_mint_${DateTime.now().millisecondsSinceEpoch}',
        properties: {
          'mint_timestamp': DateTime.now().toIso8601String(),
          'minted_by': walletAddress,
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      // Show success
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showKubusDialog(
        context: context,
        builder: (context) => KubusAlertDialog(
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KubusRadius.lg),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: KubusColorRoles.of(context).web3MarketplaceAccent,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.marketplaceMintSuccessTitle,
                style: KubusTypography.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            l10n.marketplaceMintSuccessDescription,
            style: KubusTypography.inter(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          actions: [
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context
                      .read<NavigationProvider>()
                      .navigateToScreen(context, 'wallet');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.accentColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: Text(
                  l10n.marketplaceViewInWalletButton,
                  style: KubusTypography.inter(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Marketplace: mint collectible failed: $e');
      }
      if (!mounted) return;
      if (loadingShown && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Close loading
      }

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showKubusDialog(
        context: context,
        builder: (context) => KubusAlertDialog(
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KubusRadius.lg),
          ),
          title: Row(
            children: [
              Icon(
                Icons.error,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.marketplaceMintFailedTitle,
                style: KubusTypography.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            l10n.marketplaceMintFailedDescription,
            style: KubusTypography.inter(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: Text(
                l10n.commonClose,
                style: KubusTypography.inter(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
