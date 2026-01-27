import 'maplibre_web_registration_stub.dart'
    if (dart.library.js_interop) 'maplibre_web_registration_web.dart';

/// Ensures the MapLibre web implementation is registered.
///
/// In Flutter web release builds (especially when served behind aggressive
/// caching/service workers), plugin auto-registration can be bypassed or stale,
/// causing `maplibre_gl` to fall back to the method-channel implementation and
/// throw "TargetPlatform.windows is not yet supported by the maps plugin".
///
/// This function is safe to call multiple times.
void ensureMapLibreWebRegistration() => ensureMapLibreWebRegistrationImpl();

