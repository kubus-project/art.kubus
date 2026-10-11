import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Reads `navigator.connection.saveData`. Browsers without the Network
/// Information API, or with the field missing, report no data saver.
bool communityVideoDataSaverEnabled() {
  try {
    final navigator = web.window.navigator as JSObject;
    final connection = navigator.getProperty<JSObject?>('connection'.toJS);
    if (connection == null) return false;
    final saveData = connection.getProperty<JSBoolean?>('saveData'.toJS);
    return saveData?.toDart ?? false;
  } catch (_) {
    return false;
  }
}
