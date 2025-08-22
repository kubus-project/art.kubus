import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/themeprovider.dart';

class AdvancedStatsScreen extends StatefulWidget {
  final String statType;
  
  const AdvancedStatsScreen({super.key, required this.statType});

  @override
  State<AdvancedStatsScreen> createState() => _AdvancedStatsScreenState();
}

class _AdvancedStatsScreenState extends State<AdvancedStatsScreen> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _selectedTimeframe = '7 days';
  
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('${widget.statType} Analytics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showExportDialog(),
            icon: const Icon(Icons.download),
          ),
          IconButton(
            onPressed: () => _showShareDialog(),
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimeframeSelectorCard(),
              const SizedBox(height: 20),
              _buildAdvancedChart(),
              const SizedBox(height: 20),
              _buildDetailedMetrics(),
              const SizedBox(height: 20),
              _buildComparativeAnalysis(),
              const SizedBox(height: 20),
              _buildInsightsCard(),
              const SizedBox(height: 20),
              _buildGoalsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeframeSelectorCard() {
    final timeframes = ['7 days', '30 days', '3 months', '1 year', 'All time'];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time Range',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: timeframes.map((timeframe) {
                final isSelected = _selectedTimeframe == timeframe;
                return FilterChip(
                  selected: isSelected,
                  label: Text(timeframe),
                  onSelected: (selected) {
                    setState(() {
                      _selectedTimeframe = timeframe;
                    });
                  },
                  selectedColor: Provider.of<ThemeProvider>(context).accentColor.withOpacity(0.2),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedChart() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final data = _getExtendedStatsData();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.statType} Over Time',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _selectedTimeframe,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 250,
              child: CustomPaint(
                painter: LineChartPainter(
                  data: data,
                  accentColor: themeProvider.accentColor,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                ),
                size: const Size.fromHeight(250),
              ),
            ),
            const SizedBox(height: 16),
            _buildChartLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend() {
    final currentValue = _getCurrentValue();
    final change = _getChangePercentage();
    final isPositive = change >= 0;
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Value',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                currentValue,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change ($_selectedTimeframe)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    color: isPositive ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedMetrics() {
    final metrics = _getDetailedMetrics();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detailed Metrics',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...metrics.map((metric) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    metric['title'] ?? '',
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                  Text(
                    metric['value'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildComparativeAnalysis() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comparative Analysis',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildComparisonItem('vs. Last Period', '+12.5%', true),
            _buildComparisonItem('vs. Average User', '+45.2%', true),
            _buildComparisonItem('vs. Your Best', '-8.1%', false),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonItem(String label, String value, bool isPositive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 14),
          ),
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: isPositive ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isPositive ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard() {
    final insights = _getInsights();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  color: Provider.of<ThemeProvider>(context).accentColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Insights',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...insights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: Provider.of<ThemeProvider>(context).accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      insight,
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Goals & Milestones',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildGoalItem('Next Milestone', '50 ${widget.statType}', 0.8),
            const SizedBox(height: 12),
            _buildGoalItem('Monthly Goal', '100 ${widget.statType}', 0.6),
            const SizedBox(height: 12),
            _buildGoalItem('Annual Goal', '500 ${widget.statType}', 0.2),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalItem(String title, String target, double progress) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 14),
            ),
            Text(
              target,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(themeProvider.accentColor),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toInt()}% complete',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text('Export your stats data to CSV or PDF format.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data exported successfully!')),
              );
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _showShareDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Stats'),
        content: const Text('Share your achievement with friends and followers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Stats shared successfully!')),
              );
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  List<double> _getExtendedStatsData() {
    switch (widget.statType) {
      case 'Artworks':
        switch (_selectedTimeframe) {
          case '7 days':
            return [35, 37, 39, 40, 41, 42, 42];
          case '30 days':
            return [20, 25, 28, 30, 32, 35, 37, 39, 40, 41, 42, 42];
          case '3 months':
            return [5, 8, 12, 18, 25, 30, 35, 40, 42];
          default:
            return [0, 5, 12, 20, 28, 35, 42];
        }
      case 'Followers':
        switch (_selectedTimeframe) {
          case '7 days':
            return [980, 1050, 1120, 1150, 1180, 1200, 1200];
          case '30 days':
            return [800, 850, 900, 950, 1000, 1050, 1100, 1150, 1180, 1200, 1200, 1200];
          default:
            return [100, 300, 500, 700, 900, 1100, 1200];
        }
      case 'Views':
        switch (_selectedTimeframe) {
          case '7 days':
            return [7200, 7800, 8100, 8300, 8450, 8500, 8500];
          case '30 days':
            return [5000, 5500, 6000, 6500, 7000, 7500, 8000, 8200, 8400, 8500, 8500, 8500];
          default:
            return [1000, 2500, 4000, 6000, 7500, 8200, 8500];
        }
      default:
        return [10, 20, 30, 25, 35, 40, 45];
    }
  }

  String _getCurrentValue() {
    switch (widget.statType) {
      case 'Artworks':
        return '42';
      case 'Followers':
        return '1.2k';
      case 'Views':
        return '8.5k';
      default:
        return '0';
    }
  }

  double _getChangePercentage() {
    switch (widget.statType) {
      case 'Artworks':
        return 20.0;
      case 'Followers':
        return 22.4;
      case 'Views':
        return 18.1;
      default:
        return 0.0;
    }
  }

  List<Map<String, String>> _getDetailedMetrics() {
    switch (widget.statType) {
      case 'Artworks':
        return [
          {'title': 'Average per week', 'value': '6'},
          {'title': 'Most productive day', 'value': 'Tuesday'},
          {'title': 'Upload frequency', 'value': 'Every 1.2 days'},
          {'title': 'Quality score', 'value': '8.5/10'},
        ];
      case 'Followers':
        return [
          {'title': 'Growth rate', 'value': '22.4%'},
          {'title': 'Engagement rate', 'value': '4.8%'},
          {'title': 'Daily gain average', 'value': '32'},
          {'title': 'Best performing content', 'value': 'Digital Art'},
        ];
      case 'Views':
        return [
          {'title': 'Daily average', 'value': '1,214'},
          {'title': 'Peak hour', 'value': '8 PM'},
          {'title': 'Best performing piece', 'value': 'Neon Dreams'},
          {'title': 'View duration', 'value': '2m 45s'},
        ];
      default:
        return [];
    }
  }

  List<String> _getInsights() {
    switch (widget.statType) {
      case 'Artworks':
        return [
          'Your upload rate increased by 50% this week compared to last week.',
          'Digital art pieces receive 40% more engagement than traditional art.',
          'Tuesday is your most productive day for creating content.',
          'Consider posting during 7-9 PM for maximum visibility.',
        ];
      case 'Followers':
        return [
          'Your follower growth is 22% above average for artists in your category.',
          'Interactive posts generate 3x more followers than static images.',
          'Users who discover you through hashtags are 60% more likely to follow.',
          'Your engagement rate indicates high-quality content that resonates with your audience.',
        ];
      case 'Views':
        return [
          'Your content performs best during evening hours (7-9 PM).',
          'Neon-themed artworks consistently generate the most views.',
          'Your average view duration is 45% higher than the platform average.',
          'Cross-posting to community feeds increases views by 80%.',
        ];
      default:
        return ['No insights available for this metric.'];
    }
  }
}

class LineChartPainter extends CustomPainter {
  final List<double> data;
  final Color accentColor;
  final Color backgroundColor;
  
  LineChartPainter({
    required this.data,
    required this.accentColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = accentColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    if (data.isEmpty) return;

    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minValue) / range) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw data points
    final pointPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minValue) / range) * size.height;
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
