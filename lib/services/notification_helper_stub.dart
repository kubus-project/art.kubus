import 'dart:async';

Future<bool> requestWebNotificationPermission() async {
  // Browser Notification permission does not exist on non-web platforms.
  return false;
}

Future<bool> isWebNotificationPermissionGranted() async {
  // Browser Notification permission does not exist on non-web platforms.
  return false;
}
