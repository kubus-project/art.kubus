import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/config.dart';

class MapStyleService {
  MapStyleService._();

  static const Duration styleLoadTimeout = Duration(seconds: 8);

  /// Dev-only fallback style (public demo tiles; do not rely on this for prod).
  static const String devFallbackStyleUrl = 'https://demotiles.maplibre.org/style.json';

  /// Production-safe fallback styles bundled with the app.
  static const String bundledLightStyleAsset = 'assets/map_styles/kubus_light.json';
  static const String bundledDarkStyleAsset = 'assets/map_styles/kubus_dark.json';

  static bool get devFallbackEnabled =>
      AppConfig.isDevelopment && kDebugMode && !kIsWeb;

  static String primaryStyleRef({required bool isDarkMode}) {
    return isDarkMode ? AppConfig.mapStyleDarkAsset : AppConfig.mapStyleLightAsset;
  }

  static String fallbackStyleRef({required bool isDarkMode}) {
    return isDarkMode ? bundledDarkStyleAsset : bundledLightStyleAsset;
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
    var normalized = styleRef.trim();
    if (normalized.isEmpty) return normalized;

    normalized = normalized.replaceAll('\\', '/');
    if (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }

    // Flutter web serves bundled assets under `assets/<assetPath>`.
    // For assets declared as `assets/...`, the web path becomes
    // `assets/assets/...` (Flutter prepends the `assets/` prefix).
    if (normalized.startsWith('assets/assets/')) {
      return normalized;
    }

    return 'assets/$normalized';
  }

  @visibleForTesting
  static String normalizeWebAssetUrlForTest(String styleRef) {
    return _toWebAssetUrl(styleRef);
  }
}
