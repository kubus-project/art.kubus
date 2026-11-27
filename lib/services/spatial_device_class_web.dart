import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'spatial_device_class.dart';

/// Browser signals: coarse primary pointer, viewport width and, where the
/// browser exposes it (Chromium only), `navigator.deviceMemory`.
SpatialDeviceSignals readSpatialDeviceSignals() {
  var coarse = false;
  double? width;
  double? memory;
  try {
    coarse = web.window.matchMedia('(pointer: coarse)').matches;
  } catch (_) {}
  try {
    width = web.window.innerWidth.toDouble();
  } catch (_) {}
  try {
    final value = (web.window.navigator as JSObject)
        .getProperty<JSAny?>('deviceMemory'.toJS);
    if (value != null && value.isA<JSNumber>()) {
      memory = (value as JSNumber).toDartDouble;
    }
  } catch (_) {}
  return SpatialDeviceSignals(
    coarsePointer: coarse,
    viewportWidth: width,
    deviceMemoryGb: memory,
  );
}
