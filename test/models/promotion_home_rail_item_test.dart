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
}
