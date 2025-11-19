import 'dart:async';
import 'dart:html' as html;

Future<bool> requestWebNotificationPermission() async {
  try {
    // If already allowed, return true
    if (html.Notification.permission == 'granted') return true;

    final status = await html.Notification.requestPermission();
    return status == 'granted';
  } catch (e) {
    return false;
  }
}
