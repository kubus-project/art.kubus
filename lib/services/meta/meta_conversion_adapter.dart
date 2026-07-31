import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../config/config.dart';
import '../telemetry/telemetry_uuid.dart';
import 'meta_pixel_bridge_stub.dart'
    if (dart.library.js_interop) 'meta_pixel_bridge_web.dart';

/// Feature-flagged bridge to Meta's browser pixel.
///
/// Nothing here runs unless a pixel id is supplied at build time *and* the
/// visitor has analytics enabled, so the default build ships no Meta code path
/// at all. No credential is hardcoded: see `docs/engineering/meta-measurement.md`
/// for the environment variables and the production activation steps.
///
/// The important semantic rule is that `CompleteRegistration` is emitted only
/// when an authenticated account session exists — never when the backend merely
/// accepted a registration form. Each event carries a generated `eventID` so a
/// future server-side Conversions API sender can deduplicate against the
/// browser event.
class MetaConversionAdapter {
  MetaConversionAdapter._();

  static final MetaConversionAdapter instance = MetaConversionAdapter._();

  bool _initialized = false;
  bool _active = false;

  /// True when the pixel is configured, permitted and loaded.
  bool get isActive => _active;

  /// Configured at build time: `--dart-define=META_PIXEL_ID=<id>`.
  static String get pixelId => AppConfig.metaPixelId;

  static bool get isConfigured =>
      AppConfig.enableMetaPixel && pixelId.trim().isNotEmpty;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    if (!isConfigured) return;
    if (!AppConfig.isFeatureEnabled('analytics')) return;

    // Honour the same opt-out that gates first-party telemetry. A visitor who
    // turned analytics off must not be measured by a third party either.
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('enableAnalytics') ?? true)) return;
    } catch (_) {
      return;
    }

    try {
      _active = await MetaPixelBridge.load(pixelId.trim());
    } catch (e) {
      AppConfig.debugPrint('MetaConversionAdapter: pixel load failed: $e');
      _active = false;
    }
  }

  /// Public content view. Carries only a coarse content type and id.
  Future<void> trackViewContent({
    required String contentType,
    required String contentId,
  }) async {
    await ensureInitialized();
    if (!_active) return;
    await _emit('ViewContent', <String, Object?>{
      'content_type': contentType,
      'content_ids': <String>[contentId],
    });
  }

  /// Emitted only once a usable authenticated session exists.
  ///
  /// [userId] is passed through as an opaque identifier for deduplication with
  /// a server-side event; no email, name or other personal data is sent.
  Future<void> trackCompleteRegistration({
    required String method,
    String? userId,
  }) async {
    await ensureInitialized();
    if (!_active) return;
    await _emit('CompleteRegistration', <String, Object?>{
      'status': 'activated',
      'method': method,
      if (userId != null && userId.isNotEmpty) 'external_id': userId,
    });
  }

  Future<void> _emit(String eventName, Map<String, Object?> parameters) async {
    try {
      await MetaPixelBridge.track(
        eventName: eventName,
        eventId: TelemetryUuid.v4(),
        parameters: parameters,
      );
    } catch (e) {
      // Measurement must never break the funnel it is measuring.
      AppConfig.debugPrint('MetaConversionAdapter: $eventName failed: $e');
    }
  }
}
