import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'kubus_map_platform_backdrop_controller.dart';

/// Dart side of the iOS native map-backdrop blur host.
///
/// Mirrors the web DOM/CSS host: glass surfaces over the MapLibre platform
/// view register screen-space regions via [KubusMapBackdropRegionTracker], and
/// the native side hosts real blur views — Apple's Liquid Glass
/// (`UIGlassEffect`) on iOS 26+, `UIVisualEffectView` materials below —
/// sandwiched between the map platform view and Flutter's overlay layer.
///
/// Fail-safe by design: support starts `false`, is confirmed by a one-shot
/// native probe, and any channel error demotes the host back to unsupported so
/// iOS falls back to the enriched tint sheen exactly as before.
class KubusMapNativeBackdropChannel {
  const KubusMapNativeBackdropChannel._();

  static const MethodChannel _channel =
      MethodChannel('art.kubus/map_native_backdrop');

  static bool? _supported;
  static Future<bool>? _probe;

  /// Cached, synchronous support flag.
  ///
  /// Returns `false` until the native probe completes. The first call kicks
  /// off the probe; map chrome re-resolves its blur decision on every build,
  /// so the confirmed value engages on the next frame after the probe lands.
  static bool get isSupported {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    final cached = _supported;
    if (cached != null) return cached;
    unawaited(probeSupport());
    return false;
  }

  /// One-shot native capability probe (memoized).
  static Future<bool> probeSupport() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      _supported = false;
      return Future<bool>.value(false);
    }
    return _probe ??=
        _channel.invokeMethod<bool>('isSupported').then((value) {
      _supported = value ?? false;
      return _supported!;
    }).catchError((Object _) {
      _supported = false;
      return false;
    });
  }

  /// Pushes the current backdrop regions to the native host.
  ///
  /// Regions are in Flutter logical pixels (== iOS points) in the root view's
  /// coordinate space; the native side converts them into the map view's space
  /// and clamps to its bounds.
  static Future<void> syncRegions({
    required bool enabled,
    required List<KubusMapBackdropRegion> regions,
  }) async {
    if (_supported != true) return;
    try {
      if (!enabled || regions.isEmpty) {
        await _channel.invokeMethod<void>('clearRegions');
        return;
      }
      await _channel.invokeMethod<void>('syncRegions', <String, dynamic>{
        'regions': <Map<String, dynamic>>[
          for (final region in regions)
            if (region.visible && region.rect.isFinite)
              <String, dynamic>{
                'id': region.id,
                'left': region.rect.left,
                'top': region.rect.top,
                'width': region.rect.width,
                'height': region.rect.height,
                'cornerRadius': region.borderRadius.topLeft.x,
                'blurSigma': region.blurSigma,
              },
        ],
      });
    } catch (_) {
      // Any platform failure demotes the host: the next blur decision falls
      // back to the enriched tint sheen instead of a host that does nothing.
      _supported = false;
    }
  }

  /// Removes all native blur views (host teardown).
  static Future<void> disposeRegions() async {
    if (_supported != true) return;
    try {
      await _channel.invokeMethod<void>('clearRegions');
    } catch (_) {
      _supported = false;
    }
  }

  @visibleForTesting
  static void debugReset({bool? supportedOverride}) {
    _supported = supportedOverride;
    _probe = null;
  }
}
