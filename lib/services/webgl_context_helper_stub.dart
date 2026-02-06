/// Stub implementation for non-web platforms.
///
/// On web, [webgl_context_helper_web.dart] provides JS interop bindings to
/// detect WebGL context loss and disable BackdropFilter effects gracefully.
void initWebGLContextHelper() {
  // No-op on non-web platforms
}

/// Returns true when the app is running in Firefox.
///
/// Web-only implementation lives in `webgl_context_helper_web.dart`.
bool isFirefoxBrowser() {
  return false;
}
