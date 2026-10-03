import 'package:flutter/foundation.dart';

import '../../../config/config.dart';

/// What the active map renderer can draw. One value, resolved once, read by the
/// existing map owners (`ArtMapView`, `KubusMapController`, the two screens).
///
/// It is deliberately tiny. Wave 5B-0 measured the real `maplibre_gl 0.26.2`
/// stack: the plugin has no projection API at all, MapLibre GL JS 5.x honours a
/// style-level `projection: globe` on web (Chromium and Firefox), and the
/// native Android renderer accepts the same style but draws flat Mercator.
/// iOS could not be exercised and is treated as flat. Camera, markers,
/// selection, clusters, filters and constraints are identical either way; a
/// flat renderer is a coherent fallback, never a second map.
@immutable
class KubusMapCapabilities {
  const KubusMapCapabilities({required this.supportsGlobe});

  /// The basemap can be drawn as a globe (style-level projection).
  final bool supportsGlobe;

  /// Flat Mercator renderer: the fallback every platform can run.
  static const KubusMapCapabilities flat =
      KubusMapCapabilities(supportsGlobe: false);

  /// Globe-capable renderer.
  static const KubusMapCapabilities globe =
      KubusMapCapabilities(supportsGlobe: true);

  /// Pure resolution rule, separated so the matrix is testable.
  ///
  /// [isWeb] is true only for the MapLibre GL JS renderer vendored under
  /// `web/local/maplibre-gl` (5.x, guarded by a test). [globeEnabled] is the
  /// `mapGlobe` feature flag.
  static KubusMapCapabilities resolve({
    required bool isWeb,
    required bool globeEnabled,
  }) {
    return isWeb && globeEnabled ? globe : flat;
  }

  /// Capabilities of the renderer running right now.
  static KubusMapCapabilities get current => _override ?? _resolveCurrent();

  static KubusMapCapabilities? _override;

  static KubusMapCapabilities _resolveCurrent() => resolve(
        isWeb: kIsWeb,
        globeEnabled: AppConfig.isFeatureEnabled('mapGlobe'),
      );

  /// Test seam: force a capability value (pass null to restore).
  @visibleForTesting
  static void debugOverride(KubusMapCapabilities? value) => _override = value;

  @override
  bool operator ==(Object other) =>
      other is KubusMapCapabilities && other.supportsGlobe == supportsGlobe;

  @override
  int get hashCode => supportsGlobe.hashCode;

  @override
  String toString() => 'KubusMapCapabilities(supportsGlobe: $supportsGlobe)';
}
