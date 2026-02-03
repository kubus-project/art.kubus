import 'map_attribution_helper_io.dart'
    if (dart.library.js_interop) 'map_attribution_helper_web.dart';

/// Web-only helper for positioning the MapLibre attribution control.
///
/// On web, the maplibre_gl plugin does not support attribution margins, so we
/// move the native MapLibre GL JS attribution control using CSS variables.
/// On non-web platforms, these calls are no-ops.
abstract class MapAttributionHelper {
  static void setMobileMapEnabled(bool enabled) {
    MapAttributionHelperImpl.setMobileMapEnabled(enabled);
  }

  static void setMobileMapAttributionBottomPx(double bottomPx) {
    MapAttributionHelperImpl.setMobileMapAttributionBottomPx(bottomPx);
  }
}

