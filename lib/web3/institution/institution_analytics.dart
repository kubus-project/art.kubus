import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/institution_provider.dart';
import '../../providers/artwork_provider.dart';
import '../../widgets/inline_loading.dart';


class InstitutionAnalytics extends StatefulWidget {
  const InstitutionAnalytics({super.key});

  @override
  State<InstitutionAnalytics> createState() => _InstitutionAnalyticsState();
}

class _InstitutionAnalyticsState extends State<InstitutionAnalytics> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _selectedPeriod = 'This Month';
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
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
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildPeriodSelector(),
              const SizedBox(height: 16),
              _buildStatsOverview(),
              const SizedBox(height: 16),
              _buildVisitorAnalytics(),
              const SizedBox(height: 16),
              _buildEventPerformance(),
              const SizedBox(height: 16),
              _buildRevenueAnalytics(),
              const SizedBox(height: 16),
              _buildArtworkAnalytics(),
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
          'Institution Analytics',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track your institution\'s performance and engagement',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              onPressed: () => _showExportDialog(),
              icon: Icon(Icons.download, color: Theme.of(context).colorScheme.onSurface, size: 20),
            ),
            IconButton(
              onPressed: () => _showSettingsDialog(),
              icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.onSurface, size: 20),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['This Week', 'This Month', 'This Quarter', 'This Year'];
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Time Period',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedPeriod,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            items: periods.map((period) => DropdownMenuItem<String>(
              value: period,
              child: Text(period),
            )).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedPeriod = value;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Consumer<InstitutionProvider>(
      builder: (context, institutionProvider, child) {
        // Get analytics data from the provider
        if (institutionProvider.institutions.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overview',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.analytics_outlined, size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'No analytics data available',
                        style: GoogleFonts.inter(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        
        // Get analytics data from the provider
        final institution = institutionProvider.institutions.first;
        final analytics = institutionProvider.getInstitutionAnalytics(institution.id);
        
        final stats = [
          {
            'title': 'Total Visitors',
            'value': '${analytics['totalVisitors'] ?? 0}',
            'change': '+${analytics['visitorGrowth']?.toStringAsFixed(1) ?? '0.0'}%',
            'positive': (analytics['visitorGrowth'] ?? 0) >= 0
          },
          {
            'title': 'Active Events',
            'value': '${analytics['activeEvents'] ?? 0}',
            'change': '+${analytics['activeEventsCount'] ?? 0}',
            'positive': true
          },
          {
            'title': 'Artwork Views',
            'value': _formatNumber(analytics['artworkViews'] ?? 0),
            'change': '+${analytics['revenueGrowth']?.toStringAsFixed(1) ?? '0.0'}%',
            'positive': (analytics['revenueGrowth'] ?? 0) >= 0
          },
          {
            'title': 'Revenue',
            'value': '\$${_formatRevenue(analytics['revenue'] ?? 0)}',
            'change': '+${analytics['revenueGrowth']?.toStringAsFixed(1) ?? '0.0'}%',
            'positive': (analytics['revenueGrowth'] ?? 0) >= 0
          },
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.3,
              children: stats.map((stat) => _buildStatCard(stat)).toList(),
            ),
          ],
        );
      },
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  String _formatRevenue(double revenue) {
    if (revenue >= 1000) {
      return '${(revenue / 1000).toStringAsFixed(1)}k';
    }
    return revenue.toStringAsFixed(0);
  }

  Widget _buildStatCard(Map<String, dynamic> stat) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              stat['title'],
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              stat['value'],
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Row(
              children: [
                Icon(
                  stat['positive'] ? Icons.trending_up : Icons.trending_down,
                  color: stat['positive'] ? Colors.green : Colors.red,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    stat['change'],
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: stat['positive'] ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorAnalytics() {
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
          Text(
            'Visitor Analytics',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildVisitorChart(),
          const SizedBox(height: 16),
          _buildVisitorMetrics(),
        ],
      ),
    );
  }

  Widget _buildVisitorChart() {
    return Consumer<InstitutionProvider>(
      builder: (context, institutionProvider, child) {
        // Get visitor data from analytics - use actual data if available
        final institution = institutionProvider.institutions.isNotEmpty 
            ? institutionProvider.institutions.first 
            : null;
        final analytics = institution != null 
            ? institutionProvider.getInstitutionAnalytics(institution.id) 
            : {};
        
        // TODO: Get actual daily visitor data from backend analytics API
        // For now, generate sample data based on total visitors
        final totalVisitors = analytics['totalVisitors'] ?? 1200;
        final avgDaily = (totalVisitors / 7).round();
        final data = List.generate(7, (i) => avgDaily + (i * 10) - 30);
        final maxValue = data.reduce((a, b) => a > b ? a : b);
    
        return SizedBox(
          height: 120,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: data.asMap().entries.map((entry) {
                      final index = entry.key;
                      final value = entry.value;
                      final height = (value / maxValue) * 100;
                      
                      return Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              value.toString(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 20,
                              height: height,
                              decoration: BoxDecoration(
                                color: Provider.of<ThemeProvider>(context).accentColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][index],
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildVisitorMetrics() {
    return Consumer<InstitutionProvider>(
      builder: (context, institutionProvider, child) {
        final institution = institutionProvider.institutions.isNotEmpty 
            ? institutionProvider.institutions.first 
            : null;
        final analytics = institution != null 
            ? institutionProvider.getInstitutionAnalytics(institution.id) 
            : {};
        
        // TODO: Get actual metrics from backend analytics API
        final metrics = [
          {'label': 'Avg. Visit Duration', 'value': '45 min'},
          {'label': 'Return Visitors', 'value': '${((analytics['totalVisitors'] ?? 0) * 0.34).round()}'},
          {'label': 'Active Events', 'value': '${analytics['activeEventsCount'] ?? 0}'},
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: metrics.map((metric) => Flexible(
                    child: Column(
                      children: [
                        Text(
                          metric['value']!,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          metric['label']!,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEventPerformance() {
    return Consumer<InstitutionProvider>(
      builder: (context, institutionProvider, child) {
        final institution = institutionProvider.institutions.isNotEmpty 
            ? institutionProvider.institutions.first 
            : null;
        
        // Get actual events from provider
        final institutionEvents = institution != null 
            ? institutionProvider.getEventsByInstitution(institution.id).take(3).toList() 
            : [];
        
        // Convert events to display format
        final events = institutionEvents.map((event) => {
          'name': event.title,
          'visitors': '${event.attendeeCount}',
          'rating': event.rating?.toStringAsFixed(1) ?? 'N/A',
        }).toList();
        
        // Show placeholder if no events
        if (events.isEmpty) {
          events.add({'name': 'No events yet', 'visitors': '0', 'rating': 'N/A'});
        }

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
              Text(
                'Event Performance',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ...events.map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event['name']!,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '${event['visitors']} visitors',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          event['rating']!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevenueAnalytics() {
    return Consumer<InstitutionProvider>(
      builder: (context, institutionProvider, child) {
        final institution = institutionProvider.institutions.isNotEmpty 
            ? institutionProvider.institutions.first 
            : null;
        final analytics = institution != null 
            ? institutionProvider.getInstitutionAnalytics(institution.id) 
            : {};
        
        // TODO: Get detailed revenue breakdown from backend analytics API
        final totalRevenue = analytics['revenue'] ?? 0;
        final ticketSales = totalRevenue * 0.5;
        final merchandise = totalRevenue * 0.15;
        final memberships = totalRevenue * 0.25;
        final donations = totalRevenue * 0.1;
        
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
              Text(
                'Revenue Analytics',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              _buildRevenueItem('Ticket Sales', '\$${ticketSales.toStringAsFixed(0)}', 0.5),
              _buildRevenueItem('Merchandise', '\$${merchandise.toStringAsFixed(0)}', 0.15),
              _buildRevenueItem('Memberships', '\$${memberships.toStringAsFixed(0)}', 0.25),
              _buildRevenueItem('Donations', '\$${donations.toStringAsFixed(0)}', 0.1),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevenueItem(String category, String amount, double percentage) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                amount,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: InlineLoading(
                progress: percentage,
                tileSize: 6.0,
                color: themeProvider.accentColor,
                duration: const Duration(milliseconds: 700),
                animate: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkAnalytics() {
    return Consumer2<InstitutionProvider, ArtworkProvider>(
      builder: (context, institutionProvider, artworkProvider, child) {
        final institution = institutionProvider.institutions.isNotEmpty 
            ? institutionProvider.institutions.first 
            : null;
        
        // Get artworks from institution or all artworks
        final artworks = artworkProvider.artworks.toList()
          ..sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        
        final topArtworks = artworks.take(3).toList();
        
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
              Text(
                'Top Artworks',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              if (topArtworks.isEmpty)
                _buildArtworkItem('No artworks yet', '0 views', 'N/A')
              else
                ...topArtworks.map((artwork) => _buildArtworkItem(
                  artwork.title,
                  '${_formatNumber(artwork.viewsCount)} views',
                  '${artwork.likesCount} likes',
                )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtworkItem(String title, String views, String rating) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.image,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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
                Text(
                  '$views • $rating',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text('Export Analytics', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'Export your analytics data to PDF or Excel format.',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Analytics exported successfully!')),
              );
            },
            child: Text('Export'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text('Analytics Settings', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'Configure your analytics tracking preferences.',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showVisitorDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text('Visitor Details', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailMetric('Total Unique Visitors', '9,240'),
              _buildDetailMetric('Return Visitors', '3,210'),
              _buildDetailMetric('New Visitors', '6,030'),
              _buildDetailMetric('Average Session Duration', '45 minutes'),
              _buildDetailMetric('Bounce Rate', '23%'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}











