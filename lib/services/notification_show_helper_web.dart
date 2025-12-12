import 'dart:js_util' as js_util;

import 'package:web/web.dart' as web;

Future<void> showNotification(String title, String body, [Map<String, dynamic>? data]) async {
  try {
    final options = web.NotificationOptions(
      body: body,
      data: data == null ? null : js_util.jsify(data),
    );

    // If permission not granted, attempt to request it
    if (web.Notification.permission != 'granted') {
      final status = await js_util.promiseToFuture<String>(
        web.Notification.requestPermission(),
      );
      if (status != 'granted') return;
    }

    // Prefer service worker registration so notification persists even if tab is closed
    try {
      final swContainer = web.window.navigator.serviceWorker;
      // Note: getRegistration() is allowed to resolve to null when there's no
      // active registration. Some web bindings surface this as a JS Promise
      // that completes with `null`, which can crash if we await it with a
      // non-nullable generic type.
      final regAny = await js_util.promiseToFuture(swContainer.getRegistration());
      if (regAny != null) {
        final reg = regAny as web.ServiceWorkerRegistration;
        await js_util.promiseToFuture(reg.showNotification(title, options));
        return;
      }
        } catch (_) {
      // ignore and fallback to in-page Notification
    }

    // Fallback to in-page Notification
    try {
      web.Notification(title, options);
      return;
    } catch (_) {
      // ignore and fall back to title-only notification below
    }

    // Some bindings/environments may not accept options; use title-only.
    try {
      web.Notification(title);
    } catch (_) {}
  } catch (e) {
    // ignore errors
  }
}
