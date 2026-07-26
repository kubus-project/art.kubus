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

    test('marker preview uses the live anchored standard card', () {
      expect(
        source,
        contains('KubusMarkerOverlayPlacementStrategy.anchored'),
      );
      final overlayStart = source.indexOf('Widget _buildMarkerOverlay(');
      final rippleStart = source.indexOf(
        'Widget _buildMarkerTapRipple()',
        overlayStart,
      );
      final overlaySource = source.substring(overlayStart, rippleStart);
      expect(overlaySource, isNot(contains('bottomDocked')));
      expect(overlaySource, isNot(contains('compactMobile')));
      expect(overlaySource, contains('_selectedMarkerAnchorNotifier'));
      expect(overlaySource, contains('estimateCardHeight'));
    });

    test('composition is one-shot, lower-third, and walking isolated', () {
      expect(
        source,
        contains(
          'verticalComposition: '
          'MapMarkerOverlayVerticalComposition.lowerThird',
        ),
      );
      expect(source, contains('_lastCorrectedMarkerOverlayLayoutRevision'));
      expect(source, contains('_markerCompositionInFlightToken'));
      expect(source, contains('if (_isWalkingFocusedMode)'));
      expect(
        source,
        contains('_kubusMapController.queueOverlayAnchorRefresh(force: true)'),
      );
    });

    test('target acknowledgement is token-bound and follows final layout', () {
      final handlerStart =
          source.indexOf('void _handleMarkerOverlayLayoutResolved(');
      final nextMethod = source.indexOf(
        'void _acknowledgeMarkerOverlay(',
        handlerStart,
      );
      final handler = source.substring(handlerStart, nextMethod);
      expect(handler, contains('_awaitingFinalMarkerLayoutToken'));
      expect(handler, contains('_acknowledgeMarkerOverlay(selection)'));
      expect(
        source,
        contains('selectionToken: selection.selectionToken'),
      );
    });

    test('passive chrome is independently geometry-gated', () {
      expect(source, contains('plan.searchOccluded'));
      expect(source, contains('plan.discoveryOccluded'));
      expect(source, contains('plan.controlsOccluded'));
      expect(source, contains('plan.nearbyOccluded'));
      expect(source, contains('_rectInMapViewport(_searchSurfaceKey)'));
      expect(source, contains('_rectInMapViewport(_discoveryCardKey)'));
      expect(source, contains('_rectInMapViewport(_primaryControlsKey)'));
      expect(source, contains('_rectInMapViewport(_nearbyPeekKey)'));
    });

    test('search camera settles before marker selection', () {
      final searchStart = source.indexOf(
        'Future<void> _handleSearchResultTap(',
      );
      final searchEnd = source.indexOf(
        'ArtMarker? _findLoadedMarkerForSearchResult',
        searchStart,
      );
      final searchHandler = source.substring(searchStart, searchEnd);
      expect(
        searchHandler,
        contains('await _kubusMapController.animateTo('),
      );
      expect(
        searchHandler,
        isNot(contains('unawaited(\n        _kubusMapController.animateTo(')),
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
