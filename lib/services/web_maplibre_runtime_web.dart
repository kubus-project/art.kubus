import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

const String _runtimePromiseName = 'kubusMapLibreRuntimeReady';
const String _runtimeScriptId = 'kubus-maplibre-runtime-loader';

Future<void>? _runtimeFuture;

Future<void> ensureWebMapLibreRuntimeReadyImpl() {
  return _runtimeFuture ??= _ensureRuntime();
}

Future<void> _ensureRuntime() async {
  var promise = _runtimePromise();
  if (promise == null) {
    await _loadRuntimeScript();
    promise = _runtimePromise();
  }
  if (promise == null) {
    throw StateError(
      'MapLibre runtime script loaded without exposing $_runtimePromiseName.',
    );
  }
  await promise.toDart;
}

JSPromise<JSAny?>? _runtimePromise() {
  final windowObject = JSObject.fromInteropObject(web.window);
  final value = windowObject.getProperty<JSAny?>(_runtimePromiseName.toJS);
  return value?.isA<JSPromise<JSAny?>>() ?? false
      ? value as JSPromise<JSAny?>
      : null;
}

Future<void> _loadRuntimeScript() async {
  final existing = web.document.getElementById(_runtimeScriptId);
  final script = existing?.isA<web.HTMLScriptElement>() ?? false
      ? existing as web.HTMLScriptElement
      : web.document.createElement('script') as web.HTMLScriptElement;
  final completer = Completer<void>();

  late final JSFunction onLoad;
  late final JSFunction onError;
  void cleanUp() {
    script.removeEventListener('load', onLoad);
    script.removeEventListener('error', onError);
  }

  onLoad = ((web.Event _) {
    cleanUp();
    if (!completer.isCompleted) completer.complete();
  }).toJS;
  onError = ((web.Event _) {
    cleanUp();
    if (!completer.isCompleted) {
      completer.completeError(
        StateError('Unable to load /kubus_maplibre_runtime.js.'),
      );
    }
  }).toJS;
  script.addEventListener('load', onLoad);
  script.addEventListener('error', onError);

  if (existing == null) {
    script.id = _runtimeScriptId;
    script.src = '/kubus_maplibre_runtime.js';
    script.async = true;
    final parent = web.document.head ?? web.document.body;
    if (parent == null) {
      cleanUp();
      throw StateError('Document has no element for the MapLibre runtime.');
    }
    parent.appendChild(script);
  }

  await completer.future;
}
