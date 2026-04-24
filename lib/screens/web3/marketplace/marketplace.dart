import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
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
import '../../../utils/home/home_quick_action_executor.dart';
import '../../../utils/home/home_quick_action_models.dart';
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

  @override
  void initState() {
    super.initState();
    _checkOnboarding();

    // Track this screen visit for quick actions
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final navigationProvider = context.read<NavigationProvider>();
      final collectiblesProvider = context.read<CollectiblesProvider>();
      final walletAddress =
          (context.read<WalletProvider>().currentWalletAddress ?? '').trim();

      navigationProvider.trackScreenVisit('marketplace');

      if (_didRequestCollectiblesInit) return;
      _didRequestCollectiblesInit = true;
      if (!collectiblesProvider.isLoading &&
          collectiblesProvider.allSeries.isEmpty) {
        await collectiblesProvider.initialize();
      }

      if (walletAddress.isNotEmpty) {
        unawaited(
          collectiblesProvider.refreshWalletCollectibleIndex(walletAddress),
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
            tooltip: l10n.marketplaceHelpTooltip,
            icon: Icon(Icons.help_outline,
                color: Theme.of(context).colorScheme.onSurface),
            onPressed: _showOnboarding,
          ),
          IconButton(
            tooltip: l10n.marketplaceSettingsTooltip,
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
        body: _buildSelectedPage(),
      ),
    );
  }

  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 1:
        return _buildTrendingNFTs();
      case 2:
        return _buildMyListings();
      case 0:
      default:
        return _buildFeaturedNFTs();
    }
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
              _MarketplaceSectionHeader(
                title: l10n.marketplaceFeaturedCollectionsTitle,
                subtitle: l10n.marketplaceFeaturedCollectionsSubtitle,
                trailing: _buildFilterPill(),
              ),
              const SizedBox(height: KubusSpacing.lg),
              if (collectiblesProvider.isLoading)
                const AppLoading()
              else if (featuredEntries.isEmpty)
                _buildMarketplaceEmptyState(
                  icon: Icons.storefront_outlined,
                  title: l10n.marketplaceNoMintedNftsTitle,
                  description: l10n.marketplaceNoMintedNftsDescription,
                )
              else
                _buildMarketplaceEntryGrid(
                  featuredEntries,
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
              _MarketplaceSectionHeader(
                title: l10n.marketplaceTrendingThisWeekTitle,
                subtitle: l10n.marketplaceTrendingThisWeekSubtitle,
                trailing: _buildFilterPill(),
              ),
              const SizedBox(height: KubusSpacing.lg),
              if (trendingEntries.isEmpty)
                _buildMarketplaceEmptyState(
                  icon: Icons.trending_up,
                  title: l10n.marketplaceNoTrendingNftsTitle,
                  description: l10n.marketplaceNoTrendingNftsDescription,
                )
              else
                _buildMarketplaceEntryGrid(trendingEntries),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMarketplaceEntryGrid(List<MarketplaceArtworkEntry> entries) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 620 ? 3 : 2;
        final childAspectRatio = constraints.maxWidth > 620 ? 0.74 : 0.68;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: KubusSpacing.md,
            mainAxisSpacing: KubusSpacing.md,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            return _buildMarketplaceEntryCard(entries[index]);
          },
        );
      },
    );
  }

  Widget _buildMarketplaceEmptyState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KubusSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 260),
        child: EmptyStateCard(
          icon: icon,
          title: title,
          description: description,
          showAction: false,
        ),
      ),
    );
  }

  Widget _buildFilterPill() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final accent = KubusColorRoles.of(context).web3MarketplaceAccent;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.sm,
        vertical: KubusSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: (_showArOnly ? accent : scheme.surfaceContainerHighest)
            .withValues(alpha: _showArOnly ? 0.18 : 0.74),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(
          color: (_showArOnly ? accent : scheme.outline).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _showArOnly ? Icons.view_in_ar : Icons.filter_alt_outlined,
            size: 14,
            color: _showArOnly ? accent : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: KubusSpacing.xs),
          Text(
            _showArOnly
                ? l10n.marketplaceArOnlyFilterActiveLabel
                : l10n.marketplaceArOnlyFilterInactiveLabel,
            style: KubusTextStyles.compactBadge.copyWith(
              color: _showArOnly ? accent : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(KubusSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: EmptyStateCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: l10n.marketplaceConnectWalletTitle,
                  description: l10n.marketplaceConnectWalletDescription,
                  showAction: true,
                  actionLabel: l10n.authConnectWalletButton,
                  onAction: () =>
                      Navigator.of(context).pushNamed('/connect-wallet'),
                ),
              ),
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
              // Listed for sale section
              if (myCollectiblesForSale.isNotEmpty) ...[
                _MarketplaceSectionHeader(
                  title: l10n.marketplaceListedForSaleTitle,
                  subtitle: l10n.marketplaceListedForSaleSubtitle,
                  trailing: _MarketplaceCountPill(
                    label: l10n.marketplaceMyCollectionCount(
                      myCollectiblesForSale.length,
                    ),
                    accent: KubusColorRoles.of(context).warningAction,
                  ),
                ),
                const SizedBox(height: KubusSpacing.md),
                SizedBox(
                  height: 240,
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
                        width: 172,
                        margin: const EdgeInsets.only(right: KubusSpacing.md),
                        child: _buildCollectibleCard(collectible, entry,
                            isForSale: true),
                      );
                    },
                  ),
                ),
                const SizedBox(height: KubusSpacing.xl),
              ],

              _MarketplaceSectionHeader(
                title: l10n.marketplaceOwnedCollectionTitle,
                subtitle: l10n.marketplaceOwnedCollectionSubtitle,
                trailing: _MarketplaceCountPill(
                  label: l10n.marketplaceMyCollectionCount(
                    myCollectibles.length,
                  ),
                  accent: KubusColorRoles.of(context).web3MarketplaceAccent,
                ),
              ),
              const SizedBox(height: KubusSpacing.md),

              // All owned NFTs
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                  final childAspectRatio =
                      constraints.maxWidth > 600 ? 0.74 : 0.68;

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
    final scheme = Theme.of(context).colorScheme;
    final series = entry.series;
    final coverUrl = entry.coverUrl;
    final collectiblesProvider =
        Provider.of<CollectiblesProvider>(context, listen: false);
    final value =
        collectiblesProvider.getDisplayValueForCollectible(collectible) ??
            entry.displayValue;
    return Semantics(
        button: true,
        label: l10n.marketplaceOpenCollectibleDetailsSemantic(
          entry.title,
          collectible.tokenId,
        ),
        child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(KubusRadius.lg),
            child: InkWell(
              borderRadius: BorderRadius.circular(KubusRadius.lg),
              onTap: () => _showCollectibleDetails(collectible, entry),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(KubusRadius.lg),
                  border: Border.all(
                    color: isForSale
                        ? roles.warningAction
                        : scheme.outline.withValues(alpha: 0.36),
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
                                    borderRadius:
                                        BorderRadius.circular(KubusRadius.md),
                                  ),
                                  child: Text(
                                    l10n.commonForSale,
                                    style:
                                        KubusTextStyles.compactBadge.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: scheme.onSurface,
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
                                      .surface
                                      .withValues(alpha: 0.86),
                                  borderRadius:
                                      BorderRadius.circular(KubusRadius.sm),
                                ),
                                child: Text(
                                  l10n.marketplaceTokenNumberLabel(
                                    collectible.tokenId,
                                  ),
                                  style: KubusTextStyles.compactBadge.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onSurface,
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
                              '${entry.title} ${l10n.marketplaceTokenNumberLabel(collectible.tokenId)}',
                              style: KubusTextStyles.detailCardTitle.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _statusLabel(collectible.status, l10n),
                              style: KubusTextStyles.detailCaption.copyWith(
                                fontSize: 12,
                                color: scheme.onSurface.withValues(alpha: 0.6),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),

                            // Price or status
                            if (isForSale &&
                                collectible.currentListingPrice != null)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.marketplaceListedForLabel,
                                          style: KubusTextStyles.detailCaption
                                              .copyWith(
                                            fontSize: 11,
                                            color: scheme.onSurface
                                                .withValues(alpha: 0.58),
                                          ),
                                        ),
                                        Text(
                                          MarketplaceValueFormatter
                                              .formatDisplayValue(
                                            value,
                                            fallback:
                                                '${collectible.currentListingPrice} KUB8',
                                          ),
                                          style: KubusTextStyles.detailLabel
                                              .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: roles.warningAction,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        _removeFromSale(collectible),
                                    tooltip:
                                        l10n.marketplaceRemoveFromSaleTooltip,
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _displayValueLabel(
                                            value,
                                            l10n,
                                            fallback:
                                                l10n.marketplaceOwnedLabel,
                                          ),
                                          style: KubusTextStyles.detailCaption
                                              .copyWith(
                                            fontSize: 11,
                                            color: AppColorUtils.amberAccent,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          _displayValueText(value, l10n),
                                          style: KubusTextStyles.detailLabel
                                              .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: scheme.onSurface,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        _listForSale(collectible, entry.title),
                                    tooltip: l10n.marketplaceListForSaleTooltip,
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
            )));
  }

  void _showCollectibleDetails(
      Collectible collectible, MarketplaceArtworkEntry entry) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
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
          color: scheme.primaryContainer,
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
                    '${entry.title} ${l10n.marketplaceTokenNumberLabel(collectible.tokenId)}',
                    style: KubusTextStyles.sheetTitle.copyWith(
                      color: scheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    collectible.isForSale
                        ? l10n.marketplaceOwnedNftListedStatus
                        : l10n.marketplaceOwnedNftStatus,
                    textAlign: TextAlign.center,
                    style: KubusTextStyles.sheetSubtitle.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.68),
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
                    if (_visibleCollectibleProperties(collectible)
                        .isNotEmpty) ...[
                      Text(
                        l10n.marketplacePropertiesTitle,
                        style: KubusTextStyles.detailSectionTitle.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: KubusSpacing.sm,
                        runSpacing: KubusSpacing.sm,
                        children: _visibleCollectibleProperties(collectible)
                            .map((entry) {
                          return Container(
                            padding: const EdgeInsets.all(KubusSpacing.sm),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius:
                                  BorderRadius.circular(KubusRadius.sm),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _propertyLabel(entry.key, l10n),
                                  style: KubusTextStyles.detailCaption.copyWith(
                                    fontSize: 11,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.62),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.value.toString(),
                                  style: KubusTypography.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: scheme.onSurface,
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
                      l10n.commonDetails,
                      style: KubusTextStyles.detailSectionTitle.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (series != null)
                      _buildDetailRow(
                        l10n.marketplaceDetailCollectionLabel,
                        series.name,
                      ),
                    _buildDetailRow(
                      l10n.marketplaceDetailArtworkLabel,
                      entry.artwork.title,
                    ),
                    _buildDetailRow(
                      l10n.marketplaceTokenIdLabel,
                      l10n.marketplaceTokenNumberLabel(collectible.tokenId),
                    ),
                    _buildDetailRow(
                      l10n.marketplaceMintedLabel,
                      _formatDate(collectible.mintedAt),
                    ),
                    if (collectibleValue != null)
                      _buildDetailRow(
                        _displayValueLabel(collectibleValue, l10n),
                        _displayValueText(collectibleValue, l10n),
                      ),
                    _buildDetailRow(
                      l10n.commonStatus,
                      _statusLabel(collectible.status, l10n),
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
      padding: const EdgeInsets.symmetric(vertical: KubusSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: KubusTextStyles.detailCaption.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: KubusTextStyles.detailLabel.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _displayValueLabel(
    MarketplaceDisplayValue? value,
    AppLocalizations l10n, {
    String? fallback,
  }) {
    switch (value?.source) {
      case MarketplaceValueSource.listing:
      case MarketplaceValueSource.artworkListing:
        return l10n.marketplaceListedForLabel;
      case MarketplaceValueSource.lastSale:
        return l10n.marketplaceValueLastSaleLabel;
      case MarketplaceValueSource.mint:
        return l10n.marketplaceValueMintPriceLabel;
      case null:
        return fallback ?? l10n.marketplaceValueNotListedLabel;
    }
  }

  String _displayValueText(
    MarketplaceDisplayValue? value,
    AppLocalizations l10n, {
    String? fallback,
  }) {
    return MarketplaceValueFormatter.formatDisplayValue(
      value,
      fallback: fallback ?? l10n.marketplaceValueNotListedLabel,
    );
  }

  String _rarityLabel(CollectibleRarity? rarity, AppLocalizations l10n) {
    switch (rarity) {
      case CollectibleRarity.common:
        return l10n.collectibleRarityCommon;
      case CollectibleRarity.uncommon:
        return l10n.collectibleRarityUncommon;
      case CollectibleRarity.rare:
        return l10n.collectibleRarityRare;
      case CollectibleRarity.epic:
        return l10n.collectibleRarityEpic;
      case CollectibleRarity.legendary:
        return l10n.collectibleRarityLegendary;
      case CollectibleRarity.mythic:
        return l10n.collectibleRarityMythic;
      case null:
        return l10n.marketplaceNftCollectibleLabel;
    }
  }

  String _statusLabel(CollectibleStatus status, AppLocalizations l10n) {
    switch (status) {
      case CollectibleStatus.minted:
        return l10n.collectibleStatusMinted;
      case CollectibleStatus.listed:
        return l10n.collectibleStatusListed;
      case CollectibleStatus.sold:
        return l10n.collectibleStatusSold;
      case CollectibleStatus.transferred:
        return l10n.collectibleStatusTransferred;
      case CollectibleStatus.burned:
        return l10n.collectibleStatusBurned;
    }
  }

  Iterable<MapEntry<String, dynamic>> _visibleCollectibleProperties(
    Collectible collectible,
  ) {
    return collectible.properties.entries.where((entry) {
      final key = entry.key.trim();
      return key.isNotEmpty;
    });
  }

  String _propertyLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'mint_timestamp':
        return l10n.marketplacePropertyMintTimestampLabel;
      case 'minted_by':
        return l10n.marketplacePropertyMintedByLabel;
      default:
        return key
            .split('_')
            .where((part) => part.trim().isNotEmpty)
            .map((part) => part[0].toUpperCase() + part.substring(1))
            .join(' ');
    }
  }

  String _formatDate(DateTime date) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMd(locale).format(date);
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
    final l10n = AppLocalizations.of(context)!;
    final tokenLabel = entryTitle.isEmpty
        ? l10n.marketplaceTokenNumberLabel(collectible.tokenId)
        : '$entryTitle ${l10n.marketplaceTokenNumberLabel(collectible.tokenId)}';
    String? errorText;

    showKubusDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final scheme = Theme.of(context).colorScheme;
          void validate(String raw) {
            final price = double.tryParse(raw.trim());
            setDialogState(() {
              if (raw.trim().isEmpty) {
                errorText = l10n.marketplacePriceRequiredError;
              } else if (price == null || price <= 0) {
                errorText = l10n.marketplacePriceInvalidError;
              } else {
                errorText = null;
              }
            });
          }

          final parsedPrice = double.tryParse(priceController.text.trim());
          final canSubmit = parsedPrice != null && parsedPrice > 0;

          return KubusAlertDialog(
            backgroundColor: scheme.primaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(KubusRadius.lg),
            ),
            title: Text(
              l10n.marketplaceListNftForSaleTitle,
              style: KubusTextStyles.detailSectionTitle.copyWith(
                color: scheme.onSurface,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.marketplaceListingDialogDescription(tokenLabel),
                  style: KubusTextStyles.detailBody.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: KubusSpacing.md),
                TextField(
                  controller: priceController,
                  style: KubusTypography.inter(color: scheme.onSurface),
                  decoration: InputDecoration(
                    labelText: l10n.marketplacePriceKub8Label,
                    errorText: errorText,
                    labelStyle: KubusTypography.inter(
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: scheme.outline.withValues(alpha: 0.44),
                      ),
                      borderRadius: BorderRadius.circular(KubusRadius.sm),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: themeProvider.accentColor),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(KubusRadius.sm),
                      ),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: validate,
                  onSubmitted: (_) {
                    validate(priceController.text);
                    final price = double.tryParse(priceController.text.trim());
                    if (price == null || price <= 0) return;
                    Navigator.of(context).pop();
                    _processListForSale(collectible, priceController.text);
                  },
                ),
              ],
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
                onPressed: canSubmit
                    ? () {
                        Navigator.of(context).pop();
                        _processListForSale(
                          collectible,
                          priceController.text.trim(),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.accentColor,
                  foregroundColor: scheme.onPrimary,
                ),
                child: Text(
                  l10n.marketplaceListForSaleButton,
                  style: KubusTypography.inter(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
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
    final collectiblesProvider = context.read<CollectiblesProvider>();
    final messenger = ScaffoldMessenger.of(context);
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
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await collectiblesProvider.removeCollectibleFromSale(
                  collectibleId: collectible.id,
                );
                if (!mounted) return;
                messenger.showKubusSnackBar(
                  SnackBar(
                    content: Text(l10n.marketplaceRemoveFromSaleSuccessToast),
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                );
              } catch (e) {
                if (kDebugMode) {
                  debugPrint('Marketplace: remove from sale failed: $e');
                }
                if (!mounted) return;
                messenger.showKubusSnackBar(
                  SnackBar(
                    content: Text(l10n.marketplaceRemoveFromSaleFailedToast),
                    backgroundColor: scheme.error,
                  ),
                );
              }
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
    final scheme = Theme.of(context).colorScheme;
    final series = entry.series;
    final progress = entry.mintProgress ?? 0;
    final progressPercentage = (progress * 100).toInt();
    final isNearSoldOut = progress > 0.8;
    final hasARFeature = entry.requiresArInteraction;
    final value = entry.displayValue;

    return Semantics(
        button: true,
        label: l10n.marketplaceOpenSeriesDetailsSemantic(entry.title),
        child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(KubusRadius.lg),
            child: InkWell(
              borderRadius: BorderRadius.circular(KubusRadius.lg),
              onTap: () => _showNFTSeriesDetails(entry),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(KubusRadius.lg),
                  border: Border.all(
                    color: hasARFeature
                        ? AppColorUtils.tealAccent
                        : scheme.outline.withValues(alpha: 0.36),
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
                                    borderRadius:
                                        BorderRadius.circular(KubusRadius.md),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.view_in_ar,
                                        size: 12,
                                        color: scheme.onSurface,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        l10n.marketplaceArBadgeLabel,
                                        style: KubusTextStyles.compactBadge
                                            .copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: scheme.onSurface,
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
                                    color: KubusColorRoles.of(context)
                                        .negativeAction,
                                    borderRadius:
                                        BorderRadius.circular(KubusRadius.md),
                                  ),
                                  child: Text(
                                    l10n.marketplaceSoldOutBadgeLabel,
                                    style:
                                        KubusTextStyles.compactBadge.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: scheme.onSurface,
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
                                    color:
                                        scheme.surface.withValues(alpha: 0.86),
                                    borderRadius:
                                        BorderRadius.circular(KubusRadius.sm),
                                  ),
                                  child: Text(
                                    _rarityLabel(entry.rarity, l10n),
                                    style:
                                        KubusTextStyles.compactBadge.copyWith(
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
                              style: KubusTextStyles.detailCardTitle.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.commonByArtist(entry.artistName),
                              style: KubusTextStyles.detailCaption.copyWith(
                                fontSize: 12,
                                color: scheme.onSurface.withValues(alpha: 0.6),
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${entry.mintedCount}/${entry.totalSupply}',
                                          style: KubusTextStyles.detailCaption
                                              .copyWith(
                                            fontSize: 11,
                                            color: scheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '$progressPercentage%',
                                        style: KubusTextStyles.detailCaption
                                            .copyWith(
                                          fontSize: 11,
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
                                            ? KubusColorRoles.of(context)
                                                .warningAction
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _displayValueLabel(
                                          value,
                                          l10n,
                                          fallback: l10n.commonStatus,
                                        ),
                                        style: KubusTextStyles.detailCaption
                                            .copyWith(
                                          fontSize: 11,
                                          color: scheme.onSurface
                                              .withValues(alpha: 0.58),
                                        ),
                                      ),
                                      Text(
                                        _displayValueText(value, l10n),
                                        style: KubusTextStyles.detailLabel
                                            .copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: scheme.onSurface,
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
                                        ? KubusColorRoles.of(context)
                                            .warningAction
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
                                    style:
                                        KubusTextStyles.compactBadge.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onSurface,
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
            )));
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
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
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
                        color: scheme.onSurface.withValues(alpha: 0.78),
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
                            _displayValueLabel(
                              entry.displayValue,
                              l10n,
                              fallback: l10n.commonStatus,
                            ),
                            MarketplaceValueFormatter.formatDisplayValue(
                              entry.displayValue,
                              fallback: l10n.marketplaceValueNotListedLabel,
                            ),
                            icon: Icons.sell_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            l10n.marketplaceRarityLabel,
                            _rarityLabel(entry.rarity, l10n),
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
                          tooltip: l10n.marketplaceShareTooltip,
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
                              color: scheme.surfaceContainerHighest,
                              borderRadius:
                                  BorderRadius.circular(KubusRadius.md),
                            ),
                            child: Icon(
                              Icons.share,
                              color: scheme.onSurface,
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
    final scheme = Theme.of(context).colorScheme;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: scheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KubusRadius.lg),
        ),
        title: Text(
          l10n.marketplaceMintDialogTitle,
          style: KubusTypography.inter(
            color: scheme.onSurface,
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
                color: scheme.onSurface.withValues(alpha: 0.78),
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
        throw Exception(
          AppLocalizations.of(context)!.marketplaceMintConnectWalletDescription,
        );
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
                  if (!mounted) return;
                  unawaited(
                    HomeQuickActionExecutor.execute(
                      this.context,
                      'wallet',
                      source: HomeQuickActionSurface.legacyProvider,
                    ),
                  );
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

class _MarketplaceSectionHeader extends StatelessWidget {
  const _MarketplaceSectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: KubusTextStyles.sectionTitle.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: KubusSpacing.xs),
              Text(
                subtitle,
                style: KubusTextStyles.sectionSubtitle.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: KubusSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

class _MarketplaceCountPill extends StatelessWidget {
  const _MarketplaceCountPill({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.sm,
        vertical: KubusSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(color: accent.withValues(alpha: 0.38)),
      ),
      child: Text(
        label,
        style: KubusTextStyles.compactBadge.copyWith(color: accent),
      ),
    );
  }
}
