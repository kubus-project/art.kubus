import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/features/map/controller/map_view_preferences_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapViewPreferencesController', () {
    test('load reads persisted travel/isometric values', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferenceKeys.mapTravelModeEnabledV1: true,
        PreferenceKeys.mapIsometricViewEnabledV1: false,
      });

      final controller = MapViewPreferencesController();
      final prefs = await controller.load();

      expect(prefs.travelModeEnabled, isTrue);
      expect(prefs.isometricViewEnabled, isFalse);
      expect(controller.hasLoaded, isTrue);
    });

    test('setters update state and persist values', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = MapViewPreferencesController();
      await controller.load();

      await controller.setTravelMode(true);
      await controller.setIsometric(true);

      final stored = await SharedPreferences.getInstance();
      expect(
        stored.getBool(PreferenceKeys.mapTravelModeEnabledV1),
        isTrue,
      );
      expect(
        stored.getBool(PreferenceKeys.mapIsometricViewEnabledV1),
        isTrue,
      );
      expect(controller.value.travelModeEnabled, isTrue);
      expect(controller.value.isometricViewEnabled, isTrue);
    });
  });
}
