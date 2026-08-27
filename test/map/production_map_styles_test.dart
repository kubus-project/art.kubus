import 'dart:convert';
import 'dart:io';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/services/map_style_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the CARTO basemap outage.
///
/// CARTO revoked unauthenticated access to its legacy raster basemaps
/// (`{a-d}.basemaps.cartocdn.com/{light_all,dark_all}/{z}/{x}/{y}.png`), so the
/// bundled Kubus styles started rendering "API key required" watermark tiles in
/// production. The bundled styles now build on CARTO's public *vector* basemap
/// infrastructure instead. These tests keep the app from silently regressing
/// back onto the affected raster endpoints.
void main() {
  // The bundled styles are always validated: `MapStyleService` falls back to
  // them whenever the primary style fails to load, so they must stay healthy
  // no matter what a deployment configures.
  final bundledAssets = <String, String>{
    'bundled light': MapStyleService.bundledLightStyleAsset,
    'bundled dark': MapStyleService.bundledDarkStyleAsset,
  };

  // `AppConfig` deliberately allows a deployment to point at a different
  // checked-in style via `--dart-define=MAP_STYLE_{LIGHT,DARK}_ASSET=...`.
  // Honour that contract instead of pinning the defaults, but pull whatever is
  // configured into the same validation so an override cannot smuggle the
  // revoked raster endpoints back into production.
  final configuredAssets = <String, String>{
    'configured light': AppConfig.mapStyleLightAsset,
    'configured dark': AppConfig.mapStyleDarkAsset,
  };

  final styleAssets = <String, String>{
    ...bundledAssets,
    for (final entry in configuredAssets.entries)
      if (!bundledAssets.containsValue(entry.value)) entry.key: entry.value,
  };

  Map<String, dynamic> readStyle(String assetPath) {
    final file = File(assetPath);
    expect(file.existsSync(), isTrue, reason: '$assetPath must be bundled');
    final decoded = jsonDecode(file.readAsStringSync());
    expect(decoded, isA<Map<String, dynamic>>(),
        reason: '$assetPath must be a JSON object');
    return decoded as Map<String, dynamic>;
  }

  test('every configured production style is a checked-in bundled asset', () {
    // An override may re-point the map at a different *repository* style, but
    // not at an unvalidated one: whatever `MAP_STYLE_*` resolves to has to be a
    // declared `assets/` path that exists here, so the guards below cover it.
    for (final entry in configuredAssets.entries) {
      final assetPath = entry.value;
      expect(
        assetPath,
        startsWith('assets/'),
        reason: '${entry.key} must be a bundled Flutter asset key',
      );
      expect(
        File(assetPath).existsSync(),
        isTrue,
        reason: '${entry.key} ("$assetPath") must exist in this repository',
      );
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains(assetPath),
        reason: '${entry.key} ("$assetPath") must be declared in pubspec.yaml',
      );
    }
  });

  for (final entry in styleAssets.entries) {
    final variant = entry.key;
    final assetPath = entry.value;

    group('$variant map style ($assetPath)', () {
      test('is valid JSON using MapLibre Style Specification version 8', () {
        final style = readStyle(assetPath);
        expect(style['version'], 8);
      });

      test('does not reference the revoked CARTO raster basemaps', () {
        final raw = File(assetPath).readAsStringSync();

        expect(raw, isNot(contains('light_all')));
        expect(raw, isNot(contains('dark_all')));
        expect(raw, isNot(contains('carto-raster')));
        // The unauthenticated raster PNG service in any subdomain/path form.
        expect(
          raw,
          isNot(matches(RegExp(r'basemaps\.cartocdn\.com/[^"]*\.png'))),
          reason: 'legacy CARTO raster PNG tiles now require an API key',
        );
        // No CARTO raster tile endpoint at all, whatever the tile extension.
        expect(
          raw,
          isNot(matches(RegExp(r'https?://[a-d]\.basemaps\.cartocdn\.com'))),
        );
      });

      test('has no raster sources or raster layers', () {
        final style = readStyle(assetPath);

        final sources = style['sources'] as Map<String, dynamic>;
        expect(sources, isNotEmpty);
        for (final source in sources.entries) {
          expect(
            source.value['type'],
            'vector',
            reason: 'source "${source.key}" must be a vector source',
          );
        }

        final layers =
            (style['layers'] as List<dynamic>).cast<Map<String, dynamic>>();
        expect(
          layers.where((layer) => layer['type'] == 'raster'),
          isEmpty,
          reason: 'raster layers depend on the revoked raster service',
        );
        expect(layers.map((layer) => layer['id']),
            isNot(contains('carto-raster')));
      });

      test('keeps the structure MapLibre needs to render a basemap', () {
        final style = readStyle(assetPath);

        // Glyphs are mandatory once the basemap draws vector labels.
        expect(style['glyphs'], isA<String>());
        expect(style['glyphs'], contains('{fontstack}'));
        expect(style['glyphs'], contains('{range}'));

        final sources = style['sources'] as Map<String, dynamic>;
        for (final source in sources.values.cast<Map<String, dynamic>>()) {
          final hasTiles =
              source['tiles'] is List && (source['tiles'] as List).isNotEmpty;
          expect(
            source['url'] is String || hasTiles,
            isTrue,
            reason: 'a vector source needs a TileJSON url or explicit tiles',
          );
          // Attribution must survive the migration.
          expect(source['attribution'], isA<String>());
          expect(source['attribution'], contains('OpenStreetMap'));
        }

        final layers =
            (style['layers'] as List<dynamic>).cast<Map<String, dynamic>>();
        expect(layers, isNotEmpty);

        // A background to paint the Kubus canvas colour...
        expect(layers.first['id'], 'background');
        expect(layers.first['type'], 'background');

        // ...plus real basemap geometry drawn from the vector source.
        final sourceIds = sources.keys.toSet();
        final dataLayers = layers.where(
          (layer) => sourceIds.contains(layer['source']),
        );
        expect(dataLayers, isNotEmpty);
        expect(
          dataLayers.map((layer) => layer['type']).toSet(),
          containsAll(<String>['fill', 'line', 'symbol']),
          reason: 'water/landuse, roads and labels must all be styled',
        );

        // Every layer must point at a source that exists (background aside).
        for (final layer in layers) {
          final source = layer['source'];
          if (source == null) continue;
          expect(sourceIds, contains(source),
              reason: 'layer "${layer['id']}" references an unknown source');
        }

        // Layer ids must be unique or MapLibre rejects the whole style.
        final ids = layers.map((layer) => layer['id'] as String).toList();
        expect(ids.toSet().length, ids.length);
      });
    });
  }

  test('no production map style ships a CARTO API key', () {
    for (final assetPath in styleAssets.values) {
      final raw = File(assetPath).readAsStringSync().toLowerCase();
      expect(raw, isNot(contains('api_key')));
      expect(raw, isNot(contains('apikey')));
      expect(raw, isNot(contains('access_token')));
    }
  });
}
