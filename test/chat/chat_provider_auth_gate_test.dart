import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
  });

  test('initialize skips protected chat bootstrap when no session is available',
      () async {
    final requestPaths = <String>[];
    BackendApiService().setHttpClient(
      MockClient((request) async {
        requestPaths.add(request.url.path);
        return http.Response('Unauthorized', 401);
      }),
    );

    final provider = ChatProvider();
    await provider.initialize();

    expect(requestPaths, isEmpty);
    expect(provider.conversations, isEmpty);
  });
}
