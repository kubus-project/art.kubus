import 'dart:async';

String webNotificationPermissionStateNow() {
  return 'unsupported';
}

Future<bool> requestWebNotificationPermission() async {
  // Browser Notification permission does not exist on non-web platforms.
  return false;
}

Future<bool> isWebNotificationPermissionGranted() async {
  // Browser Notification permission does not exist on non-web platforms.
  return false;
}

Future<String> webNotificationPermissionState() async {
  return webNotificationPermissionStateNow();
}
