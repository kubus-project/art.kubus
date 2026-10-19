import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/user_service.dart';
import 'package:art_kubus/widgets/community/conversation_avatar.dart';
import 'package:art_kubus/widgets/identity/kubus_identity_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _wallet = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';
const _badgeKey = ValueKey<String>('profile-avatar-role-badge');

/// Answers at once with nothing stored, so the avatar's lookup leaves no
/// secure-storage timeout pending.
const _secureStorage =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  final api = BackendApiService();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService.disableHttpFailureDiagnosticsForTesting = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, (call) async => null);
    api.setHttpClient(MockClient((_) async => http.Response('Not found', 404)));
    UserService.setUsersInCacheAuthoritative(<User>[
      User(
        id: _wallet,
        name: 'Ana',
        username: 'ana',
        bio: '',
        followersCount: 0,
        followingCount: 0,
        postsCount: 0,
        isFollowing: false,
        joinedDate: '2026-01-01',
        isArtist: true,
        isVerified: true,
      ),
    ]);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, null);
    BackendApiService.disableHttpFailureDiagnosticsForTesting = false;
    await UserService.clearCache();
  });

  testWidgets(
      'the unread count sits on the upper-left corner, clear of the role badge',
      (tester) async {
    await tester.pumpWidget(_app(const ConversationAvatar(
      avatarUrl: null,
      wallet: _wallet,
      unreadCount: 3,
    )));
    await tester.pump();

    final avatar = tester.getRect(find.byType(KubusIdentityAvatar));
    final marker =
        tester.getRect(find.byKey(ConversationAvatar.unreadMarkerKey));
    final badge = tester.getRect(find.byKey(_badgeKey));

    expect(find.text('3'), findsOneWidget);
    expect(marker.topLeft, avatar.topLeft);
    expect(badge.center.dx, greaterThan(avatar.center.dx));
    expect(badge.center.dy, greaterThan(avatar.center.dy));
    expect(marker.overlaps(badge), isFalse);

    final stack = tester.widget<Stack>(find
        .descendant(
            of: find.byType(ConversationAvatar), matching: find.byType(Stack))
        .first);
    expect(stack.clipBehavior, Clip.none);

    // Drain the avatar's profile prefetch before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('no unread marker without unread messages', (tester) async {
    await tester.pumpWidget(_app(const ConversationAvatar(
      avatarUrl: null,
      wallet: _wallet,
      unreadCount: 0,
    )));
    await tester.pump();

    expect(find.byKey(ConversationAvatar.unreadMarkerKey), findsNothing);
    expect(find.byKey(_badgeKey), findsOneWidget);

    // Drain the avatar's profile prefetch before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
