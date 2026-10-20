import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/conversation.dart';
import 'package:art_kubus/providers/cache_provider.dart';
import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/community/conversation_screen.dart';
import 'package:art_kubus/screens/community/messages_screen.dart';
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

  Widget app(String selectedConversation) => MultiProvider(
        providers: <ChangeNotifierProvider<ChangeNotifier>>[
          ChangeNotifierProvider<ChatProvider>.value(value: chat),
          ChangeNotifierProvider<CacheProvider>.value(value: cache),
          ChangeNotifierProvider<ProfileProvider>.value(value: profile),
          ChangeNotifierProvider<ThemeProvider>.value(value: theme),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MessagesScreen(
            key: const ValueKey<String>('notification-messages-route'),
            initialConversationId: selectedConversation,
          ),
        ),
      );

  testWidgets('cold message tap opens the requested conversation',
      (tester) async {
    chat.conversations.addAll(<Conversation>[
      Conversation(id: 'conversation-a', title: 'A'),
      Conversation(id: 'conversation-b', title: 'B'),
    ]);
    await tester.pumpWidget(app('conversation-a'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    var conversationScreens = tester
        .widgetList<ConversationScreen>(find.byType(ConversationScreen))
        .toList();
    expect(conversationScreens, hasLength(1));
    expect(conversationScreens.single.conversation.id, 'conversation-a');
  });
}
