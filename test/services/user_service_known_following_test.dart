import 'dart:convert';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/user_service.dart';
import 'package:art_kubus/utils/wallet_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _viewer = '4Nd1mYbF7kYgU7kD3bcd1q2w4gS7y8Z9xKLMNPQRSTU';
const _followed = '6Nd1mYbF7kYgU7kD3bcd1q2w4gS7y8Z9xKLMNPQRSTV';

void _backend({required int status, List<String> following = const []}) {
  BackendApiService().setHttpClient(MockClient((request) async {
    if (request.url.path.contains('/api/community/following/')) {
      if (status != 200) return http.Response('upstream down', status);
      return http.Response(
        jsonEncode(<String, Object?>{
          'data': [
            for (final wallet in following) {'walletAddress': wallet},
          ],
        }),
        200,
        headers: const {'content-type': 'application/json'},
      );
    }
    return http.Response('Not found', 404);
  }));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PreferenceKeys.walletAddress: _viewer,
    });
    BackendApiService().setAuthTokenForTesting(null);
    await UserService.clearCache();
  });

  test('backend failure with no cache: following set is unknown, not empty',
      () async {
    _backend(status: 503);
    expect(await UserService.getKnownFollowingUsers(), isNull);
    // Legacy callers keep their empty-list fallback.
    expect(await UserService.getFollowingUsers(), isEmpty);
  });

  test('backend failure with a cached set: the cached set is used', () async {
    _backend(status: 200, following: const [_followed]);
    expect(
      await UserService.getKnownFollowingUsers(),
      [WalletUtils.canonical(_followed)],
    );

    _backend(status: 503);
    expect(
      await UserService.getKnownFollowingUsers(),
      [WalletUtils.canonical(_followed)],
    );
  });

  test('backend success with no follows is an authoritative empty set',
      () async {
    _backend(status: 200);
    expect(await UserService.getKnownFollowingUsers(), isEmpty);
  });

  test('no active wallet: unknown', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _backend(status: 200, following: const [_followed]);
    expect(await UserService.getKnownFollowingUsers(), isNull);
  });
}
