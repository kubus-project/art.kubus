import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

String webNotificationPermissionStateNow() {
  try {
    return web.Notification.permission;
  } catch (_) {
    return 'unsupported';
  }
}

Future<bool> requestWebNotificationPermission() async {
  try {
    // If already allowed, return true
    if (webNotificationPermissionStateNow() == 'granted') return true;

    // requestPermission() returns a JS Promise on web. Avoid dart:js_util here so
    // the analyzer doesn't choke on non-web platforms.
    final statusAny = await (web.Notification.requestPermission() as JSPromise<JSAny?>).toDart;
    final status = (statusAny as JSString?)?.toDart;
    return status == 'granted';
  } catch (_) {
    return false;
  }
}

Future<bool> isWebNotificationPermissionGranted() async {
  try {
    return webNotificationPermissionStateNow() == 'granted';
  } catch (_) {
    return false;
  }
}

Future<String> webNotificationPermissionState() async {
  return webNotificationPermissionStateNow();
}
