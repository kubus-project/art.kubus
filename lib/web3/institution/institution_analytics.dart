import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/institution_provider.dart';

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
        color: const Color(0xFF0A0A0A),
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
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track your institution\'s performance and engagement',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              onPressed: () => _showExportDialog(),
              icon: const Icon(Icons.download, color: Colors.white, size: 20),
            ),
            IconButton(
              onPressed: () => _showSettingsDialog(),
              icon: const Icon(Icons.settings, color: Colors.white, size: 20),
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Time Period',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedPeriod,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            dropdownColor: const Color(0xFF1A1A1A),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white,
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
        if (institutionProvider.institutions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
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
                color: Colors.white,
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              stat['title'],
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.7),
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
                color: Colors.white,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Visitor Analytics',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () => _showVisitorDetails(),
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              ),
            ],
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
    // Simple bar chart representation
    final data = [120, 180, 150, 200, 160, 220, 180];
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
                            color: Colors.white.withValues(alpha: 0.7),
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
                            color: Colors.white.withValues(alpha: 0.5),
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
  }

  Widget _buildVisitorMetrics() {
    final metrics = [
      {'label': 'Avg. Visit Duration', 'value': '45 min'},
      {'label': 'Return Visitors', 'value': '34%'},
      {'label': 'Peak Hour', 'value': '2-4 PM'},
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
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      metric['label']!,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.7),
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
  }

  Widget _buildEventPerformance() {
    final events = [
      {'name': 'Digital Dreams Exhibition', 'visitors': '2,340', 'rating': '4.8'},
      {'name': 'Modern Art Workshop', 'visitors': '156', 'rating': '4.6'},
      {'name': 'Artist Talk Series', 'visitors': '890', 'rating': '4.9'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Event Performance',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
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
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${event['visitors']} visitors',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      event['rating']!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white,
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
  }

  Widget _buildRevenueAnalytics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue Breakdown',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildRevenueItem('Event Tickets', '\$12,400', 0.67),
          _buildRevenueItem('Merchandise', '\$3,850', 0.21),
          _buildRevenueItem('Memberships', '\$2,250', 0.12),
        ],
      ),
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
                  color: Colors.white,
                ),
              ),
              Text(
                amount,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(themeProvider.accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkAnalytics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Performing Artworks',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildArtworkItem('Neon Dreams', '5,240 views', '4.9 rating'),
          _buildArtworkItem('Digital Visions', '4,180 views', '4.7 rating'),
          _buildArtworkItem('Abstract Reality', '3,920 views', '4.8 rating'),
        ],
      ),
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
              color: Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.image,
              color: Colors.white,
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
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$views • $rating',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
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
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Export Analytics', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Export your analytics data to PDF or Excel format.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Analytics exported successfully!')),
              );
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Analytics Settings', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Configure your analytics tracking preferences.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showVisitorDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Visitor Details', style: TextStyle(color: Colors.white)),
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
            child: const Text('Close'),
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
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
