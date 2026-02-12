Future<void> showNotification(String title, String body, [Map<String, dynamic>? data]) async {
  // Browser Notification API is unavailable on non-web platforms.
  // Native notifications are handled via PushNotificationService directly.
  return;
}
