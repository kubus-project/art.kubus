import 'package:art_kubus/features/map/shared/map_screen_shared_helpers.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../../support/account_session_fixture.dart';

UserProfile _profile({required String wallet, String userId = 'user-1'}) =>
    UserProfile(
      id: 'profile-$userId',
      userId: userId,
      walletAddress: wallet,
      username: 'owner',
      displayName: 'Owner',
      bio: '',
      avatar: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// A signed-in account: a live session behind its held profile.
ProfileProvider _signedIn({required String wallet, required String userId}) {
  AccountSessionFixture.start(accountId: userId, wallet: wallet);
  return ProfileProvider()
    ..setCurrentUser(_profile(wallet: wallet, userId: userId));
}

void main() {
  tearDown(AccountSessionFixture.end);

  test('markerOwnedByCurrentUser uses canonical owner wallet address', () {
    final marker = ArtMarker(
      id: 'marker-1',
      name: 'Marker',
      description: '',
      position: const LatLng(46.056946, 14.505751),
      type: ArtMarkerType.artwork,
      createdAt: DateTime.utc(2026, 1, 1),
      createdBy: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      ownerWalletAddress: 'owner-wallet',
    );

    expect(
      KubusMarkerOverlayHelpers.markerOwnedByCurrentUser(
        marker: marker,
        profile: _signedIn(wallet: 'owner-wallet', userId: 'someone-else'),
      ),
      isTrue,
    );
  });

  test('markerOwnedByCurrentUser is false for a held profile with no session',
      () {
    final marker = ArtMarker(
      id: 'marker-1',
      name: 'Marker',
      description: '',
      position: const LatLng(46.056946, 14.505751),
      type: ArtMarkerType.artwork,
      createdAt: DateTime.utc(2026, 1, 1),
      createdBy: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      ownerWalletAddress: 'owner-wallet',
    );
    AccountSessionFixture.end();

    expect(
      KubusMarkerOverlayHelpers.markerOwnedByCurrentUser(
        marker: marker,
        profile: ProfileProvider()
          ..setCurrentUser(_profile(wallet: 'owner-wallet')),
      ),
      isFalse,
    );
  });

  test('markerOwnedByCurrentUser still accepts user id ownership', () {
    final marker = ArtMarker(
      id: 'marker-1',
      name: 'Marker',
      description: '',
      position: const LatLng(46.056946, 14.505751),
      type: ArtMarkerType.artwork,
      createdAt: DateTime.utc(2026, 1, 1),
      createdBy: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      ownerWalletAddress: 'owner-wallet',
    );

    expect(
      KubusMarkerOverlayHelpers.markerOwnedByCurrentUser(
        marker: marker,
        profile: _signedIn(
          wallet: 'other-wallet',
          userId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        ),
      ),
      isTrue,
    );
  });
}
