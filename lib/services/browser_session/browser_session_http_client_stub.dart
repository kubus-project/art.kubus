import 'package:http/http.dart' as http;

/// Native builds never call the browser-session endpoints; a plain client keeps
/// the library compiling everywhere.
http.Client createBrowserSessionHttpClient() => http.Client();
