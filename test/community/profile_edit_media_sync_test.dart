import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/community/profile_edit_screen.dart' as mobile;
import 'package:art_kubus/screens/desktop/community/desktop_profile_edit_screen.dart'
    as desktop;
import 'package:art_kubus/services/backend_api_service.dart';
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

    final state = tester.state(find.byType(mobile.ProfileEditScreen)) as dynamic;
    expect(state.debugAvatarUrl, '/uploads/profiles/avatars/current.png');
    expect(state.debugCoverImageUrl, '/uploads/profiles/cover/current.png');

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

    expect(state.debugAvatarUrl, '/uploads/profiles/avatars/current.png');
    expect(state.debugCoverImageUrl, '/uploads/profiles/cover/current.png');
  });

  testWidgets('desktop edit profile listener ignores provider media during upload',
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

    expect(state.debugAvatarUrl, '/uploads/profiles/avatars/current.png');
    expect(state.debugCoverImageUrl, '/uploads/profiles/cover/current.png');
  });
}
