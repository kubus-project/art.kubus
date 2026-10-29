import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:art_kubus/models/user.dart';
import 'package:art_kubus/services/user_service.dart';
import 'package:art_kubus/widgets/identity/kubus_identity_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/event_bus.dart';

const _badgeKey = ValueKey<String>('profile-avatar-role-badge');
const _verifiedKey = ValueKey<String>('profile-avatar-verified');

/// The secure-storage channel answers at once with nothing stored. Unmocked, the
/// auth load behind the lookup's follow-state read leaves its 800 ms timeout pending.
const _secureStorage =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _wallet = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) =>
    MaterialApp(
      locale: locale,
      theme: ThemeData(brightness: brightness),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: Scaffold(body: Center(child: child)),
    );

Widget _avatar({
  double radius = 22,
  bool isArtist = false,
  bool isInstitution = false,
  bool isVerified = false,
  bool navigation = false,
}) =>
    KubusIdentityAvatar(
      wallet: _wallet,
      radius: radius,
      isArtist: isArtist,
      isInstitution: isInstitution,
      isVerified: isVerified,
      enableProfileNavigation: navigation,
      fetchMissingAvatar: false,
      allowFabricatedFallback: true,
    );

User _cachedUser({
  bool isArtist = false,
  bool isInstitution = false,
  bool isVerified = false,
  String? avatarUrl,
}) =>
    User(
      id: _wallet,
      name: 'Cached',
      username: 'cached',
      bio: '',
      followersCount: 0,
      followingCount: 0,
      postsCount: 0,
      isFollowing: false,
      isVerified: isVerified,
      isArtist: isArtist,
      isInstitution: isInstitution,
      profileImageUrl: avatarUrl,
      joinedDate: '',
    );

