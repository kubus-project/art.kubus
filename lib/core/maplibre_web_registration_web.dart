import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:maplibre_gl_web/maplibre_gl_web.dart';

void ensureMapLibreWebRegistrationImpl() {
  try {
    MapLibreMapPlugin.registerWith(webPluginRegistrar);
  } catch (_) {
    // Intentionally swallow: failing to register shouldn't crash startup;
    // callers can still handle map failures gracefully.
  }
}

