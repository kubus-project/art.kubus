import 'dart:convert';
import 'dart:io';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/services/map_style_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the bundled art.kubus basemaps.
///
/// Two things are protected here.
///
/// 1. The CARTO raster outage. CARTO revoked unauthenticated access to its
///    legacy raster basemaps
///    (`{a-d}.basemaps.cartocdn.com/{light_all,dark_all}/{z}/{x}/{y}.png`), so
///    the bundled Kubus styles started rendering "API key required" watermark
///    tiles in production. The styles now build on CARTO's public *vector*
///    basemap infrastructure and must never fall back onto the raster service.
///
/// 2. The semantic-zoom contract. The basemap exists to orient people around
///    artworks: cities have to read as cities before individual buildings
///    exist, roads must stay neutral grey so they can never be mistaken for
///    water, and detail must not be forced on at zoom levels where the vector
///    source has nothing to draw anyway.
///
/// The assertions deliberately key off `source-layer`, filters and zoom ranges
/// rather than individual CARTO layer ids, so ordinary cartographic tuning does
/// not break them.
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
    expect(
      decoded,
      isA<Map<String, dynamic>>(),
      reason: '$assetPath must be a JSON object',
    );
    return decoded as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> layersOf(Map<String, dynamic> style) =>
      (style['layers'] as List<dynamic>).cast<Map<String, dynamic>>();

  /// Layers drawn from `source-layer` in the CARTO vector source.
  List<Map<String, dynamic>> fromSourceLayer(
    Map<String, dynamic> style,
    String sourceLayer,
  ) =>
      layersOf(
        style,
      ).where((layer) => layer['source-layer'] == sourceLayer).toList();

  double minZoomOf(Map<String, dynamic> layer) =>
      (layer['minzoom'] as num?)?.toDouble() ?? 0;

  double maxZoomOf(Map<String, dynamic> layer) =>
      (layer['maxzoom'] as num?)?.toDouble() ?? 24;

  /// A layer is "active" at [zoom] the way MapLibre evaluates it.
  bool activeAt(Map<String, dynamic> layer, double zoom) =>
      zoom >= minZoomOf(layer) && zoom < maxZoomOf(layer);

  /// Flattens a filter/expression into plain text so a test can ask whether a
  /// layer is about, say, `residential` without hard-coding filter shapes.
  String flatten(Object? node) => jsonEncode(node ?? '');

  /// Every `#rrggbb` literal reachable from a paint value, so tests work with
  /// both flat colours and zoom `interpolate` ramps.
  List<String> hexColorsIn(Object? node) {
    final found = <String>[];
    void walk(Object? value) {
      if (value is String) {
        if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
          found.add(value.toUpperCase());
        }
      } else if (value is List) {
        for (final item in value) {
          walk(item);
        }
      } else if (value is Map) {
        for (final item in value.values) {
          walk(item);
        }
      }
    }

    walk(node);
    return found;
  }

  ({int r, int g, int b}) rgbOf(String hex) => (
        r: int.parse(hex.substring(1, 3), radix: 16),
        g: int.parse(hex.substring(3, 5), radix: 16),
        b: int.parse(hex.substring(5, 7), radix: 16),
      );

  /// How far a colour strays from neutral grey. A road may only differ from
  /// grey by a hair; water is expected to be clearly cooler than it is warm.
  int chroma(String hex) {
    final c = rgbOf(hex);
    final maxChannel = [c.r, c.g, c.b].reduce((a, b) => a > b ? a : b);
    final minChannel = [c.r, c.g, c.b].reduce((a, b) => a < b ? a : b);
    return maxChannel - minChannel;
  }

  int blueBias(String hex) {
    final c = rgbOf(hex);
    return c.b - c.r;
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

        final layers = layersOf(style);
        expect(
          layers.where((layer) => layer['type'] == 'raster'),
          isEmpty,
          reason: 'raster layers depend on the revoked raster service',
        );
        expect(
          layers.map((layer) => layer['id']),
          isNot(contains('carto-raster')),
        );
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

        final layers = layersOf(style);
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
          expect(
            sourceIds,
            contains(source),
            reason: 'layer "${layer['id']}" references an unknown source',
          );
          expect(
            layer['source-layer'],
            isA<String>(),
            reason: 'layer "${layer['id']}" must name a vector source-layer',
          );
        }

        // Layer ids must be unique or MapLibre rejects the whole style.
        final ids = layers.map((layer) => layer['id'] as String).toList();
        expect(ids.toSet().length, ids.length);
      });

      test('declares sane zoom ranges on every layer', () {
        for (final layer in layersOf(readStyle(assetPath))) {
          final id = layer['id'];
          final minZoom = layer['minzoom'];
          final maxZoom = layer['maxzoom'];
          if (minZoom != null) {
            expect(minZoom, isA<num>(), reason: 'layer "$id" minzoom');
            expect(
              (minZoom as num) >= 0 && minZoom <= 24,
              isTrue,
              reason: 'layer "$id" minzoom $minZoom is out of range',
            );
          }
          if (maxZoom != null) {
            expect(maxZoom, isA<num>(), reason: 'layer "$id" maxzoom');
            expect(
              (maxZoom as num) > 0 && maxZoom <= 24,
              isTrue,
              reason: 'layer "$id" maxzoom $maxZoom is out of range',
            );
          }
          if (minZoom != null && maxZoom != null) {
            expect(
              (minZoom as num) < (maxZoom as num),
              isTrue,
              reason: 'layer "$id" has an empty zoom range',
            );
          }
        }
      });

      test('covers the semantic layer groups the basemap is built from', () {
        final style = readStyle(assetPath);
        final layers = layersOf(style);

        expect(
          layers.where((layer) => layer['type'] == 'background'),
          isNotEmpty,
          reason: 'a background paints the Kubus canvas before any tile lands',
        );

        for (final sourceLayer in <String>[
          'water', // water bodies
          'transportation', // roads and rail
          'landuse', // urban footprint
          'building', // buildings
          'place', // city labels
        ]) {
          expect(
            fromSourceLayer(style, sourceLayer),
            isNotEmpty,
            reason: 'the basemap must style the "$sourceLayer" source-layer',
          );
        }

        // The urban footprint is what makes a city read as a city before any
        // building geometry exists, so it has to arrive at regional zoom.
        final urban = fromSourceLayer(style, 'landuse')
            .where(
              (layer) =>
                  layer['type'] == 'fill' &&
                  flatten(layer['filter']).contains('residential'),
            )
            .toList();
        expect(
          urban,
          isNotEmpty,
          reason: 'a residential/urban land-use fill must exist',
        );
        expect(
          urban.map(minZoomOf).reduce((a, b) => a < b ? a : b),
          lessThanOrEqualTo(6),
          reason: 'the urban footprint must be visible at regional zoom',
        );

        // Place labels must include a settlement layer, not just countries.
        final settlementLabels = fromSourceLayer(style, 'place')
            .where(
              (layer) =>
                  layer['type'] == 'symbol' &&
                  flatten(layer['filter']).contains('city'),
            )
            .toList();
        expect(
          settlementLabels,
          isNotEmpty,
          reason: 'city labels must be styled',
        );
      });

      test('shows major cities at regional zoom', () {
        final style = readStyle(assetPath);
        // At z5 a user should already be able to tell where the major cities
        // are. Assert that at least one city/capital label layer is live there.
        final regionalCityLabels = fromSourceLayer(style, 'place').where(
          (layer) =>
              layer['type'] == 'symbol' &&
              flatten(layer['filter']).contains('city') &&
              activeAt(layer, 5),
        );
        expect(
          regionalCityLabels,
          isNotEmpty,
          reason: 'no city label layer is active at z5',
        );

        final regionalAtZ4 = fromSourceLayer(style, 'place').where(
          (layer) =>
              flatten(layer['filter']).contains('city') && activeAt(layer, 4),
        );
        expect(
          regionalAtZ4,
          isNotEmpty,
          reason: 'no city layer is active at z4',
        );
      });

      test('introduces buildings only where the source actually has them', () {
        final style = readStyle(assetPath);
        final buildings = fromSourceLayer(style, 'building');
        expect(buildings, isNotEmpty);

        for (final layer in buildings) {
          // CARTO's `carto.streets` source ships zero building features below
          // z13 (z13 is one merged built-up mass, z14 is real footprints), so
          // pulling buildings lower just costs work and renders nothing.
          expect(
            minZoomOf(layer),
            greaterThanOrEqualTo(13),
            reason: 'building layer "${layer['id']}" starts before the source '
                'has building geometry',
          );
          expect(
            minZoomOf(layer),
            lessThanOrEqualTo(14),
            reason: 'building layer "${layer['id']}" starts too late to give '
                'detailed zooms any building context',
          );
        }

        expect(
          buildings.any((layer) => activeAt(layer, 14)),
          isTrue,
          reason: 'buildings must be drawn once footprints exist at z14',
        );
        expect(
          buildings.any((layer) => activeAt(layer, 10)),
          isFalse,
          reason: 'buildings must not be forced on at mid zoom',
        );
      });

      test('defers detailed local roads to street-level zoom', () {
        final style = readStyle(assetPath);
        const localClasses = <String>['service', 'path', 'track'];

        final localRoads = fromSourceLayer(style, 'transportation').where((
          layer,
        ) {
          final filter = flatten(layer['filter']);
          return localClasses.any(filter.contains);
        }).toList();
        expect(
          localRoads,
          isNotEmpty,
          reason: 'service/path roads should still exist at detail zoom',
        );

        for (final layer in localRoads) {
          expect(
            minZoomOf(layer),
            greaterThanOrEqualTo(13),
            reason: 'local road layer "${layer['id']}" starts too early and '
                'only adds low-zoom noise',
          );
        }

        // Nothing below `secondary` belongs in a regional view.
        for (final layer in fromSourceLayer(style, 'transportation')) {
          if (!activeAt(layer, 8)) continue;
          final filter = flatten(layer['filter']);
          for (final klass in <String>[
            'service',
            'path',
            'track',
            'minor',
            'tertiary',
          ]) {
            expect(
              filter.contains('"$klass"'),
              isFalse,
              reason: 'layer "${layer['id']}" draws $klass roads at z8',
            );
          }
        }
      });

      test('keeps roads neutral grey and water blue', () {
        final style = readStyle(assetPath);

        final waterColors = <String>{
          for (final layer in layersOf(style))
            if (layer['source-layer'] == 'water' ||
                layer['source-layer'] == 'waterway')
              ...hexColorsIn(layer['paint']),
        };
        expect(waterColors, isNotEmpty);

        for (final color in waterColors) {
          expect(
            blueBias(color),
            greaterThanOrEqualTo(12),
            reason: 'water colour $color does not read as water',
          );
        }

        // Road *fills* — the wide coloured part of a road, as opposed to the
        // near-background casing drawn underneath it.
        final roadFillColors = <String, String>{};
        for (final layer in fromSourceLayer(style, 'transportation')) {
          if (layer['type'] != 'line') continue;
          if ((layer['id'] as String).contains('case')) continue;
          for (final color in hexColorsIn(layer['paint'])) {
            roadFillColors[color] = layer['id'] as String;
          }
        }
        expect(roadFillColors, isNotEmpty);

        for (final road in roadFillColors.entries) {
          expect(
            waterColors.contains(road.key),
            isFalse,
            reason: 'road layer "${road.value}" reuses the water colour '
                '${road.key}',
          );
          // The original defect was blue-grey road fills (`#414758`) sitting in
          // the same hue family as the water (`#2C353C`). Roads have to stay
          // close to neutral so the hierarchy reads by luminance, not hue.
          expect(
            chroma(road.key),
            lessThanOrEqualTo(16),
            reason: 'road layer "${road.value}" uses the tinted colour '
                '${road.key}, which can read as water',
          );
        }
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

  test('light and dark styles share one semantic layer model', () {
    final light = readStyle(MapStyleService.bundledLightStyleAsset);
    final dark = readStyle(MapStyleService.bundledDarkStyleAsset);

    List<String> ids(Map<String, dynamic> style) =>
        layersOf(style).map((layer) => layer['id'] as String).toList();

    expect(
      ids(dark),
      equals(ids(light)),
      reason: 'the two variants must differ only in palette, so a semantic '
          'change can never land in one theme and not the other',
    );

    for (var i = 0; i < layersOf(light).length; i++) {
      final lightLayer = layersOf(light)[i];
      final darkLayer = layersOf(dark)[i];
      expect(
        darkLayer['minzoom'],
        lightLayer['minzoom'],
        reason: 'layer "${lightLayer['id']}" minzoom differs between themes',
      );
      expect(
        darkLayer['maxzoom'],
        lightLayer['maxzoom'],
        reason: 'layer "${lightLayer['id']}" maxzoom differs between themes',
      );
      expect(
        jsonEncode(darkLayer['filter']),
        jsonEncode(lightLayer['filter']),
        reason: 'layer "${lightLayer['id']}" filter differs between themes',
      );
    }
  });
}
