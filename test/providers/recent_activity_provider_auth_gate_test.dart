import 'package:art_kubus/providers/recent_activity_provider.dart';
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

  test(
      'refresh keeps local activity flow without hitting backend notifications when signed out',
      () async {
    final requestPaths = <String>[];
    final api = BackendApiService();
    api.setHttpClient(
      MockClient((request) async {
        requestPaths.add(request.url.path);
        return http.Response('Unauthorized', 401);
      }),
    );

    final provider = RecentActivityProvider(
      backendApiService: api,
    );

    await provider.refresh(force: true);

    expect(requestPaths, isEmpty);
    expect(provider.error, isNull);
    expect(provider.activities, isEmpty);
  });
}
