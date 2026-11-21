import 'package:art_kubus/screens/desktop/community/desktop_community_screen.dart';
import 'package:art_kubus/widgets/identity/kubus_identity_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/forced_sign_out_fixture.dart';
import '../../support/product_surface_harness.dart';
import '../../support/product_v5_qa_fixtures.dart';

/// L3 (and the L4 author preview, which reads the same accessor): the desktop
/// Community composer prompt shows the account avatar and role badge. The
/// compose dialog itself cannot open without a session (the compose gate
/// blocks it), so the prompt is the reachable surface after a forced sign-out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Iterable<KubusIdentityAvatar> avatars() => find
      .byType(KubusIdentityAvatar)
      .evaluate()
      .map((e) => e.widget as KubusIdentityAvatar);

  testWidgets('with a live session the composer prompt shows the account',
      (tester) async {
    final prior = FlutterError.onError;
    final owner = qaOwner(isArtist: true);
    await pumpProductSurface(
      tester,
      child: const DesktopCommunityScreen(),
      size: const Size(1440, 1000),
      signedInProfile: owner,
    );
    FlutterError.onError = prior;
    expect(
      avatars().any((a) => a.wallet == owner.walletAddress && a.isArtist),
      isTrue,
      reason: 'composer author avatar carries the account wallet and role',
    );
  });

  testWidgets('after a forced sign-out the composer prompt shows no account',
      (tester) async {
    final prior = FlutterError.onError;
    final held = await loadForcedSignOutProfile(tester);
    await pumpProductSurface(
      tester,
      child: const DesktopCommunityScreen(),
      size: const Size(1440, 1000),
      profileProvider: held,
    );
    FlutterError.onError = prior;
    expect(held.isSignedIn, isFalse);
    expect(avatars().any((a) => a.wallet == forcedSignOutWallet), isFalse,
        reason: 'no held wallet on an avatar');
    expect(avatars().any((a) => a.isArtist), isFalse,
        reason: 'no held role badge');
  });
}
