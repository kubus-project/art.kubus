import 'dart:async';
import 'dart:typed_data';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/community/profile_edit_screen.dart' as mobile;
import 'package:art_kubus/screens/desktop/community/desktop_profile_edit_screen.dart'
    as desktop;
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeProfileApi implements ProfileBackendApi {
  Map<String, dynamic>? nextSaveResponse;

  @override
  String get baseUrl => 'https://api.kubus.site';

  @override
  Future<Map<String, dynamic>> getProfileByWallet(String walletAddress) async {
    return <String, dynamic>{'walletAddress': walletAddress};
  }

  @override
  Future<Map<String, dynamic>?> getDAOReview({
    required String idOrWallet,
  }) async {
    return null;
  }

  @override
  Future<Map<String, dynamic>> registerWallet({
    required String walletAddress,
    String? username,
  }) async {
    return <String, dynamic>{'success': true};
  }

  @override
  Future<Map<String, dynamic>> saveProfile(
    Map<String, dynamic> profileData,
  ) async {
    return nextSaveResponse ??
        <String, dynamic>{
          'walletAddress': profileData['walletAddress'],
          'username': profileData['username'] ?? 'artist_user',
          'displayName': profileData['displayName'] ?? 'Artist User',
          'bio': profileData['bio'] ?? '',
          'avatar': profileData['avatar'] ?? '',
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
}

final Object _useInitialProfileAvatar = Object();

class _ProfileEditTestProvider extends ProfileProvider {
  _ProfileEditTestProvider({
    Object? avatar = _useInitialProfileAvatar,
    String? coverImage,
  }) : super(apiService: _FakeProfileApi()) {
    final avatarValue = identical(avatar, _useInitialProfileAvatar)
        ? _initialProfile.avatar
        : avatar?.toString() ?? '';
    setCurrentUser(
      _initialProfile.copyWith(
        avatar: avatarValue,
        coverImage: coverImage ?? _initialProfile.coverImage,
      ),
    );
  }

  static final _initialProfile = UserProfile(
    id: 'profile-1',
    walletAddress: 'ArtistWallet111111111111111111111111111111111',
    username: 'artist_user',
    displayName: 'Artist User',
    bio: 'Existing bio',
    avatar: '/uploads/profiles/avatars/current.png',
    coverImage: '/uploads/profiles/cover/current.png',
    createdAt: DateTime.parse('2026-03-31T00:00:00.000Z'),
    updatedAt: DateTime.parse('2026-03-31T00:00:00.000Z'),
  );

  Object? avatarUploadError;
  Object? coverUploadError;
  bool saveShouldTimeout = false;
  String? lastError;
  String? savedAvatar;
  String? savedCover;
  int loadProfileCalls = 0;

  @override
  String? get error => lastError;

  @override
  Future<String> uploadAvatarBytes({
    required List<int> fileBytes,
    required String fileName,
    required String walletAddress,
    String? mimeType,
  }) async {
    final error = avatarUploadError;
    if (error != null) {
      if (error is TimeoutException) throw error;
      throw Exception(error.toString());
    }
    return '/uploads/profiles/avatars/$fileName';
  }

  @override
  Future<Map<String, dynamic>> uploadProfileCoverBytes({
    required List<int> fileBytes,
    required String fileName,
    required String walletAddress,
  }) async {
    final error = coverUploadError;
    if (error != null) {
      if (error is TimeoutException) throw error;
      throw Exception(error.toString());
    }
    return <String, dynamic>{
      'uploadedUrl': '/uploads/profiles/cover/$fileName',
    };
  }

  @override
  Future<bool> saveProfile({
    required String walletAddress,
    String? username,
    String? displayName,
    String? bio,
    String? avatar,
    String? coverImage,
    Map<String, String>? social,
    List<String>? fieldOfWork,
    int? yearsActive,
    bool? isArtist,
    bool? isInstitution,
    ProfilePreferences? preferences,
    bool reloadStats = true,
  }) async {
    if (saveShouldTimeout) {
      lastError =
          'Profile save timed out. Your connection may be slow. Please retry.';
      notifyListeners();
      return false;
    }

    final current = currentUser ?? _initialProfile;
    savedAvatar = avatar;
    savedCover = coverImage;
    setCurrentUser(
      current.copyWith(
        username: username ?? current.username,
        displayName: displayName ?? current.displayName,
        bio: bio ?? current.bio,
        avatar: avatar ?? current.avatar,
        coverImage: coverImage ?? current.coverImage,
      ),
    );
    return true;
  }

  @override
  Future<void> updatePreferences({
    bool? privateProfile,
    bool? notificationsEnabled,
    NotificationPreferenceSettings? notificationPreferences,
    bool? showActivityStatus,
    bool? showAchievements,
    bool? shareLastVisitedLocation,
    bool? showCollection,
    bool? allowMessages,
  }) async {}

  @override
  Future<void> loadProfile(String walletAddress) async {
    loadProfileCalls += 1;
  }
}

Future<ProfileProvider> _seedProfile(_FakeProfileApi api) async {
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
  return provider;
}

Future<void> _pumpEditScreen(
  WidgetTester tester,
  ProfileProvider provider,
  Widget child,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileProvider>.value(value: provider),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('mobile edit profile listener ignores provisional empty media',
      (tester) async {
    final api = _FakeProfileApi();
    final provider = await _seedProfile(api);
    await _pumpEditScreen(tester, provider, const mobile.ProfileEditScreen());

    final state =
        tester.state(find.byType(mobile.ProfileEditScreen)) as dynamic;
    expect(
      state.debugAvatarUrl,
      'https://api.kubus.site/uploads/profiles/avatars/current.png',
    );
    expect(
      state.debugCoverImageUrl,
      'https://api.kubus.site/uploads/profiles/cover/current.png',
    );

    api.nextSaveResponse = <String, dynamic>{
      'walletAddress': 'ArtistWallet111111111111111111111111111111111',
      'username': 'artist_user',
      'displayName': 'Artist User',
      'bio': 'Provisional',
      'avatar': '',
      'coverImage': '',
      'createdAt': '2026-03-31T00:00:00.000Z',
      'updatedAt': '2026-03-31T00:00:00.000Z',
    };
    await provider.saveProfile(
      walletAddress: 'ArtistWallet111111111111111111111111111111111',
      username: 'artist_user',
      displayName: 'Artist User',
      bio: 'Provisional',
      reloadStats: false,
    );
    await tester.pump();

    expect(
      state.debugAvatarUrl,
      'https://api.kubus.site/uploads/profiles/avatars/current.png',
    );
    expect(
      state.debugCoverImageUrl,
      'https://api.kubus.site/uploads/profiles/cover/current.png',
    );
  });

  testWidgets(
      'desktop edit profile listener ignores provider media during upload',
      (tester) async {
    final api = _FakeProfileApi();
    final provider = await _seedProfile(api);
    await _pumpEditScreen(tester, provider, const desktop.ProfileEditScreen());

    final state =
        tester.state(find.byType(desktop.ProfileEditScreen)) as dynamic;
    state.debugSetMediaSyncState(
      isUploadingAvatar: true,
      isUploadingCover: true,
    );
    await tester.pump();

    api.nextSaveResponse = <String, dynamic>{
      'walletAddress': 'ArtistWallet111111111111111111111111111111111',
      'username': 'artist_user',
      'displayName': 'Artist User',
      'bio': 'Upload race',
      'avatar': '/uploads/profiles/avatars/provider.png',
      'coverImage': '/uploads/profiles/cover/provider.png',
      'createdAt': '2026-03-31T00:00:00.000Z',
      'updatedAt': '2026-03-31T00:00:00.000Z',
    };
    await provider.saveProfile(
      walletAddress: 'ArtistWallet111111111111111111111111111111111',
      username: 'artist_user',
      displayName: 'Artist User',
      bio: 'Upload race',
      avatar: '/uploads/profiles/avatars/provider.png',
      coverImage: '/uploads/profiles/cover/provider.png',
      reloadStats: false,
    );
    await tester.pump();

    expect(
      state.debugAvatarUrl,
      'https://api.kubus.site/uploads/profiles/avatars/current.png',
    );
    expect(
      state.debugCoverImageUrl,
      'https://api.kubus.site/uploads/profiles/cover/current.png',
    );
  });

  testWidgets('avatar upload timeout resets state and shows timeout message',
      (tester) async {
    final provider = _ProfileEditTestProvider()
      ..avatarUploadError = TimeoutException('avatar slow');
    await _pumpEditScreen(tester, provider, const mobile.ProfileEditScreen());

    final state =
        tester.state(find.byType(mobile.ProfileEditScreen)) as dynamic;
    await state.debugUploadAvatarBytesForTesting(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      fileName: 'avatar.png',
      mimeType: 'image/png',
    );
    await tester.pump();

    expect(
      find.text(
        'Profile image upload timed out. Please try a smaller image or retry.',
      ),
      findsOneWidget,
    );
    expect(state.debugIsUploadingAvatar, isFalse);
    expect(state.debugAvatarChanged, isFalse);
    expect(state.debugHasLocalAvatarBytes, isFalse);
    expect(
        provider.currentUser?.avatar, '/uploads/profiles/avatars/current.png');
  });

  testWidgets('cover upload timeout resets state and shows timeout message',
      (tester) async {
    final provider = _ProfileEditTestProvider()
      ..coverUploadError = TimeoutException('cover slow');
    await _pumpEditScreen(tester, provider, const mobile.ProfileEditScreen());

    final state =
        tester.state(find.byType(mobile.ProfileEditScreen)) as dynamic;
    await state.debugUploadCoverBytesForTesting(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      fileName: 'cover.png',
    );
    await tester.pump();

    expect(
      find.text(
        'Cover image upload timed out. Please try a smaller image or retry.',
      ),
      findsOneWidget,
    );
    expect(state.debugIsUploadingCover, isFalse);
    expect(state.debugCoverChanged, isFalse);
    expect(state.debugHasLocalCoverBytes, isFalse);
    expect(provider.currentUser?.coverImage,
        '/uploads/profiles/cover/current.png');
  });

  testWidgets('profile save timeout resets save state and preserves values',
      (tester) async {
    final provider = _ProfileEditTestProvider()..saveShouldTimeout = true;
    await _pumpEditScreen(tester, provider, const mobile.ProfileEditScreen());

    final state =
        tester.state(find.byType(mobile.ProfileEditScreen)) as dynamic;
    await state.debugSaveProfileForTesting();
    await tester.pump();

    expect(
      find.text(
        'Profile save timed out. Your connection may be slow. Please retry.',
      ),
      findsOneWidget,
    );
    expect(state.debugIsSavingProfile, isFalse);
    expect(provider.currentUser?.displayName, 'Artist User');
    expect(provider.currentUser?.bio, 'Existing bio');
    expect(
        provider.currentUser?.avatar, '/uploads/profiles/avatars/current.png');
    expect(provider.currentUser?.coverImage,
        '/uploads/profiles/cover/current.png');
  });

  testWidgets('successful avatar upload saves avatar and reloads profile',
      (tester) async {
    final provider = _ProfileEditTestProvider();
    await _pumpEditScreen(tester, provider, const mobile.ProfileEditScreen());

    final state =
        tester.state(find.byType(mobile.ProfileEditScreen)) as dynamic;
    await state.debugUploadAvatarBytesForTesting(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      fileName: 'fresh.png',
      mimeType: 'image/png',
    );
    await tester.pump();

    expect(provider.savedAvatar, '/uploads/profiles/avatars/fresh.png');
    expect(provider.savedCover, isNull);
    expect(provider.loadProfileCalls, 1);
    expect(
      state.debugAvatarUrl,
      'https://api.kubus.site/uploads/profiles/avatars/fresh.png',
    );
    expect(state.debugIsUploadingAvatar, isFalse);
    expect(state.debugAvatarChanged, isFalse);
    expect(state.debugHasLocalAvatarBytes, isFalse);
  });

  testWidgets('successful cover upload saves cover and reloads profile',
      (tester) async {
    final provider = _ProfileEditTestProvider();
    await _pumpEditScreen(tester, provider, const mobile.ProfileEditScreen());

    final state =
        tester.state(find.byType(mobile.ProfileEditScreen)) as dynamic;
    await state.debugUploadCoverBytesForTesting(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      fileName: 'fresh-cover.png',
    );
    await tester.pump();

    expect(provider.savedCover, '/uploads/profiles/cover/fresh-cover.png');
    expect(provider.savedAvatar, isNull);
    expect(provider.loadProfileCalls, 1);
    expect(state.debugIsUploadingCover, isFalse);
    expect(state.debugCoverChanged, isFalse);
    expect(state.debugHasLocalCoverBytes, isFalse);
  });

  testWidgets('mobile edit profile initializes with null, empty, or generated avatar',
      (tester) async {
    for (final avatar in <String?>[
      null,
      '',
      '/api/avatar/ArtistWallet111111111111111111111111111111111?style=identicon&format=png',
      'https://api.dicebear.com/9.x/identicon/png?seed=ArtistWallet111111111111111111111111111111111',
    ]) {
      final provider = _ProfileEditTestProvider(avatar: avatar);
      await _pumpEditScreen(tester, provider, const mobile.ProfileEditScreen());
      final state =
          tester.state(find.byType(mobile.ProfileEditScreen)) as dynamic;
      expect(state.debugAvatarUrl, isNull);
    }
  });
}
