Future<void> showNotification(String title, String body, [Map<String, dynamic>? data]) async {
  // No-op for platforms where web notifications are not available.
  // The actual app usually shows in-app or native notifications on non-web platforms.
  return;
}
