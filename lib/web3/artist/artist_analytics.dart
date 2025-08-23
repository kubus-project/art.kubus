import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/artwork_provider.dart';
import '../../models/artwork.dart';

class ArtistAnalytics extends StatefulWidget {
  const ArtistAnalytics({super.key});

  @override
  State<ArtistAnalytics> createState() => _ArtistAnalyticsState();
}

class _ArtistAnalyticsState extends State<ArtistAnalytics> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  String _selectedPeriod = 'Last 30 Days';
  int _currentChartIndex = 0;

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
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track your artwork performance',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: DropdownButton<String>(
        value: _selectedPeriod,
        underline: const SizedBox(),
        isExpanded: true,
        dropdownColor: const Color(0xFF1A1A1A),
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Colors.white,
        ),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
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
          '125.5 KUB8', 
          '\$2,510', 
          Icons.account_balance_wallet, 
          const Color(0xFF00D4AA),
          '+12.5%',
          true,
        ),
        _buildMetricCard(
          'Active Markers', 
          '8', 
          '+2 this week', 
          Icons.location_on, 
          const Color(0xFF6C63FF),
          '+25%',
          true,
        ),
        _buildMetricCard(
          'Total Visitors', 
          '1,234', 
          '+156 this week', 
          Icons.people, 
          const Color(0xFFFFD93D),
          '+14.2%',
          true,
        ),
        _buildMetricCard(
          'NFTs Sold', 
          '23', 
          '+5 this month', 
          Icons.token, 
          const Color(0xFF9C27B0),
          '+38.5%',
          true,
        ),
      ],
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
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
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white.withOpacity(0.7),
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
                color: Colors.white.withOpacity(0.5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
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
                        color: Colors.white,
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
                        color: Colors.white,
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
              painter: LineChartPainter(_currentChartIndex),
              size: const Size(double.infinity, 200),
            ),
          ),
          const SizedBox(height: 16),
          _buildChartLegend(),
        ],
      ),
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
                          : Colors.white.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    option,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
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
                            : Colors.white.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      option,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
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
                      color: Colors.white.withOpacity(0.7),
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
                        color: Colors.white.withOpacity(0.7),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detailed Metrics',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildMetricItem('Avg. View Time', '2m 34s', Icons.schedule)),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricItem('Engagement Rate', '8.2%', Icons.thumb_up)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildMetricItem('Conversion Rate', '3.1%', Icons.trending_up)),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricItem('Return Visitors', '45%', Icons.refresh)),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.7), size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.7),
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
        // Get top performing artworks (mock analytics data for now)
        final topArtworks = artworkProvider.artworks.take(4).map((artwork) {
          // Generate mock analytics for each artwork
          final mockViews = (artwork.likesCount * 10 + artwork.viewsCount).toString();
          final mockRevenue = (artwork.rewards * 0.5).toStringAsFixed(1);
          
          return {
            'title': artwork.title,
            'views': mockViews,
            'revenue': '$mockRevenue KUB8',
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
                color: Colors.white,
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
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(Artwork.getRarityColor(artwork.rarity)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${artworkData['views']} views',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
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
    final activities = [
      {'action': 'New visitor from Gallery A', 'time': '2 minutes ago', 'icon': Icons.visibility},
      {'action': 'Artwork "Digital Dreams" liked', 'time': '15 minutes ago', 'icon': Icons.favorite},
      {'action': 'NFT sale completed', 'time': '1 hour ago', 'icon': Icons.attach_money},
      {'action': 'New AR marker created', 'time': '3 hours ago', 'icon': Icons.add_location},
    ];

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: activities.map((activity) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: themeProvider.accentColor.withOpacity(0.2),
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
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                activity['time'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.6),
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

// Custom painter for line chart
class LineChartPainter extends CustomPainter {
  final int chartType;

  LineChartPainter(this.chartType);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
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
