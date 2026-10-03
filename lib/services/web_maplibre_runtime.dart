import 'web_maplibre_runtime_stub.dart'
    if (dart.library.js_interop) 'web_maplibre_runtime_web.dart';

Future<void> ensureWebMapLibreRuntimeReady() =>
    ensureWebMapLibreRuntimeReadyImpl();

/// Sets the colour shown behind the map canvas on web.
///
/// A globe leaves transparent space around the sphere; without this it takes
/// the static boot colour from `index.html`, which belongs to neither theme.
/// No-op off web.
void setWebMapGroundColor(int argb) => setWebMapGroundColorImpl(argb);
