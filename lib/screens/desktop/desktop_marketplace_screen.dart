import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/web3provider.dart';
import '../../providers/artwork_provider.dart';
import '../../models/artwork.dart';
import '../../utils/app_animations.dart';
import 'components/desktop_widgets.dart';

/// Desktop marketplace screen with OpenSea-style NFT grid
/// Features advanced filtering, sorting, and collection browsing
class DesktopMarketplaceScreen extends StatefulWidget {
  const DesktopMarketplaceScreen({super.key});

  @override
  State<DesktopMarketplaceScreen> createState() => _DesktopMarketplaceScreenState();
}

class _DesktopMarketplaceScreenState extends State<DesktopMarketplaceScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late TabController _tabController;
  late ScrollController _scrollController;

  final List<String> _tabs = ['All NFTs', 'Art', 'Photography', 'Music', 'Virtual Worlds'];
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
      backgroundColor: themeProvider.isDarkMode
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8F9FA),
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
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Text(
            'Marketplace',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 360,
            child: DesktopSearchBar(
              hintText: 'Search NFTs, collections, artists...',
              onSubmitted: (value) {},
            ),
          ),
          const SizedBox(width: 16),
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
                icon: Icon(web3Provider.isConnected ? Icons.add : Icons.account_balance_wallet),
                label: Text(web3Provider.isConnected ? 'Create' : 'Connect Wallet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        labelStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.normal,
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
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
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
      child: Consumer<ArtworkProvider>(
        builder: (context, artworkProvider, _) {
          final totalArtworks = artworkProvider.artworks.length;
          final arEnabled = artworkProvider.artworks.where((a) => a.arEnabled).length;
          
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total Artworks', totalArtworks.toString(), Icons.collections),
              _buildVerticalDivider(),
              _buildStatItem('AR Ready', arEnabled.toString(), Icons.view_in_ar),
              _buildVerticalDivider(),
              _buildStatItem('Available', totalArtworks.toString(), Icons.storefront),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Results count
          Consumer<ArtworkProvider>(
            builder: (context, artworkProvider, _) {
              return Text(
                '${artworkProvider.artworks.length} items',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              );
            },
          ),
          const Spacer(),

          // Sort dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: DropdownButton<String>(
              value: _selectedSort,
              underline: const SizedBox.shrink(),
              icon: const Icon(Icons.keyboard_arrow_down),
              items: const [
                DropdownMenuItem(value: 'recent', child: Text('Recently Listed')),
                DropdownMenuItem(value: 'price_low', child: Text('Price: Low to High')),
                DropdownMenuItem(value: 'price_high', child: Text('Price: High to Low')),
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
          const SizedBox(width: 12),

          // View toggle
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
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

  Widget _buildViewToggle(String view, IconData icon, ThemeProvider themeProvider) {
    final isActive = _selectedView == view;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedView = view);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive ? themeProvider.accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
        padding: const EdgeInsets.all(24),
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
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
          const SizedBox(height: 24),

          // Status
          _buildFilterSection('Status', [
            _buildCheckboxFilter('Buy Now', true, themeProvider),
            _buildCheckboxFilter('On Auction', false, themeProvider),
            _buildCheckboxFilter('New', false, themeProvider),
            _buildCheckboxFilter('Has Offers', false, themeProvider),
          ]),
          const SizedBox(height: 24),

          // Price range
          Text(
            'Price Range (SOL)',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
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
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '${_priceRange.end.toInt()} SOL',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Blockchain
          _buildFilterSection('Blockchain', [
            _buildCheckboxFilter('Solana', true, themeProvider),
            _buildCheckboxFilter('Ethereum', false, themeProvider),
            _buildCheckboxFilter('Polygon', false, themeProvider),
          ]),
          const SizedBox(height: 24),

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
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildCheckboxFilter(String label, bool checked, ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
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
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No NFTs found',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try adjusting your filters',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isLarge ? 4 : 3,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
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
                    themeProvider.accentColor.withValues(alpha: 0.4),
                    themeProvider.accentColor.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.image,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  // AR badge
                  if (artwork.arEnabled)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ECDC4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.view_in_ar, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text('AR', style: TextStyle(
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
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        artwork.isDiscovered ? Icons.favorite : Icons.favorite_border,
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artwork.title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by ${artwork.artist}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: themeProvider.accentColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          Text(
                            '${(artwork.id.hashCode % 10 + 1) / 2.0} SOL',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${artwork.likesCount}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
            width: 800,
            constraints: const BoxConstraints(maxHeight: 600),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
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
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                    ),
                    child: Stack(
                      children: [
                        const Center(
                          child: Icon(
                            Icons.view_in_ar,
                            size: 100,
                            color: Colors.white,
                          ),
                        ),
                        if (artwork.arEnabled)
                          Positioned(
                            bottom: 20,
                            left: 20,
                            right: 20,
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.view_in_ar),
                              label: const Text('View in AR'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: themeProvider.accentColor,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              artwork.title,
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'by ${artwork.artist}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: themeProvider.accentColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (artwork.description.isNotEmpty)
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                artwork.description,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  height: 1.6,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),

                        // Price
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current Price',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(artwork.id.hashCode % 10 + 1) / 2.0} SOL',
                                    style: GoogleFonts.inter(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.favorite, size: 16, color: Colors.red.withValues(alpha: 0.7)),
                                      const SizedBox(width: 4),
                                      Text('${artwork.likesCount}'),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.visibility, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                                      const SizedBox(width: 4),
                                      Text('${artwork.viewsCount}'),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeProvider.accentColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Buy Now'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                side: BorderSide(color: themeProvider.accentColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
