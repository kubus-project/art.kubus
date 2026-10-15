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
    applied.complete(
        ml.CircleLayerProperties.fromJson(properties.toJson(skipNulls: false)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CoverStyleController implements ml.MapLibreMapController {
  final layers = <String, ml.SymbolLayerProperties>{};
  final updates = <Map<String, dynamic>>[];
  final snapshots = <String, Map<String, dynamic>>{};
  final completed = Completer<void>();
  @override
  Future<void> setLayerProperties(
      String id, ml.LayerProperties properties) async {
    final values = properties.toJson(skipNulls: false);
    updates.add(values);
    snapshots[id] = {...?snapshots[id], ...values};
    layers[id] = ml.SymbolLayerProperties.fromJson(snapshots[id]!);
    if (id == 'marker_cover' && !completed.isCompleted) completed.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
      'ambient ticks send only changed paint and replay layout after style reset',
      () async {
    final controller = _CoverStyleController();
    final styler = KubusMarkerLayerStyler();
    var epoch = 1;
    void update(double bob) => styler.requestUpdate(
          controller: controller,
          styleInitialized: true,
          styleEpoch: epoch,
          getCurrentStyleEpoch: () => epoch,
          managedLayerIds: {'marker', 'cube', 'marker_cover'},
          markerLayerId: 'marker',
          cubeIconLayerId: 'cube',
          force: true,
          state: KubusMarkerLayerStyleState(
              pressedMarkerId: null,
              hoveredMarkerId: null,
              selectedMarkerId: 'selected',
              selectionPopAnimationValue: 0,
              cubeLayerVisible: false,
              markerBadgeBobOffsetPx: bob),
        );
    update(2);
    await controller.completed.future;
    await Future<void>.delayed(Duration.zero);
    expect(
        controller.updates
            .every((patch) => patch.values.every((value) => value != null)),
        isTrue,
        reason: 'SDK skipNulls:false must not reset unrequested properties');
    final before = controller.updates.length;
    update(4);
    await Future<void>.delayed(Duration.zero);
    final paintPatches = controller.updates.skip(before).toList();
    expect(paintPatches, hasLength(3));
    for (final patch in paintPatches) {
      expect(patch.keys, ['icon-translate']);
      expect(patch['icon-translate'], <Object>[0.0, 4.0]);
    }
    final settled = controller.updates.length;
    update(4);
    await Future<void>.delayed(Duration.zero);
    expect(controller.updates.length, settled,
        reason: 'unchanged frames write nothing');
    epoch = 2;
    update(4);
    await Future<void>.delayed(Duration.zero);
    expect(controller.updates.last, contains('icon-image'),
        reason: 'a new style needs its complete layout again');
  });
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
      expect(cover.iconTranslate, canonical.iconTranslate);
      expect(cover.iconTranslate, <Object>[0.0, 2.0]);
      expect(cover.iconTranslateAnchor, 'viewport');
      expect(cover.iconOffset,
          cubeVisible ? <Object>[0.0, -42.0] : <Object>[0.0, 0.0],
          reason: 'ambient bob must never invalidate symbol layout');
      expect(cover.iconAnchor, canonical.iconAnchor);
      expect(cover.iconRotationAlignment, canonical.iconRotationAlignment);
      expect(cover.iconImage.toString(), contains('coverIconSelected'));
      expect((cover.iconOpacity as List).first, 'interpolate');
      expect(cover.iconOpacity.toString(), contains('coverReveal'));
      expect(cover.iconOpacity.toString(), contains('entryOpacity'));
    }
  });
  test('accuracy stays static across decorative pulse phases', () async {
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
      expect(properties.circleOpacity, 0.12);
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
