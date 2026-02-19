// Conditional helper for web notification permission
// Uses conditional imports to avoid importing dart:html on non-web platforms

import 'notification_helper_stub.dart'
  if (dart.library.js_interop) 'notification_helper_web.dart' as impl;

Future<bool> requestWebNotificationPermission() async => impl.requestWebNotificationPermission();

/// Returns true iff the browser currently reports Notification permission as granted.
///
/// This does NOT prompt the user; it only reflects current browser state.
Future<bool> isWebNotificationPermissionGranted() async =>
    impl.isWebNotificationPermissionGranted();

/// Returns the raw browser Notification permission state.
///
/// Values are typically: `granted`, `denied`, `default`.
/// On non-web platforms this returns `unsupported`.
Future<String> webNotificationPermissionState() async =>
    impl.webNotificationPermissionState();

/// Returns the raw browser Notification permission state synchronously.
///
/// Important for web: permission prompts must be triggered directly from a user
/// gesture. Avoid `await` before calling `Notification.requestPermission()`.
String webNotificationPermissionStateNow() => impl.webNotificationPermissionStateNow();
