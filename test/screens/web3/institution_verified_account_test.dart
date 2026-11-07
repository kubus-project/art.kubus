import 'dart:convert';

import 'package:art_kubus/models/pending_action_intent.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/pending_action_provider.dart';
import 'package:art_kubus/screens/web3/institution/institution_detail_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:art_kubus/widgets/profile/profile_identity_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';
import '../../support/product_v5_qa_fixtures.dart';
import '../../helpers/secure_storage_absent.dart';

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
  String? walletAddress,
}) =>
    {
      'profileId': _profileId,
      if (userId != null) 'userId': userId,
      if (username != null) 'username': username,
      'displayName': 'City Museum',
      if (walletAddress != null) 'walletAddress': walletAddress,
      'allowMessages': allowMessages,
    };

/// Lets the messaging flow run to its request. It awaits real platform I/O
/// and timeout timers that only fire when both the event loop and the fake
/// clock advance, so the two are driven together for a bounded time.
Future<void> _driveMessaging(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The linked public profile's own wallet, as the backend serves it: a
/// base58 Solana address, never a member's wallet.
const _accountWallet = 'G1mUnv6Yv3xq8mzbwb9c8rD2zYw3Lk5nVq4tJ7yHp2Ar';

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

  /// Bodies of every conversation the messaging flow tried to create.
  final List<Map<String, dynamic>> conversations = <Map<String, dynamic>>[];

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
      if (path == '/api/messages' && request.method == 'POST') {
        // Refused on purpose: the flow stops at the request, before any chat
        // screen opens, so the test asserts who was addressed and nothing else.
        conversations.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({'success': false, 'error': 'refused in test'}),
          500,
          headers: const <String, String>{'content-type': 'application/json'},
        );
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
  UserProfile? signedInProfile,
  PendingActionProvider? pendingActions,
}) async {
  backend.install();
  await tester.pumpWidget(const SizedBox.shrink());
  final prior = FlutterError.onError;
  final errors = await pumpProductSurface(
    tester,
    size: size,
    brightness: brightness,
    signedInProfile: signedInProfile,
    extraProviders: [
      if (pendingActions != null)
        ChangeNotifierProvider<PendingActionProvider>.value(
          value: pendingActions,
        ),
    ],
    child: const InstitutionDetailScreen(institutionId: _institutionId),
  );
  FlutterError.onError = prior;
  await tester.pump();
  return errors;
}

