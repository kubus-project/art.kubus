import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/map_screen.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
  });

  group('mobile map dominant-surface integration', () {
    test('projects filters and discovery directly from coordinator state', () {
      expect(source, isNot(contains('bool _filtersExpanded')));
      expect(source, isNot(contains('bool _isDiscoveryExpanded')));
      expect(
        source,
        contains(
          '_mapUiStateCoordinator.value.contextSurface ==\n'
          '              MapContextSurface.filters',
        ),
      );
      expect(
        source,
        contains(
          '_mapUiStateCoordinator.value.contextSurface ==\n'
          '          MapContextSurface.discovery',
        ),
      );
    });

    test('search results suspend and restore the dominant surface', () {
      expect(
        source,
        contains('MapContextSurface.searchResults,\n'
            '          intent: MapSurfaceTransitionIntent.suspendCurrent'),
      );
      expect(source, contains('onDismiss: _dismissSearchResults'));
      expect(source, contains('restoreSuspendedSurface()'));
    });

    test('marker preview is conditionally mounted from coordinator state', () {
      expect(
        source,
        matches(
          RegExp(
            r'if \(ui\.contextSurface == MapContextSurface\.markerPreview\)\s+'
            r'_buildMarkerOverlay',
          ),
        ),
      );
    });

    test('nearby extent sync cannot reopen during programmatic collapse', () {
      expect(source, contains('_suppressNearbySurfaceSync'));
      expect(source, contains('if (_suppressNearbySurfaceSync) return;'));
      expect(
        source,
        contains('MapContextSurface.nearby,\n'
            '        intent: MapSurfaceTransitionIntent.suspendCurrent'),
      );
      expect(
        source,
        contains('_sheetController.animateTo(\n'
            '          _nearbySheetMin'),
      );
    });

    test('create marker becomes dominant only after prerequisites', () {
      final walletGuard =
          source.indexOf('if (wallet == null || wallet.isEmpty)');
      final begin =
          source.indexOf('_mapUiStateCoordinator.beginCreateMarker()');
      final dialog = source.indexOf('result = await MapMarkerDialog.show(');
      final close = source.indexOf(
        '_mapUiStateCoordinator.closeSurface(MapContextSurface.createMarker)',
      );

      expect(walletGuard, greaterThanOrEqualTo(0));
      expect(begin, greaterThan(walletGuard));
      expect(dialog, greaterThan(begin));
      expect(close, greaterThan(dialog));
      expect(source, isNot(contains('bool _isCreateMarkerFlowActive')));
    });

    test('tutorial state is mirrored and background taps clear context', () {
      expect(
        source,
        contains(
          '_mapTutorialCoordinator.addListener(_handleMapTutorialStateChanged)',
        ),
      );
      expect(source, contains('_mapUiStateCoordinator.setTutorial('));
      expect(source,
          contains('onBackgroundTap: () {\n        _dismissMapContext();'));
      expect(source, contains('_mapUiStateCoordinator.dismissToMap('));
    });
  });
}
