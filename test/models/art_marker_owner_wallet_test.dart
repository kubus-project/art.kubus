import 'package:art_kubus/models/art_marker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses canonical ownerWalletAddress separately from createdBy', () {
    final marker = ArtMarker.fromMap(<String, dynamic>{
      'id': 'marker-1',
      'name': 'Marker',
      'description': '',
      'latitude': 46.056946,
      'longitude': 14.505751,
      'markerType': 'artwork',
      'createdAt': '2026-01-01T00:00:00.000Z',
      'createdBy': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'ownerWalletAddress': 'owner-wallet',
    });

    expect(marker.createdBy, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    expect(marker.ownerWalletAddress, 'owner-wallet');
    expect(marker.toMap()['ownerWalletAddress'], 'owner-wallet');
  });

  test('falls back to owner wallet when createdBy is missing', () {
    final marker = ArtMarker.fromMap(<String, dynamic>{
      'id': 'marker-1',
      'name': 'Marker',
      'description': '',
      'latitude': 46.056946,
      'longitude': 14.505751,
      'markerType': 'artwork',
      'createdAt': '2026-01-01T00:00:00.000Z',
      'owner_wallet_address': 'owner-wallet',
    });

    expect(marker.createdBy, 'owner-wallet');
    expect(marker.ownerWalletAddress, 'owner-wallet');
  });
}
