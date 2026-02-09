import 'package:flutter_test/flutter_test.dart';

import 'package:art_kubus/features/map/map_layers_manager.dart';
import 'package:art_kubus/widgets/map_marker_style_config.dart';

void main() {
  group('KubusMarkerLayerStyler', () {
    test('interactiveIconImageExpression uses base icon when no selection', () {
      const state = KubusMarkerLayerStyleState(
        pressedMarkerId: null,
        hoveredMarkerId: null,
        selectedMarkerId: null,
        selectionPopAnimationValue: 0.0,
        cubeLayerVisible: false,
        cubeIconSpinDegrees: 0.0,
        cubeIconBobOffsetEm: 0.0,
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
        cubeIconSpinDegrees: 0.0,
        cubeIconBobOffsetEm: 0.0,
      );

      final expr = KubusMarkerLayerStyler.interactiveIconImageExpression(state);
      expect(
        expr,
        equals(<Object>[
          'case',
          <Object>['==', <Object>['id'], 'm1'],
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
        cubeIconSpinDegrees: 0.0,
        cubeIconBobOffsetEm: 0.0,
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
        cubeIconSpinDegrees: 0.0,
        cubeIconBobOffsetEm: 0.0,
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
            <Object>['==', <Object>['id'], 'p'],
            MapMarkerStyleConfig.pressedScaleFactor,
            <Object>['==', <Object>['id'], 's'],
            1.0,
            <Object>['==', <Object>['id'], 'h'],
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
