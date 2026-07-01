import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserProfile parses explicit avatar fields without transport services',
      () {
    final profile = UserProfile.fromJson(<String, dynamic>{
      'id': 'profile-1',
      'walletAddress': 'wallet-1',
      'username': 'artist_user',
      'displayName': 'Artist User',
      'bio': 'Bio',
      'avatar_url': '/uploads/profiles/avatars/current.png',
      'createdAt': '2026-03-31T00:00:00.000Z',
      'updatedAt': '2026-03-31T00:00:00.000Z',
    });

    expect(profile.avatar, '/uploads/profiles/avatars/current.png');
  });

  test('sample avatars use configured backend avatar base', () {
    final normalizedBase = AppConfig.baseApiUrl.replaceAll(RegExp(r'/$'), '');
    final samples = UserProfileSamples.getSampleUsers();

    expect(samples, isNotEmpty);
    for (final sample in samples) {
      expect(sample.avatar, startsWith('$normalizedBase/api/avatar/'));
    }
  });
}
