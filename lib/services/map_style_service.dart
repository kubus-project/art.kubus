import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config/config.dart';

class MapStyleService {
  MapStyleService._();

  static const Duration styleLoadTimeout = Duration(seconds: 8);

  /// Dev-only fallback style (public demo tiles; do not rely on this for prod).
  static const String devFallbackStyleUrl = 'https://demotiles.maplibre.org/style.json';

  static final Map<String, Future<String>> _resolvedStyleCache =
      <String, Future<String>>{};

  static bool get devFallbackEnabled => AppConfig.isDevelopment && kDebugMode;

  static String primaryStyleRef({required bool isDarkMode}) {
    return isDarkMode ? AppConfig.mapStyleDarkAsset : AppConfig.mapStyleLightAsset;
  }

  /// Resolves a map style reference into a `styleString` compatible with `maplibre_gl`.
  ///
  /// Supported inputs:
  /// - `http(s)://...` URLs
  /// - Raw style JSON (`{...}` / `[...]`)
  /// - Asset paths (e.g. `assets/map_styles/kubus_light.json`)
  /// - Local file paths (absolute paths)
  ///
  /// Notes:
  /// - On **web** we return a URL to the bundled asset so MapLibre GL JS loads it
  ///   natively (avoids JS worker transfer issues with Dart-created objects).
  /// - On **native** we load asset JSON and pass the raw JSON string.
  static Future<String> resolveStyleString(String styleRef) {
    final trimmed = styleRef.trimLeft();
    if (trimmed.isEmpty) return Future<String>.value(styleRef);

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return Future<String>.value(styleRef);
    }

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('mapbox://') ||
        lower.startsWith('file://')) {
      return Future<String>.value(styleRef);
    }

    if (kIsWeb) {
      return Future<String>.value(_toWebAssetUrl(trimmed));
    }

    return _resolvedStyleCache.putIfAbsent(trimmed, () async {
      try {
        return await rootBundle.loadString(trimmed);
      } catch (e, st) {
        if (kDebugMode) {
          dev.log(
            'Failed to load map style from assets: $trimmed',
            name: 'MapStyleService',
            error: e,
            stackTrace: st,
          );
        }
        // Fall back to original string. It may be a valid file path.
        return styleRef;
      }
    });
  }

  static String _toWebAssetUrl(String styleRef) {
    var normalized = styleRef;
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }

    // If the style already points inside the web `assets/` folder, keep it.
    if (normalized.startsWith('assets/assets/') ||
        normalized.startsWith('assets/packages/') ||
        normalized.startsWith('assets/fonts/') ||
        normalized.startsWith('assets/shaders/')) {
      return normalized;
    }

    // Flutter web serves bundled assets under `assets/<assetPath>`.
    return 'assets/$normalized';
  }
}
