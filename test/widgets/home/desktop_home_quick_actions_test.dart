import 'package:art_kubus/screens/desktop/desktop_home_screen.dart';
import 'package:art_kubus/widgets/common/kubus_action_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/product_surface_harness.dart';
import '../../support/product_v5_qa_fixtures.dart';

/// A returning desktop user: recorded quick actions render as inline tiles in
/// the horizontal scroll strip (unbounded width per tile).
void main() {
  const visited = <String>[
    'map',
    'community',
    'marketplace',
    'achievements',
    'dao_hub',
    'studio',
    'institution_hub',
  ];

  for (final scenario in const <(String, Locale, double)>[
    ('en 1x', Locale('en'), 1.0),
    ('sl 2x text', Locale('sl'), 2.0),
  ]) {
    testWidgets('desktop Home recorded quick actions lay out (${scenario.$1})',
        (tester) async {
      final prior = FlutterError.onError;
      final errors = await pumpProductSurface(
        tester,
        child: qaShellHost(const DesktopHomeScreen()),
        // Tall enough that the lazily built quick-actions section is laid
        // out at 2x text too.
        size: const Size(1440, 4000),
        locale: scenario.$2,
        textScale: scenario.$3,
        signedInProfile: qaOwner(),
        extraProviders: [qaNavigationWithVisits(visited)],
      );
      final tiles = find.byWidgetPredicate((widget) =>
          widget is KubusActionTile &&
          widget.layout == KubusActionTileLayout.inline);
      final tileCount = tiles.evaluate().length;
      final cap =
          TextScaler.linear(scenario.$3).scale(KubusActionTile.inlineMaxWidth);
      final widths = [
        for (var i = 0; i < tileCount; i++) tester.getSize(tiles.at(i)).width,
      ];
      // Hand error reporting back before expecting: a failing expect while
      // the harness hook collects errors would hang the test.
      FlutterError.onError = prior;
      expect(errors, isEmpty, reason: errors.join(' | '));
      expect(tileCount, visited.length);
      for (final width in widths) {
        expect(width, lessThanOrEqualTo(cap + 0.5));
      }
    });
  }
}
