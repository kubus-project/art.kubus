import 'package:art_kubus/features/analytics/analytics_metric_registry.dart';
import 'package:art_kubus/features/analytics/analytics_time.dart';
import 'package:art_kubus/features/analytics/widgets/analytics_trend_panel.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
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
  Size size = const Size(390, 844),
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final metric = AnalyticsMetricRegistry.byId('viewsReceived')!;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? ThemeData.light(useMaterial3: true),
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

  group('desktop width (1440 x 900)', () {
    final datasets = <String, AnalyticsSeriesSummary>{
      'normal': _summary(
        values: List<double>.generate(30, (i) => 4 + (i % 7) * 1.5),
        previous: List<double>.generate(30, (i) => 3 + (i % 5) * 1.2),
        changePercent: 12,
      ),
      'spiky': _summary(
        values: <double>[
          ...List<double>.filled(14, 1),
          240,
          ...List<double>.filled(15, 2)
        ],
        previous: List<double>.filled(30, 3),
        changePercent: 340,
      ),
      'single point': _summary(values: <double>[7], previous: <double>[3]),
      'empty': _summary(values: const <double>[], previous: const <double>[]),
    };

    for (final entry in datasets.entries) {
      for (final dark in <bool>[false, true]) {
        testWidgets(
            '${entry.key}, ${dark ? 'dark' : 'light'}: lays out and hovers without errors',
            (tester) async {
          await _pump(
            tester,
            summary: entry.value,
            size: const Size(1440, 900),
            theme: dark
                ? ThemeData.dark(useMaterial3: true)
                : ThemeData.light(useMaterial3: true),
          );
          final panel = find.byType(AnalyticsTrendPanel);
          expect(panel, findsOneWidget);
          expect(tester.getSize(panel).width, lessThanOrEqualTo(1440));

          final mouse =
              await tester.createGesture(kind: PointerDeviceKind.mouse);
          await mouse.addPointer(location: Offset.zero);
          addTearDown(mouse.removePointer);
          final box = tester.getRect(panel);
          for (final fx in <double>[0.2, 0.5, 0.8]) {
            await mouse
                .moveTo(Offset(box.left + box.width * fx, box.center.dy));
            await tester.pump(const Duration(milliseconds: 120));
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
