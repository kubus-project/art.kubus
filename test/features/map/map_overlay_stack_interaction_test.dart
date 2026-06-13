import 'package:art_kubus/features/map/controller/kubus_map_controller.dart';
import 'package:art_kubus/features/map/map_layers_manager.dart';
import 'package:art_kubus/features/map/map_overlay_stack.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/widgets/common/kubus_glass_chip.dart';
import 'package:art_kubus/widgets/map/controls/kubus_map_primary_controls.dart';
import 'package:art_kubus/widgets/map/filters/kubus_map_marker_layer_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'hidden marker overlay with cursor does not block Flutter buttons',
      (tester) async {
    var outsideTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 24,
                top: 24,
                child: ElevatedButton(
                  key: const ValueKey<String>('under_marker_overlay_button'),
                  onPressed: () => outsideTapCount += 1,
                  child: const Text('Under overlay'),
                ),
              ),
              KubusMapMarkerOverlayLayer(
                content: null,
                contentKey: const ValueKey<String>('hidden_marker_overlay'),
                cursor: SystemMouseCursors.basic,
                blockMapGestures: false,
                dismissOnBackdropTap: false,
                onDismiss: () {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester
        .tap(find.byKey(const ValueKey<String>('under_marker_overlay_button')));
    await tester.pump();

    expect(outsideTapCount, 1);
  });

  testWidgets('marker overlay layer does not block controls outside the card',
      (tester) async {
    var outsideTapCount = 0;
    var cardTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 24,
                top: 24,
                child: ElevatedButton(
                  key: const ValueKey<String>('outside_control'),
                  onPressed: () => outsideTapCount += 1,
                  child: const Text('Outside'),
                ),
              ),
              KubusMapMarkerOverlayLayer(
                content: Center(
                  child: SizedBox(
                    width: 160,
                    height: 96,
                    child: ElevatedButton(
                      key: const ValueKey<String>('overlay_card_button'),
                      onPressed: () => cardTapCount += 1,
                      child: const Text('Card'),
                    ),
                  ),
                ),
                contentKey:
                    const ValueKey<String>('visible_marker_overlay_content'),
                cursor: SystemMouseCursors.basic,
                blockMapGestures: false,
                dismissOnBackdropTap: false,
                onDismiss: () {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('outside_control')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('overlay_card_button')));
    await tester.pump();

    expect(outsideTapCount, 1);
    expect(cardTapCount, 1);
  });

  testWidgets(
      'filter chips and primary controls remain clickable under overlay',
      (tester) async {
    final controller = _buildMapController();
    var chipToggleCount = 0;
    var createMarkerCount = 0;
    var centerOnMeCount = 0;

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Stack(
                children: [
                  Positioned(
                    left: 16,
                    top: 16,
                    child: KubusMapMarkerLayerChips(
                      l10n: l10n,
                      visibility: <ArtMarkerType, bool>{
                        for (final type in ArtMarkerType.values) type: true,
                      },
                      onToggle: (type, nextSelected) => chipToggleCount += 1,
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: KubusMapPrimaryControls(
                      controller: controller,
                      layout: KubusMapPrimaryControlsLayout.mobileRightRail,
                      onCenterOnMe: () => centerOnMeCount += 1,
                      onCreateMarker: () => createMarkerCount += 1,
                      centerOnMeActive: false,
                      centerOnMeKey:
                          const ValueKey<String>('center_on_me_control'),
                      createMarkerKey:
                          const ValueKey<String>('create_marker_control'),
                    ),
                  ),
                  KubusMapMarkerOverlayLayer(
                    content: Center(
                      child: Container(
                        width: 180,
                        height: 100,
                        color: Colors.black12,
                      ),
                    ),
                    contentKey:
                        const ValueKey<String>('marker_overlay_card_content'),
                    blockMapGestures: false,
                    dismissOnBackdropTap: false,
                    onDismiss: () {},
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byType(KubusGlassChip).first);
    await tester.pump();
    await tester
        .tap(find.byKey(const ValueKey<String>('create_marker_control')));
    await tester.pump();
    await tester
        .tap(find.byKey(const ValueKey<String>('center_on_me_control')));
    await tester.pump();

    expect(chipToggleCount, 1);
    expect(createMarkerCount, 1);
    expect(centerOnMeCount, 1);
  });

  testWidgets('desktop primary control optional callbacks fire',
      (tester) async {
    final controller = _buildMapController();
    var nearbyToggleCount = 0;
    var travelToggleCount = 0;
    var isometricToggleCount = 0;

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: KubusMapPrimaryControls(
              controller: controller,
              layout: KubusMapPrimaryControlsLayout.desktopToolbar,
              onCenterOnMe: () {},
              onCreateMarker: () {},
              centerOnMeActive: false,
              showNearbyToggle: true,
              onToggleNearby: () => nearbyToggleCount += 1,
              nearbyKey: const ValueKey<String>('nearby_toggle_control'),
              showTravelModeToggle: true,
              onToggleTravelMode: () => travelToggleCount += 1,
              travelModeKey: const ValueKey<String>('travel_toggle_control'),
              showIsometricViewToggle: true,
              onToggleIsometricView: () => isometricToggleCount += 1,
              isometricViewTooltip: 'Isometric',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey<String>('nearby_toggle_control')));
    await tester.pump();
    await tester
        .tap(find.byKey(const ValueKey<String>('travel_toggle_control')));
    await tester.pump();
    await tester.tap(find.byTooltip('Isometric'));
    await tester.pump();

    expect(nearbyToggleCount, 1);
    expect(travelToggleCount, 1);
    expect(isometricToggleCount, 1);
  });
}

KubusMapController _buildMapController() {
  return KubusMapController(
    ids: const KubusMapControllerIds(
      layers: MapLayersIds(
        markerSourceId: 'kubus_markers',
        markerLayerId: 'kubus_marker_layer',
        markerHitboxLayerId: 'kubus_marker_hitbox_layer',
        markerHitboxImageId: 'kubus_hitbox_square_transparent',
        markerDotLayerId: 'kubus_marker_dot_layer',
        markerPulseLayerId: 'kubus_marker_pulse_layer',
        cubeSourceId: 'kubus_marker_cubes',
        cubeLayerId: 'kubus_marker_cubes_layer',
        cubeIconLayerId: 'kubus_marker_cubes_icon_layer',
        locationSourceId: 'kubus_user_location',
        locationLayerId: 'kubus_user_location_layer',
      ),
    ),
    debugTracing: false,
    tapConfig: const KubusMapTapConfig(),
    distance: const Distance(),
  );
}
