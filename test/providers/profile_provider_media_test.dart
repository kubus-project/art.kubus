import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/profile_media_ref_utils.dart';

class _FakeProfileApi implements ProfileBackendApi {
  Map<String, dynamic>? lastSavedProfile;
  Map<String, dynamic>? nextSaveResponse;

  @override
  String get baseUrl => 'https://api.kubus.site';

  @override
  Future<Map<String, dynamic>> registerWallet({
    required String walletAddress,
    String? username,
  }) async {
    return <String, dynamic>{'success': true};
  }

  @override
  Future<Map<String, dynamic>> getProfileByWallet(String walletAddress) async {
    return <String, dynamic>{'walletAddress': walletAddress};
  }

  @override
  Future<Map<String, dynamic>> saveProfile(Map<String, dynamic> profileData) async {
    lastSavedProfile = Map<String, dynamic>.from(profileData);
    return nextSaveResponse ?? <String, dynamic>{
      'walletAddress': profileData['walletAddress'],
      'username': profileData['username'] ?? 'artist_user',
      'displayName': profileData['displayName'] ?? 'Artist User',
      'bio': profileData['bio'] ?? '',
      'avatar': profileData['avatar'],
      'coverImage': profileData['coverImage'],
      'createdAt': '2026-03-31T00:00:00.000Z',
      'updatedAt': '2026-03-31T00:00:00.000Z',
    };
  }

  @override
  Future<Map<String, dynamic>> updateProfile(
    String walletAddress,
    Map<String, dynamic> updates,
  ) async {
    return <String, dynamic>{'success': true};
  }

  @override
  Future<Map<String, dynamic>> uploadAvatarToProfile({
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
    Map<String, String>? metadata,
  }) async {
    return <String, dynamic>{
      'uploadedUrl': '/uploads/profiles/avatars/$fileName',
    };
  }

  @override
  Future<void> followUser(String walletAddress) async {}

  @override
  Future<void> unfollowUser(String walletAddress) async {}

  @override
  Future<bool> isFollowing(String walletAddress) async => false;

  @override
  Future<Map<String, dynamic>?> getDAOReview({required String idOrWallet}) async {
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('ProfileMediaRefUtils flags generated avatars and keeps upload refs', () {
    expect(
      ProfileMediaRefUtils.isGeneratedAvatarRef(
        'https://api.kubus.site/api/avatar/abc?style=identicon&format=png',
      ),
      isTrue,
    );
    expect(ProfileMediaRefUtils.isGeneratedAvatarRef('/uploads/avatar.png'), isFalse);
    expect(
      ProfileMediaRefUtils.isPersistableAvatarRef('/uploads/avatar.png'),
      isTrue,
    );
    expect(
      ProfileMediaRefUtils.isPersistableAvatarRef(
        'https://api.kubus.site/api/avatar/abc?style=identicon&format=png',
      ),
      isFalse,
    );
    expect(
      ProfileMediaRefUtils.toPersistableCoverRef(
        'https://api.kubus.site/uploads/profiles/cover/one.png',
      ),
      '/uploads/profiles/cover/one.png',
    );
  });

  test('ProfileProvider saveProfile preserves avatar when omitted or empty', () async {
    final api = _FakeProfileApi();
    final provider = ProfileProvider(apiService: api);

    await provider.saveProfile(
      walletAddress: 'ArtistWallet111111111111111111111111111111111',
      username: 'artist_user',
      displayName: 'Artist User',
      bio: 'Updated bio',
      reloadStats: false,
    );

    expect(api.lastSavedProfile?['avatar'], isNull);

    await provider.saveProfile(
      walletAddress: 'ArtistWallet111111111111111111111111111111111',
      username: 'artist_user',
      displayName: 'Artist User',
      bio: 'Updated bio',
      avatar: '',
      reloadStats: false,
    );

    expect(api.lastSavedProfile?['avatar'], isNull);

    await provider.saveProfile(
      walletAddress: 'ArtistWallet111111111111111111111111111111111',
      username: 'artist_user',
      displayName: 'Artist User',
      bio: 'Updated bio',
      avatar: 'https://api.kubus.site/api/avatar/ArtistWallet111111111111111111111111111111111?style=identicon&format=png',
      reloadStats: false,
    );

    expect(api.lastSavedProfile?['avatar'], isNull);
  });

  test('ProfileProvider saveProfile normalizes backend cover URLs to stable paths', () async {
    final api = _FakeProfileApi();
    final provider = ProfileProvider(apiService: api);

    await provider.saveProfile(
      walletAddress: 'ArtistWallet111111111111111111111111111111111',
      username: 'artist_user',
      displayName: 'Artist User',
      bio: 'Updated bio',
      coverImage: 'https://api.kubus.site/uploads/profiles/cover/2026/cover.png',
      reloadStats: false,
    );

    expect(api.lastSavedProfile?['coverImage'], '/uploads/profiles/cover/2026/cover.png');
  });
}