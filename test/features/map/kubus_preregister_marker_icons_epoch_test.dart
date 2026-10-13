import 'dart:async';
import 'dart:typed_data';

import 'package:art_kubus/features/map/shared/map_screen_shared_helpers.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/map/kubus_map_marker_rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

class _ControlledImageController implements ml.MapLibreMapController {
  _ControlledImageController({this.onAddImage});

  final void Function(String imageId)? onAddImage;
  final Completer<void> firstAddEntered = Completer<void>();
  final Completer<void> releaseAdds = Completer<void>();
  final List<String> addedIds = <String>[];

  @override
  Future<void> addImage(String imageId, Uint8List bytes, [bool sdf = false]) {
    addedIds.add(imageId);
    if (!firstAddEntered.isCompleted) firstAddEntered.complete();
    onAddImage?.call(imageId);
    return releaseAdds.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ArtMarker _marker() => ArtMarker(
      id: 'epoch-test-marker',
      name: 'Epoch test marker',
      description: 'Canonical marker icon test',
      position: const LatLng(46.056946, 14.505751),
      type: ArtMarkerType.artwork,
      artworkId: 'epoch-test-artwork',
      createdAt: DateTime.utc(2026, 10, 13),
      createdBy: 'test-user',
    );

Future<void> _preregister({
  required ml.MapLibreMapController controller,
  required Set<String> registry,
  required bool Function() shouldAbort,
}) =>
    kubusPreregisterMarkerIcons(
      controller: controller,
      registeredMapImages: registry,
      markers: <ArtMarker>[_marker()],
      isDark: false,
      useClustering: false,
      zoom: 13,
      clusterGridLevelForZoom: (_) => 8,
      sortClustersBySizeDesc: true,
      scheme: ThemeData.light().colorScheme,
      roles: KubusColorRoles.light,
      pixelRatio: 1,
      resolveMarkerIcon: KubusMapMarkerHelpers.resolveArtMarkerIcon,
      resolveMarkerBaseColor: (_) => Colors.blue,
      shouldAbort: shouldAbort,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'canonical icon registration completes when healthy and drops stale epoch results',
    (tester) async {
      await tester.runAsync(() async {
        final healthyRegistry = <String>{};
        final healthyController = _ControlledImageController();
        final healthyRun = _preregister(
          controller: healthyController,
          registry: healthyRegistry,
          shouldAbort: () => false,
        );
        await healthyController.firstAddEntered.future
            .timeout(const Duration(seconds: 10));
        healthyController.releaseAdds.complete();
        await healthyRun.timeout(const Duration(seconds: 10));
        expect(healthyController.addedIds, hasLength(2));
        expect(healthyRegistry, hasLength(2));

        var styleEpoch = 7;
        final capturedEpoch = styleEpoch;
        final staleRegistry = <String>{};
        final staleController = _ControlledImageController(
          onAddImage: (_) {
            styleEpoch += 1;
            // A new style epoch replaces the registry while addImage is
            // outstanding. Completion from the old style must not re-add it.
            staleRegistry.clear();
          },
        );
        final staleRun = _preregister(
          controller: staleController,
          registry: staleRegistry,
          shouldAbort: () => styleEpoch != capturedEpoch,
        );
        await staleController.firstAddEntered.future
            .timeout(const Duration(seconds: 10));
        expect(staleController.addedIds, isNotEmpty);
        staleController.releaseAdds.complete();
        await staleRun.timeout(const Duration(seconds: 10));
        expect(staleRegistry, isEmpty);
      }).timeout(const Duration(seconds: 20));
    },
  );
}
