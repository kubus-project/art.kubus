import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/account_session_fixture.dart';
import '../support/forced_sign_out_fixture.dart';

/// ProfileProvider is the one owner of "who is signed in and what is their
/// profile". These are the scenarios of the identity map (S1-S6, S3b) asserted
/// on the owner itself: one definition of signed in, one accessor that display
/// code reads, and an explicit held profile for restore and auth flows.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const accountId = 'user-artist-held';

  UserProfile profileOf({String wallet = forcedSignOutWallet}) => UserProfile(
        id: accountId,
        userId: accountId,
        walletAddress: wallet,
        username: forcedSignOutUsername,
        displayName: forcedSignOutDisplayName,
        bio: 'bio',
        avatar: '',
        isArtist: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  tearDown(() {
    AccountSessionFixture.end();
    AccountIdentity.notifyListenersChanged();
  });

  Future<ProfileProvider> heldWithoutSession() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'wallet_address': forcedSignOutWallet,
      'private_profile': true,
    });
    final profile = ProfileProvider(
      apiService: WalletProfileApi(forcedSignOutProfileJson()),
    );
    await profile.loadProfile(forcedSignOutWallet);
    return profile;
  }

  test('S1 signed in: a live session and a held profile', () async {
    AccountSessionFixture.start(
        accountId: accountId, wallet: forcedSignOutWallet);
    final profile = ProfileProvider(
      apiService: WalletProfileApi(forcedSignOutProfileJson()),
    );
    await profile.loadProfile(forcedSignOutWallet);

    expect(profile.isSignedIn, isTrue);
    expect(profile.currentUser?.username, forcedSignOutUsername);
    expect(profile.heldProfile, same(profile.currentUser));
  });

  test('S2 explicit logout: nothing is held and nobody is signed in', () async {
    AccountSessionFixture.start(
        accountId: accountId, wallet: forcedSignOutWallet);
    final profile = ProfileProvider()..setCurrentUser(profileOf());
    expect(profile.isSignedIn, isTrue);

    AccountSessionFixture.end();
    profile.signOut();

    expect(profile.isSignedIn, isFalse);
    expect(profile.currentUser, isNull);
    expect(profile.heldProfile, isNull);
  });

  test('S3 forced sign-out cold start: held, but nobody is signed in',
      () async {
    final profile = await heldWithoutSession();

    expect(profile.heldProfile?.username, forcedSignOutUsername);
    expect(profile.isSignedIn, isFalse);
    expect(profile.currentUser, isNull);
    expect(profile.userPersona, isNull);
    // The survived prefs mirror is not the account's setting.
    expect(profile.preferences.privacy.toLowerCase(), isNot('private'));
  });

  test('S4 wallet-only device is the same state as S3', () async {
    // A wallet that was never signed in: stored wallet, no token, same load.
    final profile = await heldWithoutSession();

    expect(profile.isSignedIn, isFalse);
    expect(profile.currentUser, isNull);
    expect(profile.followersCount, 0);
    expect(profile.formattedFollowersCount, '0');
  });

  test('S5 walletless account: a session and a profile with no wallet',
      () async {
    AccountSessionFixture.start(accountId: accountId);
    final profile = ProfileProvider()..setCurrentUser(profileOf(wallet: ''));

    expect(profile.isSignedIn, isTrue);
    expect(profile.currentUser?.walletAddress, isEmpty);
  });

  test('S6 guest: nothing held, nobody signed in', () {
    final profile = ProfileProvider();

    expect(profile.isSignedIn, isFalse);
    expect(profile.currentUser, isNull);
    expect(profile.heldProfile, isNull);
  });

  test('S3b a session lost in place clears the account at once', () async {
    AccountSessionFixture.start(
        accountId: accountId, wallet: forcedSignOutWallet);
    final profile = ProfileProvider()..setCurrentUser(profileOf());
    var notified = 0;
    profile.addListener(() => notified++);
    expect(profile.isSignedIn, isTrue);

    // clearAuth-only loss: token gone, identity change announced.
    AccountSessionFixture.end();
    AccountIdentity.notifyListenersChanged();

    expect(profile.isSignedIn, isFalse);
    expect(profile.currentUser, isNull);
    expect(profile.heldProfile, isNull);
    expect(notified, greaterThan(0));
  });

  test('a held profile becomes the signed-in account when its session starts',
      () async {
    final profile = await heldWithoutSession();
    var notified = 0;
    profile.addListener(() => notified++);
    expect(profile.isSignedIn, isFalse);

    // The session starts the way production starts one: the account key is
    // set, and nothing else is announced by hand.
    AccountSessionFixture.start(
        accountId: accountId, wallet: forcedSignOutWallet);

    expect(profile.isSignedIn, isTrue);
    expect(profile.currentUser?.username, forcedSignOutUsername);
    expect(notified, greaterThan(0), reason: 'listeners rebuild on sign-in');
  });

  group('isCurrentAccount', () {
    test(
        'matches account id, profile id, wallet and public actor id, only '
        'while signed in', () async {
      AccountSessionFixture.start(
          accountId: accountId, wallet: forcedSignOutWallet);
      final profile = ProfileProvider()
        ..setCurrentUser(
          profileOf().copyWith(publicActorId: 'actor-held'),
        );

      expect(profile.isCurrentAccount(accountId), isTrue);
      expect(profile.isCurrentAccount(forcedSignOutWallet), isTrue);
      expect(profile.isCurrentAccount('actor-held'), isTrue);
      expect(profile.isCurrentAccount('someone-else'), isFalse);
      expect(profile.isCurrentAccount(null), isFalse);
      expect(profile.isCurrentAccount(''), isFalse);

      AccountSessionFixture.end();
      AccountIdentity.notifyListenersChanged();
      expect(profile.isCurrentAccount(accountId), isFalse);
    });

    test('a held profile with no session is nobody', () async {
      final profile = await heldWithoutSession();

      expect(profile.isCurrentAccount(forcedSignOutWallet), isFalse);
      expect(profile.isCurrentAccount(accountId), isFalse);
    });
  });
}
