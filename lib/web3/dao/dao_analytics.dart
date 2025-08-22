import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DAOAnalytics extends StatefulWidget {
  const DAOAnalytics({super.key});

  @override
  State<DAOAnalytics> createState() => _DAOAnalyticsState();
}

class _DAOAnalyticsState extends State<DAOAnalytics> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  String _selectedPeriod = 'Last 30 Days';

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
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'DAO Analytics',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          actions: [
            _buildPeriodSelector(),
            const SizedBox(width: 16),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGovernanceMetrics(),
              const SizedBox(height: 24),
              _buildParticipationChart(),
              const SizedBox(height: 24),
              _buildProposalAnalytics(),
              const SizedBox(height: 24),
              _buildVotingPowerDistribution(),
              const SizedBox(height: 24),
              _buildTreasuryMetrics(),
              const SizedBox(height: 24),
              _buildCommunityHealth(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: DropdownButton<String>(
        value: _selectedPeriod,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF1A1A1A),
        style: const TextStyle(color: Colors.white),
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

  Widget _buildGovernanceMetrics() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildMetricCard(
          'Total Proposals',
          '47',
          '+5 this month',
          Icons.how_to_vote,
          const Color(0xFF4CAF50),
          '+12.2%',
          true,
        ),
        _buildMetricCard(
          'Active Voters',
          '2,134',
          '+89 this week',
          Icons.people,
          const Color(0xFF6C63FF),
          '+4.3%',
          true,
        ),
        _buildMetricCard(
          'Participation Rate',
          '67.8%',
          '+2.1% this month',
          Icons.trending_up,
          const Color(0xFFFFD93D),
          '+3.2%',
          true,
        ),
        _buildMetricCard(
          'Avg. Voting Power',
          '145 KUB8',
          'Per active voter',
          Icons.account_balance_wallet,
          const Color(0xFF00D4AA),
          '+8.5%',
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  change,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: isPositive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipationChart() {
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
            'Voting Participation Trends',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: CustomPaint(
              painter: ParticipationChartPainter(),
              size: const Size(double.infinity, 200),
            ),
          ),
          const SizedBox(height: 16),
          _buildChartLegend(),
        ],
      ),
    );
  }

  Widget _buildChartLegend() {
    final items = [
      {'label': 'Participation Rate', 'color': const Color(0xFF4CAF50)},
      {'label': 'New Voters', 'color': const Color(0xFF6C63FF)},
      {'label': 'Proposals', 'color': const Color(0xFFFFD93D)},
    ];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 3,
                decoration: BoxDecoration(
                  color: item['color'] as Color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                item['label'] as String,
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

  Widget _buildProposalAnalytics() {
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
            'Proposal Analytics',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildProposalTypeChart()),
              const SizedBox(width: 20),
              Expanded(child: _buildProposalOutcomes()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProposalTypeChart() {
    final types = [
      {'type': 'Platform Update', 'count': 18, 'color': const Color(0xFF4CAF50)},
      {'type': 'Treasury', 'count': 12, 'color': const Color(0xFF6C63FF)},
      {'type': 'Policy Change', 'count': 8, 'color': const Color(0xFFFFD93D)},
      {'type': 'Community', 'count': 9, 'color': const Color(0xFF00D4AA)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Proposals by Type',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ...types.map((type) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: type['color'] as Color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  type['type'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
              Text(
                '${type['count']}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildProposalOutcomes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Success Rate',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        _buildOutcomeItem('Passed', 32, const Color(0xFF4CAF50)),
        const SizedBox(height: 8),
        _buildOutcomeItem('Failed', 12, const Color(0xFFFF5252)),
        const SizedBox(height: 8),
        _buildOutcomeItem('Active', 3, const Color(0xFFFFD93D)),
      ],
    );
  }

  Widget _buildOutcomeItem(String label, int count, Color color) {
    final total = 47;
    final percentage = (count / total * 100).round();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const Spacer(),
            Text(
              '$count ($percentage%)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: count / total,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVotingPowerDistribution() {
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
            'Voting Power Distribution',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          _buildPowerDistributionItem('Top 10 Holders', '45.2%', const Color(0xFFFF5252)),
          const SizedBox(height: 12),
          _buildPowerDistributionItem('Top 50 Holders', '72.8%', const Color(0xFFFFD93D)),
          const SizedBox(height: 12),
          _buildPowerDistributionItem('Top 100 Holders', '86.4%', const Color(0xFF4CAF50)),
          const SizedBox(height: 12),
          _buildPowerDistributionItem('Remaining Holders', '13.6%', const Color(0xFF6C63FF)),
        ],
      ),
    );
  }

  Widget _buildPowerDistributionItem(String label, String percentage, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ),
        Text(
          percentage,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTreasuryMetrics() {
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
            'Treasury Health',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildTreasuryMetricItem('Total Value', '2.45M KUB8', Icons.account_balance)),
              const SizedBox(width: 16),
              Expanded(child: _buildTreasuryMetricItem('Monthly Growth', '+5.2%', Icons.trending_up)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTreasuryMetricItem('Utilization Rate', '23.4%', Icons.pie_chart)),
              const SizedBox(width: 16),
              Expanded(child: _buildTreasuryMetricItem('Reserve Ratio', '76.6%', Icons.security)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTreasuryMetricItem(String label, String value, IconData icon) {
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

  Widget _buildCommunityHealth() {
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
            'Community Health Score',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF4CAF50), width: 4),
                      ),
                      child: Center(
                        child: Text(
                          '87',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4CAF50),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Overall Score',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildHealthMetric('Participation', 0.85, const Color(0xFF4CAF50)),
                    const SizedBox(height: 8),
                    _buildHealthMetric('Diversity', 0.72, const Color(0xFFFFD93D)),
                    const SizedBox(height: 8),
                    _buildHealthMetric('Activity', 0.94, const Color(0xFF6C63FF)),
                    const SizedBox(height: 8),
                    _buildHealthMetric('Consensus', 0.68, const Color(0xFF00D4AA)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetric(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const Spacer(),
            Text(
              '${(value * 100).round()}%',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Custom painter for participation chart
class ParticipationChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
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

    // Draw participation rate line
    paint.color = const Color(0xFF4CAF50);
    final participationData = [0.4, 0.5, 0.3, 0.7, 0.6, 0.8, 0.75, 0.85];
    final participationPath = Path();
    for (int i = 0; i < participationData.length; i++) {
      final x = size.width * i / (participationData.length - 1);
      final y = size.height * (1 - participationData[i]);
      if (i == 0) {
        participationPath.moveTo(x, y);
      } else {
        participationPath.lineTo(x, y);
      }
    }
    canvas.drawPath(participationPath, paint);

    // Draw new voters line
    paint.color = const Color(0xFF6C63FF);
    final newVotersData = [0.2, 0.3, 0.2, 0.5, 0.4, 0.6, 0.5, 0.7];
    final newVotersPath = Path();
    for (int i = 0; i < newVotersData.length; i++) {
      final x = size.width * i / (newVotersData.length - 1);
      final y = size.height * (1 - newVotersData[i]);
      if (i == 0) {
        newVotersPath.moveTo(x, y);
      } else {
        newVotersPath.lineTo(x, y);
      }
    }
    canvas.drawPath(newVotersPath, paint);

    // Draw proposals line
    paint.color = const Color(0xFFFFD93D);
    final proposalsData = [0.1, 0.2, 0.15, 0.3, 0.25, 0.4, 0.35, 0.45];
    final proposalsPath = Path();
    for (int i = 0; i < proposalsData.length; i++) {
      final x = size.width * i / (proposalsData.length - 1);
      final y = size.height * (1 - proposalsData[i]);
      if (i == 0) {
        proposalsPath.moveTo(x, y);
      } else {
        proposalsPath.lineTo(x, y);
      }
    }
    canvas.drawPath(proposalsPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
