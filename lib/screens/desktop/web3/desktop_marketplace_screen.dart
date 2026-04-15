import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../models/collectible.dart';
import '../../../providers/collectibles_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/kubus_labs_feature.dart';
import '../../../utils/marketplace_value_formatter.dart';
import '../../../utils/wallet_action_guard.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/design_tokens.dart';
import '../../../widgets/artwork_creator_byline.dart';
import '../../../widgets/common/kubus_labs_adornment.dart';
import '../../../widgets/common/kubus_screen_header.dart';
import '../../../widgets/detail/detail_shell_components.dart';
import '../../../widgets/glass_components.dart';
import '../components/desktop_widgets.dart';
import '../../art/ar_screen.dart';
import 'desktop_wallet_screen.dart';

/// Desktop marketplace screen with OpenSea-style NFT grid
/// Features advanced filtering, sorting, and collection browsing
class DesktopMarketplaceScreen extends StatefulWidget {
  const DesktopMarketplaceScreen({super.key});

  @override
  State<DesktopMarketplaceScreen> createState() =>
      _DesktopMarketplaceScreenState();
}

class _DesktopMarketplaceScreenState extends State<DesktopMarketplaceScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late TabController _tabController;
  late ScrollController _scrollController;

  final List<String> _tabs = [
    'All NFTs',
    'Art',
    'Photography',
    'Music',
    'Virtual Worlds'
  ];
  String _selectedSort = 'recent';
  String _selectedView = 'grid';
  bool _showFilters = false;
  RangeValues _priceRange = const RangeValues(0, 100);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _scrollController = ScrollController();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!mounted || _tabController.indexIsChanging) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          // Filters sidebar
          AnimatedContainer(
            duration: animationTheme.medium,
            width: _showFilters ? 280 : 0,
            child: _showFilters
                ? _buildFiltersSidebar(themeProvider)
                : const SizedBox.shrink(),
          ),

          // Main content
          Expanded(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _animationController,
                    curve: animationTheme.fadeCurve,
                  ),
                  child: Column(
                    children: [
                      // Header
                      _buildHeader(themeProvider),

                      // Category tabs
                      _buildCategoryTabs(themeProvider),

                      // Stats banner
                      _buildStatsBanner(themeProvider),

                      // Toolbar
                      _buildToolbar(themeProvider),

                      // NFT Grid
                      Expanded(
                        child: _buildNFTGrid(themeProvider, isLarge),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.lg + KubusSpacing.xs),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NFT Marketplace',
                style: KubusTextStyles.screenTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: KubusSpacing.sm),
              const KubusLabsAdornment.inlinePill(
                feature: KubusLabsFeature.marketplace,
                emphasized: true,
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 400,
            child: DesktopSearchBar(
              hintText: 'Search NFTs, collections, artists...',
              onSubmitted: (value) {},
            ),
          ),
          const SizedBox(width: KubusSpacing.lg),
          Consumer<Web3Provider>(
            builder: (context, web3Provider, _) {
              final walletProvider = Provider.of<WalletProvider?>(
                context,
                listen: false,
              );
              final profileProvider = Provider.of<ProfileProvider?>(
                context,
                listen: false,
              );

              final canCreate = web3Provider.canTransact;
              final hasWalletIdentity = walletProvider?.hasWalletIdentity ??
                  web3Provider.walletAddress.trim().isNotEmpty;

              return ElevatedButton.icon(
                onPressed: () async {
                  if (canCreate) {
                    // Create NFT
                    return;
                  }

                  if (walletProvider == null || profileProvider == null) {
                    if (!context.mounted) return;
                    Navigator.of(context).pushNamed('/connect-wallet');
                    return;
                  }

                  await WalletActionGuard.ensureSignerAccess(
                    context: context,
                    profileProvider: profileProvider,
                    walletProvider: walletProvider,
                  );
                },
                icon: Icon(
                  canCreate
                      ? Icons.add
                      : hasWalletIdentity
                          ? Icons.refresh
                          : Icons.account_balance_wallet,
                  size: KubusHeaderMetrics.actionIcon,
                ),
                label: Text(
                  canCreate
                      ? l10n.commonCreate
                      : hasWalletIdentity
                          ? l10n.commonReconnect
                          : l10n.authConnectWalletButton,
                  style: KubusTextStyles.detailButton,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.lg + KubusSpacing.xs,
                    vertical: KubusSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DetailRadius.md),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.lg + KubusSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: themeProvider.accentColor,
        unselectedLabelColor:
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        labelStyle: KubusTextStyles.detailLabel.copyWith(
          color: themeProvider.accentColor,
        ),
        unselectedLabelStyle: KubusTextStyles.detailBody.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        indicatorColor: themeProvider.accentColor,
        indicatorWeight: 3,
        dividerColor: Colors.transparent,
        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  Widget _buildStatsBanner(ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.all(KubusSpacing.lg + KubusSpacing.xs),
      padding: const EdgeInsets.all(KubusSpacing.lg + KubusSpacing.xs),
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
      child: Consumer<CollectiblesProvider>(
        builder: (context, collectiblesProvider, _) {
          final entries = _resolveVisibleEntries(collectiblesProvider);
          final totalArtworks = entries.length;
          final arEnabled =
              entries.where((entry) => entry.requiresArInteraction).length;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total Artworks', totalArtworks.toString(),
                  Icons.collections),
              _buildVerticalDivider(),
              _buildStatItem(
                  'AR Ready', arEnabled.toString(), Icons.view_in_ar),
              _buildVerticalDivider(),
              _buildStatItem(
                  'Available', totalArtworks.toString(), Icons.storefront),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.7),
          size: KubusChromeMetrics.heroIcon,
        ),
        const SizedBox(height: KubusSpacing.sm),
        Text(
          value,
          style: KubusTextStyles.heroTitle.copyWith(color: Colors.white),
        ),
        const SizedBox(height: KubusSpacing.xs),
        Text(
          label,
          style: KubusTextStyles.heroSubtitle.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 60,
      width: 1,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildToolbar(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.lg + KubusSpacing.xs,
        vertical: KubusSpacing.md,
      ),
      child: Row(
        children: [
          // Filter button
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _showFilters = !_showFilters);
            },
            icon: Icon(
              _showFilters ? Icons.filter_list_off : Icons.filter_list,
              size: KubusHeaderMetrics.actionIcon,
            ),
            label: Text(
              _showFilters ? 'Hide Filters' : 'Filters',
              style: KubusTextStyles.detailButton,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.3),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: KubusSpacing.lg,
                vertical: KubusSpacing.md,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DetailRadius.sm + 2),
              ),
            ),
          ),
          const SizedBox(width: KubusSpacing.lg),

          // Results count
          Consumer<CollectiblesProvider>(
            builder: (context, collectiblesProvider, _) {
              return Text(
                '${_resolveVisibleEntries(collectiblesProvider).length} items',
                style: KubusTextStyles.sectionSubtitle.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
              );
            },
          ),
          const Spacer(),

          // Sort dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(DetailRadius.sm + 2),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
              ),
            ),
            child: DropdownButton<String>(
              value: _selectedSort,
              underline: const SizedBox.shrink(),
              icon: const Icon(Icons.keyboard_arrow_down),
              items: const [
                DropdownMenuItem(
                    value: 'recent', child: Text('Recently Listed')),
                DropdownMenuItem(
                    value: 'price_low', child: Text('Price: Low to High')),
                DropdownMenuItem(
                    value: 'price_high', child: Text('Price: High to Low')),
                DropdownMenuItem(value: 'popular', child: Text('Most Popular')),
                DropdownMenuItem(value: 'ending', child: Text('Ending Soon')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedSort = value);
                }
              },
            ),
          ),
          const SizedBox(width: KubusSpacing.md),

          // View toggle
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(DetailRadius.sm + 2),
            ),
            child: Row(
              children: [
                _buildViewToggle('grid', Icons.grid_view, themeProvider),
                _buildViewToggle('list', Icons.view_list, themeProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle(
      String view, IconData icon, ThemeProvider themeProvider) {
    final isActive = _selectedView == view;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedView = view);
        },
        borderRadius: BorderRadius.circular(DetailRadius.sm),
        child: Container(
          padding: const EdgeInsets.all(KubusSpacing.md),
          decoration: BoxDecoration(
            color: isActive ? themeProvider.accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(DetailRadius.sm),
          ),
          child: Icon(
            icon,
            size: KubusHeaderMetrics.actionIcon,
            color: isActive
                ? Colors.white
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersSidebar(ThemeProvider themeProvider) {
    final glassStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.sidebarBackground,
    );
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: LiquidGlassPanel(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: BorderRadius.zero,
        showBorder: false,
        backgroundColor: glassStyle.tintColor,
        blurSigma: glassStyle.blurSigma,
        fallbackMinOpacity: glassStyle.fallbackMinOpacity,
        child: ListView(
          padding: const EdgeInsets.all(KubusSpacing.lg + KubusSpacing.xs),
          children: [
            KubusSectionHeader(
              title: 'Filters',
              action: TextButton(
                onPressed: () {
                  // Reset filters
                },
                child: Text(
                  'Reset',
                  style: KubusTextStyles.detailButton.copyWith(
                    color: themeProvider.accentColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: KubusSpacing.lg + KubusSpacing.xs),

            // Status
            _buildFilterSection('Status', [
              _buildCheckboxFilter('Buy Now', true, themeProvider),
              _buildCheckboxFilter('On Auction', false, themeProvider),
              _buildCheckboxFilter('New', false, themeProvider),
              _buildCheckboxFilter('Has Offers', false, themeProvider),
            ]),
            const SizedBox(height: KubusSpacing.lg + KubusSpacing.xs),

            // Price range
            Text(
              'Price Range (KUB8)',
              style: KubusTextStyles.detailLabel.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: KubusSpacing.md),
            RangeSlider(
              values: _priceRange,
              min: 0,
              max: 100,
              divisions: 20,
              activeColor: themeProvider.accentColor,
              onChanged: (values) {
                setState(() => _priceRange = values);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_priceRange.start.toInt()} KUB8',
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  '${_priceRange.end.toInt()} KUB8',
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KubusSpacing.lg + KubusSpacing.xs),

            // Blockchain
            _buildFilterSection('Blockchain', [
              _buildCheckboxFilter('Solana', true, themeProvider),
              _buildCheckboxFilter('Ethereum', false, themeProvider),
              _buildCheckboxFilter('Polygon', false, themeProvider),
            ]),
            const SizedBox(height: KubusSpacing.lg + KubusSpacing.xs),

            // AR Features
            _buildFilterSection('Features', [
              _buildCheckboxFilter('AR Enabled', false, themeProvider),
              _buildCheckboxFilter('3D Model', false, themeProvider),
              _buildCheckboxFilter('Unlockable', false, themeProvider),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: KubusTextStyles.detailLabel.copyWith(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        ...children,
      ],
    );
  }

  Widget _buildCheckboxFilter(
      String label, bool checked, ThemeProvider themeProvider) {
    return Container(
      margin: EdgeInsets.only(bottom: DetailSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: KubusHeaderMetrics.actionHitArea - 24,
            height: KubusHeaderMetrics.actionHitArea - 24,
            child: Checkbox(
              value: checked,
              onChanged: (value) {},
              activeColor: themeProvider.accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: KubusSpacing.md),
          Text(
            label,
            style: KubusTextStyles.detailBody.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  List<MarketplaceArtworkEntry> _resolveVisibleEntries(
    CollectiblesProvider collectiblesProvider,
  ) {
    final selectedTab = _tabs[_tabController.index].toLowerCase();
    final entries = collectiblesProvider.marketplaceEntries.where((entry) {
      if (selectedTab == 'all nfts') return true;
      final haystack = <String>[
        entry.title,
        entry.artwork.category,
        entry.artwork.description,
      ].join(' ').toLowerCase();
      switch (selectedTab) {
        case 'art':
          return true;
        case 'photography':
          return haystack.contains('photo');
        case 'music':
          return haystack.contains('music') || haystack.contains('audio');
        case 'virtual worlds':
          return haystack.contains('virtual') ||
              haystack.contains('3d') ||
              haystack.contains('world');
        default:
          return true;
      }
    }).where((entry) {
      final amount = entry.displayValue?.amount;
      if (amount == null) {
        return _priceRange.start <= 0;
      }
      return amount >= _priceRange.start && amount <= _priceRange.end;
    }).toList();

    int compareByAmount(MarketplaceArtworkEntry a, MarketplaceArtworkEntry b) {
      final aAmount = a.displayValue?.amount;
      final bAmount = b.displayValue?.amount;
      if (aAmount == null && bAmount == null) return 0;
      if (aAmount == null) return 1;
      if (bAmount == null) return -1;
      return aAmount.compareTo(bAmount);
    }

    switch (_selectedSort) {
      case 'price_low':
        entries.sort(compareByAmount);
        break;
      case 'price_high':
        entries.sort((a, b) => compareByAmount(b, a));
        break;
      case 'popular':
        entries.sort(
          (a, b) => b.artwork.likesCount.compareTo(a.artwork.likesCount),
        );
        break;
      case 'ending':
        entries.sort((a, b) {
          final aRemaining = (a.totalSupply ?? 0) - (a.mintedCount ?? 0);
          final bRemaining = (b.totalSupply ?? 0) - (b.mintedCount ?? 0);
          return aRemaining.compareTo(bRemaining);
        });
        break;
      case 'recent':
      default:
        entries.sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));
        break;
    }

    return entries;
  }

  Widget _buildNFTGrid(ThemeProvider themeProvider, bool isLarge) {
    return Consumer<CollectiblesProvider>(
      builder: (context, collectiblesProvider, _) {
        final entries = _resolveVisibleEntries(collectiblesProvider);

        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.collections,
                  size: KubusChromeMetrics.heroIconBox + KubusSpacing.lg,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.25),
                ),
                const SizedBox(height: KubusSpacing.lg),
                Text(
                  'No NFTs found',
                  style: KubusTextStyles.detailCardTitle.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: KubusSpacing.sm),
                Text(
                  'Try adjusting your filters',
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(KubusSpacing.lg + KubusSpacing.xs),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isLarge ? 4 : 3,
            crossAxisSpacing: DetailSpacing.lg + DetailSpacing.xs,
            mainAxisSpacing: DetailSpacing.lg + DetailSpacing.xs,
            childAspectRatio: 0.75,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            return _buildNFTCard(entries[index], themeProvider);
          },
        );
      },
    );
  }

  Widget _buildNFTCard(
      MarketplaceArtworkEntry entry, ThemeProvider themeProvider) {
    final artwork = entry.artwork;
    final marketplaceAccent = KubusColorRoles.of(context).web3MarketplaceAccent;
    return DesktopCard(
      padding: EdgeInsets.zero,
      onTap: () {
        _showNFTDetail(entry, themeProvider);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    marketplaceAccent.withValues(alpha: 0.4),
                    marketplaceAccent.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(DetailRadius.lg)),
              ),
              child: Stack(
                children: [
                  if (entry.coverUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(DetailRadius.lg)),
                      child: Image.network(
                        entry.coverUrl!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.image,
                            size: KubusChromeMetrics.heroIcon,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(
                        Icons.image,
                        size: KubusChromeMetrics.heroIcon,
                        color: Colors.white,
                      ),
                    ),
                  // AR badge
                  if (entry.requiresArInteraction)
                    Positioned(
                      top: DetailSpacing.md,
                      right: DetailSpacing.md,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: KubusSpacing.sm,
                          vertical: KubusSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ECDC4),
                          borderRadius: BorderRadius.circular(DetailRadius.xs),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.view_in_ar,
                              size: KubusSizes.trailingChevron,
                              color: Colors.white,
                            ),
                            const SizedBox(width: KubusSpacing.xs),
                            Text(
                              'AR',
                              style: KubusTextStyles.compactBadge.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Favorite button
                  Positioned(
                    top: DetailSpacing.md,
                    left: DetailSpacing.md,
                    child: Container(
                      padding: const EdgeInsets.all(KubusSpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        artwork.isLikedByCurrentUser
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: KubusSizes.trailingChevron,
                        color: artwork.isLikedByCurrentUser
                            ? Colors.red
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Info
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.all(DetailSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: DetailTypography.cardTitle(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: KubusSpacing.xs),
                  ArtworkCreatorByline(
                    artwork: artwork,
                    style: KubusTextStyles.detailCaption.copyWith(
                      color: marketplaceAccent,
                    ),
                    maxLines: 1,
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.displayValue?.label ?? 'Status',
                            style: KubusTextStyles.detailLabel.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          Text(
                            MarketplaceValueFormatter.formatDisplayValue(
                              entry.displayValue,
                            ),
                            style: DetailTypography.cardTitle(context),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            size: KubusSizes.trailingChevron,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: KubusSpacing.xs),
                          Text(
                            '${artwork.likesCount}',
                            style: KubusTextStyles.detailCaption.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNFTDetail(
      MarketplaceArtworkEntry entry, ThemeProvider themeProvider) {
    final artwork = entry.artwork;
    final dialogGlassStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.panelBackground,
    );
    showKubusDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: LiquidGlassPanel(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(DetailRadius.xl),
            blurSigma: dialogGlassStyle.blurSigma,
            backgroundColor: dialogGlassStyle.tintColor,
            fallbackMinOpacity: dialogGlassStyle.fallbackMinOpacity,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 640),
              child: SizedBox(
                width: 860,
                child: Row(
                  children: [
                    // Image side
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              themeProvider.accentColor.withValues(alpha: 0.4),
                              themeProvider.accentColor.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.horizontal(
                              left: Radius.circular(DetailRadius.xl)),
                        ),
                        child: Stack(
                          children: [
                            if (entry.coverUrl != null)
                              ClipRRect(
                                borderRadius: BorderRadius.horizontal(
                                    left: Radius.circular(DetailRadius.xl)),
                                child: Image.network(
                                  entry.coverUrl!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(
                                      Icons.image,
                                      size: KubusChromeMetrics.heroIconBox +
                                          KubusSpacing.xl,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            else
                              const Center(
                                child: Icon(
                                  Icons.image,
                                  size: KubusChromeMetrics.heroIconBox +
                                      KubusSpacing.xl,
                                  color: Colors.white,
                                ),
                              ),
                            if (entry.requiresArInteraction)
                              Positioned(
                                bottom: DetailSpacing.lg + DetailSpacing.xs,
                                left: DetailSpacing.lg + DetailSpacing.xs,
                                right: DetailSpacing.lg + DetailSpacing.xs,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(dialogContext).push(
                                      MaterialPageRoute(
                                        builder: (context) => const ARScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.view_in_ar,
                                    size: KubusHeaderMetrics.actionIcon,
                                  ),
                                  label: Text(
                                    'View in AR',
                                    style: KubusTextStyles.detailButton,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: themeProvider.accentColor,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: KubusSpacing.lg,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          DetailRadius.md),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Info side
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(KubusSpacing.xxl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.title,
                                    style: DetailTypography.screenTitle(
                                        dialogContext),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: KubusSpacing.sm),
                            Text(
                              'by ${entry.artistName}',
                              style: KubusTextStyles.detailBody.copyWith(
                                color: themeProvider.accentColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(
                                height: KubusSpacing.lg + KubusSpacing.xs),
                            if (artwork.description.isNotEmpty)
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Text(
                                    artwork.description,
                                    style: KubusTextStyles.detailBody.copyWith(
                                      height: 1.7,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(
                                height: KubusSpacing.lg + KubusSpacing.xs),

                            // Price
                            Container(
                              padding: const EdgeInsets.all(
                                KubusSpacing.lg + KubusSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(dialogContext)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius:
                                    BorderRadius.circular(DetailRadius.lg),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.displayValue?.label ??
                                            'Current status',
                                        style: KubusTextStyles.detailLabel
                                            .copyWith(
                                          color: Theme.of(dialogContext)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                      const SizedBox(height: KubusSpacing.xs),
                                      Text(
                                        MarketplaceValueFormatter
                                            .formatDisplayValue(
                                          entry.displayValue,
                                        ),
                                        style:
                                            KubusTextStyles.heroTitle.copyWith(
                                          color: Theme.of(dialogContext)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.favorite,
                                            size: KubusSizes.trailingChevron,
                                            color: Colors.red
                                                .withValues(alpha: 0.7),
                                          ),
                                          const SizedBox(
                                              width: KubusSpacing.xs),
                                          Text(
                                            '${artwork.likesCount}',
                                            style:
                                                KubusTextStyles.detailCaption,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: KubusSpacing.xs),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.visibility,
                                            size: KubusSizes.trailingChevron,
                                            color: Theme.of(dialogContext)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                          const SizedBox(
                                              width: KubusSpacing.xs),
                                          Text(
                                            '${artwork.viewsCount}',
                                            style:
                                                KubusTextStyles.detailCaption,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(
                                height: KubusSpacing.lg + KubusSpacing.xs),

                            // Actions
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(dialogContext).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const DesktopWalletScreen(),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          themeProvider.accentColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: KubusSpacing.lg,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            DetailRadius.md),
                                      ),
                                    ),
                                    child: Text(
                                      'Buy Now',
                                      style: KubusTextStyles.detailButton,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: KubusSpacing.md),
                                OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(dialogContext).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const DesktopWalletScreen(),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: KubusSpacing.lg,
                                      horizontal:
                                          KubusSpacing.lg + KubusSpacing.xs,
                                    ),
                                    side: BorderSide(
                                        color: themeProvider.accentColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          DetailRadius.md),
                                    ),
                                  ),
                                  child: Text(
                                    'Make Offer',
                                    style: KubusTextStyles.detailButton,
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
            ),
          ),
        );
      },
    );
  }
}
