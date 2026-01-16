// Conditional helper for web notification permission
// Uses conditional imports to avoid importing dart:html on non-web platforms

import 'dart:async';

import 'notification_helper_stub.dart'
  if (dart.library.js_interop) 'notification_helper_web.dart' as impl;

Future<bool> requestWebNotificationPermission() async => impl.requestWebNotificationPermission();

/// Returns true iff the browser currently reports Notification permission as granted.
///
/// This does NOT prompt the user; it only reflects current browser state.
Future<bool> isWebNotificationPermissionGranted() async =>
    impl.isWebNotificationPermissionGranted();
