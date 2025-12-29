import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/presence_provider.dart';
import 'package:art_kubus/services/presence_api.dart';
import 'package:art_kubus/widgets/avatar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakePresenceApi implements PresenceApi {
  Map<String, dynamic> Function(List<String> wallets) _presenceBatchBuilder;

  _FakePresenceApi(this._presenceBatchBuilder);

  void setPresenceBatchBuilder(Map<String, dynamic> Function(List<String> wallets) builder) {
    _presenceBatchBuilder = builder;
  }

  @override
  Future<Map<String, dynamic>> getPresenceBatch(List<String> wallets) async {
    return _presenceBatchBuilder(wallets);
  }

  @override
  Future<void> ensureAuthLoaded({String? walletAddress}) async {}

  @override
  Future<Map<String, dynamic>> pingPresence({String? walletAddress}) async => {'success': true};

  @override
  Future<Map<String, dynamic>> recordPresenceVisit({
    required String type,
    required String id,
    String? walletAddress,
  }) async =>
      {'success': true, 'stored': false};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AvatarWidget hides presence badge when presence is private', (tester) async {
    const wallet = '0xABC123';
    final now = DateTime.now();

    final api = _FakePresenceApi((wallets) {
      return {
        'success': true,
        'data': [
          {
            'walletAddress': wallet,
            'exists': true,
            'visible': true,
            'isOnline': false,
            'lastSeenAt': now.toIso8601String(),
            'lastVisited': null,
            'lastVisitedTitle': null,
          }
        ],
      };
    });

    final presenceProvider = PresenceProvider(api: api);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: presenceProvider,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(
            body: AvatarWidget(
              wallet: wallet,
              // A DiceBear URL is treated as a placeholder avatar and avoids any network image fetch.
              avatarUrl: 'https://api.dicebear.com/7.x/identicon/svg?seed=test',
              enableProfileNavigation: false,
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(const ValueKey('avatar_presence_indicator')), findsOneWidget);

    api.setPresenceBatchBuilder((wallets) {
      return {
        'success': true,
        'data': [
          {
            'walletAddress': wallet,
            'exists': true,
            'visible': false,
            'isOnline': null,
            'lastSeenAt': null,
            'lastVisited': null,
            'lastVisitedTitle': null,
          }
        ],
      };
    });

    await presenceProvider.refreshWallet(wallet);
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byKey(const ValueKey('avatar_presence_indicator')), findsNothing);

    // Dispose provider before test ends to avoid pending timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    presenceProvider.dispose();
  });
}
