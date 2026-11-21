import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/account_session_fixture.dart';
import '../support/forced_sign_out_fixture.dart';

/// A legacy wallet profile (profiles.user_id NULL, found by the wallet
/// fallback of GET /api/profiles/me) answers with the profile ROW id as `id`
/// and no `userId`. Its session token carries the users.id claim. The two ids
/// are different kinds of id and must never be compared: the wallet identifies
/// the account then.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const rowId = 'b1f0c0de-0000-4000-8000-000000000001';
  const accountId = 'a3c4d5e6-0000-4000-8000-0000000000aa';

  Map<String, dynamic> legacyJson() => <String, dynamic>{
        'id': rowId,
        'profileId': rowId,
        'userId': null,
        'walletAddress': forcedSignOutWallet,
        'username': 'legacy',
        'displayName': 'Legacy',
        'bio': '',
        'avatar': '',
        'createdAt': '2026-03-31T00:00:00.000Z',
        'updatedAt': '2026-03-31T00:00:00.000Z',
      };

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
  });
  tearDown(() {
    AccountSessionFixture.end();
    AccountIdentity.notifyListenersChanged();
  });

  Future<ProfileProvider> signedInLegacy(
      {String wallet = forcedSignOutWallet}) async {
    final profile = ProfileProvider(apiService: WalletProfileApi(legacyJson()));
    BackendApiService().setAuthTokenForTesting(
      AccountSessionFixture.jwt(accountId: accountId, wallet: wallet),
    );
    await profile.loadAuthenticatedProfile();
    return profile;
  }

  test('a legacy profile with no userId is the live session account by wallet',
      () async {
    final profile = await signedInLegacy();
    expect(profile.heldProfile?.accountId, isNull);
    expect(profile.isSignedIn, isTrue);
    expect(profile.currentUser?.username, 'legacy');
  });

  test('its own posts and messages keep owner affordances', () async {
    final profile = await signedInLegacy();
    // The author payload names the users.id account and the wallet.
    expect(
      profile.isCurrentAccountActor(
        accountId: accountId,
        wallet: forcedSignOutWallet,
      ),
      isTrue,
    );
    // Only the wallet is known (older payloads).
    expect(
      profile.isCurrentAccountActor(wallet: forcedSignOutWallet),
      isTrue,
    );
    // The profile row id is not an account id: an actor carrying it as its
    // account id, with another wallet, is somebody else.
    expect(
      profile.isCurrentAccountActor(accountId: rowId, wallet: 'other-wallet'),
      isFalse,
    );
    // The profile row id still names this profile as an identifier.
    expect(profile.isCurrentAccount(rowId), isTrue);
  });

  test('a session for another account still does not adopt the profile',
      () async {
    final profile = ProfileProvider(apiService: WalletProfileApi(legacyJson()));
    BackendApiService().setAuthTokenForTesting(
      AccountSessionFixture.jwt(
        accountId: accountId,
        wallet: 'someone-elses-wallet-0000000000000000000000',
      ),
    );
    await profile.loadAuthenticatedProfile();
    expect(profile.isSignedIn, isFalse);
    expect(profile.currentUser, isNull);
  });
}
