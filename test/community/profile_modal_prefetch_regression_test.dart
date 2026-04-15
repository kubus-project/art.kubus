import 'dart:convert';

import 'package:art_kubus/screens/community/profile_screen_methods.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:art_kubus/services/backend_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('fetchFollowersForWallet uses cache when fresh', () async {
    const wallet = 'wallet_prefetch_cache_regression';
    var followersCalls = 0;

    final api = BackendApiService();
    api.setHttpClient(MockClient((request) async {
      final path = request.url.path;

      if (path.contains('/api/community/followers/')) {
        followersCalls += 1;
        return http.Response(
          jsonEncode(<String, Object?>{
            'data': <Map<String, Object?>>[
              <String, Object?>{
                'walletAddress': 'follower_wallet_1',
                'displayName': 'Follower One',
                'username': 'follower.one',
              },
            ],
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }

      if (path.contains('/api/community/following/')) {
        return http.Response(
          jsonEncode(<String, Object?>{'data': <Object?>[]}),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }

      if (path.contains('/api/artworks')) {
        return http.Response(
          jsonEncode(<String, Object?>{'data': <Object?>[]}),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }

      return http.Response('Not found', 404);
    }));

    final first = await ProfileScreenMethods.fetchFollowersForWallet(
      wallet,
      force: true,
    );
    final second = await ProfileScreenMethods.fetchFollowersForWallet(wallet);

    expect(first, isNotEmpty);
    expect(second, isNotEmpty);
    expect(followersCalls, 1,
        reason:
            'Fresh follower cache should satisfy subsequent reads without refetching.');
  });

}
