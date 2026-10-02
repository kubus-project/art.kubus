import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/features/map/controller/map_view_preferences_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapViewPreferencesController', () {
    test(
      'load ignores legacy Travel preference and reads isometric value',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'map_travel_mode_enabled_v1': true,
          PreferenceKeys.mapIsometricViewEnabledV1: false,
        });

        final controller = MapViewPreferencesController();
        final prefs = await controller.load();

        expect(prefs.isometricViewEnabled, isFalse);
        expect(controller.hasLoaded, isTrue);
      },
    );

    test('setters update state and persist values', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = MapViewPreferencesController();
      await controller.load();

      await controller.setIsometric(true);

      final stored = await SharedPreferences.getInstance();
      expect(stored.getBool(PreferenceKeys.mapIsometricViewEnabledV1), isTrue);
      expect(controller.value.isometricViewEnabled, isTrue);
    });
  });
}
