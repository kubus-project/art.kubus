import 'package:flutter/foundation.dart';

/// Stub: WebGL context is always healthy on non-web platforms.
final ValueNotifier<bool> webGLContextHealthy = ValueNotifier<bool>(true);

/// Stub: non-web platforms don't expose this CSS media query.
bool prefersReducedMotion() => false;

/// Stub: no WebGL context handling needed on non-web platforms.
void initWebGLContextHelper() {
  // No-op on non-web platforms.
}
