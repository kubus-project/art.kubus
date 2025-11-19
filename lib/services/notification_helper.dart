// Conditional helper for web notification permission
// Uses conditional imports to avoid importing dart:html on non-web platforms

import 'dart:async';

import 'notification_helper_stub.dart'
  if (dart.library.html) 'notification_helper_web.dart' as impl;

Future<bool> requestWebNotificationPermission() async => impl.requestWebNotificationPermission();
