import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/config.dart';

class MapStyleService {
  MapStyleService._();

  static const Duration styleLoadTimeout = Duration(seconds: 8);

  /// Dev-only fallback style (public demo tiles; do not rely on this for prod).
  static const String devFallbackStyleUrl = 'https://demotiles.maplibre.org/style.json';

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
  /// - On **native**, prefer passing asset/file paths. Raw JSON is only
  ///   supported on Android in `maplibre_gl`.
  static Future<String> resolveStyleString(String styleRef) {
    final trimmed = styleRef.trimLeft();
    if (trimmed.isEmpty) return Future<String>.value(styleRef);

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      // Raw JSON styles are only supported on Android by `maplibre_gl`.
      // Keep as-is so Android continues to work; other platforms should pass a
      // URL/asset/file style reference instead.
      if (kDebugMode && defaultTargetPlatform != TargetPlatform.android) {
        AppConfig.debugPrint(
          'MapStyleService: raw JSON styleString is not supported on '
          '${defaultTargetPlatform.name}; prefer an asset path or URL.',
        );
      }
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

    // Native platforms: pass asset path or file path directly.
    // This is the most compatible option across Android/iOS/desktop.
    return Future<String>.value(trimmed);
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
