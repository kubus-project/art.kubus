import 'notification_show_helper_stub.dart'
  if (dart.library.html) 'notification_show_helper_web.dart' as impl;

Future<void> showNotification(String title, String body, [Map<String, dynamic>? data]) => impl.showNotification(title, body, data);
