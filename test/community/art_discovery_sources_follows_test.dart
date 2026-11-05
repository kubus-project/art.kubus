import 'dart:convert';

import 'package:art_kubus/community/art_discovery_sources.dart';
import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/user_service.dart';
import 'package:art_kubus/utils/wallet_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _viewer = '4Nd1mYbF7kYgU7kD3bcd1q2w4gS7y8Z9xKLMNPQRSTU';
const _followed = '6Nd1mYbF7kYgU7kD3bcd1q2w4gS7y8Z9xKLMNPQRSTV';

class _Wallet extends WalletProvider {
  _Wallet() : super(deferInit: true);

  @override
  String? get currentWalletAddress => _viewer;
}

void _backend({required int status}) {
  BackendApiService().setHttpClient(MockClient((request) async {
    if (request.url.path.contains('/api/community/following/')) {
      if (status != 200) return http.Response('upstream down', status);
      return http.Response(
        jsonEncode(<String, Object?>{
          'data': [
            {'walletAddress': _followed},
          ],
        }),
        200,
        headers: const {'content-type': 'application/json'},
      );
    }
    return http.Response('Not found', 404);
  }));
}

// The follow graph is read and written through account-scoped cache storage,
// which finishes on the real event loop, so the calls run under runAsync.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    BackendApiService().resetCredentialStoreForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{
      PreferenceKeys.walletAddress: _viewer,
    });
    BackendApiService().setAuthTokenForTesting(null);
    await UserService.clearCache();
  });

  testWidgets(
      'discovery ranking keeps the followed wallets through a following outage',
      (tester) async {
    late final sources = buildLiveArtDiscoverySources(
      tester.element(find.byType(SizedBox)),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ArtworkProvider>(
            create: (_) => ArtworkProvider(),
          ),
          ChangeNotifierProvider<SavedItemsProvider>(
            create: (_) => SavedItemsProvider(),
          ),
          ChangeNotifierProvider<ProfileProvider>(
            create: (_) => ProfileProvider(),
          ),
          ChangeNotifierProvider<WalletProvider>.value(value: _Wallet()),
        ],
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    final expected = WalletUtils.canonical(_followed);

    _backend(status: 200);
    final online = (await tester.runAsync(sources.signals))!;
    expect(online.followedWallets, contains(expected));

    // The endpoint goes down: the cached follow graph still feeds the ranking
    // instead of every followed boost silently disappearing.
    _backend(status: 503);
    final offline = (await tester.runAsync(sources.signals))!;
    expect(offline.followedWallets, contains(expected));
  });

  testWidgets('with no cache an outage yields no follows, not an error',
      (tester) async {
    late final sources = buildLiveArtDiscoverySources(
      tester.element(find.byType(SizedBox)),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ArtworkProvider>(
            create: (_) => ArtworkProvider(),
          ),
          ChangeNotifierProvider<SavedItemsProvider>(
            create: (_) => SavedItemsProvider(),
          ),
          ChangeNotifierProvider<ProfileProvider>(
            create: (_) => ProfileProvider(),
          ),
          ChangeNotifierProvider<WalletProvider>.value(value: _Wallet()),
        ],
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    _backend(status: 503);
    final signals = (await tester.runAsync(sources.signals))!;
    expect(signals.followedWallets, isEmpty);
  });
}
