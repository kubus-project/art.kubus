import 'package:flutter/foundation.dart';

/// Stub: WebGL context is always healthy on non-web platforms.
final ValueNotifier<bool> webGLContextHealthy = ValueNotifier<bool>(true);

/// Stub: non-web platforms don't expose this CSS media query.
bool prefersReducedMotion() {
  return false;
}

/// Non-web fallback: no WebGL context handling is required.
void initWebGLContextHelper() {
  return;
}
