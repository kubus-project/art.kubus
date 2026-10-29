import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Web implementation for URL strategy configuration.
void configureUrlStrategy() {
  // Canonical share URLs (e.g. https://app.kubus.site/m/<id>) rely on
  // path-based routing on Flutter web.
  // Keep URL fragments in RouteInformation during browser history traversal.
  // The default PathUrlStrategy intentionally omits fragments from getPath().
  setUrlStrategy(PathUrlStrategy(const BrowserPlatformLocation(), true));
}
