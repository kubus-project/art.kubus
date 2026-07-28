import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/config.dart';

class MapStyleService {
  MapStyleService._();

  static const Duration styleLoadTimeout = Duration(seconds: 8);

  /// Dev-only fallback style (public demo tiles; do not rely on this for prod).
  static const String devFallbackStyleUrl =
      'https://demotiles.maplibre.org/style.json';

  /// Production-safe fallback styles bundled with the app.
  static const String bundledLightStyleAsset =
      'assets/map_styles/kubus_light.json';
  static const String bundledDarkStyleAsset =
      'assets/map_styles/kubus_dark.json';

  static bool get devFallbackEnabled =>
      AppConfig.isDevelopment && kDebugMode && !kIsWeb;

  static String primaryStyleRef({required bool isDarkMode}) {
    return isDarkMode
        ? AppConfig.mapStyleDarkAsset
        : AppConfig.mapStyleLightAsset;
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
  /// - On **web** we return the plain Flutter *asset key* (a single `assets/`
  ///   segment), NOT a pre-resolved `assets/assets/...` HTTP path. Since
  ///   `maplibre_gl_web` 0.26.2 the web plugin resolves style strings that
  ///   start with `assets/` through `rootBundle` itself, and Flutter's web
  ///   engine adds the served `assets/` directory on top. See
  ///   [_toWebAssetKey] for the full explanation.
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
      return Future<String>.value(_toWebAssetKey(trimmed));
    }

    // Native platforms: pass asset path or file path directly.
    // This is the most compatible option across Android/iOS/desktop.
    return Future<String>.value(trimmed);
  }

  /// Normalizes a bundled-style reference into a plain Flutter **asset key**
  /// with exactly one leading `assets/` segment.
  ///
  /// Why this must NOT pre-apply the web `assets/` prefix
  /// ----------------------------------------------------
  /// Flutter web serves bundled assets from `<base href>assets/<assetKey>`, so
  /// the asset declared in `pubspec.yaml` as `assets/map_styles/kubus_light.json`
  /// is fetched over HTTP from `/assets/assets/map_styles/kubus_light.json`.
  ///
  /// This used to return that doubled HTTP path, because `maplibre_gl_web`
  /// handed the `styleString` straight to MapLibre GL JS, which fetched it as a
  /// plain URL. As of `maplibre_gl_web` 0.26.2 that is no longer true: its
  /// `_sanitizeStyleObject` intercepts any style string starting with `assets/`
  /// and loads it through `rootBundle.loadString(styleString)` instead (so that
  /// styles keep working under a non-root `<base href>`). Flutter's web engine
  /// then resolves that asset *key* to `<base href>assets/<key>`.
  ///
  /// Passing the already-doubled path therefore produced a third prefix:
  /// `rootBundle.loadString('assets/assets/map_styles/kubus_light.json')`
  ///   -> GET `/assets/assets/assets/map_styles/kubus_light.json` -> 404,
  /// which left the map as a permanently blank canvas.
  ///
  /// The plugin now expects the same value web and native do: the asset key.
  static String _toWebAssetKey(String styleRef) {
    var normalized = styleRef.trim();
    if (normalized.isEmpty) return normalized;

    normalized = normalized.replaceAll('\\', '/');
    if (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }

    // Collapse any historically/accidentally doubled `assets/` prefixes (e.g. a
    // stale `--dart-define=MAP_STYLE_LIGHT_ASSET=assets/assets/...`) back to the
    // single-segment asset key the plugin and `rootBundle` expect.
    while (normalized.startsWith('assets/assets/')) {
      normalized = normalized.substring('assets/'.length);
    }

    // Every bundled style asset lives under `assets/` in `pubspec.yaml`, and the
    // plugin only routes strings starting with `assets/` through `rootBundle`.
    if (!normalized.startsWith('assets/')) {
      normalized = 'assets/$normalized';
    }

    return normalized;
  }

  @visibleForTesting
  static String normalizeWebAssetKeyForTest(String styleRef) {
    return _toWebAssetKey(styleRef);
  }
}
