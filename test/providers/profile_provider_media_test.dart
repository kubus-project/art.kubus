import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/profile_media_ref_utils.dart';

class _FakeProfileApi implements ProfileBackendApi {
  Map<String, dynamic>? lastSavedProfile;
  Map<String, dynamic>? lastProfileUpdate;
  Map<String, dynamic>? nextSaveResponse;
  Object? saveError;
  Object? updateError;
  Object? uploadError;
  int updateProfileCalls = 0;

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
  Future<Map<String, dynamic>> getMyProfile() async {
    return <String, dynamic>{'success': false, 'status': 404};
  }

  @override
  Future<Map<String, dynamic>> saveProfile(
      Map<String, dynamic> profileData) async {
    final error = saveError;
    if (error != null) {
      throw error;
    }
    lastSavedProfile = Map<String, dynamic>.from(profileData);
    return nextSaveResponse ??
        <String, dynamic>{
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
    updateProfileCalls += 1;
    lastProfileUpdate = <String, dynamic>{
      'walletAddress': walletAddress,
      ...updates,
    };
    final error = updateError;
    if (error != null) {
      throw error;
    }
    return <String, dynamic>{'success': true};
  }

  @override
  Future<Map<String, dynamic>> uploadAvatarToProfile({
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
    Map<String, String>? metadata,
  }) async {
    final error = uploadError;
    if (error != null) {
      throw error;
    }
    return <String, dynamic>{
      'uploadedUrl': '/uploads/profiles/avatars/$fileName',
    };
  }

  @override
  Future<bool> verifyImageUrl(String url) async => true;

  @override
  Future<void> followUser(String walletAddress) async {}

  @override
  Future<void> unfollowUser(String walletAddress) async {}

  @override
  Future<bool> isFollowing(String walletAddress) async => false;

  @override
  Future<Map<String, dynamic>?> getDAOReview(
      {required String idOrWallet}) async {
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  UserProfile profileForPreferences({
    ProfilePreferences? preferences,
  }) {
    return UserProfile(
      id: 'profile-1',
      walletAddress: 'ArtistWallet111111111111111111111111111111111',
      username: 'artist_user',
      displayName: 'Artist User',
      bio: 'Existing bio',
      avatar: '/uploads/profiles/avatars/current.png',
      coverImage: '/uploads/profiles/cover/current.png',
      preferences: preferences ?? ProfilePreferences(),
      createdAt: DateTime.parse('2026-03-31T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-03-31T00:00:00.000Z'),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('ProfileMediaRefUtils flags generated avatars and keeps upload refs',
      () {
    expect(
      ProfileMediaRefUtils.isGeneratedAvatarRef(
        'https://api.kubus.site/api/avatar/abc?style=identicon&format=png',
      ),
      isTrue,
    );
    expect(
      ProfileMediaRefUtils.isGeneratedAvatarRef(
        '/api/avatar/wallet?style=identicon',
      ),
      isTrue,
    );
    expect(
      ProfileMediaRefUtils.isGeneratedAvatarRef(
        'https://api.dicebear.com/9.x/identicon/png?seed=wallet',
      ),
      isTrue,
    );
    expect(ProfileMediaRefUtils.isGeneratedAvatarRef(''), isTrue);
    expect(ProfileMediaRefUtils.isGeneratedAvatarRef('/uploads/avatar.png'),
        isFalse);
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
      ProfileMediaRefUtils.toPersistableAvatarRef(
        '/api/avatar/wallet?style=identicon',
      ),
      isNull,
    );
    expect(
      ProfileMediaRefUtils.toPersistableAvatarRef('/uploads/a.png'),
      '/uploads/a.png',
    );
    expect(
      ProfileMediaRefUtils.toPersistableAvatarRef('uploads/a.png'),
      '/uploads/a.png',
    );
    expect(ProfileMediaRefUtils.toPersistableAvatarRef(null), isNull);
    expect(ProfileMediaRefUtils.toPersistableAvatarRef(''), isNull);
    expect(
      ProfileMediaRefUtils.toPersistableCoverRef(
        'https://api.kubus.site/uploads/profiles/cover/one.png',
      ),
      '/uploads/profiles/cover/one.png',
    );
  });

  test(
      'ProfileProvider saveProfile omits avatar when omitted, empty, or generated',
      () async {
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
      avatar:
          'https://api.kubus.site/api/avatar/ArtistWallet111111111111111111111111111111111?style=identicon&format=png',
      reloadStats: false,
    );

    expect(api.lastSavedProfile?['avatar'], isNull);
  });

  test('ProfileProvider text-only save does not resend current avatar or cover',
      () async {
    final api = _FakeProfileApi();
    final provider = ProfileProvider(apiService: api);

    api.nextSaveResponse = <String, dynamic>{
      'walletAddress': 'ArtistWallet111111111111111111111111111111111',
      'username': 'artist_user',
      'displayName': 'Artist User',
      'bio': 'Initial bio',
      'avatar': '/uploads/profiles/avatars/current.png',
      'coverImage': '/uploads/profiles/cover/current.png',
      'createdAt': '2026-03-31T00:00:00.000Z',
      'updatedAt': '2026-03-31T00:00:00.000Z',
    };

    await provider.saveProfile(
      walletAddress: 'ArtistWallet111111111111111111111111111111111',
      username: 'artist_user',
      displayName: 'Artist User',
      bio: 'Initial bio',
      avatar: '/uploads/profiles/avatars/current.png',
      coverImage: '/uploads/profiles/cover/current.png',
      reloadStats: false,
    );

    api.nextSaveResponse = <String, dynamic>{
      'walletAddress': 'ArtistWallet111111111111111111111111111111111',
      'username': 'artist_user',
      'displayName': 'Artist User',
      'bio': 'Updated text only',
      'avatar': '/uploads/profiles/avatars/current.png',
      'coverImage': '/uploads/profiles/cover/current.png',
      'createdAt': '2026-03-31T00:00:00.000Z',
      'updatedAt': '2026-03-31T00:00:00.000Z',
    };

    await provider.saveProfile(
      walletAddress: 'ArtistWallet111111111111111111111111111111111',
      username: 'artist_user',
      displayName: 'Artist User',
      bio: 'Updated text only',
      reloadStats: false,
    );

    expect(api.lastSavedProfile?.containsKey('avatar'), isFalse);
    expect(api.lastSavedProfile?.containsKey('coverImage'), isFalse);
  });

  test(
      'ProfileProvider saveProfile normalizes backend cover URLs to stable paths',
      () async {
    final api = _FakeProfileApi();
    final provider = ProfileProvider(apiService: api);

    await provider.saveProfile(
      walletAddress: 'ArtistWallet111111111111111111111111111111111',
      username: 'artist_user',
      displayName: 'Artist User',
      bio: 'Updated bio',
      coverImage:
          'https://api.kubus.site/uploads/profiles/cover/2026/cover.png',
      reloadStats: false,
    );

    expect(api.lastSavedProfile?['coverImage'],
        '/uploads/profiles/cover/2026/cover.png');
  });

  test('ProfileProvider saveProfile clears loading after save exceptions',
      () async {
    final api = _FakeProfileApi()..saveError = Exception('network timeout');
    final provider = ProfileProvider(apiService: api);

    final saved = await provider.saveProfile(
      walletAddress: 'ArtistWallet111111111111111111111111111111111',
      username: 'artist_user',
      reloadStats: false,
    );

    expect(saved, isFalse);
    expect(provider.isLoading, isFalse);
    expect(provider.error, contains('network timeout'));
  });

  test('ProfileProvider exposes failed preference backend sync for retry',
      () async {
    final api = _FakeProfileApi()
      ..updateError = Exception('profile update rejected');
    final provider = ProfileProvider(apiService: api)
      ..setCurrentUser(profileForPreferences());

    await provider.updatePreferences(showCollection: false);

    expect(provider.preferences.showCollection, isFalse);
    expect(provider.isSavingPreferences, isFalse);
    expect(provider.hasUnsyncedPreferences, isTrue);
    expect(provider.hasPendingPreferenceSync, isTrue);
    expect(provider.preferencesSaveError, contains('profile update rejected'));
    expect(api.updateProfileCalls, 1);
    expect(
      (api.lastProfileUpdate?['preferences']
          as Map<String, dynamic>)['showCollection'],
      isFalse,
    );

    api.updateError = null;
    final synced = await provider.retryPreferenceSync();

    expect(synced, isTrue);
    expect(provider.isSavingPreferences, isFalse);
    expect(provider.hasUnsyncedPreferences, isFalse);
    expect(provider.hasPendingPreferenceSync, isFalse);
    expect(provider.preferencesSaveError, isNull);
    expect(api.updateProfileCalls, 2);
  });

  test('ProfileProvider saveProfile timeout keeps current profile values',
      () async {
    final api = _FakeProfileApi();
    final provider = ProfileProvider(apiService: api);

    await provider.saveProfile(
      walletAddress: 'ArtistWallet111111111111111111111111111111111',
      username: 'artist_user',
      displayName: 'Artist User',
      bio: 'Existing bio',
      avatar: '/uploads/profiles/avatars/current.png',
      coverImage: '/uploads/profiles/cover/current.png',
      reloadStats: false,
    );

    api.saveError = TimeoutException('profile save timed out');
    final saved = await provider.saveProfile(
      walletAddress: 'ArtistWallet111111111111111111111111111111111',
      username: 'artist_user',
      displayName: 'Changed User',
      bio: 'Changed bio',
      reloadStats: false,
    );

    expect(saved, isFalse);
    expect(provider.isLoading, isFalse);
    expect(provider.error, contains('Profile save timed out'));
    expect(provider.currentUser?.displayName, 'Artist User');
    expect(provider.currentUser?.bio, 'Existing bio');
    expect(provider.currentUser?.avatar,
        'https://api.kubus.site/uploads/profiles/avatars/current.png');
    expect(provider.currentUser?.coverImage,
        '/uploads/profiles/cover/current.png');
  });

  test('ProfileProvider avatar upload timeout remains typed and debuggable',
      () async {
    final api = _FakeProfileApi()
      ..uploadError = TimeoutException('avatar upload timed out');
    final provider = ProfileProvider(apiService: api);

    await expectLater(
      provider.uploadAvatarBytes(
        fileBytes: <int>[1, 2, 3],
        fileName: 'avatar.png',
        walletAddress: 'ArtistWallet111111111111111111111111111111111',
      ),
      throwsA(isA<TimeoutException>()),
    );

    expect(provider.lastUploadDebug?['error'],
        contains('avatar upload timed out'));
  });
}
