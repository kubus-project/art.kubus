import 'dart:js_interop';
import 'package:web/web.dart' as web;

String? readFamilyConsentContext() {
  try {
    final values = <String, String>{};
    for (final part in web.document.cookie.split(';')) {
      final equal = part.indexOf('=');
      if (equal < 0) continue;
      final key = part.substring(0, equal).trim();
      if (key == 'kubus_cookie_consent' || key == 'kubus_consent_revision') {
        final value = Uri.decodeComponent(part.substring(equal + 1));
        if (values.containsKey(key)) return '!unavailable';
        values[key] = value;
      }
    }
    return '${values['kubus_cookie_consent'] ?? ''}|${values['kubus_consent_revision'] ?? ''}';
  } catch (_) {
    return '!unavailable';
  }
}

void Function() observeFamilyConsentContext(void Function() changed) {
  var previous = readFamilyConsentContext();
  void check() {
    final next = readFamilyConsentContext();
    if (next != previous) {
      previous = next;
      changed();
    }
  }

  final listener = ((web.Event _) => check()).toJS;
  // A browser interval, not a Dart Timer: the page-lifetime observer must not
  // register with a test zone's fake clock, and it is cancelled below.
  final interval = web.window.setInterval((() => check()).toJS, 500.toJS);
  web.window.addEventListener('focus', listener);
  web.document.addEventListener('visibilitychange', listener);
  return () {
    web.window.clearInterval(interval);
    web.window.removeEventListener('focus', listener);
    web.document.removeEventListener('visibilitychange', listener);
  };
}
