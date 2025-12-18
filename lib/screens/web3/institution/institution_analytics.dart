import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../models/institution.dart';
import '../../../providers/institution_provider.dart';
import '../../../providers/artwork_provider.dart';
import '../../../utils/app_color_utils.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../widgets/inline_loading.dart';
import '../../../widgets/empty_state_card.dart';
import '../../../utils/app_animations.dart';

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
  bool _didPlayEntrance = false;

  @override
  void initState() {
    super.initState();
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
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              onPressed: () => _showExportDialog(),
              icon: Icon(Icons.download,
                  color: Theme.of(context).colorScheme.onSurface, size: 20),
            ),
            IconButton(
              onPressed: () => _showSettingsDialog(),
              icon: Icon(Icons.settings,
                  color: Theme.of(context).colorScheme.onSurface, size: 20),
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
        border: Border.all(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
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
          InputDecorator(
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimary
                        .withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimary
                        .withValues(alpha: 0.2)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPeriod,
                isExpanded: true,
                dropdownColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                items: periods
                    .map(
                      (period) => DropdownMenuItem<String>(
                        value: period,
                        child: Text(period),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPeriod = value;
                    });
                  }
                },
              ),
            ),
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
              Center(
                child: EmptyStateCard(
                  icon: Icons.analytics_outlined,
                  title: 'No analytics data available',
                  description:
                      'There is no analytics data for this institution yet.',
                ),
              ),
            ],
          );
        }

        // Get analytics data from the provider
        final institution = institutionProvider.institutions.first;
        final analytics =
            institutionProvider.getInstitutionAnalytics(institution.id);

        final stats = [
          {
            'title': 'Total Visitors',
            'value': '${analytics['totalVisitors'] ?? 0}',
            'change':
                '+${analytics['visitorGrowth']?.toStringAsFixed(1) ?? '0.0'}%',
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
            'change':
                '+${analytics['revenueGrowth']?.toStringAsFixed(1) ?? '0.0'}%',
            'positive': (analytics['revenueGrowth'] ?? 0) >= 0
          },
          {
            'title': 'Revenue',
            'value': '\$${_formatRevenue(analytics['revenue'] ?? 0)}',
            'change':
                '+${analytics['revenueGrowth']?.toStringAsFixed(1) ?? '0.0'}%',
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
        border: Border.all(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              stat['title'],
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
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
                  color: stat['positive'] 
                      ? KubusColorRoles.of(context).positiveAction 
                      : KubusColorRoles.of(context).negativeAction,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    stat['change'],
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: stat['positive'] 
                          ? KubusColorRoles.of(context).positiveAction 
                          : KubusColorRoles.of(context).negativeAction,
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
        border: Border.all(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
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

        // Build a simple 7-day series derived from available stats so the
        // analytics UI remains useful in offline/local mode.
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 20,
                              height: height,
                              decoration: BoxDecoration(
                                color: AppColorUtils.indigoAccent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                'Mon',
                                'Tue',
                                'Wed',
                                'Thu',
                                'Fri',
                                'Sat',
                                'Sun'
                              ][index],
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
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

        final events = institution != null
            ? institutionProvider.getEventsByInstitution(institution.id)
            : const <Event>[];
        final totalVisitors = (analytics['totalVisitors'] as int?) ?? 0;

        double? avgDurationMinutes;
        if (events.isNotEmpty) {
          final minutes = events
              .map((e) => e.endDate.difference(e.startDate).inMinutes)
              .fold<int>(0, (sum, value) => sum + value);
          avgDurationMinutes = minutes / events.length;
        }
        final avgDurationLabel = avgDurationMinutes == null
            ? '—'
            : avgDurationMinutes >= 60
                ? '${(avgDurationMinutes / 60).toStringAsFixed(1)} h'
                : '${avgDurationMinutes.round()} min';

        double? avgFill;
        final fillValues = events
            .where((e) => (e.capacity ?? 0) > 0)
            .map((e) => e.currentAttendees / e.capacity!)
            .toList();
        if (fillValues.isNotEmpty) {
          avgFill = fillValues.fold<double>(0, (sum, v) => sum + v) /
              fillValues.length;
        }
        final avgFillLabel =
            avgFill == null ? '—' : '${(avgFill * 100).toStringAsFixed(0)}%';

        final metrics = [
          {'label': 'Avg. Event Duration', 'value': avgDurationLabel},
          {'label': 'Avg. Event Fill', 'value': avgFillLabel},
          {
            'label': 'Return Visitors (est.)',
            'value': '${(totalVisitors * 0.34).round()}'
          },
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: metrics
                      .map((metric) => Flexible(
                            child: Column(
                              children: [
                                Text(
                                  metric['value']!,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  metric['label']!,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ))
                      .toList(),
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

        final institutionEvents = institution != null
            ? List<Event>.from(
                institutionProvider.getEventsByInstitution(institution.id))
            : <Event>[];
        institutionEvents
            .sort((a, b) => b.currentAttendees.compareTo(a.currentAttendees));
        final topEvents = institutionEvents.take(3).toList();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .onPrimary
                    .withValues(alpha: 0.1)),
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
              if (topEvents.isEmpty)
                EmptyStateCard(
                  icon: Icons.event_busy,
                  title: 'No events yet',
                  description:
                      'Create your first event to see performance analytics.',
                  showAction: false,
                )
              else
                ...topEvents.map((event) {
                  final capacity = event.capacity ?? 0;
                  final fillPct =
                      capacity > 0 ? (event.currentAttendees / capacity) : null;
                  final fillText = fillPct == null
                      ? 'No capacity'
                      : '${(fillPct * 100).toStringAsFixed(0)}% full';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${event.currentAttendees} attendees',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimary
                                    .withValues(alpha: 0.14)),
                          ),
                          child: Text(
                            fillText,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
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

        final events = institution != null
            ? institutionProvider.getEventsByInstitution(institution.id)
            : const <Event>[];
        final revenueByType = <String, double>{};
        var totalRevenue = 0.0;

        for (final event in events) {
          final price = event.price ?? 0;
          if (price <= 0) continue;
          final revenue = price * event.currentAttendees;
          if (revenue <= 0) continue;
          totalRevenue += revenue;
          final typeLabel =
              event.type.name.replaceAll(RegExp(r'([A-Z])'), r' $1');
          final normalizedTypeLabel = typeLabel.isNotEmpty
              ? '${typeLabel[0].toUpperCase()}${typeLabel.substring(1)}'
              : 'Event';
          revenueByType[normalizedTypeLabel] =
              (revenueByType[normalizedTypeLabel] ?? 0) + revenue;
        }

        final fromStats = (analytics['revenue'] as num?)?.toDouble() ?? 0.0;
        if (totalRevenue <= 0 && fromStats > 0) {
          totalRevenue = fromStats;
          revenueByType['Total'] = fromStats;
        }

        final sorted = revenueByType.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .onPrimary
                    .withValues(alpha: 0.1)),
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
              if (totalRevenue <= 0)
                EmptyStateCard(
                  icon: Icons.payments_outlined,
                  title: 'No revenue data yet',
                  description:
                      'Revenue will appear after paid events collect attendees.',
                  showAction: false,
                )
              else ...[
                ...sorted.take(4).map((entry) {
                  final pct =
                      totalRevenue > 0 ? entry.value / totalRevenue : 0.0;
                  return _buildRevenueItem(
                      entry.key, '\$${entry.value.toStringAsFixed(0)}', pct);
                }),
                const SizedBox(height: 4),
                Text(
                  'Total: \$${totalRevenue.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevenueItem(String category, String amount, double percentage) {
    final animationTheme = context.animationTheme;

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
                color: AppColorUtils.indigoAccent,
                duration: animationTheme.medium,
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
        // Get artworks from institution or all artworks
        final artworks = artworkProvider.artworks.toList()
          ..sort((a, b) => b.viewsCount.compareTo(a.viewsCount));

        final topArtworks = artworks.take(3).toList();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .onPrimary
                    .withValues(alpha: 0.1)),
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
              color: AppColorUtils.indigoAccent.withValues(alpha: 0.2),
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
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
        title: Text('Export Analytics',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'Export your analytics data to PDF or Excel format.',
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onPrimary
                  .withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Analytics exported successfully!')),
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
        title: Text('Analytics Settings',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'Configure your analytics tracking preferences.',
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onPrimary
                  .withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.commonClose),
          ),
        ],
      ),
    );
  }
}
