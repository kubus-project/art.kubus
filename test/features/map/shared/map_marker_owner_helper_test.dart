import 'package:art_kubus/features/map/shared/map_screen_shared_helpers.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
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
        walletAddress: 'owner-wallet',
        currentUserId: null,
      ),
      isTrue,
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
        walletAddress: 'other-wallet',
        currentUserId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      ),
      isTrue,
    );
  });
}
