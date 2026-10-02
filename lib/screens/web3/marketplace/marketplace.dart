import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../onboarding/web3/web3_onboarding.dart';
import '../../onboarding/web3/onboarding_data.dart';
import '../../../providers/collectibles_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../features/web3/web3_capabilities.dart';
import '../../../models/collectible.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../utils/marketplace_value_formatter.dart';
import '../../../utils/wallet_action_guard.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/kubus_labs_feature.dart';
import '../../../utils/design_tokens.dart';
import '../../../services/share/share_service.dart';
import '../../../services/share/share_types.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/common/kubus_labs_adornment.dart';
import 'package:art_kubus/widgets/common/kubus_stat_card.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import '../../../widgets/dashboard/kubus_dashboard_chrome.dart';
import '../../../widgets/marketplace/marketplace_listing_card.dart';
import '../../../widgets/states/kubus_product_states.dart';
import '../../../widgets/common/kubus_cached_image.dart';
import '../../../widgets/kubus_button.dart';

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
        // No title: the dashboard header below is the page title and
        // carries the Lab marker. The bar holds actions only.
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
          style: KubusTypography.content(
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
                activeThumbColor: KubusColorRoles.of(context).active,
                title: Text(
                  l10n.marketplaceSettingsShowArOnlyTitle,
                  style: KubusTypography.content(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  l10n.marketplaceSettingsShowArOnlyDescription,
                  style: KubusTypography.content(
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
                      style: KubusTypography.content(
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
                        style: KubusTypography.content(
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
              style: KubusTypography.content(
                color: KubusColorRoles.of(context).foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplaceHeader() {
    final l10n = AppLocalizations.of(context)!;
    return KubusDashboardHeader(
      notion: l10n.dashboardNotionInfrastructure,
      title: l10n.navigationScreenMarketplace,
      accent: KubusColorRoles.of(context).web3MarketplaceAccent,
      glyph: Icons.storefront_outlined,
      lede: l10n.homeWeb3MarketplaceSubtitle,
      actions: const [
        KubusLabsAdornment.inlinePill(
          feature: KubusLabsFeature.marketplace,
          emphasized: true,
        ),
      ],
    );
  }

  Widget _buildNavigationTabs() {
    final l10n = AppLocalizations.of(context)!;
    return KubusDashboardTabs(
      selectedIndex: _selectedIndex,
      onSelected: (index) => setState(() => _selectedIndex = index),
      tabs: [
        KubusDashboardTab(
          label: l10n.marketplaceFeaturedTab,
          icon: Icons.star_outline,
        ),
        KubusDashboardTab(
          label: l10n.marketplaceTrendingTab,
          icon: Icons.trending_up,
        ),
        KubusDashboardTab(
          label: l10n.marketplaceMyListingsTab,
          icon: Icons.inventory_2_outlined,
        ),
      ],
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
                const KubusSectionLoading(rows: 3, rowHeight: 180)
              else if (collectiblesProvider.error != null &&
                  featuredEntries.isEmpty)
                KubusStateView.fromError(
                  collectiblesProvider.error,
                  compact: true,
                  onRetry: () => collectiblesProvider.initialize(),
                )
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
              if (collectiblesProvider.error != null && trendingEntries.isEmpty)
                KubusStateView.fromError(
                  collectiblesProvider.error,
                  compact: true,
                  onRetry: () => collectiblesProvider.initialize(),
                )
              else if (trendingEntries.isEmpty)
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
        final childAspectRatio = constraints.maxWidth > 620 ? 0.74 : 0.62;

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
    final roles = KubusColorRoles.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.sm,
        vertical: KubusSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _showArOnly ? roles.surfaceRaised : roles.surface,
        borderRadius: BorderRadius.circular(KubusRadius.control),
        border: Border.all(
          color: _showArOnly ? roles.ruleStrong : roles.rule,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _showArOnly ? Icons.view_in_ar : Icons.filter_alt_outlined,
            size: 14,
            color: roles.foregroundMuted,
          ),
          const SizedBox(width: KubusSpacing.xs),
          Text(
            _showArOnly
                ? l10n.marketplaceArOnlyFilterActiveLabel
                : l10n.marketplaceArOnlyFilterInactiveLabel,
            style: KubusTextStyles.compactBadge.copyWith(
              color: roles.foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyListings() {
    return Consumer2<CollectiblesProvider, ThemeProvider>(
      builder: (context, collectiblesProvider, themeProvider, child) {
        final l10n = AppLocalizations.of(context)!;
        final profileProvider = context.watch<ProfileProvider>();
        final walletProvider = context.watch<WalletProvider>();
        final capabilities = Web3CapabilityResolver.resolve(
          Web3CapabilityContext.fromProviders(
            profileProvider: profileProvider,
            walletProvider: walletProvider,
          ),
        );
        // Show user's collectibles using real wallet address
        final walletAddress = walletProvider.authority.walletAddress ?? '';
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
        if (!capabilities.hasWalletIdentity) {
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
                  onAction: () => WalletActionGuard.ensureSignerAccess(
                    context: context,
                    profileProvider: profileProvider,
                    walletProvider: walletProvider,
                    returnRoute: '/marketplace',
                  ),
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
              if (capabilities.hasAccount &&
                  capabilities.hasWalletIdentity &&
                  !capabilities.signerReady) ...[
                KubusNoticeBanner(
                  margin: EdgeInsets.zero,
                  icon: Icons.link_off,
                  title: l10n.walletReadOnlyStatus,
                  message: AppLocalizations.of(context)!
                      .walletReconnectManualRequiredToast,
                ),
                const SizedBox(height: KubusSpacing.sm),
                KubusButton(
                  onPressed: () async {
                    await WalletActionGuard.ensureSignerAccess(
                      context: context,
                      profileProvider: profileProvider,
                      walletProvider: walletProvider,
                      returnRoute: '/marketplace',
                    );
                  },
                  icon: Icons.link,
                  label: AppLocalizations.of(context)!.commonReconnect,
                  variant: KubusButtonVariant.secondary,
                ),
                const SizedBox(height: KubusSpacing.md),
              ],
              // Listed for sale section
              if (myCollectiblesForSale.isNotEmpty) ...[
                _MarketplaceSectionHeader(
                  title: l10n.marketplaceListedForSaleTitle,
                  subtitle: l10n.marketplaceListedForSaleSubtitle,
                  trailing: _MarketplaceCountPill(
                    label: l10n.marketplaceMyCollectionCount(
                      myCollectiblesForSale.length,
                    ),
                    accent: KubusColorRoles.of(context).foregroundMuted,
                  ),
                ),
                const SizedBox(height: KubusSpacing.md),
                SizedBox(
                  height: 300,
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
                        width: 190,
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
                  accent: KubusColorRoles.of(context).foregroundMuted,
                ),
              ),
              const SizedBox(height: KubusSpacing.md),

              // All owned NFTs
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                  final childAspectRatio =
                      constraints.maxWidth > 600 ? 0.74 : 0.52;

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

  /// An edition the viewer owns. Cultural identity first (image, artwork,
  /// token number), then the economic state: this edition's listing price
  /// when it is for sale, otherwise its reference value, and an explicit
  /// List / Remove action when the wallet may perform it (44 px targets).
  Widget _buildCollectibleCard(
      Collectible collectible, MarketplaceArtworkEntry entry,
      {bool isForSale = false}) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final collectiblesProvider =
        Provider.of<CollectiblesProvider>(context, listen: false);
    final value =
        collectiblesProvider.getDisplayValueForCollectible(collectible) ??
            entry.displayValue;
    final capabilities = Web3CapabilityResolver.resolve(
      Web3CapabilityContext.fromProviders(
        profileProvider: context.watch<ProfileProvider>(),
        walletProvider: context.watch<WalletProvider>(),
        entityOwnerAddress: collectible.ownerAddress,
        entityIsListed: collectible.isForSale,
      ),
    );
    final tokenLabel = l10n.marketplaceTokenNumberLabel(collectible.tokenId);
    final hasAmount = value?.hasAmount ?? false;

    return Semantics(
      button: true,
      label: l10n.marketplaceOpenCollectibleDetailsSemantic(
        entry.title,
        collectible.tokenId,
      ),
      child: Material(
        color: roles.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KubusRadius.surface),
          side: BorderSide(color: roles.rule),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showCollectibleDetails(collectible, entry),
          focusColor: roles.focus.withValues(alpha: 0.12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: roles.surfaceRaised),
                    if ((entry.coverUrl ?? '').trim().isNotEmpty)
                      KubusCachedImage(
                        imageUrl: entry.coverUrl,
                        semanticLabel: entry.title,
                      )
                    else
                      Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 32,
                          color: roles.foregroundSubtle,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KubusTextStyles.detailCardTitle.copyWith(
                        color: roles.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      tokenLabel,
                      style: KubusTextStyles.machineValue.copyWith(
                        color: roles.foregroundMuted,
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    KubusStatusText(
                      label: isForSale || collectible.isForSale
                          ? l10n.commonForSale
                          : _statusLabel(collectible.status, l10n),
                      tone: isForSale || collectible.isForSale
                          ? KubusStatusTone.positive
                          : KubusStatusTone.neutral,
                    ),
                    if (hasAmount) ...[
                      const SizedBox(height: KubusSpacing.xs),
                      Text(
                        _displayValueLabel(value, l10n),
                        style: KubusTextStyles.detailCaption.copyWith(
                          color: roles.foregroundMuted,
                        ),
                      ),
                      Text(
                        _displayValueText(value, l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KubusTextStyles.detailLabel.copyWith(
                          color: roles.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (capabilities.canUnlistEdition ||
                        capabilities.canListEdition) ...[
                      const SizedBox(height: KubusSpacing.sm),
                      KubusButton(
                        isFullWidth: true,
                        onPressed: capabilities.canUnlistEdition
                            ? () => _removeFromSale(collectible)
                            : () => _listForSale(collectible, entry.title),
                        label: capabilities.canUnlistEdition
                            ? l10n.marketplaceRemoveFromSaleTitle
                            : l10n.marketplaceListNftForSaleTitle,
                        variant: capabilities.canUnlistEdition
                            ? KubusButtonVariant.quiet
                            : KubusButtonVariant.secondary,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                                  style: KubusTypography.content(
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
      returnRoute: '/marketplace',
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
                  style: KubusTypography.content(color: scheme.onSurface),
                  decoration: InputDecoration(
                    labelText: l10n.marketplacePriceKub8Label,
                    errorText: errorText,
                    labelStyle: KubusTypography.content(
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
                  style: KubusTypography.content(
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
                  style: KubusTypography.content(
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
      returnRoute: '/marketplace',
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

  Future<void> _removeFromSale(Collectible collectible) async {
    final profileProvider = context.read<ProfileProvider>();
    final walletProvider = context.read<WalletProvider>();
    final capabilities = Web3CapabilityResolver.resolve(
      Web3CapabilityContext.fromProviders(
        profileProvider: profileProvider,
        walletProvider: walletProvider,
        entityOwnerAddress: collectible.ownerAddress,
        entityIsListed: collectible.isForSale,
      ),
    );
    if (!capabilities.canUnlistEdition) return;

    final canProceed = await WalletActionGuard.ensureSignerAccess(
      context: context,
      profileProvider: profileProvider,
      walletProvider: walletProvider,
      returnRoute: '/marketplace',
    );
    if (!mounted || !canProceed) return;

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
          style: KubusTypography.content(
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.marketplaceRemoveFromSaleConfirmBody,
          style: KubusTypography.content(
            color: scheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              l10n.commonCancel,
              style: KubusTypography.content(
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
              style: KubusTypography.content(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplaceEntryCard(MarketplaceArtworkEntry entry) {
    return MarketplaceListingCard(
      entry: entry,
      onOpen: () => _showNFTSeriesDetails(entry),
    );
  }

  void _showNFTSeriesDetails(MarketplaceArtworkEntry entry) {
    final series = entry.series;
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
                    style: KubusTypography.content(
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
                    style: KubusTypography.content(
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
                      style: KubusTypography.content(
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
                      style: KubusTypography.content(
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
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
                            borderRadius: BorderRadius.circular(KubusRadius.md),
                          ),
                          child: Icon(
                            Icons.share,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
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
      accent: KubusColorRoles.of(context).web3MarketplaceAccent,
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
