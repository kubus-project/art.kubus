import 'package:http/http.dart' as http;

/// Non-web implementation.
http.Client createPlatformHttpClient() {
  return http.Client();
}
