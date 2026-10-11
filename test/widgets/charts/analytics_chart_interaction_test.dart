import 'package:art_kubus/widgets/charts/stats_interactive_bar_chart.dart';
import 'package:art_kubus/widgets/charts/stats_interactive_line_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpLine(
  WidgetTester tester, {
  required List<double> current,
  required List<double> previous,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: StatsInteractiveLineChart(
              series: <StatsLineSeries>[
                StatsLineSeries(
                  label: 'Current',
                  values: current,
                  color: Colors.indigo,
                  showArea: true,
                ),
                StatsLineSeries(
                  label: 'Previous',
                  values: previous,
                  color: Colors.teal,
                ),
              ],
              xLabels: List<String>.generate(current.length, (i) => 'D$i'),
              gridColor: Colors.black12,
              height: 260,
              emptyLabel: 'No data yet',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'the tooltip builder returns one item per touched spot, header included',
      (tester) async {
    final current = List<double>.generate(30, (i) => (i % 4).toDouble() + 1);
    final previous = List<double>.generate(30, (i) => (i % 3).toDouble() + 1);
    await _pumpLine(tester, current: current, previous: previous);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final bars = chart.data.lineBarsData;
    final touched = <LineBarSpot>[
      LineBarSpot(bars[0], 0, bars[0].spots[20]),
      LineBarSpot(bars[1], 1, bars[1].spots[20]),
    ];

    final items =
        chart.data.lineTouchData.touchTooltipData.getTooltipItems(touched);

    // fl_chart throws "tooltipItems and touchedSpots size should be same"
    // when the counts differ, so the header must not be an extra item.
    expect(items, hasLength(touched.length));
    expect(items.first!.text, 'D20\n');
    expect(items.first!.children!.single.text, 'Current: 1');
    expect(items.last!.children!.single.text, 'Previous: 3');
  });

  testWidgets('a single touched spot still gets exactly one item',
      (tester) async {
    await _pumpLine(
      tester,
      current: List<double>.generate(12, (i) => i.toDouble() + 1),
      previous: List<double>.filled(12, 0),
    );
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final bars = chart.data.lineBarsData;
    final items = chart.data.lineTouchData.touchTooltipData.getTooltipItems(
      <LineBarSpot>[LineBarSpot(bars[0], 0, bars[0].spots[5])],
    );
    expect(items, hasLength(1));
  });

  testWidgets('reduced motion removes the line tween', (tester) async {
    await _pumpLine(
      tester,
      current: List<double>.generate(30, (i) => (i % 5).toDouble()),
      previous: List<double>.filled(30, 1),
      disableAnimations: true,
    );
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.duration, Duration.zero);
  });

  testWidgets('the line tween stays on when motion is allowed', (tester) async {
    await _pumpLine(
      tester,
      current: List<double>.generate(30, (i) => (i % 5).toDouble()),
      previous: List<double>.filled(30, 1),
    );
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.duration, const Duration(milliseconds: 150));
  });

  testWidgets('reduced motion removes the bar tween', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: StatsInteractiveBarChart(
              entries: <StatsBarEntry>[
                for (var i = 0; i < 7; i++)
                  StatsBarEntry(
                    bucketStart: DateTime.utc(2026, 10, 1 + i),
                    value: i + 1,
                  ),
              ],
              xLabels: List<String>.generate(7, (i) => 'D$i'),
              barColor: Colors.indigo,
              gridColor: Colors.black12,
              emptyLabel: 'No data yet',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.duration, Duration.zero);
  });

  testWidgets('a sparse series marks its few non-zero points', (tester) async {
    final current = List<double>.filled(30, 0);
    current[29] = 1;
    await _pumpLine(
      tester,
      current: current,
      previous: List<double>.filled(30, 0),
    );
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final line = chart.data.lineBarsData.first;
    expect(line.dotData.show, isTrue);
    expect(line.dotData.checkToShowDot(line.spots[29], line), isTrue);
    expect(line.dotData.checkToShowDot(line.spots[5], line), isFalse);
  });

  testWidgets('a dense series keeps its line without markers', (tester) async {
    final current = List<double>.generate(30, (i) => (i % 4 == 0) ? 0 : 2.0);
    await _pumpLine(
      tester,
      current: current,
      previous: List<double>.filled(30, 1),
    );
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final line = chart.data.lineBarsData.first;
    expect(line.dotData.checkToShowDot(line.spots[1], line), isFalse);
  });
}
