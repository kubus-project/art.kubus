import 'package:art_kubus/features/analytics/analytics_metric_registry.dart';
import 'package:art_kubus/features/analytics/widgets/analytics_filter_summary_bar.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/analytics_filters_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final metrics = <AnalyticsMetricDefinition>[
    AnalyticsMetricRegistry.requireById('viewsReceived'),
    AnalyticsMetricRegistry.requireById('likesReceived'),
    AnalyticsMetricRegistry.requireById('followers'),
  ];

  Widget buildHarness(
    AnalyticsFiltersProvider filters, {
    Locale locale = const Locale('en'),
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final metricId = filters.metricFor(
              AnalyticsFiltersProvider.profileContextKey,
              fallback: 'viewsReceived',
            );
            final timeframe = filters.timeframeFor(
              AnalyticsFiltersProvider.profileContextKey,
            );
            return AnalyticsFilterSummaryBar(
              metrics: metrics,
              selectedMetricId: metricId,
              timeframe: timeframe,
              onMetricChanged: (id) => filters.setMetricFor(
                AnalyticsFiltersProvider.profileContextKey,
                id,
                allowedMetrics: metrics.map((metric) => metric.id),
              ),
              onTimeframeChanged: (tf) => filters.setTimeframeFor(
                AnalyticsFiltersProvider.profileContextKey,
                tf,
              ),
            );
          },
        ),
      ),
    );
  }

  testWidgets('summary bar opens the sheet and persists metric selection',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final filters = AnalyticsFiltersProvider();
    await tester.pumpWidget(buildHarness(filters));

    await tester.tap(find.text('Views received'));
    await tester.pumpAndSettle();

    expect(find.text('Analytics filters'), findsOneWidget);

    await tester.tap(find.text('Followers'));
    await tester.pump();

    expect(
      filters.metricFor(AnalyticsFiltersProvider.profileContextKey),
      'followers',
    );

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Analytics filters'), findsNothing);
    expect(
      filters.metricFor(AnalyticsFiltersProvider.profileContextKey),
      'followers',
    );
  });

  testWidgets('sheet persists timeframe selection through the provider',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final filters = AnalyticsFiltersProvider();
    await tester.pumpWidget(buildHarness(filters));

    await tester.tap(find.text('Last 30 days'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Last 7 days'));
    await tester.pump();

    expect(
      filters.timeframeFor(AnalyticsFiltersProvider.profileContextKey),
      '7d',
    );
  });

  testWidgets('summary bar renders Slovenian labels', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final filters = AnalyticsFiltersProvider();
    await tester.pumpWidget(
      buildHarness(filters, locale: const Locale('sl')),
    );

    expect(find.text('Prejeti ogledi'), findsOneWidget);
    expect(find.text('Zadnjih 30 dni'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
