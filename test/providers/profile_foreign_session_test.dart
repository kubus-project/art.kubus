import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/auth_credential_store.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/account_session_fixture.dart';
import '../support/forced_sign_out_fixture.dart';

/// A held profile belongs to the session it was loaded for. A session for
/// another account, started through the real commit and restore paths (not a
/// hand-sent notification), must never make the previous account's held profile
/// the signed-in one.
const _secureChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

class _FailingMeApi extends WalletProfileApi {
  _FailingMeApi(super.profile);

  @override
  Future<Map<String, dynamic>> getMyProfile() async =>
      throw Exception('network down');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackendApiService api;
  late Map<String, String> secure;

  const accountA = 'user-artist-held'; // the held profile's account
  const accountB = 'account-B-other';

  setUp(() {
    api = BackendApiService();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'wallet_address': forcedSignOutWallet,
    });
    secure = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String?;
      if (call.method == 'read') return secure[key];
      if (call.method == 'write') secure[key!] = args['value'] as String;
      if (call.method == 'delete') secure.remove(key);
      return null;
    });
    api.resetCredentialStoreForTesting();
    api.setAuthTokenForTesting(null);
  });
  tearDown(() {
    AccountSessionFixture.end();
    AccountIdentity.notifyListenersChanged();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, null);
  });

  Future<ProfileProvider> heldAFromStoredWallet({bool meFails = false}) async {
    final json = forcedSignOutProfileJson();
    final profile = ProfileProvider(
      apiService: meFails ? _FailingMeApi(json) : WalletProfileApi(json),
    );
    await profile.loadProfile(forcedSignOutWallet);
    expect(profile.heldProfile, isNotNull);
    expect(profile.isSignedIn, isFalse);
    return profile;
  }

  test(
      'a session for account B started by sign-in does not make held A the '
      'signed-in account', () async {
    final profile = await heldAFromStoredWallet(meFails: true);
    var notified = 0;
    profile.addListener(() => notified++);

    await api.setAuthToken(AccountSessionFixture.jwt(accountId: accountB));

    expect(profile.isSignedIn, isFalse);
    expect(profile.currentUser, isNull);
    expect(profile.heldProfile, isNull,
        reason: 'a foreign held profile is cleared when the session starts');
    expect(profile.isCurrentAccount(forcedSignOutWallet), isFalse);
    expect(profile.isCurrentAccountActor(wallet: forcedSignOutWallet), isFalse);
    expect(notified, greaterThan(0),
        reason: 'the owner is told at session start');

    // The post-auth load for B fails: A must still not appear as the account.
    await expectLater(profile.loadAuthenticatedProfile(), throwsException);
    expect(profile.isSignedIn, isFalse);
    expect(profile.currentUser, isNull);
  });

  test('B then loads and becomes the signed-in account', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final profile = ProfileProvider(
      apiService: WalletProfileApi(<String, dynamic>{
        'id': accountB,
        'userId': accountB,
        'username': 'bee',
        'displayName': 'Bee',
        'bio': '',
        'avatar': '',
        'createdAt': '2026-03-31T00:00:00.000Z',
        'updatedAt': '2026-03-31T00:00:00.000Z',
      }),
    );
    await api.setAuthToken(AccountSessionFixture.jwt(accountId: accountB));
    await profile.loadAuthenticatedProfile();

    expect(profile.isSignedIn, isTrue);
    expect(profile.currentUser?.username, 'bee');
    expect(profile.isCurrentAccount(accountB), isTrue);
  });

  test(
      'a session for the held account itself keeps its profile and announces '
      'the sign-in', () async {
    final profile = await heldAFromStoredWallet();
    var notified = 0;
    profile.addListener(() => notified++);

    await api.setAuthToken(AccountSessionFixture.jwt(
        accountId: accountA, wallet: forcedSignOutWallet));

    expect(profile.isSignedIn, isTrue);
    expect(profile.currentUser?.username, forcedSignOutUsername);
    expect(notified, greaterThan(0));
  });

  test('a credential restored at launch for B does not show held A', () async {
    final profile = await heldAFromStoredWallet();
    var notified = 0;
    profile.addListener(() => notified++);
    secure['jwt_token'] = AccountSessionFixture.jwt(accountId: accountB);
    api.resetCredentialStoreForTesting(store: AuthCredentialStore());

    await api.loadAuthToken();

    expect(api.hasAuthSession, isTrue, reason: 'the restore path ran');
    expect(profile.isSignedIn, isFalse);
    expect(profile.currentUser, isNull);
    expect(notified, greaterThan(0));
  });

  test('a session in place for B turns a held A profile into nobody', () async {
    final profile = await heldAFromStoredWallet();
    // The held profile is shown for a session that was never A's.
    AccountSessionFixture.start(accountId: accountB);
    expect(profile.isSignedIn, isFalse);
    expect(profile.currentUser, isNull);
    expect(profile.preferences.privacy.toLowerCase(), isNot('private'));
    expect(profile.userPersona, isNull);
  });
}
