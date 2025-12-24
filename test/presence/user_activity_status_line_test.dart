import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/presence_provider.dart';
import 'package:art_kubus/services/presence_api.dart';
import 'package:art_kubus/widgets/user_activity_status_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakePresenceApi implements PresenceApi {
  final Map<String, dynamic> presenceResponse;

  _FakePresenceApi({required this.presenceResponse});

  @override
  Future<Map<String, dynamic>> getPresenceBatch(List<String> wallets) async {
    return presenceResponse;
  }

  @override
  Future<void> ensureAuthLoaded({String? walletAddress}) async {}

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

  testWidgets('UserActivityStatusLine alternates to location when available and not expired', (tester) async {
    const wallet = '0xABC123';
    final now = DateTime.now();
    final api = _FakePresenceApi(
      presenceResponse: {
        'success': true,
        'data': [
          {
            'walletAddress': wallet,
            'exists': true,
            'visible': true,
            'isOnline': false,
            'lastSeenAt': now.subtract(const Duration(minutes: 2)).toIso8601String(),
            'lastVisited': {
              'type': 'artwork',
              'id': '00000000-0000-0000-0000-000000000001',
              'visitedAt': now.subtract(const Duration(minutes: 2)).toIso8601String(),
              'expiresAt': now.add(const Duration(minutes: 30)).toIso8601String(),
            },
            'lastVisitedTitle': 'Test Artwork',
          }
        ],
      },
    );

    final presenceProvider = PresenceProvider(api: api);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: presenceProvider,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(
            body: UserActivityStatusLine(walletAddress: wallet),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(const ValueKey('presence_time')), findsOneWidget);
    expect(find.byKey(const ValueKey('presence_location')), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('presence_location')), findsOneWidget);

    // Dispose provider before test ends to avoid pending timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    presenceProvider.dispose();
  });

  testWidgets('UserActivityStatusLine does not alternate when lastVisited is expired', (tester) async {
    const wallet = '0xDEF456';
    final now = DateTime.now();
    final api = _FakePresenceApi(
      presenceResponse: {
        'success': true,
        'data': [
          {
            'walletAddress': wallet,
            'exists': true,
            'visible': true,
            'isOnline': false,
            'lastSeenAt': now.subtract(const Duration(minutes: 1)).toIso8601String(),
            'lastVisited': {
              'type': 'artwork',
              'id': '00000000-0000-0000-0000-000000000002',
              'visitedAt': now.subtract(const Duration(minutes: 2)).toIso8601String(),
              'expiresAt': now.subtract(const Duration(minutes: 1)).toIso8601String(),
            },
            'lastVisitedTitle': 'Expired Artwork',
          }
        ],
      },
    );

    final presenceProvider = PresenceProvider(api: api);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: presenceProvider,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(
            body: UserActivityStatusLine(walletAddress: wallet),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 150));
    expect(find.textContaining('Last seen'), findsOneWidget);
    expect(find.byKey(const ValueKey('presence_location')), findsNothing);

    await tester.pump(const Duration(seconds: 8));
    expect(find.byKey(const ValueKey('presence_location')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    presenceProvider.dispose();
  });
}
