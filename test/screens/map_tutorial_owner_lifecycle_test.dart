import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readNormalized(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('map tutorial owner lifecycle wiring', () {
    test('mobile map tab switch away deactivates tutorial without persisting',
        () {
      final source = _readNormalized('lib/screens/map_screen.dart');

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

    test('mobile map removes build-time tutorial mutation', () {
      final source = _readNormalized('lib/screens/map_screen.dart');

      expect(source, contains('_scheduleMapTutorialConfigure('));
      expect(source, contains('_scheduleMapTutorialStartIfEligible('));
      expect(
        source,
        isNot(contains(
          'final l10n = AppLocalizations.of(context)!;\n'
          '    _mapTutorialCoordinator.configure(',
        )),
      );
    });

    test('desktop map removes build-time tutorial mutation', () {
      final source =
          _readNormalized('lib/screens/desktop/desktop_map_screen.dart');

      expect(source, contains('_scheduleMapTutorialConfigure('));
      expect(source, contains('_scheduleMapTutorialStartIfEligible('));
      expect(
        source,
        isNot(contains(
          'final l10n = AppLocalizations.of(context)!;\n'
          '    _mapTutorialCoordinator.configure(',
        )),
      );
    });

    test('startup gate requires active owner and two stable checks', () {
      final mobile = _readNormalized('lib/screens/map_screen.dart');
      final desktop =
          _readNormalized('lib/screens/desktop/desktop_map_screen.dart');

      for (final source in <String>[mobile, desktop]) {
        expect(
            source, contains('final generation = _mapTutorialOwnerGeneration'));
        expect(source, contains('await WidgetsBinding.instance.endOfFrame'));
        expect(source, contains('second.signature != first.signature'));
        expect(source, contains('_isMapTutorialFirstRectStable('));
        expect(source, contains('hasPersistedSeen()'));
      }
    });

    test('direct map targets suppress automatic tutorial takeover', () {
      final mobile = _readNormalized('lib/screens/map_screen.dart');
      final desktop =
          _readNormalized('lib/screens/desktop/desktop_map_screen.dart');

      for (final source in <String>[mobile, desktop]) {
        expect(source, contains('if (_hasInitialDirectTarget) return;'));
        expect(source, contains('widget.initialMarkerId'));
        expect(source, contains('widget.initialArtworkId'));
        expect(source, contains('widget.initialSubjectId'));
      }
    });

    test('mobile schedules tutorial start only when route and tab are active',
        () {
      final source = _readNormalized('lib/screens/map_screen.dart');

      expect(source, contains('if (!_isRouteVisible) return false;'));
      expect(source, contains('if (!_isMapTabVisible) return false;'));
      expect(source,
          contains('if (_tutorialOverlayController == null) return false;'));
    });

    test('pending tutorial starts are cancelled before mobile owner exit', () {
      final source = _readNormalized('lib/screens/map_screen.dart');
      final generationIndex =
          source.indexOf('_mapTutorialOwnerGeneration += 1;');
      final cancelIndex = source.indexOf('_cancelMapTutorialStartRetry();');
      final deactivateIndex = source.indexOf(
        '_mapTutorialCoordinator.deactivateForOwnerExit(reason: reason);',
      );

      expect(generationIndex, isNonNegative);
      expect(cancelIndex, isNonNegative);
      expect(deactivateIndex, isNonNegative);
      expect(generationIndex, lessThan(deactivateIndex));
      expect(cancelIndex, lessThan(deactivateIndex));
    });

    test('route invisible deactivates before mobile targets can detach', () {
      final source = _readNormalized('lib/screens/map_screen.dart');
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
      final source =
          _readNormalized('lib/screens/desktop/desktop_map_screen.dart');

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

    test('pending tutorial starts are cancelled before desktop owner exit', () {
      final source =
          _readNormalized('lib/screens/desktop/desktop_map_screen.dart');
      final generationIndex =
          source.indexOf('_mapTutorialOwnerGeneration += 1;');
      final cancelIndex = source.indexOf('_cancelMapTutorialStartRetry();');
      final deactivateIndex = source.indexOf(
        '_mapTutorialCoordinator.deactivateForOwnerExit(reason: reason);',
      );

      expect(generationIndex, isNonNegative);
      expect(cancelIndex, isNonNegative);
      expect(deactivateIndex, isNonNegative);
      expect(generationIndex, lessThan(deactivateIndex));
      expect(cancelIndex, lessThan(deactivateIndex));
    });

    test('scope changes deactivate and cancel pending tutorial starts', () {
      final mobile = _readNormalized('lib/screens/map_screen.dart');
      final desktop =
          _readNormalized('lib/screens/desktop/desktop_map_screen.dart');

      expect(
        mobile,
        contains(
            "_deactivateRootTutorialOwner(reason: 'mobile-map-scope-changed')"),
      );
      expect(
        desktop,
        contains(
            "_deactivateRootTutorialOwner(reason: 'desktop-map-scope-changed')"),
      );
    });

    test('readiness failure cannot call maybeStart', () {
      final source = _readNormalized('lib/screens/map_screen.dart');
      final readinessFailureIndex = source.indexOf('if (!first.ready)');
      final retryIndex = source.indexOf(
        '_scheduleMapTutorialStartRetry(reason: first.reason);',
        readinessFailureIndex,
      );
      final maybeStartIndex = source.indexOf(
        '_mapTutorialCoordinator.maybeStart()',
        readinessFailureIndex,
      );

      expect(readinessFailureIndex, isNonNegative);
      expect(retryIndex, isNonNegative);
      expect(maybeStartIndex, isNonNegative);
      expect(retryIndex, lessThan(maybeStartIndex));
    });

    test('desktop shell switch away from Explore deactivates map owner', () {
      final source = _readNormalized('lib/screens/desktop/desktop_shell.dart');

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
      final source = _readNormalized('lib/main_app.dart');

      expect(source, contains("deactivateOwner(\n        'mobile-map'"));
      expect(source, contains("reason: 'mobile-shell-nav-tap'"));
      expect(source, contains("reason: 'mobile-shell-tab-change'"));
    });

    test('overlay geometry is scoped by tutorial session key', () {
      final presenter = _readNormalized(
          'lib/widgets/tutorial/tutorial_overlay_presenter.dart');
      final overlay = _readNormalized(
          'lib/widgets/tutorial/interactive_tutorial_overlay.dart');

      expect(presenter, contains('sessionKey:'));
      expect(presenter, contains('driver.hashCode'));
      expect(overlay, contains('oldWidget.sessionKey != widget.sessionKey'));
      expect(overlay, contains('_clearCachedGeometry();'));
    });
  });
}
