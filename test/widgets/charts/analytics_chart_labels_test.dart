import 'package:art_kubus/widgets/charts/stats_interactive_bar_chart.dart';
import 'package:art_kubus/widgets/charts/stats_interactive_line_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _emptyLabel = 'No data yet';

/// Unique, short labels so every painted label can be found by its text.
List<String> _labels(int count) => List<String>.generate(count, (i) => 'D$i');

Future<void> _pumpLine(
  WidgetTester tester,
  Size size,
  List<double> values,
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
          child: StatsInteractiveLineChart(
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
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpBars(
  WidgetTester tester,
  Size size,
  List<int> values,
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
          child: StatsInteractiveBarChart(
            entries: <StatsBarEntry>[
              for (var i = 0; i < values.length; i++)
                StatsBarEntry(
                  bucketStart: DateTime.utc(2026, 10, 1 + i),
                  value: values[i],
                ),
            ],
            xLabels: _labels(values.length),
            barColor: Colors.indigo,
            gridColor: Colors.black12,
            emptyLabel: _emptyLabel,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Painted x labels, left to right, and asserts none of them overlap.
List<String> _paintedInOrder(WidgetTester tester, List<String> labels) {
  final painted = <(String, Rect)>[
    for (final label in labels)
      if (find.text(label).evaluate().isNotEmpty)
        (label, tester.getRect(find.text(label))),
  ]..sort((a, b) => a.$2.left.compareTo(b.$2.left));
  for (var i = 1; i < painted.length; i++) {
    expect(
      painted[i].$2.left,
      greaterThanOrEqualTo(painted[i - 1].$2.right),
      reason: '${painted[i - 1].$1} overlaps ${painted[i].$1}',
    );
  }
  return painted.map((entry) => entry.$1).toList(growable: false);
}

void main() {
  for (final width in const <double>[320, 390, 820, 1024, 1440, 1920]) {
    for (final count in const <int>[7, 30, 90, 52]) {
      testWidgets(
          'line x labels never overlap and end on the newest day '
          '($count points at ${width.round()} px)', (tester) async {
        final values =
            List<double>.generate(count, (i) => (i % 5).toDouble() + 1);
        await _pumpLine(tester, Size(width, 844), values);

        final painted = _paintedInOrder(tester, _labels(count));
        expect(painted, isNotEmpty);
        expect(painted.last, 'D${count - 1}',
            reason: 'newest bucket must carry a label');
      });

      testWidgets(
          'bar x labels never overlap and end on the newest day '
          '($count bars at ${width.round()} px)', (tester) async {
        final values = List<int>.generate(count, (i) => (i % 5) + 1);
        await _pumpBars(tester, Size(width, 844), values);

        final painted = _paintedInOrder(tester, _labels(count));
        expect(painted, isNotEmpty);
        expect(painted.last, 'D${count - 1}',
            reason: 'newest bucket must carry a label');
      });
    }
  }

  testWidgets('a single point keeps its x label', (tester) async {
    await _pumpLine(tester, const Size(390, 844), const <double>[42]);

    expect(find.text('D0'), findsOneWidget);
  });
}
