import 'package:art_kubus/features/analytics/analytics_metric_registry.dart';
import 'package:art_kubus/features/analytics/analytics_time.dart';
import 'package:art_kubus/features/analytics/widgets/analytics_trend_panel.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AnalyticsSeriesSummary _summary({
  required List<double> values,
  required List<double> previous,
  double? changePercent,
}) {
  final total = values.fold<double>(0, (sum, value) => sum + value);
  final previousTotal = previous.fold<double>(0, (sum, value) => sum + value);
  return AnalyticsSeriesSummary(
    values: values,
    previousValues: previous,
    currentTotal: total,
    previousTotal: previousTotal,
    average: values.isEmpty ? 0 : total / values.length,
    previousAverage: previous.isEmpty ? 0 : previousTotal / previous.length,
    peak: values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b),
    consistency: 0,
    changePercent: changePercent,
    groupTotals: const <String, int>{},
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required AnalyticsSeriesSummary summary,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final metric = AnalyticsMetricRegistry.byId('viewsReceived')!;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: AnalyticsTrendPanel(
            metric: metric,
            summary: summary,
            labels: List<String>.generate(
              summary.values.length,
              (i) => '${i + 1}/10',
            ),
            timeframe: '30d',
            isLoading: false,
            error: null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the trend names both lines once data exists', (tester) async {
    await _pump(
      tester,
      summary: _summary(
        values: <double>[0, 3, 5, 2, 8, 4, 6],
        previous: <double>[1, 2, 2, 3, 1, 0, 4],
      ),
    );

    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Previous'), findsOneWidget);
  });

  testWidgets('no legend is shown while there is no data to draw',
      (tester) async {
    await _pump(
      tester,
      summary: _summary(
        values: List<double>.filled(7, 0),
        previous: List<double>.filled(7, 0),
      ),
    );

    expect(find.text('Current'), findsNothing);
    expect(find.text('Previous'), findsNothing);
    expect(find.text('No data yet'), findsOneWidget);
  });

  testWidgets('the legend follows the Slovenian copy', (tester) async {
    await _pump(
      tester,
      locale: const Locale('sl'),
      summary: _summary(
        values: <double>[0, 3, 5, 2, 8, 4, 6],
        previous: <double>[1, 2, 2, 3, 1, 0, 4],
      ),
    );

    expect(find.text('Trenutno'), findsOneWidget);
    expect(find.text('Prejšnje'), findsOneWidget);
    expect(find.text('Current'), findsNothing);
  });

  testWidgets('a flat period reads as neutral, not as growth', (tester) async {
    await _pump(
      tester,
      summary: _summary(
        values: List<double>.filled(7, 0),
        previous: List<double>.filled(7, 0),
        changePercent: 0,
      ),
    );

    expect(find.text('0.0%'), findsOneWidget);
    expect(find.text('+0.0%'), findsNothing);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
  });

  testWidgets('a real gain keeps its sign and up arrow', (tester) async {
    await _pump(
      tester,
      summary: _summary(
        values: <double>[0, 3, 5, 2, 8, 4, 6],
        previous: <double>[1, 2, 2, 3, 1, 0, 4],
        changePercent: 12.5,
      ),
    );

    expect(find.text('+12.5%'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
  });
}
