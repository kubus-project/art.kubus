import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/models/user.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/event_bus.dart';
import 'package:art_kubus/services/user_service.dart';
import 'package:art_kubus/widgets/avatar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _wallet = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';
const _oldAvatar = 'https://images.example.test/old.png';
const _savedAvatar = 'https://images.example.test/saved.png';
const _oldCover = 'https://images.example.test/old-cover.png';
const _savedCover = 'https://images.example.test/saved-cover.png';

User _user({required String? avatar, String? cover = _oldCover}) => User(
      id: _wallet,
      name: 'Ana Artist',
      username: 'ana',
      bio: '',
      profileImageUrl: avatar,
      coverImageUrl: cover,
      followersCount: 4,
      followingCount: 2,
      postsCount: 1,
      isFollowing: false,
      isVerified: false,
      isArtist: true,
      joinedDate: 'Joined recently',
    );

Widget _app() => const MaterialApp(
      home: Scaffold(
        body: Center(
          child: AvatarWidget(
            wallet: _wallet,
            radius: 24,
            enableProfileNavigation: false,
            fetchMissingAvatar: false,
          ),
        ),
      ),
    );

String? _networkUrl(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image));
  final provider = image.image;
  return provider is NetworkImage ? provider.url : null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackendApiService api;

  setUp(() async {
    api = BackendApiService();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await UserService.clearCache();
    BackendApiService.disableHttpFailureDiagnosticsForTesting = true;
  });

  tearDown(() async {
    api.setHttpClient(http.Client());
    api.setAuthTokenForTesting(null);
    BackendApiService.disableHttpFailureDiagnosticsForTesting = false;
    await UserService.clearCache();
  });

  testWidgets('mounted avatar applies a saved profile avatar immediately', (
    tester,
  ) async {
    UserService.setUsersInCacheAuthoritative([_user(avatar: _oldAvatar)]);
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(_networkUrl(tester), _oldAvatar);

    final updated = _user(avatar: _savedAvatar, cover: _savedCover);
    UserService.setUsersInCacheAuthoritative([updated]);
    EventBus().emitProfileUpdated(updated);
    await tester.idle();
    await tester.pump();

    expect(_networkUrl(tester), _savedAvatar);
    expect(UserService.getCachedUser(_wallet)?.coverImageUrl, _savedCover);
  });

  testWidgets('an older profile fetch cannot overwrite a saved avatar', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    api.setHttpClient(
      MockClient((request) {
        if (request.url.path == '/api/profiles/$_wallet') {
          return response.future;
        }
        return Future<http.Response>.value(http.Response('Not found', 404));
      }),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AvatarWidget(
              wallet: _wallet,
              radius: 24,
              enableProfileNavigation: false,
              fetchMissingAvatar: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final updated = _user(avatar: _savedAvatar, cover: _savedCover);
    UserService.setUsersInCacheAuthoritative([updated]);
    EventBus().emitProfileUpdated(updated);
    await tester.pump();
    expect(_networkUrl(tester), _savedAvatar);

    await tester.runAsync(() async {
      response.complete(
        http.Response(
          jsonEncode(<String, Object?>{
            'id': _wallet,
            'walletAddress': _wallet,
            'username': 'ana',
            'displayName': 'Ana Artist',
            'avatar': _oldAvatar,
            'coverImage': _oldCover,
            'isFollowing': true,
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(UserService.getCachedUser(_wallet)?.profileImageUrl, _savedAvatar);
    expect(UserService.getCachedUser(_wallet)?.coverImageUrl, _savedCover);
    expect(_networkUrl(tester), _savedAvatar);
  });

  testWidgets('a stale payload avatar loses to the saved cached avatar', (
    tester,
  ) async {
    UserService.setUsersInCacheAuthoritative([_user(avatar: _savedAvatar)]);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AvatarWidget(
              wallet: _wallet,
              avatarUrl: _oldAvatar,
              radius: 24,
              enableProfileNavigation: false,
              fetchMissingAvatar: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_networkUrl(tester), _savedAvatar);
  });

  testWidgets('saving an unchanged avatar URL re-renders with a cache bust', (
    tester,
  ) async {
    UserService.setUsersInCacheAuthoritative([_user(avatar: _oldAvatar)]);
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(_networkUrl(tester), _oldAvatar);

    final saved = _user(avatar: _oldAvatar);
    UserService.setUsersInCacheAuthoritative([saved]);
    UserService.markProfileMediaChanged([_wallet]);
    EventBus().emitProfileUpdated(saved);
    await tester.idle();
    await tester.pump();

    final url = _networkUrl(tester);
    expect(url, isNotNull);
    expect(url, startsWith(_oldAvatar));
    expect(url, contains('v='));
  });
}
