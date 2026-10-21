import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/conversation.dart';
import 'package:art_kubus/providers/cache_provider.dart';
import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/community/conversation_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatProvider chat;
  late CacheProvider cache;
  late ProfileProvider profile;
  late ThemeProvider theme;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting('test-token');
    BackendApiService().setHttpClient(
      MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object?>{'success': true, 'data': <Object?>[]}),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        ),
      ),
    );
    chat = ChatProvider();
    cache = CacheProvider();
    profile = ProfileProvider();
    theme = ThemeProvider();
  });

  tearDown(() {
    chat.dispose();
    cache.dispose();
    profile.dispose();
    theme.dispose();
    BackendApiService().setHttpClient(createPlatformHttpClient());
    BackendApiService().setAuthTokenForTesting(null);
  });

  Widget app(Widget home) => MultiProvider(
        providers: <ChangeNotifierProvider<ChangeNotifier>>[
          ChangeNotifierProvider<ChatProvider>.value(value: chat),
          ChangeNotifierProvider<CacheProvider>.value(value: cache),
          ChangeNotifierProvider<ProfileProvider>.value(value: profile),
          ChangeNotifierProvider<ThemeProvider>.value(value: theme),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      );

  // The screen schedules debounced read-marking timers; unmount it and drain
  // them inside the test body so no timer outlives the fake clock.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  final conversation = Conversation(id: 'conversation-a', title: 'Alpha');

  testWidgets(
      'embedded presentation has no leading Back and title hugs the left inset',
      (tester) async {
    await tester.pumpWidget(
      app(
        ConversationScreen(
          conversation: conversation,
          presentation: ConversationPresentation.embedded,
          onClose: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.arrow_back), findsNothing);
    final titleLeft = tester.getTopLeft(find.text('Alpha')).dx;
    expect(titleLeft, lessThan(100));
    await unmount(tester);
  });

  testWidgets('fullscreen presentation keeps Back and invokes onClose',
      (tester) async {
    var closeCalls = 0;
    await tester.pumpWidget(
      app(
        ConversationScreen(
          conversation: conversation,
          onClose: () => closeCalls++,
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    // The icon-only Back control carries a screen-reader label.
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(closeCalls, 1);
    await unmount(tester);
  });
}
