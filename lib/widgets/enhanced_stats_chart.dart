import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EnhancedStatsChart extends StatefulWidget {
  final String title;
  final List<double> data;
  final Color accentColor;
  final List<String>? labels;

  const EnhancedStatsChart({
    super.key,
    required this.title,
    required this.data,
    required this.accentColor,
    this.labels,
  });

  @override
  State<EnhancedStatsChart> createState() => _EnhancedStatsChartState();
}

class _EnhancedStatsChartState extends State<EnhancedStatsChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
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
    return Container(
      height: 250,
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
            widget.title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  painter: StatsChartPainter(
                    data: widget.data,
                    accentColor: widget.accentColor,
                    labels: widget.labels,
                    animationValue: _animation.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class StatsChartPainter extends CustomPainter {
  final List<double> data;
  final Color accentColor;
  final List<String>? labels;
  final double animationValue;

  StatsChartPainter({
    required this.data,
    required this.accentColor,
    this.labels,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = accentColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = accentColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Calculate chart area (leave space for labels)
    const chartTop = 20.0;
    final chartBottom = size.height - 40.0;
    const chartLeft = 30.0;
    final chartRight = size.width - 20.0;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;

    // Draw grid lines
    for (int i = 0; i <= 4; i++) {
      final y = chartTop + (chartHeight * i / 4);
      canvas.drawLine(
        Offset(chartLeft, y),
        Offset(chartRight, y),
        gridPaint,
      );
    }

    // Find min and max values for scaling
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    if (range == 0) return;

    // Draw value labels on Y-axis
    for (int i = 0; i <= 4; i++) {
      final value = minValue + (range * (4 - i) / 4);
      final y = chartTop + (chartHeight * i / 4);
      
      textPainter.text = TextSpan(
        text: value.toStringAsFixed(0),
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(chartLeft - textPainter.width - 5, y - textPainter.height / 2),
      );
    }

    // Create path for line chart
    final path = Path();
    final fillPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = chartLeft + (chartWidth * i / (data.length - 1));
      final normalizedValue = (data[i] - minValue) / range;
      final y = chartBottom - (chartHeight * normalizedValue * animationValue);
      
      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartBottom);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Complete fill path
    if (points.isNotEmpty) {
      fillPath.lineTo(points.last.dx, chartBottom);
      fillPath.close();
    }

    // Draw fill and line
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw data points
    final pointPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final pointBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      
      // Draw point border
      canvas.drawCircle(point, 5, pointBorderPaint);
      // Draw point
      canvas.drawCircle(point, 3, pointPaint);

      // Draw value label above point
      textPainter.text = TextSpan(
        text: data[i].toStringAsFixed(0),
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          point.dx - textPainter.width / 2,
          point.dy - textPainter.height - 8,
        ),
      );
    }

    // Draw X-axis labels
    if (labels != null && labels!.length == data.length) {
      for (int i = 0; i < labels!.length; i++) {
        final x = chartLeft + (chartWidth * i / (data.length - 1));
        
        textPainter.text = TextSpan(
          text: labels![i],
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 10,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, chartBottom + 5),
        );
      }
    } else {
      // Default labels (day numbers)
      for (int i = 0; i < data.length; i++) {
        final x = chartLeft + (chartWidth * i / (data.length - 1));
        
        textPainter.text = TextSpan(
          text: '${i + 1}d',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 10,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, chartBottom + 5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Bar chart variant
class EnhancedBarChart extends StatefulWidget {
  final String title;
  final List<double> data;
  final Color accentColor;
  final List<String>? labels;

  const EnhancedBarChart({
    super.key,
    required this.title,
    required this.data,
    required this.accentColor,
    this.labels,
  });

  @override
  State<EnhancedBarChart> createState() => _EnhancedBarChartState();
}

class _EnhancedBarChartState extends State<EnhancedBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
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
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final maxValue = widget.data.reduce((a, b) => a > b ? a : b);
                    final minValue = widget.data.reduce((a, b) => a < b ? a : b);
                    final range = maxValue - minValue;
                    
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: widget.data.asMap().entries.map((entry) {
                        final index = entry.key;
                        final value = entry.value;
                        final normalizedHeight = range > 0 
                            ? ((value - minValue) / range) * (constraints.maxHeight - 40)
                            : constraints.maxHeight * 0.3;
                        final barHeight = (normalizedHeight * _animation.value).clamp(4.0, constraints.maxHeight - 30);
                        
                        return Flexible(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (_animation.value > 0.8)
                                  Text(
                                    value.toStringAsFixed(0),
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                if (_animation.value > 0.8) const SizedBox(height: 4),
                                Container(
                                  width: 16,
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        widget.accentColor,
                                        widget.accentColor.withOpacity(0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: widget.accentColor.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.labels?[index] ?? '${index + 1}d',
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
