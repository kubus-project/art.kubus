import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Do Not Track or Global Privacy Control in this browser.
///
/// The website's optional collectors send nothing while either is on, even
/// after Accept; the app follows the same rule (no prompt, no optional
/// telemetry), pending the owner's policy decision on these signals (#203).
bool browserPrivacySignal() {
  try {
    final navigator = globalContext.getProperty<JSObject?>('navigator'.toJS);
    if (navigator == null) return false;
    final gpc = navigator.getProperty<JSAny?>('globalPrivacyControl'.toJS);
    if (gpc != null && gpc.isA<JSBoolean>() && (gpc as JSBoolean).toDart) {
      return true;
    }
    final dnt = navigator.getProperty<JSAny?>('doNotTrack'.toJS);
    if (dnt != null && dnt.isA<JSString>() && (dnt as JSString).toDart == '1') {
      return true;
    }
    final windowDnt = globalContext.getProperty<JSAny?>('doNotTrack'.toJS);
    return windowDnt != null &&
        windowDnt.isA<JSString>() &&
        (windowDnt as JSString).toDart == '1';
  } catch (_) {
    return false;
  }
}
