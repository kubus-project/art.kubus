import 'package:http/http.dart' as http;

import 'http_client_factory_stub.dart'
    if (dart.library.js_interop) 'http_client_factory_web.dart' as impl;

/// Creates the HTTP client used for all backend API requests.
///
/// - Mobile/desktop: normal [http.Client].
/// - Web: a [BrowserClient] configured to allow credentialed requests.
///   This enables cookie-based auth when the backend uses it and is also
///   required for some CORS+credential configurations.
http.Client createPlatformHttpClient() => impl.createPlatformHttpClient();
