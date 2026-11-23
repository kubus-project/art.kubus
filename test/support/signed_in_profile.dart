import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/profile_provider.dart';

import 'account_session_fixture.dart';

/// The owner (ProfileProvider) holding a signed-in account, for tests that ask
/// "is this me". [accountId] is the session's account id (and the profile's
/// user id); a legacy wallet-only account passes none and is keyed by [wallet].
/// Call [AccountSessionFixture.end] in tear-down.
ProfileProvider signedInProfile({String? accountId, String? wallet}) {
  AccountSessionFixture.start(
    accountId: accountId ?? wallet ?? 'fixture-account',
    wallet: wallet,
  );
  return ProfileProvider()
    ..setCurrentUser(
      UserProfile(
        id: accountId ?? 'profile_local',
        userId: accountId,
        walletAddress: wallet ?? '',
        username: 'fixture',
        displayName: 'Fixture',
        bio: '',
        avatar: '',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
}
