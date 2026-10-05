import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/common/kubus_stat_card.dart';
import 'package:art_kubus/widgets/dao/dao_metric_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _metrics = <DaoMetric>[
  DaoMetric(
    title: 'Your voting power',
    value: '1284.50 KUB8',
    icon: Icons.how_to_vote_outlined,
  ),
  DaoMetric(title: 'Active proposals', value: '3', icon: Icons.ballot_outlined),
  DaoMetric(title: 'Delegates', value: '12', icon: Icons.groups_outlined),
];

Widget _harness(double width, {double textScale = 1}) => MaterialApp(
      theme:
          ThemeData.dark().copyWith(extensions: const [KubusColorRoles.dark]),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: const DaoMetricStrip(metrics: _metrics),
              ),
            ),
          ),
        ),
      ),
    );

List<Rect> _tiles(WidgetTester tester) => tester
    .widgetList(find.byType(KubusStatCard))
    .map((w) => tester.getRect(find.byWidget(w)))
    .toList();

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1600, 1200);
    view.devicePixelRatio = 1;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('desktop: one balanced row', (tester) async {
    await tester.pumpWidget(_harness(1100));
    final tiles = _tiles(tester);
    expect(tiles, hasLength(3));
    expect(tiles.map((r) => r.top).toSet(), hasLength(1));
    expect((tiles[0].width - tiles[2].width).abs(), lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet: still one row at 768', (tester) async {
    await tester.pumpWidget(_harness(736));
    final tiles = _tiles(tester);
    expect(tiles.map((r) => r.top).toSet(), hasLength(1));
  });

  testWidgets('phone: voting power full width, the rest share a row',
      (tester) async {
    await tester.pumpWidget(_harness(358));
    final tiles = _tiles(tester);
    expect(tiles[0].width, closeTo(358, 1));
    expect(tiles[1].top, tiles[2].top);
    expect(tiles[1].top, greaterThan(tiles[0].bottom));
    for (final tile in tiles) {
      expect(tile.right, lessThanOrEqualTo(358.5), reason: 'no h-overflow');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('200% text grows the tiles instead of clipping', (tester) async {
    for (final width in <double>[358, 736, 1100]) {
      await tester.pumpWidget(_harness(width, textScale: 2));
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
  });

  testWidgets('every tile is expressive with its own glyph', (tester) async {
    await tester.pumpWidget(_harness(1100));
    for (final card
        in tester.widgetList<KubusStatCard>(find.byType(KubusStatCard))) {
      expect(card.expressive, isTrue);
      expect(card.icon, isNotNull);
      expect(
          card.minHeight, greaterThanOrEqualTo(DaoMetricStrip.minTileHeight));
    }
  });
}
