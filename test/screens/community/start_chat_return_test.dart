import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/community_hub_provider.dart';
import 'package:art_kubus/screens/community/community_screen.dart';
import 'package:art_kubus/screens/community/messages_screen.dart';
import 'package:art_kubus/screens/desktop/community/desktop_community_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';
import '../../support/product_v5_qa_fixtures.dart' as qa;

class _SilentChat extends ChatProvider {
  @override
  Future<void> initialize({String? initialWallet}) async {}
}

Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// A guest asked to start a chat, signed in, and the community screen mounts
/// after the sign-in: the remembered request must reopen Messages. [check] runs
/// while the screen is mounted; the screen is then unmounted and its signed-in
/// start-up timers are drained, so the test ends with nothing pending.
Future<void> _mountAfterSignIn(
  WidgetTester tester, {
  required Widget screen,
  required Size size,
  required void Function() check,
}) async {
  final hub = CommunityHubProvider()
    ..rememberComposeIntentForAuth(CommunityComposeIntent.startChat);
  final collab = CollabProvider();
  final chat = _SilentChat();
  final prior = FlutterError.onError;
  try {
    await pumpProductSurface(
      tester,
      child: screen,
      size: size,
      signedInProfile: qa.qaOwner(),
      extraProviders: <SingleChildWidget>[
        ChangeNotifierProvider<CommunityHubProvider>.value(value: hub),
        ChangeNotifierProvider<CollabProvider>.value(value: collab),
        ChangeNotifierProvider<ChatProvider>.value(value: chat),
      ],
      settle: const Duration(milliseconds: 500),
    );
    FlutterError.onError = prior;
    await _drain(tester);
    expect(hub.hasPendingComposeIntent, isFalse,
        reason: 'the request was taken');
    check();
    await tester.pumpWidget(const SizedBox());
    SocketService().disconnect();
    await _drain(tester);
  } finally {
    collab.stopInvitePolling();
    chat.dispose();
    SocketService().disconnect();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(
      MockClient((request) async => http.Response('{}', 404)),
    );
  });

  tearDown(() {
    BackendApiService().setHttpClient(http.Client());
  });

  testWidgets('mobile: a remembered chat request reopens Messages',
      (tester) async {
    await _mountAfterSignIn(
      tester,
      screen: CommunityScreen(),
      size: const Size(390, 844),
      check: () => expect(find.byType(MessagesScreen), findsOneWidget),
    );
  });

  testWidgets('desktop: a remembered chat request shows the Messages panel',
      (tester) async {
    await _mountAfterSignIn(
      tester,
      screen: DesktopCommunityScreen(),
      size: const Size(1440, 900),
      // The panel's new-conversation entry is what the guest came back for.
      check: () => expect(find.byIcon(Icons.edit_square), findsWidgets),
    );
  });
}
