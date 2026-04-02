import 'package:art_kubus/models/promotion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profileTargetId keeps profile ids and profile-backed institution ids',
      () {
    final profileItem = HomeRailItem.fromJson(<String, dynamic>{
      'id': 'wallet-artist-1',
      'entityType': 'profile',
      'title': 'Artist',
    });
    final institutionProfileItem = HomeRailItem.fromJson(<String, dynamic>{
      'id': 'wallet-institution-1',
      'entityType': 'institution',
      'title': 'Institution Profile',
    });

    expect(profileItem.profileTargetId, 'wallet-artist-1');
    expect(institutionProfileItem.profileTargetId, 'wallet-institution-1');
  });

  test('profileTargetId does not treat institution UUIDs as profile wallets',
      () {
    final institutionItem = HomeRailItem.fromJson(<String, dynamic>{
      'id': '108b0fff-0514-4acc-a508-465e7aa97b87',
      'entityType': 'institution',
      'title': 'Institution Entity',
    });

    expect(institutionItem.profileTargetId, isNull);
    expect(institutionItem.hasProfileTarget, isFalse);
  });

  test('artwork creator getters expose creator identity fields', () {
    final artworkItem = HomeRailItem.fromJson(<String, dynamic>{
      'id': 'art-1',
      'entityType': 'artwork',
      'title': 'Promoted Artwork',
      'subtitle': 'Ada Lovelace',
      'artistName': 'Ada Lovelace',
      'creatorDisplayName': 'Ada Lovelace',
      'creatorUsername': 'ada',
      'creatorWalletAddress': 'wallet-artist-1',
    });

    expect(artworkItem.creatorDisplayName, 'Ada Lovelace');
    expect(artworkItem.creatorArtistName, 'Ada Lovelace');
    expect(artworkItem.creatorUsername, 'ada');
    expect(artworkItem.creatorWalletAddress, 'wallet-artist-1');
    expect(artworkItem.creatorTargetId, 'wallet-artist-1');
  });
}
