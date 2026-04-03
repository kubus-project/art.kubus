import 'package:art_kubus/models/promotion.dart';
import 'package:art_kubus/widgets/profile_identity_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromProfileMap prefers explicit avatar fields and sanitized handle', () {
    final identity = ProfileIdentityData.fromProfileMap(
      <String, dynamic>{
        'id': 'wallet-artist-1',
        'displayName': 'Ada Lovelace',
        'username': '@ada',
        'avatar_url': '/uploads/ada-avatar.png',
        'cover_image_url': '/uploads/ada-cover.png',
      },
      fallbackLabel: 'Creator',
    );

    expect(identity.label, 'Ada Lovelace');
    expect(identity.handle, '@ada');
    expect(identity.username, 'ada');
    expect(identity.avatarUrl, '/uploads/ada-avatar.png');
    expect(identity.userId, 'wallet-artist-1');
  });

  test('fromHomeRailItem profile uses avatar fields instead of cover image', () {
    final item = HomeRailItem.fromJson(<String, dynamic>{
      'id': 'wallet-artist-1',
      'entityType': 'profile',
      'title': 'Ada Lovelace',
      'subtitle': '@ada',
      'imageUrl': '/uploads/ada-cover.png',
      'avatar_url': '/uploads/ada-avatar.png',
    });

    final identity = ProfileIdentityData.fromHomeRailItem(
      item,
      fallbackLabel: 'Creator',
    );

    expect(identity.label, 'Ada Lovelace');
    expect(identity.handle, '@ada');
    expect(identity.avatarUrl, '/uploads/ada-avatar.png');
    expect(identity.userId, 'wallet-artist-1');
  });
}
