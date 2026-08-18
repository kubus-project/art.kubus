import 'package:flutter/foundation.dart';

/// Maximum length for any single free-form diagnostic string.
const int kMaxDiagnosticFieldLength = 240;

/// Builds bounded, non-identifying context for an unhandled error report.
///
/// The production incident on `/main/tab/map` arrived as nothing but
/// `FlutterError: Null check operator used on a null value`, because the
/// handler forwarded only `details.exception` and `details.stack` and dropped
/// the rest of [FlutterErrorDetails]. The fields collected here are what turn
/// that message into something actionable — in particular
/// `details.context?.toDescription()`, which names the subtree that was
/// building when the error was thrown (for example
/// "while building KubusNearbyArtPanel").
///
/// Everything collected is either a framework-owned constant
/// ([FlutterErrorDetails.library]), a widget-ancestry description built from
/// class names ([FlutterErrorDetails.context]), a type name, or a
/// device-geometry scalar. No user content, credentials, wallet address,
/// location, or request payload is reachable from any of these fields.
///
/// This function never throws. A failure while describing an error would
/// replace the original report with a less useful one, so every source is
/// individually guarded and partial results are returned as-is.
Map<String, dynamic>? buildFlutterErrorContext(
  Object error,
  FlutterErrorDetails? details,
) {
  final context = <String, dynamic>{};

  void put(String key, String? value) {
    if (value == null) return;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    context[key] = trimmed.length > kMaxDiagnosticFieldLength
        ? trimmed.substring(0, kMaxDiagnosticFieldLength)
        : trimmed;
  }

  try {
    put('exception_type', error.runtimeType.toString());
  } catch (_) {
    // A pathological runtimeType override must not abort the report.
  }

  if (details != null) {
    try {
      put('flutter_library', details.library);
    } catch (_) {
      // Keep whatever context has already been collected.
    }
    try {
      put('flutter_context', details.context?.toDescription());
    } catch (_) {
      // toDescription() runs diagnostics code that may itself throw.
    }
    try {
      if (details.silent) context['flutter_silent'] = true;
    } catch (_) {
      // Ignore.
    }
  }

  try {
    context['is_web'] = kIsWeb;
    final dispatcher = PlatformDispatcher.instance;
    final view = dispatcher.implicitView;
    if (view != null) {
      final ratio = view.devicePixelRatio;
      if (ratio > 0) {
        // Logical pixels. This incident only reproduced on a narrow mobile
        // viewport, so the geometry is load-bearing for triage.
        context['viewport_width'] = (view.physicalSize.width / ratio).round();
        context['viewport_height'] = (view.physicalSize.height / ratio).round();
        context['device_pixel_ratio'] = double.parse(ratio.toStringAsFixed(2));
      }
    }
    put('locale', dispatcher.locale.toLanguageTag());
  } catch (_) {
    // Platform geometry is best-effort only.
  }

  return context.isEmpty ? null : context;
}
