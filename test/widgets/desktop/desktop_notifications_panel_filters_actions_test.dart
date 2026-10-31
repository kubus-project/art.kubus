import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/app_mode_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/recent_activity_provider.dart';
import 'package:art_kubus/screens/desktop/components/desktop_notifications_panel.dart';
import 'package:art_kubus/services/account_cache_store.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/account_notifications_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    BackendApiService().resetCredentialStoreForTesting();
    await AccountCacheStore.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'user_action_history': <String>[
        // Legacy-style action entry (no explicit source), still authored by "You".
        jsonEncode(<String, dynamic>{
          'id': 'user_action_1',
          'type': 'save',
          'title': 'Saved an artwork',
          'description': 'You saved something locally',
          'timestamp': '2026-04-06T11:00:00.000Z',
          'isRead': true,
          'actorName': 'You',
          'metadata': <String, dynamic>{'targetType': 'artwork'},
        }),
      ],
    });
    await storeInAppNotifications(<Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'comment',
        'title': 'New Comment',
        'body': 'Someone left a comment',
        'payload': <String, dynamic>{'postId': 'post_123'},
        'timestamp': hoursAgo(2),
      },
    ]);
  });

  tearDown(() async {
    BackendApiService().setAuthTokenForTesting(null);
    await AccountCacheStore.resetForTesting();
  });

  testWidgets('DesktopNotificationsPanel hides user action entries',
      (tester) async {
    final activityProvider = RecentActivityProvider();
    // RecentActivityProvider.refresh() touches BackendApiService.loadAuthToken(),
    // which uses timeouts around secure storage reads. In widget tests, those
    // timeouts can stall under the fake async clock unless we use runAsync.
    await tester.runAsync(() => activityProvider.refresh(force: true));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<RecentActivityProvider>.value(
            value: activityProvider,
          ),
          // DesktopNotificationsPanel uses a nullable watch, but still requires a provider.
          Provider<AppModeProvider?>.value(value: null),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 720,
              child: DesktopNotificationsPanel(
                onClose: () {},
                onRefresh: () => activityProvider.refresh(force: true),
                onMarkAllRead: () async {},
                onActivitySelected: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('New Comment'), findsOneWidget);
    expect(find.text('Saved an artwork'), findsNothing);
  });
}
