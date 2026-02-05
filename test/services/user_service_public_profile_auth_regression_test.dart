import 'dart:convert';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/user_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await UserService.clearCache();
  });

  test('Viewing another user profile does not fetch self-only achievements',
      () async {
    const myWallet = '4Nd1mYbF7kYgU7kD3bcd1q2w4gS7y8Z9xKLMNPQRSTU';
    const otherWallet = '6Nd1mYbF7kYgU7kD3bcd1q2w4gS7y8Z9xKLMNPQRSTV';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PreferenceKeys.walletAddress, myWallet);

    final requests = <http.Request>[];
    final api = BackendApiService();
    api.setHttpClient(MockClient((request) async {
      requests.add(request);

      if (request.url.path.contains('/api/profiles/')) {
        return http.Response(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'walletAddress': otherWallet,
              'username': 'someone',
              'displayName': 'Someone Else',
              'bio': '',
            },
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }

      if (request.url.path.contains('/api/achievements/user/')) {
        // If we ever hit this in this test, it's a regression.
        return http.Response('Forbidden', 403);
      }

      return http.Response('Not found', 404);
    }));

    final user = await UserService.getUserById(otherWallet, forceRefresh: true);
    expect(user, isNotNull);

    expect(
      requests.any((r) => r.url.path.contains('/api/achievements/user/')),
      isFalse,
      reason:
          'Public profile viewing must not call self-only achievements endpoints for other wallets.',
    );
  });

  test('Viewing own user profile may fetch self-only achievements', () async {
    const myWallet = '4Nd1mYbF7kYgU7kD3bcd1q2w4gS7y8Z9xKLMNPQRSTU';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PreferenceKeys.walletAddress, myWallet);

    final requests = <http.Request>[];
    final api = BackendApiService();
    api.setHttpClient(MockClient((request) async {
      requests.add(request);

      if (request.url.path.contains('/api/profiles/')) {
        return http.Response(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'walletAddress': myWallet,
              'username': 'me',
              'displayName': 'Me',
              'bio': '',
            },
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }

      if (request.url.path.contains('/api/achievements/user/')) {
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'unlocked': <Object?>[],
            'progress': <Object?>[],
            'totalTokens': 0,
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }

      return http.Response('Not found', 404);
    }));

    final user = await UserService.getUserById(myWallet, forceRefresh: true);
    expect(user, isNotNull);

    expect(
      requests.any((r) => r.url.path.contains('/api/achievements/user/')),
      isTrue,
      reason: 'Own profile can fetch self-only achievements when available.',
    );
  });
}
