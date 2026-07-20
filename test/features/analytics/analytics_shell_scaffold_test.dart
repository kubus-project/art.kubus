import 'package:art_kubus/features/analytics/widgets/analytics_shell_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildHarness({
    required double width,
    double textScale = 1.0,
    bool embedded = false,
    Widget? filterSummary,
  }) {
    return MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(textScale),
        ),
        child: AnalyticsShellScaffold(
          embedded: embedded,
          header: const SizedBox(height: 72, child: Text('Header')),
          filterBar: const SizedBox(height: 64, child: Text('Filters')),
          filterSummary:
              filterSummary ?? const SizedBox(child: Text('Summary')),
          overview: const SizedBox(height: 80, child: Text('Overview')),
          trend: const SizedBox(height: 120, child: Text('Trend')),
          insights: const SizedBox(height: 80, child: Text('Insights')),
          comparison: const SizedBox(height: 80, child: Text('Compare')),
        ),
      ),
    );
  }

  testWidgets('mobile shell pins the filter summary, not the toolbar',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildHarness(width: 390));

    expect(find.text('Header'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Filters'), findsNothing);
    expect(find.byType(SliverPersistentHeader), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Trend'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Compare'), findsOneWidget);
  });

  testWidgets('mobile summary survives large text scale without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      buildHarness(
        width: 390,
        textScale: 1.6,
        filterSummary: const Text(
          'Zelo dolga slovenska oznaka izbrane metrike – Prejeti ogledi',
          maxLines: 2,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('Zelo dolga slovenska oznaka'),
      findsOneWidget,
    );
  });

  testWidgets('desktop shell renders the toolbar unpinned with the rail',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildHarness(width: 1280));

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Summary'), findsNothing);
    expect(find.byType(SliverPersistentHeader), findsNothing);

    final trendBox = tester.renderObject<RenderBox>(find.text('Trend'));
    final insightsBox = tester.renderObject<RenderBox>(find.text('Insights'));
    expect(trendBox.localToGlobal(Offset.zero).dx,
        lessThan(insightsBox.localToGlobal(Offset.zero).dx));
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Compare'), findsOneWidget);
  });

  testWidgets('embedded shell keeps the responsive filter composition',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildHarness(width: 390, embedded: true));

    expect(find.byType(Scaffold), findsNothing);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
  });
}