void main() {
  group("roles from the avatar's own profile lookup", () {
    const profileId = '6f1c2b1e-4d3a-4b8e-9c7d-2a1b3c4d5e6f';
    final api = BackendApiService();

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      BackendApiService.disableHttpFailureDiagnosticsForTesting = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_secureStorage, (call) async => null);
      api.setHttpClient(MockClient((request) async {
        if (request.url.path == '/api/profiles/$profileId') {
          // The profile is addressed by its UUID but states its wallet.
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': profileId,
              'userId': profileId,
              'walletAddress': _wallet,
              'username': 'ana',
              'displayName': 'Ana',
              'roles': <String, dynamic>{'artist': true},
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      }));
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_secureStorage, null);
      api.setHttpClient(
          MockClient((_) async => http.Response('Not found', 404)));
      BackendApiService.disableHttpFailureDiagnosticsForTesting = false;
      await UserService.clearCache();
    });

    testWidgets(
        'a UUID lookup whose user is cached under the wallet gains the roles '
        'the payload omitted', (tester) async {
      await tester.pumpWidget(_app(const KubusIdentityAvatar(
        wallet: profileId,
        radius: 22,
        enableProfileNavigation: false,
        fetchMissingAvatar: true,
        allowFabricatedFallback: true,
      )));
      // Let the lookup complete, then rebuild with the resolved user.
      for (var i = 0; i < 5 && find.byKey(_badgeKey).evaluate().isEmpty; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      // The lookup cached the user under its wallet, not the UUID.
      expect(UserService.getCachedUser(profileId), isNull);
      expect(UserService.getCachedUser(_wallet)?.isArtist, isTrue);
      expect(find.byKey(_badgeKey), findsOneWidget);
      expect(find.byIcon(Icons.brush_rounded), findsOneWidget);
      // Unmount and drain the lookup's pending timers before the test ends.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
        'a late profile lookup cannot put account A roles on reused account B',
        (tester) async {
      await UserService.clearCache();
      final response = Completer<http.Response>();
      var profileRequestStarted = false;
      api.setHttpClient(MockClient((request) {
        if (request.url.path == '/api/profiles/$profileId') {
          profileRequestStarted = true;
          return response.future;
        }
        return Future<http.Response>.value(http.Response('Not found', 404));
      }));

      final identityA = ProfileIdentityData.fromIdentityPayload(
        <String, dynamic>{
          'author': <String, dynamic>{
            'id': profileId,
            'userId': profileId,
            'walletAddress': _wallet,
            'displayName': 'Account A',
          },
        },
        fallbackLabel: 'Unknown',
      );
      await tester.pumpWidget(_app(KubusIdentityAvatar.fromIdentity(
        identityA,
        key: const ValueKey<String>('reused-account-avatar'),
        fetchMissingAvatar: true,
        enableProfileNavigation: false,
      )));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
      expect(profileRequestStarted, isTrue);

      const accountBWallet = '9xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';
      final identityB = ProfileIdentityData.fromIdentityPayload(
        <String, dynamic>{
          'author': <String, dynamic>{
            'id': '0bdb20de-596c-4c36-a15e-dcfba4cf4e6f',
            'userId': '0bdb20de-596c-4c36-a15e-dcfba4cf4e6f',
            'walletAddress': accountBWallet,
            'displayName': 'Account B',
            'avatarUrl': 'https://images.example.test/account-b.png',
            'roles': <String, dynamic>{'artist': true},
          },
        },
        fallbackLabel: 'Unknown',
      );
      await tester.pumpWidget(_app(KubusIdentityAvatar.fromIdentity(
        identityB,
        key: const ValueKey<String>('reused-account-avatar'),
        fetchMissingAvatar: true,
        enableProfileNavigation: false,
      )));
      await tester.pump();
      expect(find.byIcon(Icons.brush_rounded), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_rounded), findsNothing);

      await tester.runAsync(() async {
        response.complete(
          http.Response(
            jsonEncode(<String, dynamic>{
              'id': profileId,
              'walletAddress': _wallet,
              'username': 'account-a',
              'displayName': 'Account A',
              'avatar': 'https://images.example.test/account-a.png',
              'isFollowing': true,
              'roles': <String, dynamic>{'institution': true},
              'isInstitution': true,
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.byIcon(Icons.brush_rounded), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_rounded), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('roles from the profile cache (no network)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    tearDown(() async {
      await UserService.clearCache();
    });

    testWidgets(
        'a cached artist profile marks an avatar the payload is silent '
        'about', (tester) async {
      UserService.setUsersInCacheAuthoritative(
        [_cachedUser(isArtist: true, isVerified: true)],
      );
      await tester.pumpWidget(_app(_avatar()));
      await tester.pump();
      expect(find.byKey(_badgeKey), findsOneWidget);
      expect(find.byKey(_verifiedKey), findsOneWidget);
      expect(find.byIcon(Icons.brush_rounded), findsOneWidget);
    });

    testWidgets('an explicit role revocation overrides stale cached role marks',
        (tester) async {
      UserService.setUsersInCacheAuthoritative(
        [_cachedUser(isArtist: true, isVerified: true)],
      );
      final identity = ProfileIdentityData.fromIdentityPayload(
        <String, dynamic>{
          'author': <String, dynamic>{
            'id': _wallet,
            'walletAddress': _wallet,
            'roles': <String, dynamic>{
              'artist': false,
              'institution': false,
            },
            'isArtist': false,
            'isInstitution': false,
            'isVerified': false,
          },
        },
        fallbackLabel: 'Unknown',
      );
      await tester.pumpWidget(_app(KubusIdentityAvatar.fromIdentity(
        identity,
        fetchMissingAvatar: false,
        enableProfileNavigation: false,
      )));
      await tester.pump();

      expect(find.byKey(_badgeKey), findsNothing);
    });

    testWidgets(
        'a wallet profile update refreshes an avatar addressed by account ID',
        (tester) async {
      const profileId = 'e482d0cc-7cc4-4d7a-8ace-5dddc2dd92f0';
      const oldAvatar = 'https://images.example.test/old.png';
      const newAvatar = 'https://images.example.test/new.png';
      final identity = ProfileIdentityData.fromIdentityPayload(
        <String, dynamic>{
          'author': <String, dynamic>{
            'id': profileId,
            'userId': profileId,
            'walletAddress': _wallet,
            'displayName': 'Ana',
            'avatarUrl': oldAvatar,
          },
        },
        fallbackLabel: 'Unknown',
      );
      await tester.pumpWidget(_app(KubusIdentityAvatar.fromIdentity(
        identity,
        fetchMissingAvatar: false,
        enableProfileNavigation: false,
      )));
      await tester.pump();
      expect(
        (tester.widget<Image>(find.byType(Image)).image as NetworkImage).url,
        oldAvatar,
      );

      final updated = _cachedUser(avatarUrl: newAvatar);
      UserService.setUsersInCacheAuthoritative([updated]);
      EventBus().emitProfileUpdated(updated);
      await tester.idle();
      await tester.pump();

      expect(
        (tester.widget<Image>(find.byType(Image)).image as NetworkImage).url,
        newAvatar,
      );
    });

    testWidgets('a cached profile with no roles draws nothing', (tester) async {
      UserService.setUsersInCacheAuthoritative([_cachedUser()]);
      await tester.pumpWidget(_app(_avatar()));
      await tester.pump();
      expect(find.byKey(_badgeKey), findsNothing);
    });

    testWidgets(
        'wallet cache supplies the avatar on a profile-ID addressed surface',
        (tester) async {
      const profileId = 'e482d0cc-7cc4-4d7a-8ace-5dddc2dd92f0';
      const cachedAvatar = 'https://images.example.test/cached-profile.png';
      UserService.setUsersInCacheAuthoritative(
        [_cachedUser(isArtist: true, avatarUrl: cachedAvatar)],
      );
      final identity = ProfileIdentityData.fromIdentityPayload(
        <String, dynamic>{
          'author': <String, dynamic>{
            'id': profileId,
            'userId': profileId,
            'walletAddress': _wallet,
            'displayName': 'Ana',
          },
        },
        fallbackLabel: 'Unknown',
      );

      await tester.pumpWidget(_app(KubusIdentityAvatar.fromIdentity(
        identity,
        fetchMissingAvatar: false,
        enableProfileNavigation: false,
      )));
      await tester.pump();

      expect(
        (tester.widget<Image>(find.byType(Image)).image as NetworkImage).url,
        cachedAvatar,
      );
      expect(find.byIcon(Icons.brush_rounded), findsOneWidget);
    });

    testWidgets('stated roles and cached roles add up to a dual role',
        (tester) async {
      UserService.setUsersInCacheAuthoritative(
        [_cachedUser(isInstitution: true)],
      );
      await tester.pumpWidget(_app(_avatar(isArtist: true)));
      await tester.pump();
      expect(find.byIcon(Icons.brush_rounded), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_rounded), findsOneWidget);
    });

    testWidgets('opting out ignores the cache', (tester) async {
      UserService.setUsersInCacheAuthoritative([_cachedUser(isArtist: true)]);
      await tester.pumpWidget(_app(KubusIdentityAvatar(
        wallet: _wallet,
        resolveCachedRoles: false,
        fetchMissingAvatar: false,
        enableProfileNavigation: false,
      )));
      await tester.pump();
      expect(find.byKey(_badgeKey), findsNothing);
    });

    testWidgets('fromIdentity carries the stated roles of the identity',
        (tester) async {
      final identity = ProfileIdentityData.fromIdentityPayload(
        {
          'author': {
            'id': 'u9',
            'walletAddress': _wallet,
            'displayName': 'Ana Artist',
            'roles': {'institution': true},
          },
        },
        fallbackLabel: 'Unknown',
      );
      await tester.pumpWidget(_app(KubusIdentityAvatar.fromIdentity(
        identity,
        radius: 20,
        enableProfileNavigation: false,
        fetchMissingAvatar: false,
      )));
      await tester.pump();
      expect(find.byIcon(Icons.account_balance_rounded), findsOneWidget);
      expect(find.byIcon(Icons.brush_rounded), findsNothing);
    });

    testWidgets('a name that sounds like a role is not a role', (tester) async {
      final identity = ProfileIdentityData.fromValues(
        fallbackLabel: 'Unknown',
        displayName: 'Official Museum Artist (verified)',
        username: 'verified_artist',
        wallet: _wallet,
      );
      await tester.pumpWidget(_app(KubusIdentityAvatar.fromIdentity(
        identity,
        radius: 20,
        enableProfileNavigation: false,
        fetchMissingAvatar: false,
      )));
      await tester.pump();
      expect(find.byKey(_badgeKey), findsNothing);
    });
  });

  group('roles across profile lookups and identity changes', () {
    const profileId = '6f1c2b1e-4d3a-4b8e-9c7d-2a1b3c4d5e6f';
    final api = BackendApiService();
    var profileRequests = 0;
    var profilePayload = <String, dynamic>{};

    User userFor(String id,
            {bool isArtist = false, bool isInstitution = false}) =>
        User(
          id: id,
          name: 'Cached',
          username: 'cached',
          bio: '',
          followersCount: 0,
          followingCount: 0,
          postsCount: 0,
          isFollowing: false,
          isVerified: false,
          isArtist: isArtist,
          isInstitution: isInstitution,
          joinedDate: '',
        );

    KubusIdentityAvatar avatarFor(String wallet,
            {bool fetch = false, List<String> aliases = const <String>[]}) =>
        KubusIdentityAvatar(
          wallet: wallet,
          walletAliases: aliases,
          radius: 22,
          enableProfileNavigation: false,
          fetchMissingAvatar: fetch,
          allowFabricatedFallback: true,
        );

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      BackendApiService.disableHttpFailureDiagnosticsForTesting = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_secureStorage, (call) async => null);
      profileRequests = 0;
      api.setHttpClient(MockClient((request) async {
        if (request.url.path.startsWith('/api/profiles/')) {
          profileRequests++;
          return http.Response(
            jsonEncode(profilePayload),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      }));
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_secureStorage, null);
      api.setHttpClient(
          MockClient((_) async => http.Response('Not found', 404)));
      BackendApiService.disableHttpFailureDiagnosticsForTesting = false;
      await UserService.clearCache();
    });

    testWidgets(
        'an unstated lookup keeps the cached artist badge on every frame',
        (tester) async {
      UserService.setUsersInCacheAuthoritative(
          [userFor(_wallet, isArtist: true)]);
      profilePayload = <String, dynamic>{
        'id': profileId,
        'walletAddress': _wallet,
        'username': 'cached',
        'displayName': 'Cached',
      };
      await tester.pumpWidget(_app(
          avatarFor(profileId, fetch: true, aliases: const <String>[_wallet])));
      expect(find.byKey(_badgeKey), findsOneWidget);

      var gaps = 0;
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
        if (find.byKey(_badgeKey).evaluate().isEmpty) gaps++;
      }
      expect(profileRequests, greaterThan(0));
      expect(gaps, 0);
      expect(UserService.getCachedUser(_wallet)?.isArtist, isTrue);
      expect(find.byIcon(Icons.brush_rounded), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('an explicit false from the lookup removes the cached badge',
        (tester) async {
      UserService.setUsersInCacheAuthoritative(
          [userFor(_wallet, isArtist: true)]);
      profilePayload = <String, dynamic>{
        'id': profileId,
        'walletAddress': _wallet,
        'username': 'cached',
        'displayName': 'Cached',
        'roles': <String, dynamic>{'artist': false, 'institution': false},
        'isVerified': false,
      };
      await tester.pumpWidget(_app(
          avatarFor(profileId, fetch: true, aliases: const <String>[_wallet])));
      for (var i = 0;
          i < 10 && find.byKey(_badgeKey).evaluate().isNotEmpty;
          i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(profileRequests, greaterThan(0));
      expect(UserService.getCachedUser(_wallet)?.isArtist, isFalse);
      expect(find.byKey(_badgeKey), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
        'an identity change shows the new account cached roles on its first '
        'frame', (tester) async {
      const otherWallet = '9xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';
      UserService.setUsersInCacheAuthoritative([
        userFor(_wallet, isInstitution: true),
        userFor(otherWallet, isArtist: true),
      ]);
      await tester.pumpWidget(_app(avatarFor(_wallet)));
      await tester.pump();
      expect(find.byIcon(Icons.account_balance_rounded), findsOneWidget);

      await tester.pumpWidget(_app(avatarFor(otherWallet)));
      expect(find.byIcon(Icons.brush_rounded), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_rounded), findsNothing);
    });
  });

  group('presence of the badge', () {
    testWidgets('an account with no stated role draws no badge at all',
        (tester) async {
      await tester.pumpWidget(_app(_avatar()));
      await tester.pump();
      expect(find.byKey(_badgeKey), findsNothing);
      expect(find.byKey(_verifiedKey), findsNothing);
    });

    for (final c in <(String, bool, bool, bool)>[
      ('artist', true, false, false),
      ('institution', false, true, false),
      ('dual role', true, true, false),
      ('verified artist', true, false, true),
      ('verified institution', false, true, true),
      ('verified dual role', true, true, true),
      ('verified without a role', false, false, true),
    ]) {
      testWidgets('${c.$1}: one badge on the avatar\'s lower-right corner',
          (tester) async {
        await tester.pumpWidget(_app(
          _avatar(isArtist: c.$2, isInstitution: c.$3, isVerified: c.$4),
        ));
        await tester.pump();
        expect(find.byKey(_badgeKey), findsOneWidget);
        final avatar = tester.getRect(find.byType(KubusIdentityAvatar));
        final badge = tester.getRect(find.byKey(_badgeKey));
        expect(badge.right, closeTo(avatar.right, 0.5));
        expect(badge.bottom, closeTo(avatar.bottom, 0.5));
        expect(avatar.contains(badge.topLeft), isTrue);
        // The verified check is separate from, and never implied by, a role.
        expect(find.byKey(_verifiedKey),
            c.$4 && (c.$2 || c.$3) ? findsOneWidget : findsNothing);
        expect(find.byIcon(Icons.brush_rounded),
            c.$2 ? findsOneWidget : findsNothing);
        expect(find.byIcon(Icons.account_balance_rounded),
            c.$3 ? findsOneWidget : findsNothing);
      });
    }
  });

  group('size and scale', () {
    for (final radius in <double>[12, 14, 16, 20, 24, 32, 44]) {
      testWidgets('radius $radius: legible, inside bounds, dual role fits',
          (tester) async {
        await tester.pumpWidget(_app(
          _avatar(radius: radius, isArtist: true, isInstitution: true),
        ));
        await tester.pump();
        final avatar = tester.getRect(find.byType(KubusIdentityAvatar));
        final badge = tester.getRect(find.byKey(_badgeKey));
        expect(badge.height, greaterThanOrEqualTo(14));
        expect(badge.height, lessThanOrEqualTo(20));
        // Both glyphs are drawn and the pill never exceeds the avatar width.
        expect(find.byIcon(Icons.brush_rounded), findsOneWidget);
        expect(find.byIcon(Icons.account_balance_rounded), findsOneWidget);
        expect(badge.width, lessThanOrEqualTo(avatar.width + 0.5));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the badge scales with the avatar and stays bounded',
        (tester) async {
      expect(KubusAvatarRoleBadge.heightFor(12), 14);
      expect(KubusAvatarRoleBadge.heightFor(22), closeTo(17.6, 0.01));
      expect(KubusAvatarRoleBadge.heightFor(44), 20);
    });
  });

  group('interaction and accessibility', () {
    testWidgets('the badge does not take the avatar tap target',
        (tester) async {
      await tester.pumpWidget(_app(
        GestureDetector(
          onTap: () {},
          child: _avatar(isArtist: true, radius: 22),
        ),
      ));
      await tester.pump();
      final badge = find.byKey(_badgeKey);
      final ignore = tester.widget<IgnorePointer>(
        find.ancestor(of: badge, matching: find.byType(IgnorePointer)).first,
      );
      expect(ignore.ignoring, isTrue);
    });

    testWidgets('screen readers hear every role and the verification',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(
        _avatar(isArtist: true, isInstitution: true, isVerified: true),
      ));
      await tester.pump();
      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
      final label = KubusAvatarRoleBadge.semanticLabel(
        l10n,
        isArtist: true,
        isInstitution: true,
        isVerified: true,
      );
      expect(label, contains(l10n.badgeArtistLabel));
      expect(label, contains(l10n.badgeInstitutionLabel));
      expect(label, contains(l10n.peopleVerifiedLabel));
      expect(find.bySemanticsLabel(label), findsOneWidget);
      semantics.dispose();
    });

    for (final locale in const [Locale('en'), Locale('sl')]) {
      for (final brightness in Brightness.values) {
        for (final scale in <double>[1, 2]) {
          testWidgets(
              '${locale.languageCode} ${brightness.name} x$scale renders the '
              'same badge without overflow', (tester) async {
            await tester.pumpWidget(_app(
              _avatar(isArtist: true, isVerified: true),
              locale: locale,
              brightness: brightness,
              textScale: scale,
            ));
            await tester.pump();
            expect(find.byKey(_badgeKey), findsOneWidget);
            expect(find.byKey(_verifiedKey), findsOneWidget);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
