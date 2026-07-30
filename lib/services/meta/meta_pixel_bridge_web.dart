import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('fbq')
external JSAny? get _fbq;

@JS('eval')
external void _eval(String code);

@JS('__kubusMetaTrack')
external JSAny? get _kubusMetaTrack;

@JS('__kubusMetaTrack')
external void _callKubusMetaTrack(
  String eventName,
  String parametersJson,
  String eventId,
);

/// Loads and drives the Meta browser pixel.
///
/// The loader snippet is injected only when a pixel id is configured, so a
/// build without one never contacts Meta and never adds a third-party script to
/// the page. `PageView` is deliberately *not* auto-fired: this is a single-page
/// shell where a blanket page view would misattribute every route change, so
/// only explicit conversion events are sent.
///
/// Events go through one small helper installed on `window`, which keeps the
/// `eventID` deduplication contract (browser vs server-side Conversions API) in
/// a single place.
class MetaPixelBridge {
  const MetaPixelBridge._();

  static Completer<bool>? _loaded;

  static Future<bool> load(String pixelId) {
    final existing = _loaded;
    if (existing != null) return existing.future;

    final completer = Completer<bool>();
    _loaded = completer;

    final id = pixelId.trim();
    if (id.isEmpty || !_isSafePixelId(id)) {
      completer.complete(false);
      return completer.future;
    }

    try {
      _installStubAndHelper(id);

      final script =
          web.document.createElement('script') as web.HTMLScriptElement
            ..async = true
            ..src = 'https://connect.facebook.net/en_US/fbevents.js';
      script.onload = (JSAny _) {
        if (!completer.isCompleted) completer.complete(_kubusMetaTrack != null);
      }.toJS;
      script.onerror = (JSAny _) {
        // Blocked by a content blocker, or offline. Measurement is optional.
        if (!completer.isCompleted) completer.complete(false);
      }.toJS;
      web.document.head?.appendChild(script);

      // Never hang the caller on a script that neither loads nor errors.
      Timer(const Duration(seconds: 8), () {
        if (!completer.isCompleted) completer.complete(_kubusMetaTrack != null);
      });
    } catch (_) {
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }

  /// Meta pixel ids are numeric. Validating before interpolating keeps a
  /// misconfigured build define from becoming script injection.
  static bool _isSafePixelId(String id) =>
      RegExp(r'^[0-9]{6,32}$').hasMatch(id);

  static void _installStubAndHelper(String pixelId) {
    final needsStub = _fbq == null;
    final buffer = StringBuffer();
    if (needsStub) {
      buffer.writeln('''
(function(f){
  if (f.fbq) return;
  var n = f.fbq = function(){
    n.callMethod ? n.callMethod.apply(n, arguments) : n.queue.push(arguments);
  };
  if (!f._fbq) f._fbq = n;
  n.push = n; n.loaded = true; n.version = '2.0'; n.queue = [];
})(window);''');
    }
    buffer.writeln("fbq('init', '$pixelId');");
    buffer.writeln('''
window.__kubusMetaTrack = function(name, paramsJson, eventId) {
  try {
    window.fbq('track', name, JSON.parse(paramsJson), { eventID: eventId });
  } catch (e) {}
};''');
    _eval(buffer.toString());
  }

  static Future<void> track({
    required String eventName,
    required String eventId,
    required Map<String, Object?> parameters,
  }) async {
    if (_kubusMetaTrack == null) return;
    _callKubusMetaTrack(eventName, jsonEncode(parameters), eventId);
  }
}