void main() {
  installEmptySecureStorage();
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
      'Message stays hidden for a linked account without a wallet, with or without allowMessages',
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
              'the conversation API is wallet-keyed; this account carries no wallet');
      expect(find.text('Follow'), findsOneWidget,
          reason: 'allowMessages=$allowMessages');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
      'a linked account with a wallet and allowed messages offers Message, which addresses that wallet',
      (tester) async {
    final backend = _AccountBackend(
      institution: _institution(
        verifiedAccountProfile: _verifiedAccount(walletAddress: _accountWallet),
      ),
    );
    final errors =
        await _pump(tester, backend: backend, signedInProfile: qaOwner());
    expect(errors, isEmpty);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);

    // The signed-in wallet binds asynchronously, through real platform I/O that
    // fake time does not advance; a conversation started before it settles is
    // correctly discarded. Let it settle, as the app does.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.tap(find.text('Message'));
    await _driveMessaging(tester);

    expect(backend.conversations, hasLength(1),
        reason: 'requests: ${backend.requests.join(' | ')}');
    expect(backend.conversations.single['members'], [_accountWallet],
        reason: 'the conversation is addressed to the account wallet only');
    expect(backend.mutations.where((m) => m.contains('/follow')), isEmpty,
        reason: 'opening a conversation never follows the account');
  });

  testWidgets(
      'a linked account with a wallet but messages disallowed hides Message',
      (tester) async {
    final backend = _AccountBackend(
      institution: _institution(
        verifiedAccountProfile: _verifiedAccount(
          walletAddress: _accountWallet,
          allowMessages: false,
        ),
      ),
    );
    final errors =
        await _pump(tester, backend: backend, signedInProfile: qaOwner());
    expect(errors, isEmpty);
    expect(find.text('Message'), findsNothing);
    expect(find.text('Follow'), findsOneWidget);
  });

  testWidgets(
      'a wallet with no account id offers Message alone, with no Follow',
      (tester) async {
    final backend = _AccountBackend(
      institution: _institution(
        verifiedAccountProfile: _verifiedAccount(
          userId: null,
          walletAddress: _accountWallet,
        ),
      ),
    );
    final errors =
        await _pump(tester, backend: backend, signedInProfile: qaOwner());
    expect(errors, isEmpty);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Follow'), findsNothing,
        reason: 'there is no users.id to follow by');

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.tap(find.text('Message'));
    await _driveMessaging(tester);
    expect(backend.conversations.single['members'], [_accountWallet]);
  });

  testWidgets('a signed-out Message tap sends no conversation request',
      (tester) async {
    BackendApiService().setAuthTokenForTesting(null);
    final backend = _AccountBackend(
      institution: _institution(
        verifiedAccountProfile: _verifiedAccount(walletAddress: _accountWallet),
      ),
    );
    final errors = await _pump(tester, backend: backend);
    expect(errors, isEmpty);
    expect(find.text('Message'), findsOneWidget);

    await tester.tap(find.text('Message'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(backend.conversations, isEmpty);
  });

  testWidgets(
      'a signed-out Follow captures a follow intent keyed by the account id',
      (tester) async {
    BackendApiService().setAuthTokenForTesting(null);
    final pending = PendingActionProvider();
    final backend = _AccountBackend(
      institution: _institution(verifiedAccountProfile: _verifiedAccount()),
    );
    final errors =
        await _pump(tester, backend: backend, pendingActions: pending);
    expect(errors, isEmpty);

    await tester.tap(find.text('Follow'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final intent = pending.pending;
    expect(intent, isNotNull, reason: 'the gate kept the visitor\'s follow');
    expect(intent!.actionType, PendingActionType.follow);
    expect(intent.targetType, PendingActionTargetType.user);
    expect(intent.targetId, _userId,
        reason: 'replayed through the account-id route, never a wallet');
    expect(backend.mutations, isEmpty);
  });

  testWidgets(
      'without a linked account the credit button stays at the cover bottom-right',
      (tester) async {
    final payload = _institution()
      ..['coverImageUrl'] = 'https://example.test/cover.jpg'
      ..['coverAttribution'] = {
        'credit': 'Synthetic photographer',
        'licenseUrl': 'https://creativecommons.org/licenses/by-sa/4.0/',
      };
    final backend = _AccountBackend(institution: payload);
    final errors = await _pump(tester, backend: backend);
    expect(errors, isEmpty);

    final cover = tester.getRect(
      find.byKey(const ValueKey('profile-identity-hero-cover')),
    );
    final credit = tester.getRect(
      find.byKey(const ValueKey('institution-cover-credit-button')),
    );
    expect(
      credit.top - cover.top,
      ProfileIdentityHero.coverHeightWithImage - 44 - KubusSpacing.sm,
      reason: 'the accepted position: the photo\'s bottom-right corner',
    );
    expect(cover.right - credit.right, KubusSpacing.sm);
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
      final coverRect = tester.getRect(
        find.byKey(const ValueKey('profile-identity-hero-cover')),
      );
      final creditRect = tester.getRect(find.byKey(credit));
      final followRect = tester.getRect(find
          .ancestor(
            of: find.text('Follow'),
            matching: find.byType(KubusButton),
          )
          .first);
      expect(creditRect.overlaps(followRect), isFalse, reason: '$size');
      // With a Follow row the button moves to the cover's top corner.
      expect(creditRect.top - coverRect.top, KubusSpacing.sm, reason: '$size');
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
