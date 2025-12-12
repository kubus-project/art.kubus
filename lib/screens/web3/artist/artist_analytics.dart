import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/artwork_provider.dart';
import '../../../providers/collectibles_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../models/artwork.dart';
import '../../../utils/app_animations.dart';
import '../../../utils/rarity_ui.dart';

class ArtistAnalytics extends StatefulWidget {
  const ArtistAnalytics({super.key});

  @override
  State<ArtistAnalytics> createState() => _ArtistAnalyticsState();
}

class _ArtistAnalyticsState extends State<ArtistAnalytics> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _didPlayEntrance = false;
  
  String _selectedPeriod = 'Last 30 Days';
  int _currentChartIndex = 0;
  int _nftsSold = 0;
  bool _loadingNFTs = true;

  @override
  void initState() {
    super.initState();
    _loadNFTData();
    _animationController = AnimationController(
      duration: AppAnimationTheme.defaults.long,
      vsync: this,
    );
    _configureAnimations(AppAnimationTheme.defaults);
  }

  void _configureAnimations(AppAnimationTheme animationTheme) {
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: animationTheme.fadeCurve,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationTheme = context.animationTheme;
    if (_animationController.duration != animationTheme.long) {
      _animationController.duration = animationTheme.long;
    }
    _configureAnimations(animationTheme);
    if (!_didPlayEntrance) {
      _didPlayEntrance = true;
      _animationController.forward();
    }
  }

  Future<void> _loadNFTData() async {
    final web3 = Provider.of<Web3Provider>(context, listen: false);
    if (!web3.isConnected || web3.walletAddress.isEmpty) {
      setState(() {
        _loadingNFTs = false;
        _nftsSold = 0;
      });
      return;
    }

    try {
      final collectiblesProvider = Provider.of<CollectiblesProvider>(context, listen: false);
      if (!collectiblesProvider.isLoading &&
          collectiblesProvider.allSeries.isEmpty &&
          collectiblesProvider.allCollectibles.isEmpty) {
        await collectiblesProvider.initialize();
      }
      final nfts = collectiblesProvider.getCollectiblesByOwner(web3.walletAddress);
      setState(() {
        _nftsSold = nfts.length;
        _loadingNFTs = false;
      });
    } catch (e) {
      debugPrint('Failed to load NFT data: $e');
      setState(() {
        _loadingNFTs = false;
        _nftsSold = 0;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildOverviewCards(),
              const SizedBox(height: 16),
              _buildChartSection(),
              const SizedBox(height: 16),
              _buildDetailedMetrics(),
              const SizedBox(height: 16),
              _buildTopArtworks(),
              const SizedBox(height: 16),
              _buildRecentActivity(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics Dashboard',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track your artwork performance',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        _buildPeriodSelector(),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2)),
      ),
      child: DropdownButton<String>(
        value: _selectedPeriod,
        underline: const SizedBox(),
        isExpanded: true,
        dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.onSurface, size: 20),
        items: ['Last 7 Days', 'Last 30 Days', 'Last 90 Days', 'Last Year'].map((period) {
          return DropdownMenuItem<String>(
            value: period,
            child: Text(period),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedPeriod = value!;
          });
        },
      ),
    );
  }

  Widget _buildOverviewCards() {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, child) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final web3 = Provider.of<Web3Provider>(context, listen: false);

        final artworks = artworkProvider.userArtworks;
        final totalViews = artworks.fold<int>(0, (sum, a) => sum + a.viewsCount);
        final activeMarkers = artworks.where((a) => a.arEnabled).length;
        final estimatedRewards = artworks.fold<int>(0, (sum, a) => sum + a.actualRewards);
        final kub8Balance = web3.kub8Balance;
        final totalRevenueKub8 = kub8Balance + estimatedRewards.toDouble();

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _buildMetricCard(
              'Total Revenue',
              '${totalRevenueKub8.toStringAsFixed(1)} KUB8',
              'Wallet: ${kub8Balance.toStringAsFixed(1)} KUB8',
              Icons.account_balance_wallet,
              themeProvider.accentColor,
              '+0%',
              true,
            ),
            _buildMetricCard(
              'Active Markers',
              activeMarkers.toString(),
              'AR-enabled artworks',
              Icons.location_on,
              Theme.of(context).colorScheme.primary,
              '+0%',
              true,
            ),
            _buildMetricCard(
              'Total Visitors',
              totalViews.toString(),
              'All-time views',
              Icons.people,
              Theme.of(context).colorScheme.tertiary,
              '+0%',
              true,
            ),
            _buildMetricCard(
              'NFTs Sold',
              _loadingNFTs ? '...' : _nftsSold.toString(),
              _loadingNFTs 
                  ? 'Loading...'
                  : (web3.isConnected 
                      ? (_nftsSold > 0 ? '$_nftsSold minted' : 'No sales yet')
                      : 'Connect wallet'),
              Icons.token,
              Theme.of(context).colorScheme.secondary,
              '+0%',
              true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    String change,
    bool isPositive,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  change,
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    color: isPositive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 9,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth < 400;
                  
                  if (isSmallScreen) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Performance Overview',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildChartSelector(),
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Text(
                          'Performance Overview',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        _buildChartSelector(),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: CustomPaint(
                  painter: LineChartPainter(_currentChartIndex, Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
                  size: const Size(double.infinity, 200),
                ),
              ),
              const SizedBox(height: 16),
              _buildChartLegend(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartSelector() {
    final options = ['Revenue', 'Views', 'Engagement'];
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;
        
        if (isSmallScreen) {
          // Use Wrap for small screens to prevent overflow
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = _currentChartIndex == index;
              
              return GestureDetector(
                onTap: () => setState(() => _currentChartIndex = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Provider.of<ThemeProvider>(context).accentColor 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected 
                          ? Provider.of<ThemeProvider>(context).accentColor 
                          : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    option,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        } else {
          // Use Row for larger screens
          return Row(
            children: options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = _currentChartIndex == index;
              
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _currentChartIndex = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Provider.of<ThemeProvider>(context).accentColor 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected 
                            ? Provider.of<ThemeProvider>(context).accentColor 
                            : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      option,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }
      },
    );
  }

  Widget _buildChartLegend() {
    final colors = [Colors.blue, Colors.green, Colors.orange];
    final labels = ['This Period', 'Previous Period', 'Average'];
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 350;
        
        if (isSmallScreen) {
          // Use Wrap for very small screens to prevent overflow
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: labels.asMap().entries.map((entry) {
              final index = entry.key;
              final label = entry.value;
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 3,
                    decoration: BoxDecoration(
                      color: colors[index],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              );
            }).toList(),
          );
        } else {
          // Use Row for larger screens
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: labels.asMap().entries.map((entry) {
              final index = entry.key;
              final label = entry.value;
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 3,
                      decoration: BoxDecoration(
                        color: colors[index],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        }
      },
    );
  }

  Widget _buildDetailedMetrics() {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, child) {
        final artworks = artworkProvider.userArtworks;
        final totalViews = artworks.fold<int>(0, (sum, a) => sum + a.viewsCount);
        final totalLikes = artworks.fold<int>(0, (sum, a) => sum + a.likesCount);
        final totalComments = artworks.fold<int>(0, (sum, a) => sum + a.commentsCount);
        final favoritesCount = artworks.where((a) => a.isFavorite || a.isFavoriteByCurrentUser).length;

        final engagementRate = totalViews > 0 ? ((totalLikes + totalComments) / totalViews * 100) : 0.0;
        final conversionRate = totalViews > 0 ? (favoritesCount / totalViews * 100) : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detailed Metrics',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildMetricItem('Avg. View Time', 'N/A', Icons.schedule)),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricItem('Engagement Rate', '${engagementRate.toStringAsFixed(1)}%', Icons.thumb_up)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMetricItem('Conversion Rate', '${conversionRate.toStringAsFixed(1)}%', Icons.trending_up)),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricItem('Return Visitors', 'N/A', Icons.refresh)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopArtworks() {
    return Consumer<ArtworkProvider>(
      builder: (context, artworkProvider, child) {
        // Top performing artworks by views
        final sorted = List<Artwork>.from(artworkProvider.artworks)
          ..sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        final topArtworks = sorted.take(4).map((artwork) {
          final viewsText = artwork.viewsCount.toString();
          final revenueText = '${artwork.actualRewards} KUB8';

          return {
            'title': artwork.title,
            'views': viewsText,
            'revenue': revenueText,
            'artwork': artwork,
          };
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Performing Artworks',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...topArtworks.asMap().entries.map((entry) {
              final index = entry.key;
              final artworkData = entry.value;
              final artwork = artworkData['artwork'] as Artwork;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: RarityUi.artworkColor(context, artwork.rarity),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            artworkData['title'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '${artworkData['views']} views',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      artworkData['revenue'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Provider.of<ThemeProvider>(context).accentColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
  }

  Widget _buildRecentActivity() {
    return Consumer2<ArtworkProvider, ThemeProvider>(
      builder: (context, artworkProvider, themeProvider, child) {
        final activities = <Map<String, dynamic>>[];
        final artworks = artworkProvider.artworks;

        for (final a in artworks) {
          if (a.discoveredAt != null) {
            activities.add({
              'time': a.discoveredAt!,
              'icon': Icons.visibility,
              'action': 'Artwork "${a.title}" discovered',
            });
          }
          // Creation event
          activities.add({
            'time': a.createdAt,
            'icon': Icons.add,
            'action': 'New artwork "${a.title}" added',
          });
          // Latest comment event if available
          final comments = artworkProvider.getComments(a.id);
          if (comments.isNotEmpty) {
            comments.sort((c1, c2) => c2.createdAt.compareTo(c1.createdAt));
            activities.add({
              'time': comments.first.createdAt,
              'icon': Icons.comment,
              'action': 'New comment on "${a.title}"',
            });
          }
        }

        activities.sort((x, y) => (y['time'] as DateTime).compareTo(x['time'] as DateTime));
        final recent = activities.take(8).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: recent.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No recent activity',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        )
                      ]
                    : recent.map((activity) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: themeProvider.accentColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  activity['icon'] as IconData,
                                  color: themeProvider.accentColor,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activity['action'] as String,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      _relativeTime(activity['time'] as DateTime),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final weeks = (diff.inDays / 7).floor();
    return weeks <= 1 ? '1w ago' : '${weeks}w ago';
  }

// Custom painter for line chart
class LineChartPainter extends CustomPainter {
  final int chartType;
  final Color gridColor;

  LineChartPainter(this.chartType, this.gridColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    // Draw grid
    for (int i = 0; i <= 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 0; i <= 7; i++) {
      final x = size.width * i / 7;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Generate sample data based on chart type
    final points = _generateDataPoints(size);
    
    // Draw line
    final path = Path();
    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }
    
    canvas.drawPath(path, paint);

    // Draw points
    final pointPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 3, pointPaint);
    }
  }

  List<Offset> _generateDataPoints(Size size) {
    final points = <Offset>[];
    final data = _getSampleData();
    
    for (int i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y = size.height * (1 - data[i]);
      points.add(Offset(x, y));
    }
    
    return points;
  }

  List<double> _getSampleData() {
    switch (chartType) {
      case 0: // Revenue
        return [0.2, 0.3, 0.25, 0.6, 0.8, 0.7, 0.9];
      case 1: // Views
        return [0.1, 0.4, 0.3, 0.7, 0.6, 0.8, 0.85];
      case 2: // Engagement
        return [0.3, 0.2, 0.5, 0.4, 0.7, 0.6, 0.8];
      default:
        return [0.2, 0.3, 0.25, 0.6, 0.8, 0.7, 0.9];
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}



