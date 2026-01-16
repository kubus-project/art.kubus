// Web URL strategy configuration.
//
// This file is safe to import from all platforms; it uses conditional imports
// so mobile/desktop builds do not pull in flutter_web_plugins (web-only).

import 'url_strategy_stub.dart'
    if (dart.library.html) 'url_strategy_web.dart' as impl;

/// Configures URL strategy for Flutter web.
///
/// On non-web platforms this is a no-op.
void configureUrlStrategy() => impl.configureUrlStrategy();
