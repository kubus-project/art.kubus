import 'package:art_kubus/features/analytics/analytics_view_models.dart';
import 'package:art_kubus/features/analytics/widgets/analytics_overview_grid.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('overview cards select their metric when tapped', (tester) async {
    String? selectedMetric;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

  testWidgets('selected metric renders as the full-width lead card',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(900, 600)),
            child: AnalyticsOverviewGrid(
              isLoading: false,
              selectedMetricId: 'artworks',
              onMetricSelected: (_) {},
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
                  value: '7',
                  icon: Icons.palette_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // The selected metric's value renders at lead-card scale; the
    // supporting metric stays at tile scale.
    final leadValue = tester.widget<Text>(find.text('7'));
    final supportingValue = tester.widget<Text>(find.text('18'));
    expect(
      leadValue.style!.fontSize!,
      greaterThan(supportingValue.style!.fontSize!),
    );

    // Lead card spans the full grid width; supporting tiles do not.
    final leadWidth = tester.getSize(find.text('7')).width +
        tester.getTopLeft(find.text('7')).dx;
    expect(leadWidth, lessThanOrEqualTo(900));
    final gridFinder = find.byType(GridView);
    expect(gridFinder, findsOneWidget);
  });
}
