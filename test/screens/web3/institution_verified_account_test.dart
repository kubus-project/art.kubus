import 'dart:convert';

import 'package:art_kubus/screens/web3/institution/institution_detail_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:art_kubus/widgets/profile/profile_identity_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';

const _validAuthToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

const _institutionId = 'inst-linked';
const _profileId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _userId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _followPath = '/api/community/follow/account/$_userId';
const _statusPath = '/api/community/follow/account/$_userId/status';
const _accountButtonKey = ValueKey('institution-linked-account-profile');
const _longName = 'Moderna galerija in Muzej sodobne umetnosti Metelkova';
const _longHandle = 'moderna-galerija-muzej-sodobne-umetnosti-metelkova';

Map<String, Object?> _verifiedAccount({
  String? userId = _userId,
  Object? username = 'citymuseum',
  bool allowMessages = true,
}) =>
    {
      'profileId': _profileId,
      if (userId != null) 'userId': userId,
      if (username != null) 'username': username,
      'displayName': 'City Museum',
      'allowMessages': allowMessages,
    };

Map<String, Object?> _institution({
  String name = 'City Museum',
  Map<String, Object?>? verifiedAccountProfile,
}) =>
    {
      'id': _institutionId,
      'name': name,
      'description': 'A synthetic venue for account-link checks.',
      'type': 'museum',
      'kind': 'museum',
      'address': 'Main Street 1, 1000 Ljubljana',
      'latitude': 46.0511,
      'longitude': 14.5051,
      'contactEmail': '',
      'website': '',
      'stats': {
        'totalVisitors': 0,
        'activeEvents': 0,
        'artworkViews': 0,
        'revenue': 0,
        'visitorGrowth': 0,
        'revenueGrowth': 0,
      },
      'isVerified': true,
      'createdAt': '2026-07-01T10:00:00.000Z',
      if (verifiedAccountProfile != null)
        'verifiedAccountProfile': verifiedAccountProfile,
    };

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );

/// A fake of the account-link backend: it serves the institution payload and
/// the follow-by-account endpoints, and records every call it receives.
class _AccountBackend {
  _AccountBackend({required this.institution, this.following = false});

  final Map<String, Object?> institution;
  bool following;
  final List<String> requests = <String>[];

  List<String> get mutations => requests
      .where((r) => r.startsWith('POST ') || r.startsWith('DELETE '))
      .toList(growable: false);

  void install() {
    BackendApiService().setHttpClient(MockClient((request) async {
      final path = request.url.path;
      requests.add('${request.method} $path');
      if (path == '/api/institutions') {
        return _json({
          'success': true,
          'institutions': [institution],
        });
      }
      if (path == _statusPath) {
        return _json({'success': true, 'isFollowing': following});
      }
      if (path == _followPath &&
          (request.method == 'POST' || request.method == 'DELETE')) {
        following = request.method == 'POST';
        return _json({
          'success': true,
          'isFollowing': following,
          'changed': true,
          'followCreated': following,
          'unfollowed': !following,
          'targetUserId': _userId,
        });
      }
      return _json({
        'success': true,
        'data': {'events': <Object>[]},
      });
    }));
  }
}

