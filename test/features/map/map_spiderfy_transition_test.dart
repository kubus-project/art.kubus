import 'package:art_kubus/features/map/controller/kubus_map_controller.dart';
import 'package:art_kubus/features/map/map_layers_manager.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const origin = LatLng(46.056946, 14.505751);
  const radialA = LatLng(46.0572, 14.5054);
  const radialB = LatLng(46.0567, 14.5061);

  test('expansion interpolates from anchor to retained radial targets', () {
    final transition = KubusSpiderfyPositionTransition(
      startedAtMs: 1000,
      durationMs: 280,
      startPositions: const <String, LatLng>{
        'a': origin,
        'b': origin,
      },
      targetPositions: const <String, LatLng>{
        'a': radialA,
        'b': radialB,
      },
      finalPositions: const <String, LatLng>{
        'a': radialA,
        'b': radialB,
      },
      coordinateKeyAfterCompletion: 'same-location',
      curve: Curves.linear,
    );

    expect(transition.positionsAtMs(1000)['a'], origin);
    final halfway = transition.positionsAtMs(1140);
    expect(halfway['a']!.latitude, closeTo(46.057073, 0.0000001));
    expect(halfway['a']!.longitude, closeTo(14.5055755, 0.0000001));
    expect(transition.positionsAtMs(1280)['a'], radialA);
    expect(transition.isCompleteAtMs(1279), isFalse);
    expect(transition.isCompleteAtMs(1280), isTrue);
  });

  test('collapse can reverse from an interrupted expansion without a jump', () {
    final expansion = KubusSpiderfyPositionTransition(
      startedAtMs: 0,
      durationMs: 280,
      startPositions: const <String, LatLng>{'a': origin},
      targetPositions: const <String, LatLng>{'a': radialA},
      finalPositions: const <String, LatLng>{'a': radialA},
      coordinateKeyAfterCompletion: 'same-location',
      curve: Curves.linear,
    );
    final interrupted = expansion.positionsAtMs(112);
    final collapse = KubusSpiderfyPositionTransition(
      startedAtMs: 112,
      durationMs: 280,
      startPositions: interrupted,
      targetPositions: const <String, LatLng>{'a': origin},
      finalPositions: const <String, LatLng>{},
      coordinateKeyAfterCompletion: null,
      curve: Curves.linear,
    );

    expect(collapse.positionsAtMs(112)['a'], interrupted['a']);
    expect(collapse.positionsAtMs(392)['a'], origin);
    expect(collapse.finalPositions, isEmpty);
    expect(collapse.coordinateKeyAfterCompletion, isNull);
  });

  test('zero-duration reduced motion resolves directly to final positions', () {
    final transition = KubusSpiderfyPositionTransition(
      startedAtMs: 50,
      durationMs: 0,
      startPositions: const <String, LatLng>{'a': origin},
      targetPositions: const <String, LatLng>{'a': radialA},
      finalPositions: const <String, LatLng>{'a': radialA},
      coordinateKeyAfterCompletion: 'same-location',
    );

    expect(transition.progressAtMs(50), 1);
    expect(transition.positionsAtMs(50)['a'], radialA);
    expect(transition.isCompleteAtMs(50), isTrue);
  });

  test('controller exposes reduced-motion and timer lifecycle state', () {
    final controller = KubusMapController(
      ids: const KubusMapControllerIds(
        layers: MapLayersIds(
          markerSourceId: 'markers',
          markerLayerId: 'marker-layer',
          markerHitboxLayerId: 'marker-hitbox',
          markerHitboxImageId: 'marker-hitbox-image',
          markerDotLayerId: 'marker-dot',
          markerPulseLayerId: 'marker-pulse',
          cubeSourceId: 'cubes',
          cubeLayerId: 'cube-layer',
          cubeIconLayerId: 'cube-icon-layer',
          locationSourceId: 'location',
          locationLayerId: 'location-layer',
        ),
      ),
      debugTracing: false,
      tapConfig: const KubusMapTapConfig(),
      distance: const Distance(),
    );

    expect(controller.reduceMotion, isFalse);
    controller.setReduceMotion(true);
    expect(controller.reduceMotion, isTrue);
    final timers =
        controller.debugResourceSnapshot['activeTimers']! as Map<String, bool>;
    expect(timers['spiderfyMotion'], isFalse);
    controller.dispose();
  });
}
