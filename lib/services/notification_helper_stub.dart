import 'dart:async';

Future<bool> requestWebNotificationPermission() async {
  // Not supported on non-web platforms. Return false.
  return Future.value(false);
}

Future<bool> isWebNotificationPermissionGranted() async {
  // Not supported on non-web platforms.
  return Future.value(false);
}