Future<List<String>> _pump(
  WidgetTester tester, {
  required _AccountBackend backend,
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
}) async {
  backend.install();
  await tester.pumpWidget(const SizedBox.shrink());
  final prior = FlutterError.onError;
  final errors = await pumpProductSurface(
    tester,
    size: size,
    brightness: brightness,
    child: const InstitutionDetailScreen(institutionId: _institutionId),
  );
  FlutterError.onError = prior;
  await tester.pump();
  return errors;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(_validAuthToken);
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  testWidgets(
      'an unlinked institution shows no handle, follow, message or account button',
      (tester) async {
    final backend = _AccountBackend(institution: _institution());
    final errors = await _pump(tester, backend: backend);
    expect(errors, isEmpty);

    expect(find.textContaining('@'), findsNothing);
    expect(find.text('Follow'), findsNothing);
    expect(find.text('Following'), findsNothing);
    expect(find.text('Message'), findsNothing);
    expect(find.byKey(_accountButtonKey), findsNothing);
    expect(
      backend.requests.where((r) => r.contains('/follow/account')),
      isEmpty,
      reason: 'an unlinked venue never asks about a follow relation',
    );
    expect(find.byType(ProfileIdentityHero), findsOneWidget);
  });

  testWidgets(
      'a verified account shows its @handle in the shared hero with Follow',
      (tester) async {
    final backend = _AccountBackend(
      institution: _institution(verifiedAccountProfile: _verifiedAccount()),
    );
    final errors = await _pump(tester, backend: backend);
    expect(errors, isEmpty);

    expect(find.text('@citymuseum'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Message'), findsNothing);
    expect(find.byKey(_accountButtonKey), findsOneWidget);
    final hero = tester.widget<ProfileIdentityHero>(
      find.byType(ProfileIdentityHero),
    );
    expect(hero.handle, 'citymuseum');
    expect(hero.actions, isNotNull);
    expect(hero.isInstitution, isTrue);
    expect(
      backend.requests,
      contains('GET $_statusPath'),
      reason: 'the follow state is read from the account-id status endpoint',
    );
  });

  testWidgets('a linked account that is already followed starts as Following',
      (tester) async {
    final backend = _AccountBackend(
      institution: _institution(verifiedAccountProfile: _verifiedAccount()),
      following: true,
    );
    final errors = await _pump(tester, backend: backend);
    expect(errors, isEmpty);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
  });

  testWidgets('Follow and Unfollow toggle through the account-id endpoints',
      (tester) async {
    final backend = _AccountBackend(
      institution: _institution(verifiedAccountProfile: _verifiedAccount()),
    );
    final errors = await _pump(tester, backend: backend);
    expect(errors, isEmpty);

    await tester.tap(find.text('Follow'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(backend.mutations, ['POST $_followPath']);
    expect(find.text('Following'), findsOneWidget);

    await tester.tap(find.text('Following'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(backend.mutations, ['POST $_followPath', 'DELETE $_followPath']);
    expect(find.text('Follow'), findsOneWidget);
  });

  testWidgets(
      'Message stays hidden for a linked account, with or without allowMessages',
      (tester) async {
    for (final allowMessages in [false, true]) {
      final backend = _AccountBackend(
        institution: _institution(
          verifiedAccountProfile:
              _verifiedAccount(allowMessages: allowMessages),
        ),
      );
      final errors = await _pump(tester, backend: backend);
      expect(errors, isEmpty, reason: 'allowMessages=$allowMessages');
      expect(find.text('Message'), findsNothing,
          reason:
              'the conversation API is wallet-keyed and the contract carries no wallet');
      expect(find.text('Follow'), findsOneWidget,
          reason: 'allowMessages=$allowMessages');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('a blank username never becomes a fake handle', (tester) async {
    for (final username in ['', '   ', '@', null]) {
      final backend = _AccountBackend(
        institution: _institution(
          verifiedAccountProfile: _verifiedAccount(username: username),
        ),
      );
      final errors = await _pump(tester, backend: backend);
      expect(errors, isEmpty, reason: 'username=$username');
      expect(find.textContaining('@'), findsNothing,
          reason: 'username=$username');
      expect(find.text('City Museum'), findsWidgets,
          reason: 'the display name is not promoted to a handle');
      expect(find.byKey(_accountButtonKey), findsOneWidget,
          reason: 'username=$username');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('a wallet-shaped username is not presented as a handle',
      (tester) async {
    final backend = _AccountBackend(
      institution: _institution(
        verifiedAccountProfile: _verifiedAccount(
          username: '0x1234567890abcdef1234567890abcdef12345678',
        ),
      ),
    );
    final errors = await _pump(tester, backend: backend);
    expect(errors, isEmpty);
    expect(find.textContaining('0x1234'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets(
      'a linked account without a user id keeps the profile button but offers no follow',
      (tester) async {
    final backend = _AccountBackend(
      institution: _institution(
        verifiedAccountProfile: _verifiedAccount(userId: null),
      ),
    );
    final errors = await _pump(tester, backend: backend);
    expect(errors, isEmpty);
    expect(find.text('@citymuseum'), findsOneWidget);
    expect(find.byKey(_accountButtonKey), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
    expect(find.text('Message'), findsNothing);
    expect(
      backend.requests.where((r) => r.contains('/follow/account')),
      isEmpty,
    );
  });

  testWidgets(
      'the cover credit button never overlaps the Follow action at phone, tablet or desktop width',
      (tester) async {
    final payload = _institution(verifiedAccountProfile: _verifiedAccount())
      ..['coverImageUrl'] = 'https://example.test/cover.jpg'
      ..['coverAttribution'] = {
        'credit': 'Synthetic photographer',
        'licenseUrl': 'https://creativecommons.org/licenses/by-sa/4.0/',
      };
    final backend = _AccountBackend(institution: payload);
    const credit = ValueKey('institution-cover-credit-button');
    for (final size in const [
      Size(390, 844),
      Size(820, 1180),
      Size(1440, 900),
    ]) {
      final errors = await _pump(tester, backend: backend, size: size);
      expect(errors, isEmpty, reason: '$size');
      final creditRect = tester.getRect(find.byKey(credit));
      final followRect = tester.getRect(find
          .ancestor(
            of: find.text('Follow'),
            matching: find.byType(KubusButton),
          )
          .first);
      expect(creditRect.overlaps(followRect), isFalse, reason: '$size');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('a signed-out visitor who taps Follow sends no follow request',
      (tester) async {
    BackendApiService().setAuthTokenForTesting(null);
    final backend = _AccountBackend(
      institution: _institution(verifiedAccountProfile: _verifiedAccount()),
    );
    final errors = await _pump(tester, backend: backend);
    expect(errors, isEmpty);
    expect(find.text('Follow'), findsOneWidget);

    await tester.tap(find.text('Follow'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(backend.mutations, isEmpty);
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
        'a long name and a long handle fit at 320 px, ${brightness.name} theme',
        (tester) async {
      final backend = _AccountBackend(
        institution: _institution(
          name: _longName,
          verifiedAccountProfile: _verifiedAccount(username: _longHandle),
        ),
      );
      final errors = await _pump(
        tester,
        backend: backend,
        size: const Size(320, 640),
        brightness: brightness,
      );
      expect(errors, isEmpty);
      expect(find.text('@$_longHandle'), findsOneWidget);
      expect(find.textContaining('Metelkova'), findsWidgets);
      expect(find.text('Follow'), findsOneWidget);
    });
  }
}
