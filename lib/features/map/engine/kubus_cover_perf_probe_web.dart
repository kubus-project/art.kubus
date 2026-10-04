import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void recordKubusCoverPhase(String phase, double milliseconds) {
  final sink = globalContext.getProperty<JSAny?>('__kubusCoverPerf'.toJS);
  if (sink == null || !sink.isA<JSArray>()) return;
  final entry = JSObject()
    ..setProperty('phase'.toJS, phase.toJS)
    ..setProperty('ms'.toJS, milliseconds.toJS);
  (sink as JSObject).callMethod<JSAny?>('push'.toJS, entry);
}
