import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('map tutorial owner lifecycle wiring', () {
    test('mobile map tab switch away deactivates tutorial without persisting',
        () {
      final source = File('lib/screens/map_screen.dart').readAsStringSync();

      expect(
        source,
        contains(
          "_deactivateRootTutorialOwner(reason: 'mobile-map-tab-hidden')",
        ),
      );
      expect(
        source,
        contains(
          "_deactivateRootTutorialOwner(reason: 'mobile-map-route-hidden')",
        ),
      );
      expect(
        source,
        contains("_deactivateRootTutorialOwner(reason: 'mobile-map-dispose')"),
      );
      expect(
        source,
        isNot(contains(
          "_mapTutorialCoordinator.dismiss();\n"
          "    _tutorialOverlayController?.unbindDriver",
        )),
      );
    });

    test('route invisible deactivates before mobile targets can detach', () {
      final source = File('lib/screens/map_screen.dart').readAsStringSync();
      final routeHiddenIndex = source.indexOf(
        "_deactivateRootTutorialOwner(reason: 'mobile-map-route-hidden')",
      );
      final routeVisibleAssignIndex = source.indexOf(
        '_isRouteVisible = isVisible;',
        routeHiddenIndex,
      );

      expect(routeHiddenIndex, isNonNegative);
      expect(routeVisibleAssignIndex, isNonNegative);
      expect(routeHiddenIndex, lessThan(routeVisibleAssignIndex));
    });

    test('desktop map route switch deactivates tutorial without persisting',
        () {
      final source = File('lib/screens/desktop/desktop_map_screen.dart')
          .readAsStringSync();

      expect(
        source,
        contains(
          "_deactivateRootTutorialOwner(reason: 'desktop-map-route-hidden')",
        ),
      );
      expect(
        source,
        contains(
          "_deactivateRootTutorialOwner(reason: 'desktop-map-dispose')",
        ),
      );
    });

    test('desktop shell switch away from Explore deactivates map owner', () {
      final source = File('lib/screens/desktop/desktop_shell.dart')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');

      expect(source, contains("deactivateOwner(\n      'desktop-explore-map'"));
      expect(
        source,
        contains(
            "_deactivateExploreTutorial(reason: 'desktop-shell-nav-change')"),
      );
      expect(
        source,
        contains(
            "_deactivateExploreTutorial(reason: 'desktop-shell-route-change')"),
      );
    });

    test('mobile shell switch away from map deactivates map owner', () {
      final source =
          File('lib/main_app.dart').readAsStringSync().replaceAll('\r\n', '\n');

      expect(source, contains("deactivateOwner(\n        'mobile-map'"));
      expect(source, contains("reason: 'mobile-shell-nav-tap'"));
      expect(source, contains("reason: 'mobile-shell-tab-change'"));
    });
  });
}
