import 'dart:async';
import 'dart:js_util' as js_util;

import 'package:web/web.dart' as web;

Future<bool> requestWebNotificationPermission() async {
  try {
    // If already allowed, return true
    if (web.Notification.permission == 'granted') return true;

    final status = await js_util.promiseToFuture<String>(
      web.Notification.requestPermission(),
    );
    return status == 'granted';
  } catch (_) {
    return false;
  }
}
