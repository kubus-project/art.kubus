import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/utils/wallet_action_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/account_session_fixture.dart';
import '../support/forced_sign_out_fixture.dart';

/// The wallet side asks the one owner whether anybody is signed in. It keeps no
/// copy that can outlive the session (S3b: a session lost in place through a
/// clearAuth-only path, which never runs the wallet's own sign-out).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  tearDown(() {
    AccountSessionFixture.end();
    AccountIdentity.notifyListenersChanged();
  });

  bool signedInSeenByWallet(ProfileProvider profile, WalletProvider wallet) =>
      WalletSessionAccessSnapshot.fromProviders(
        profileProvider: profile,
        walletProvider: wallet,
      ).isSignedIn;

  test('the wallet side follows the owner through sign-in and a lost session',
      () async {
    AccountSessionFixture.start(
      accountId: 'user-artist-held',
      wallet: forcedSignOutWallet,
    );
    final wallet = WalletProvider(deferInit: true);
    final profile = ProfileProvider(
      apiService: WalletProfileApi(forcedSignOutProfileJson()),
    );
    await profile.loadProfile(forcedSignOutWallet);
    expect(signedInSeenByWallet(profile, wallet), isTrue);

    AccountSessionFixture.end();
    AccountIdentity.notifyListenersChanged();

    expect(profile.isSignedIn, isFalse);
    expect(signedInSeenByWallet(profile, wallet), isFalse);
  });

  test('a stored wallet with no session is not signed in on the wallet side',
      () async {
    final wallet = WalletProvider(deferInit: true);
    final profile = ProfileProvider(
      apiService: WalletProfileApi(forcedSignOutProfileJson()),
    );
    await profile.loadProfile(forcedSignOutWallet);

    expect(signedInSeenByWallet(profile, wallet), isFalse);
  });
}
