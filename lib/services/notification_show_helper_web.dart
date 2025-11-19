import 'dart:html' as html;

Future<void> showNotification(String title, String body, [Map<String, dynamic>? data]) async {
  try {
    // Build options as Map so we can pass a JS-style options object to showNotification
    final options = {
      'body': body,
      'data': data,
    };

    // If permission not granted, attempt to request it
    if (html.Notification.permission != 'granted') {
      final status = await html.Notification.requestPermission();
      if (status != 'granted') return;
    }

    // Prefer service worker registration so notification persists even if tab is closed
    try {
      final swContainer = html.window.navigator.serviceWorker;
      if (swContainer != null) {
        final reg = await swContainer.getRegistration();
        await reg.showNotification(title, options);
        return;
      }
    } catch (e) {
      // ignore and fallback to in-page Notification
    }

    // Fallback: constructor with only title (some dart:html bindings do not accept options)
    try {
      html.Notification(title);
    } catch (e) {
      // If this fails, do nothing. Avoid throwing in release builds.
    }
  } catch (e) {
    // ignore errors
  }
}
