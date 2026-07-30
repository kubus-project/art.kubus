/// Non-web bridge: there is no Meta browser pixel outside the web target.
///
/// Native builds intentionally have no Meta measurement path. Keeping this a
/// hard no-op (rather than routing native events elsewhere) means a mobile
/// build can never emit a conversion the web pixel is also reporting.
class MetaPixelBridge {
  const MetaPixelBridge._();

  static Future<bool> load(String pixelId) async => false;

  static Future<void> track({
    required String eventName,
    required String eventId,
    required Map<String, Object?> parameters,
  }) async {}
}
