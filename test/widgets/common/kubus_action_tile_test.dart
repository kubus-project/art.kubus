import 'package:art_kubus/widgets/common/kubus_action_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _longTitle =
    'Institucionalno središče za razstave, dogodke in sodelovanje';

Widget _app(Widget child, {double textScale = 1}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(1440, 900),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: child),
      ),
    );

KubusActionTile _tile(
  String title, {
  KubusActionTileLayout layout = KubusActionTileLayout.inline,
}) =>
    KubusActionTile(
      title: title,
      icon: Icons.map_outlined,
      accent: const Color(0xFF14B8A6),
      onTap: () {},
      layout: layout,
    );

/// The desktop Home "recorded quick actions" geometry: a horizontal scroll
/// view gives its Row, and so every tile, an unbounded width.
Widget _scrollingStrip(List<String> titles) => Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final title in titles)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _tile(title),
              ),
          ],
        ),
      ),
    );

double _maxInlineWidth(double textScale) =>
    TextScaler.linear(textScale).scale(KubusActionTile.inlineMaxWidth);

void main() {
  group('KubusActionTile.inline under an unbounded width', () {
    testWidgets('lays out in a horizontal scroll row', (tester) async {
      await tester.pumpWidget(
        _app(_scrollingStrip(const ['Map', 'Studio', 'Achievements'])),
      );
      expect(tester.takeException(), isNull);

      final tiles = find.byType(KubusActionTile);
      expect(tiles, findsNWidgets(3));
      for (final element in tiles.evaluate()) {
        final width = tester.getSize(find.byWidget(element.widget)).width;
        expect(width.isFinite, isTrue);
        expect(width, lessThanOrEqualTo(_maxInlineWidth(1)));
      }
      // Short titles stay content-sized rather than stretching to the cap.
      expect(
        tester.getSize(find.byType(KubusActionTile).first).width,
        lessThan(_maxInlineWidth(1)),
      );
    });

    for (final scale in const [1.0, 2.0]) {
      testWidgets('long title wraps inside the cap at ${scale}x text',
          (tester) async {
        await tester.pumpWidget(
          _app(_scrollingStrip(const [_longTitle, 'Map']), textScale: scale),
        );
        expect(tester.takeException(), isNull);

        final tile = find.widgetWithText(KubusActionTile, _longTitle);
        final size = tester.getSize(tile);
        expect(size.width, moreOrLessEquals(_maxInlineWidth(scale)));

        final title = find.descendant(
          of: tile,
          matching: find.text(_longTitle),
        );
        final paragraph = tester.renderObject<RenderParagraph>(title);
        final lineHeight = paragraph.preferredLineHeight;
        expect(
          tester.getSize(title).height,
          greaterThan(lineHeight * 1.5),
          reason: 'the title wraps to a second line',
        );
        expect(tester.getSize(title).height, lessThan(lineHeight * 2.5));
      });
    }
  });

  group('KubusActionTile under finite constraints is unchanged', () {
    testWidgets('inline tile fills a fixed-width slot', (tester) async {
      await tester.pumpWidget(_app(Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 208, child: _tile(_longTitle)),
      )));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KubusActionTile)).width, 208);
    });

    testWidgets('stacked tile ignores the inline cap', (tester) async {
      await tester.pumpWidget(_app(Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          child: _tile(_longTitle, layout: KubusActionTileLayout.stacked),
        ),
      )));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KubusActionTile)).width, 400);
    });
  });
}
