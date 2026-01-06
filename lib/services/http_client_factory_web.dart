import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// Web implementation.
///
/// Note: This app primarily uses Bearer tokens (Authorization header), not cookies.
/// Setting `withCredentials=true` forces browsers to require
/// `Access-Control-Allow-Credentials: true` (and non-wildcard ACAO) on the API.
///
/// Production `api.kubus.site` is typically configured with wildcard CORS; therefore
/// credentials must remain disabled here, otherwise Flutter Web requests will fail
/// with CORS errors like "expected 'true' in CORS header 'Access-Control-Allow-Credentials'".
http.Client createPlatformHttpClient() {
  final client = BrowserClient()..withCredentials = false;
  return client;
}
