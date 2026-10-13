import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:flutter_test/flutter_test.dart';

import 'package:art_kubus/features/map/map_layers_manager.dart';
import 'package:art_kubus/widgets/map_marker_style_config.dart';

class _AccuracyStyleController implements ml.MapLibreMapController {
  final applied = Completer<ml.CircleLayerProperties>();
  @override
  Future<void> setLayerProperties(
      String id, ml.LayerProperties properties) async {
    applied.complete(properties as ml.CircleLayerProperties);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CoverStyleController implements ml.MapLibreMapController {
  final layers = <String, ml.SymbolLayerProperties>{};
  final completed = Completer<void>();
  @override
  Future<void> setLayerProperties(
      String id, ml.LayerProperties properties) async {
    layers[id] = properties as ml.SymbolLayerProperties;
    if (id == 'marker_cover') completed.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('cover paint follows selected badge geometry in 2D and 3D', () async {
    for (final cubeVisible in <bool>[false, true]) {
      final controller = _CoverStyleController();
      KubusMarkerLayerStyler().requestUpdate(
        controller: controller,
        styleInitialized: true,
        styleEpoch: 1,
        getCurrentStyleEpoch: () => 1,
        managedLayerIds: {'marker', 'cube', 'marker_cover'},
        markerLayerId: 'marker',
        cubeIconLayerId: 'cube',
        force: true,
        state: KubusMarkerLayerStyleState(
            pressedMarkerId: null,
            hoveredMarkerId: null,
            selectedMarkerId: 'selected',
            selectionPopAnimationValue: 0.6,
            cubeLayerVisible: cubeVisible,
            markerBadgeBobOffsetPx: 2),
      );
      await controller.completed.future.timeout(const Duration(seconds: 10));
      final cover = controller.layers['marker_cover']!;
      final canonical = controller.layers[cubeVisible ? 'cube' : 'marker']!;
      expect(cover.iconSize, canonical.iconSize);
      expect(cover.iconOffset, canonical.iconOffset);
      expect(cover.iconAnchor, canonical.iconAnchor);
      expect(cover.iconRotationAlignment, canonical.iconRotationAlignment);
      expect(cover.iconImage.toString(), contains('coverIconSelected'));
      expect((cover.iconOpacity as List).first, 'interpolate');
      expect(cover.iconOpacity.toString(), contains('coverReveal'));
      expect(cover.iconOpacity.toString(), contains('entryOpacity'));
    }
  });
  test('accuracy animation preserves geometry and theme in every paint update',
      () async {
    for (final phase in <double>[0, 0.5]) {
      final controller = _AccuracyStyleController();
      KubusMarkerLayerStyler().requestUpdate(
        controller: controller,
        styleInitialized: true,
        styleEpoch: 1,
        getCurrentStyleEpoch: () => 1,
        managedLayerIds: <String>{'accuracy'},
        markerLayerId: 'marker',
        cubeIconLayerId: 'cube',
        locationAccuracyLayerId: 'accuracy',
        state: KubusMarkerLayerStyleState(
          pressedMarkerId: null,
          hoveredMarkerId: null,
          selectedMarkerId: null,
          selectionPopAnimationValue: 0,
          cubeLayerVisible: false,
          markerPulsePhase: phase,
          locationAccentColor: const Color(0xff00766a),
        ),
        force: true,
      );
      final properties =
          await controller.applied.future.timeout(const Duration(seconds: 10));
      expect(properties.circleRadius, isNotNull);
      expect(properties.circleColor, '#00766a');
      expect(properties.circleStrokeColor, '#00766a');
      expect(properties.circleStrokeWidth, 1);
      expect(properties.circlePitchAlignment, 'map');
      expect(properties.circleOpacity, phase == 0 ? 0.10 : 0.18);
    }
  });
  group('KubusMarkerLayerStyler', () {
    test('interactiveIconImageExpression uses base icon when no selection', () {
      const state = KubusMarkerLayerStyleState(
        pressedMarkerId: null,
        hoveredMarkerId: null,
        selectedMarkerId: null,
        selectionPopAnimationValue: 0.0,
        cubeLayerVisible: false,
      );

      final expr = KubusMarkerLayerStyler.interactiveIconImageExpression(state);
      expect(expr, equals(const <Object>['get', 'icon']));
    });

    test('interactiveIconImageExpression switches for selected id', () {
      const state = KubusMarkerLayerStyleState(
        pressedMarkerId: null,
        hoveredMarkerId: null,
        selectedMarkerId: 'm1',
        selectionPopAnimationValue: 0.0,
        cubeLayerVisible: false,
      );

      final expr = KubusMarkerLayerStyler.interactiveIconImageExpression(state);
      expect(
        expr,
        equals(<Object>[
          'case',
          <Object>[
            '==',
            <Object>['id'],
            'm1'
          ],
          const <Object>['get', 'iconSelected'],
          const <Object>['get', 'icon'],
        ]),
      );
    });

    test('interactiveIconSizeExpression matches base expression when idle', () {
      const state = KubusMarkerLayerStyleState(
        pressedMarkerId: null,
        hoveredMarkerId: null,
        selectedMarkerId: null,
        selectionPopAnimationValue: 0.0,
        cubeLayerVisible: false,
      );

      final expr = KubusMarkerLayerStyler.interactiveIconSizeExpression(state);
      expect(
        expr,
        equals(
          MapMarkerStyleConfig.iconSizeExpression(
            constantScale: 1.0,
            multiplier: <Object>[
              'coalesce',
              <Object>['get', 'entryScale'],
              1.0,
            ],
          ),
        ),
      );
    });

    test('interactiveIconSizeExpression encodes interaction multiplier', () {
      const state = KubusMarkerLayerStyleState(
        pressedMarkerId: 'p',
        hoveredMarkerId: 'h',
        selectedMarkerId: 's',
        // t=0 -> sin(0)=0 -> pop=1.0
        selectionPopAnimationValue: 0.0,
        cubeLayerVisible: false,
      );

      final expr = KubusMarkerLayerStyler.interactiveIconSizeExpression(state);
      expect(expr, isA<List<Object>>());

      final list = expr as List<Object>;
      expect(list.first, equals('interpolate'));

      // Stop value at minZoom is of the form: ['*', <double>, <multiplier>]
      final stopValue = list[4];
      expect(stopValue, isA<List<Object>>());

      final stopList = stopValue as List<Object>;
      expect(stopList[0], equals('*'));
      expect(stopList[2], isA<List<Object>>());

      final multiplier = stopList[2] as List<Object>;
      expect(
        multiplier,
        equals(<Object>[
          '*',
          <Object>[
            'case',
            <Object>[
              '==',
              <Object>['id'],
              'p'
            ],
            MapMarkerStyleConfig.pressedScaleFactor,
            <Object>[
              '==',
              <Object>['id'],
              's'
            ],
            1.0,
            <Object>[
              '==',
              <Object>['id'],
              'h'
            ],
            MapMarkerStyleConfig.hoverScaleFactor,
            1.0,
          ],
          <Object>[
            'coalesce',
            <Object>['get', 'entryScale'],
            1.0,
          ],
        ]),
      );
    });
  });
}
