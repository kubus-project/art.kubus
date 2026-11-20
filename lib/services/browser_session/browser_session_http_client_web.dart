import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// Credentialed client reserved for the browser-session endpoints. The cookie
/// is HttpOnly and host-only, so the browser must send it with `credentials:
/// 'include'`. The general API client keeps `withCredentials = false`
/// (see http_client_factory_web.dart).
http.Client createBrowserSessionHttpClient() {
  final client = BrowserClient()..withCredentials = true;
  return client;
}
