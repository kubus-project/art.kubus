import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:art_kubus/screens/desktop/desktop_home_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  Artwork artwork({String? wallet, String artist = ''}) => Artwork(
        id: 'public-artwork',
        title: 'Public artwork',
        artist: artist,
        walletAddress: wallet,
        description: '',
        position: const LatLng(0, 0),
        rewards: 0,
        createdAt: DateTime.utc(2026),
      );

  ProfileIdentityData identityFor(Artwork artwork) {
    final rows = buildDesktopTopCreatorSummaries(
      communityPosts: const [],
      artworks: [artwork],
      resolvedIdentities: const {},
      fallbackLabel: 'Creator',
    );
    return ProfileIdentityData.fromIdentityPayload(
      {'author': rows.single},
      fallbackLabel: 'Creator',
    );
  }

  test('fallback creator remains display-only through summary projection', () {
    final identity = identityFor(artwork());
    expect(identity.label, 'Creator');
    expect(identity.navigationIdentifier, isNull);
    expect(identity.canOpenProfile, isFalse);
  });

  test('named creator without wallet remains display-only', () {
    final identity = identityFor(artwork(artist: 'Mina Artist'));
    expect(identity.label, 'Mina Artist');
    expect(identity.canOpenProfile, isFalse);
  });

  test('real creator wallet remains usable for profile lookup', () {
    const wallet = '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final identity =
        identityFor(artwork(wallet: wallet, artist: 'Mina Artist'));
    expect(identity.label, 'Mina Artist');
    expect(identity.navigationIdentifier, wallet);
    expect(identity.canOpenProfile, isTrue);
  });
}
