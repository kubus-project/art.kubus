import 'package:art_kubus/widgets/charts/chart_scale.dart';
import 'package:art_kubus/widgets/charts/stats_interactive_bar_chart.dart';
import 'package:art_kubus/widgets/charts/stats_interactive_line_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _emptyLabel = 'No data yet';

List<String> _labels(int count) =>
    List<String>.generate(count, (i) => '${i + 1}/10');

Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  Widget chart,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(width: size.width - 32, child: chart),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

StatsInteractiveLineChart _trend(List<double> values) {
  return StatsInteractiveLineChart(
    series: <StatsLineSeries>[
      StatsLineSeries(
        label: 'Current',
        values: values,
        color: Colors.indigo,
        showArea: true,
      ),
    ],
    xLabels: _labels(values.length),
    gridColor: Colors.black12,
    height: 260,
    emptyLabel: _emptyLabel,
    valueFormatter: (value) => value.round().toString(),
  );
}

void main() {
  final thirty = List<double>.generate(
    30,
    (i) => (i * 37 % 23).toDouble() + (i == 12 ? 400 : 0),
  );
  final week = <double>[3, 8, 5, 13, 9, 21, 17];

  for (final size in const <Size>[Size(390, 844), Size(1440, 900)]) {
    testWidgets(
        'trend chart fits ${size.width.round()} px without overflow or NaN',
        (tester) async {
      await _pumpAt(tester, size, _trend(week));

      expect(tester.takeException(), isNull);
      final chart = tester.getSize(find.byType(LineChart));
      expect(chart.width, lessThanOrEqualTo(size.width));
      expect(chart.width, lessThanOrEqualTo(ChartScale.maxContentWidth));
      expect(find.textContaining('NaN'), findsNothing);
      expect(find.textContaining('Infinity'), findsNothing);
    });
  }

  testWidgets('a 30-day outlier series draws without errors on a phone',
      (tester) async {
    await _pumpAt(tester, const Size(390, 844), _trend(thirty));

    expect(tester.takeException(), isNull);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final line = chart.data.lineBarsData.single;
    // The spike at index 12 is drawn at the clipped top, not at 400.
    expect(line.spots[12].y, lessThan(100));
    expect(line.spots[12].y, closeTo(chart.data.maxY, 1e-9));
  });

  testWidgets('wide desktop keeps the line chart at the content cap',
      (tester) async {
    await _pumpAt(tester, const Size(1440, 900), _trend(week));

    final chart = tester.getSize(find.byType(LineChart));
    expect(chart.width, lessThanOrEqualTo(ChartScale.maxContentWidth));
    expect(chart.width, greaterThan(400));
  });

  testWidgets('all-zero series shows the empty label on a baseline',
      (tester) async {
    await _pumpAt(tester, const Size(390, 844), _trend(const [0, 0, 0, 0]));

    expect(tester.takeException(), isNull);
    expect(find.text(_emptyLabel), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('a single point renders as a point, not an empty line',
      (tester) async {
    await _pumpAt(tester, const Size(390, 844), _trend(const [42]));

    expect(tester.takeException(), isNull);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final line = chart.data.lineBarsData.single;
    expect(line.spots, hasLength(1));
    expect(chart.data.minX, lessThan(0));
    expect(chart.data.maxX, greaterThan(0));
    expect(line.dotData.show, isTrue);
    expect(line.dotData.checkToShowDot(line.spots.single, line), isTrue);
    expect(chart.data.minY, lessThan(42));
    expect(chart.data.maxY, greaterThan(42));
  });

  for (final size in const <Size>[Size(390, 844), Size(1440, 900)]) {
    testWidgets('bar chart fits ${size.width.round()} px without NaN',
        (tester) async {
      final entries = <StatsBarEntry>[
        for (var i = 0; i < week.length; i++)
          StatsBarEntry(
            bucketStart: DateTime.utc(2026, 10, 1 + i),
            value: week[i].round(),
          ),
      ];
      await _pumpAt(
        tester,
        size,
        StatsInteractiveBarChart(
          entries: entries,
          xLabels: _labels(week.length),
          barColor: Colors.teal,
          gridColor: Colors.black12,
          emptyLabel: _emptyLabel,
          height: 200,
        ),
      );

      expect(tester.takeException(), isNull);
      final chart = tester.getSize(find.byType(BarChart));
      expect(chart.width, lessThanOrEqualTo(size.width));
      expect(chart.width, lessThanOrEqualTo(ChartScale.maxContentWidth));
    });
  }
}
