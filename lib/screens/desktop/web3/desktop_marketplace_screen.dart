import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/artwork_provider.dart';
import '../../../models/artwork.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../widgets/artwork_creator_byline.dart';
import '../../../widgets/detail/detail_shell_components.dart';
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
    _scrollController = ScrollController();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
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
    return Container(
      padding: EdgeInsets.all(DetailSpacing.xl),
      child: Row(
        children: [
          Text(
            'Marketplace',
            style: DetailTypography.screenTitle(context),
          ),
          const Spacer(),
          SizedBox(
            width: 400,
            child: DesktopSearchBar(
              hintText: 'Search NFTs, collections, artists...',
              onSubmitted: (value) {},
            ),
          ),
          SizedBox(width: DetailSpacing.lg),
          Consumer<Web3Provider>(
            builder: (context, web3Provider, _) {
              return ElevatedButton.icon(
                onPressed: web3Provider.isConnected
                    ? () {
                        // Create NFT
                      }
                    : () {
                        Navigator.of(context).pushNamed('/connect-wallet');
                      },
                icon: Icon(web3Provider.isConnected
                    ? Icons.add
                    : Icons.account_balance_wallet),
                label: Text(
                    web3Provider.isConnected ? 'Create' : 'Connect Wallet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.accentColor,
                  foregroundColor: Colors.white,
                  padding:
                      EdgeInsets.symmetric(horizontal: DetailSpacing.lg + DetailSpacing.xs, vertical: DetailSpacing.md + 2),
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
      padding: EdgeInsets.symmetric(horizontal: DetailSpacing.xl),
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
        labelStyle: DetailTypography.label(context),
        unselectedLabelStyle: DetailTypography.body(context),
        indicatorColor: themeProvider.accentColor,
        indicatorWeight: 3,
        dividerColor: Colors.transparent,
        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  Widget _buildStatsBanner(ThemeProvider themeProvider) {
    return Container(
      margin: EdgeInsets.all(DetailSpacing.xl),
      padding: EdgeInsets.all(DetailSpacing.xl),
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
      child: Consumer<ArtworkProvider>(
        builder: (context, artworkProvider, _) {
          final totalArtworks = artworkProvider.artworks.length;
          final arEnabled =
              artworkProvider.artworks.where((a) => a.arEnabled).length;

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
        Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 26),
        SizedBox(height: DetailSpacing.sm),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: DetailSpacing.xs),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
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
      padding: EdgeInsets.symmetric(horizontal: DetailSpacing.xl, vertical: DetailSpacing.md),
      child: Row(
        children: [
          // Filter button
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _showFilters = !_showFilters);
            },
            icon: Icon(
              _showFilters ? Icons.filter_list_off : Icons.filter_list,
              size: 20,
            ),
            label: Text(_showFilters ? 'Hide Filters' : 'Filters'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.3),
              ),
              padding: EdgeInsets.symmetric(horizontal: DetailSpacing.lg, vertical: DetailSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DetailRadius.sm + 2),
              ),
            ),
          ),
          SizedBox(width: DetailSpacing.lg),

          // Results count
          Consumer<ArtworkProvider>(
            builder: (context, artworkProvider, _) {
              return Text(
                '${artworkProvider.artworks.length} items',
                style: DetailTypography.caption(context),
              );
            },
          ),
          const Spacer(),

          // Sort dropdown
          Container(
            padding: EdgeInsets.symmetric(horizontal: DetailSpacing.md),
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
          SizedBox(width: DetailSpacing.md),

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
          padding: EdgeInsets.all(DetailSpacing.md),
          decoration: BoxDecoration(
            color: isActive ? themeProvider.accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(DetailRadius.sm),
          ),
          child: Icon(
            icon,
            size: 20,
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: ListView(
        padding: EdgeInsets.all(DetailSpacing.xl),
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: DetailTypography.sectionTitle(context),
              ),
              TextButton(
                onPressed: () {
                  // Reset filters
                },
                child: Text(
                  'Reset',
                  style: GoogleFonts.inter(
                    color: themeProvider.accentColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: DetailSpacing.xl),

          // Status
          _buildFilterSection('Status', [
            _buildCheckboxFilter('Buy Now', true, themeProvider),
            _buildCheckboxFilter('On Auction', false, themeProvider),
            _buildCheckboxFilter('New', false, themeProvider),
            _buildCheckboxFilter('Has Offers', false, themeProvider),
          ]),
          SizedBox(height: DetailSpacing.xl),

          // Price range
          Text(
            'Price Range (SOL)',
            style: DetailTypography.label(context),
          ),
          SizedBox(height: DetailSpacing.md),
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
                '${_priceRange.start.toInt()} SOL',
                style: DetailTypography.caption(context),
              ),
              Text(
                '${_priceRange.end.toInt()} SOL',
                style: DetailTypography.caption(context),
              ),
            ],
          ),
          SizedBox(height: DetailSpacing.xl),

          // Blockchain
          _buildFilterSection('Blockchain', [
            _buildCheckboxFilter('Solana', true, themeProvider),
            _buildCheckboxFilter('Ethereum', false, themeProvider),
            _buildCheckboxFilter('Polygon', false, themeProvider),
          ]),
          SizedBox(height: DetailSpacing.xl),

          // AR Features
          _buildFilterSection('Features', [
            _buildCheckboxFilter('AR Enabled', false, themeProvider),
            _buildCheckboxFilter('3D Model', false, themeProvider),
            _buildCheckboxFilter('Unlockable', false, themeProvider),
          ]),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: DetailTypography.label(context),
        ),
        SizedBox(height: DetailSpacing.md),
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
            width: 20,
            height: 20,
            child: Checkbox(
              value: checked,
              onChanged: (value) {},
              activeColor: themeProvider.accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          SizedBox(width: DetailSpacing.md),
          Text(
            label,
            style: DetailTypography.body(context),
          ),
        ],
      ),
    );
  }

  Widget _buildNFTGrid(ThemeProvider themeProvider, bool isLarge) {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, _) {
        final artworks = artworkProvider.artworks;

        if (artworks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.collections,
                  size: 72,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.25),
                ),
                SizedBox(height: DetailSpacing.lg),
                Text(
                  'No NFTs found',
                  style: DetailTypography.cardTitle(context).copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
                SizedBox(height: DetailSpacing.sm),
                Text(
                  'Try adjusting your filters',
                  style: DetailTypography.caption(context),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          controller: _scrollController,
          padding: EdgeInsets.all(DetailSpacing.xl),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isLarge ? 4 : 3,
            crossAxisSpacing: DetailSpacing.lg + DetailSpacing.xs,
            mainAxisSpacing: DetailSpacing.lg + DetailSpacing.xs,
            childAspectRatio: 0.75,
          ),
          itemCount: artworks.length,
          itemBuilder: (context, index) {
            return _buildNFTCard(artworks[index], themeProvider);
          },
        );
      },
    );
  }

  Widget _buildNFTCard(Artwork artwork, ThemeProvider themeProvider) {
    final marketplaceAccent = KubusColorRoles.of(context).web3MarketplaceAccent;
    return DesktopCard(
      padding: EdgeInsets.zero,
      onTap: () {
        _showNFTDetail(artwork, themeProvider);
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
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(DetailRadius.lg)),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.image,
                      size: 52,
                      color: Colors.white,
                    ),
                  ),
                  // AR badge
                  if (artwork.arEnabled)
                    Positioned(
                      top: DetailSpacing.md,
                      right: DetailSpacing.md,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: DetailSpacing.sm, vertical: DetailSpacing.xs),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ECDC4),
                          borderRadius: BorderRadius.circular(DetailRadius.xs),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.view_in_ar,
                                size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text('AR',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                )),
                          ],
                        ),
                      ),
                    ),
                  // Favorite button
                  Positioned(
                    top: DetailSpacing.md,
                    left: DetailSpacing.md,
                    child: Container(
                      padding: EdgeInsets.all(DetailSpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        artwork.isDiscovered
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 16,
                        color: artwork.isDiscovered ? Colors.red : Colors.white,
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
                    artwork.title,
                    style: DetailTypography.cardTitle(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: DetailSpacing.xs),
                  ArtworkCreatorByline(
                    artwork: artwork,
                    style: GoogleFonts.inter(
                      fontSize: 13,
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
                            'Price',
                            style: DetailTypography.caption(context).copyWith(
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '${(artwork.id.hashCode % 10 + 1) / 2.0} SOL',
                            style: DetailTypography.cardTitle(context),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            size: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.4),
                          ),
                          SizedBox(width: DetailSpacing.xs),
                          Text(
                            '${artwork.likesCount}',
                            style: DetailTypography.caption(context).copyWith(
                              fontSize: 12,
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

  void _showNFTDetail(Artwork artwork, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 860,
            constraints: const BoxConstraints(maxHeight: 640),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(DetailRadius.xl),
            ),
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
                        const Center(
                          child: Icon(
                            Icons.view_in_ar,
                            size: 110,
                            color: Colors.white,
                          ),
                        ),
                        if (artwork.arEnabled)
                          Positioned(
                            bottom: DetailSpacing.lg + DetailSpacing.xs,
                            left: DetailSpacing.lg + DetailSpacing.xs,
                            right: DetailSpacing.lg + DetailSpacing.xs,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const ARScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.view_in_ar),
                              label: const Text('View in AR'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: themeProvider.accentColor,
                                padding:
                                    EdgeInsets.symmetric(vertical: DetailSpacing.lg),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(DetailRadius.md),
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
                    padding: EdgeInsets.all(DetailSpacing.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                artwork.title,
                                style: DetailTypography.screenTitle(context),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        SizedBox(height: DetailSpacing.sm),
                        Text(
                          'by ${artwork.artist}',
                          style: DetailTypography.body(context).copyWith(
                            color: themeProvider.accentColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: DetailSpacing.lg + DetailSpacing.xs),
                        if (artwork.description.isNotEmpty)
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                artwork.description,
                                style: DetailTypography.body(context).copyWith(
                                  height: 1.7,
                                ),
                              ),
                            ),
                          ),
                        SizedBox(height: DetailSpacing.lg + DetailSpacing.xs),

                        // Price
                        Container(
                          padding: EdgeInsets.all(DetailSpacing.lg + DetailSpacing.xs),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(DetailRadius.lg),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current Price',
                                    style: DetailTypography.caption(context),
                                  ),
                                  SizedBox(height: DetailSpacing.xs),
                                  Text(
                                    '${(artwork.id.hashCode % 10 + 1) / 2.0} SOL',
                                    style: GoogleFonts.inter(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
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
                                      Icon(Icons.favorite,
                                          size: 16,
                                          color: Colors.red
                                              .withValues(alpha: 0.7)),
                                      SizedBox(width: DetailSpacing.xs),
                                      Text('${artwork.likesCount}'),
                                    ],
                                  ),
                                  SizedBox(height: DetailSpacing.xs),
                                  Row(
                                    children: [
                                      Icon(Icons.visibility,
                                          size: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.5)),
                                      SizedBox(width: DetailSpacing.xs),
                                      Text('${artwork.viewsCount}'),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: DetailSpacing.lg + DetailSpacing.xs),

                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const DesktopWalletScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeProvider.accentColor,
                                  foregroundColor: Colors.white,
                                  padding:
                                      EdgeInsets.symmetric(vertical: DetailSpacing.lg),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(DetailRadius.md),
                                  ),
                                ),
                                child: const Text('Buy Now'),
                              ),
                            ),
                            SizedBox(width: DetailSpacing.md),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const DesktopWalletScreen(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                    vertical: DetailSpacing.lg, horizontal: DetailSpacing.lg + DetailSpacing.xs),
                                side: BorderSide(
                                    color: themeProvider.accentColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(DetailRadius.md),
                                ),
                              ),
                              child: const Text('Make Offer'),
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
      },
    );
  }
}
