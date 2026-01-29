import 'package:art_kubus/services/map_style_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MapStyleService normalizes web asset URLs', () {
    const stylePath = 'assets/map_styles/kubus_light.json';

    expect(
      MapStyleService.normalizeWebAssetUrlForTest(stylePath),
      'assets/map_styles/kubus_light.json',
    );

    expect(
      MapStyleService.normalizeWebAssetUrlForTest('assets/assets/map_styles/kubus_light.json'),
      'assets/map_styles/kubus_light.json',
    );

    expect(
      MapStyleService.normalizeWebAssetUrlForTest('/assets/map_styles/kubus_light.json'),
      'assets/map_styles/kubus_light.json',
    );

    expect(
      MapStyleService.normalizeWebAssetUrlForTest('map_styles/kubus_light.json'),
      'assets/map_styles/kubus_light.json',
    );

    expect(
      MapStyleService.normalizeWebAssetUrlForTest('assets\\map_styles\\kubus_light.json'),
      'assets/map_styles/kubus_light.json',
    );
  });
}
