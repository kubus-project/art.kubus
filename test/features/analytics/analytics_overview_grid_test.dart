import 'package:art_kubus/features/analytics/analytics_view_models.dart';
import 'package:art_kubus/features/analytics/widgets/analytics_overview_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('overview cards select their metric when tapped', (tester) async {
    String? selectedMetric;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(900, 600)),
            child: AnalyticsOverviewGrid(
              isLoading: false,
              selectedMetricId: 'viewsReceived',
              onMetricSelected: (metricId) => selectedMetric = metricId,
              cards: const <AnalyticsOverviewCardData>[
                AnalyticsOverviewCardData(
                  metricId: 'viewsReceived',
                  title: 'Views received',
                  value: '18',
                  icon: Icons.visibility_outlined,
                ),
                AnalyticsOverviewCardData(
                  metricId: 'artworks',
                  title: 'Artworks',
                  value: '1',
                  icon: Icons.palette_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Artworks'));
    await tester.pumpAndSettle();

    expect(selectedMetric, 'artworks');
  });
}
