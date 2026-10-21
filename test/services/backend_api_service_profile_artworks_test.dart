import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object? payload) {
  return http.Response(
    jsonEncode(payload),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  test('getProfileArtworks honours an echoed relationship scope', () async {
    // Unique wallet per test: the rate-limit window is process-wide per path.
    const wallet = 'profile_artworks_echo_wallet_0001';
    final requests = <http.Request>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request);
      return _json(<String, Object?>{
        'data': <Map<String, Object?>>[
          <String, Object?>{'id': 'authored-1', 'title': 'Authored one'},
        ],
        'relationship': 'authored',
        'pagination': <String, Object?>{'total': 7, 'limit': 6, 'offset': 0},
      });
    }));

    final page = await BackendApiService().getProfileArtworks(
      wallet,
      relationship: 'authored',
      limit: 6,
    );

    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/api/profiles/$wallet/artworks');
    expect(requests.single.url.queryParameters['relationship'], 'authored');
    expect(requests.single.url.queryParameters['limit'], '6');
    expect(page.relationshipHonoured, isTrue);
    expect(page.total, 7);
    expect(page.items, hasLength(1));
    expect(page.items.single['id'], 'authored-1');
  });

  test('getProfileArtworks flags a non-echoing legacy response as unscoped',
      () async {
    const wallet = 'profile_artworks_legacy_wallet_0002';
    BackendApiService().setHttpClient(MockClient((request) async {
      // Legacy backends ignore `relationship` and return a mixed list.
      return _json(<String, Object?>{
        'data': <Map<String, Object?>>[
          <String, Object?>{'id': 'legacy-1'},
          <String, Object?>{'id': 'legacy-2'},
        ],
      });
    }));

    final page = await BackendApiService().getProfileArtworks(
      wallet,
      relationship: 'documented',
      limit: 6,
    );

    expect(page.relationshipHonoured, isFalse);
    expect(page.items.map((item) => item['id']),
        <Object?>['legacy-1', 'legacy-2']);
    // Without pagination the total falls back to the item count.
    expect(page.total, 2);
  });

  test('getProfileArtworks treats a different echoed scope as not honoured',
      () async {
    const wallet = 'profile_artworks_mismatch_wallet_0003';
    BackendApiService().setHttpClient(MockClient((request) async {
      return _json(<String, Object?>{
        'data': <Map<String, Object?>>[
          <String, Object?>{'id': 'managed-1'},
        ],
        'relationship': 'managed',
      });
    }));

    final page = await BackendApiService().getProfileArtworks(
      wallet,
      relationship: 'authored',
    );

    expect(page.relationshipHonoured, isFalse);
  });
}
