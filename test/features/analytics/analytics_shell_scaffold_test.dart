import 'package:art_kubus/features/analytics/widgets/analytics_shell_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildHarness(double width) {
    return MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 900)),
        child: AnalyticsShellScaffold(
          embedded: false,
          header: const SizedBox(height: 72, child: Text('Header')),
          filterBar: const SizedBox(height: 72, child: Text('Filters')),
          overview: const SizedBox(height: 80, child: Text('Overview')),
          trend: const SizedBox(height: 120, child: Text('Trend')),
          insights: const SizedBox(height: 80, child: Text('Insights')),
          comparison: const SizedBox(height: 80, child: Text('Compare')),
        ),
      ),
    );
  }

  testWidgets('analytics shell renders core sections on mobile',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildHarness(390));

    expect(find.text('Header'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Trend'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Compare'), findsOneWidget);
  });

  testWidgets('analytics shell keeps desktop rail readable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildHarness(1280));

    final trendBox = tester.renderObject<RenderBox>(find.text('Trend'));
    final insightsBox = tester.renderObject<RenderBox>(find.text('Insights'));

    expect(trendBox.localToGlobal(Offset.zero).dx,
        lessThan(insightsBox.localToGlobal(Offset.zero).dx));
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Compare'), findsOneWidget);
  });
}
