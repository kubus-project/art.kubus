import 'dart:convert';
import 'dart:io';

import 'package:art_kubus/services/map_style_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MapStyleService web asset key normalization', () {
    // Regression: `maplibre_gl_web` >= 0.26.2 resolves style strings starting
    // with `assets/` through `rootBundle`, and Flutter's web engine then serves
    // them from `<base href>assets/<key>`. Returning the pre-resolved
    // `assets/assets/...` HTTP path made the engine add a *third* prefix and
    // request `/assets/assets/assets/map_styles/kubus_light.json` (404), which
    // left the web map as a permanently blank canvas.
    // The resolver must emit the plain asset key with exactly one `assets/`.
    test('keeps a single assets/ segment for declared style assets', () {
      expect(
        MapStyleService.normalizeWebAssetKeyForTest(
          'assets/map_styles/kubus_light.json',
        ),
        'assets/map_styles/kubus_light.json',
      );

      expect(
        MapStyleService.normalizeWebAssetKeyForTest(
          'assets/map_styles/kubus_dark.json',
        ),
        'assets/map_styles/kubus_dark.json',
      );
    });

    test('never emits a doubled assets/assets/ prefix', () {
      for (final ref in <String>[
        'assets/map_styles/kubus_light.json',
        'assets/map_styles/kubus_dark.json',
        MapStyleService.bundledLightStyleAsset,
        MapStyleService.bundledDarkStyleAsset,
      ]) {
        final resolved = MapStyleService.normalizeWebAssetKeyForTest(ref);
        expect(
          resolved.startsWith('assets/assets/'),
          isFalse,
          reason: '$ref must not resolve to a doubled assets/ prefix',
        );
        expect(resolved.startsWith('assets/'), isTrue);
      }
    });

    test('collapses already web-resolved / compounded assets/ prefixes', () {
      expect(
        MapStyleService.normalizeWebAssetKeyForTest(
          'assets/assets/map_styles/kubus_light.json',
        ),
        'assets/map_styles/kubus_light.json',
      );

      expect(
        MapStyleService.normalizeWebAssetKeyForTest(
          'assets/assets/assets/map_styles/kubus_light.json',
        ),
        'assets/map_styles/kubus_light.json',
      );
    });

    test('is idempotent under repeated resolution', () {
      var value = MapStyleService.bundledLightStyleAsset;
      for (var i = 0; i < 5; i++) {
        value = MapStyleService.normalizeWebAssetKeyForTest(value);
      }
      expect(value, 'assets/map_styles/kubus_light.json');
    });

    test('normalizes leading slashes, ./ and backslashes', () {
      expect(
        MapStyleService.normalizeWebAssetKeyForTest(
          '/assets/map_styles/kubus_light.json',
        ),
        'assets/map_styles/kubus_light.json',
      );

      expect(
        MapStyleService.normalizeWebAssetKeyForTest(
          './assets/map_styles/kubus_light.json',
        ),
        'assets/map_styles/kubus_light.json',
      );

      expect(
        MapStyleService.normalizeWebAssetKeyForTest(
          r'assets\map_styles\kubus_light.json',
        ),
        'assets/map_styles/kubus_light.json',
      );

      expect(
        MapStyleService.normalizeWebAssetKeyForTest(
          '//assets/assets/map_styles/kubus_dark.json',
        ),
        'assets/map_styles/kubus_dark.json',
      );
    });

    test('adds the assets/ prefix when the ref omits it', () {
      expect(
        MapStyleService.normalizeWebAssetKeyForTest(
          'map_styles/kubus_light.json',
        ),
        'assets/map_styles/kubus_light.json',
      );
    });

    test('leaves an empty ref alone', () {
      expect(MapStyleService.normalizeWebAssetKeyForTest(''), '');
      expect(MapStyleService.normalizeWebAssetKeyForTest('   '), '');
    });
  });

  group('MapStyleService.resolveStyleString', () {
    // These run on the VM (kIsWeb == false), so they cover the native branch.
    test('passes remote and raw-JSON styles through untouched', () async {
      const url = 'https://demotiles.maplibre.org/style.json';
      expect(await MapStyleService.resolveStyleString(url), url);

      const rawJson = '{"version":8,"sources":{},"layers":[]}';
      expect(await MapStyleService.resolveStyleString(rawJson), rawJson);
    });

    test('passes bundled asset refs through on native', () async {
      expect(
        await MapStyleService.resolveStyleString(
          MapStyleService.bundledLightStyleAsset,
        ),
        'assets/map_styles/kubus_light.json',
      );
    });

    test('never yields a doubled assets/ prefix for bundled refs', () async {
      for (final isDark in <bool>[false, true]) {
        final resolved = await MapStyleService.resolveStyleString(
          MapStyleService.fallbackStyleRef(isDarkMode: isDark),
        );
        expect(resolved.startsWith('assets/assets/'), isFalse);
      }
    });
  });
  group('MapStyleService globe projection (Wave 5B)', () {
    test('stamps a globe projection onto a style document', () {
      final stamped = MapStyleService.withGlobeProjection(
        '{"version":8,"sources":{},"layers":[]}',
      );
      final decoded = jsonDecode(stamped) as Map<String, dynamic>;
      expect(decoded['projection'], <String, dynamic>{'type': 'globe'});
      expect(decoded['version'], 8);
    });

    test('leaves a style that already declares a projection alone', () {
      const own =
          '{"version":8,"projection":{"type":"mercator"},"sources":{},"layers":[]}';
      expect(MapStyleService.withGlobeProjection(own), own);
    });

    test('returns anything that is not a style object unchanged', () {
      expect(MapStyleService.withGlobeProjection('not json'), 'not json');
      expect(MapStyleService.withGlobeProjection('[1,2]'), '[1,2]');
    });

    test('native never receives a stamped style (globe is web-only)', () async {
      // The host test platform is not web, so the globe request is ignored
      // and the bundled asset reference passes through untouched.
      expect(
        await MapStyleService.resolveStyleString(
          MapStyleService.bundledLightStyleAsset,
          globe: true,
        ),
        'assets/map_styles/kubus_light.json',
      );
    });

    test('both bundled styles are valid flat styles the globe can stamp', () {
      for (final path in <String>[
        'assets/map_styles/kubus_light.json',
        'assets/map_styles/kubus_dark.json',
      ]) {
        final raw = File(path).readAsStringSync();
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        expect(decoded.containsKey('projection'), isFalse,
            reason: '$path must stay flat; globe is stamped at load time');
        final stamped = jsonDecode(MapStyleService.withGlobeProjection(raw))
            as Map<String, dynamic>;
        expect((stamped['layers'] as List).length,
            (decoded['layers'] as List).length);
      }
    });
  });

  group('vendored web MapLibre runtime', () {
    // The globe path needs MapLibre GL JS 5.x. 4.7.1 silently ignores the
    // style projection and draws flat, so a downgrade must fail loudly.
    test('is 5.x (globe-capable), not the 4.x line', () {
      final header = File('web/local/maplibre-gl/maplibre-gl-csp.js')
          .readAsStringSync()
          .substring(0, 400);
      final match = RegExp(r'maplibre-gl-js/blob/v(\d+)\.(\d+)\.(\d+)/')
          .firstMatch(header);
      expect(match, isNotNull, reason: 'version banner not found');
      expect(int.parse(match!.group(1)!), greaterThanOrEqualTo(5));
    });

    test('worker and bundle come from the same release', () {
      String banner(String file) {
        final header = File('web/local/maplibre-gl/$file')
            .readAsStringSync()
            .substring(0, 400);
        return RegExp(r'blob/(v\d+\.\d+\.\d+)/').firstMatch(header)!.group(1)!;
      }

      expect(banner('maplibre-gl-csp-worker.js'), banner('maplibre-gl-csp.js'));
    });
  });
}
