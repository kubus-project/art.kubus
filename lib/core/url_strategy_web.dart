import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Web implementation for URL strategy configuration.
void configureUrlStrategy() {
  // Canonical share URLs (e.g. https://app.kubus.site/marker/<id>) rely on
  // path-based routing on Flutter web.
  usePathUrlStrategy();
}
