import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> requestWebNotificationPermission() async {
  try {
    // If already allowed, return true
    if (web.Notification.permission == 'granted') return true;

    // requestPermission() returns a JS Promise on web. Avoid dart:js_util here so
    // the analyzer doesn't choke on non-web platforms.
    final statusAny = await (web.Notification.requestPermission() as JSPromise<JSAny?>).toDart;
    final status = (statusAny as JSString?)?.toDart;
    return status == 'granted';
  } catch (_) {
    return false;
  }
}
