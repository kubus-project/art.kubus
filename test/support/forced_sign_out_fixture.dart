import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serves one wallet's public profile by wallet address. That is how the
/// cold-start load reads a stored wallet when no account session is left.
class WalletProfileApi implements ProfileBackendApi {
  WalletProfileApi(this.profile);

  final Map<String, dynamic> profile;

  @override
  String get baseUrl => 'https://api.kubus.site';

  @override
  Future<Map<String, dynamic>> getMyProfile() async =>
      Map<String, dynamic>.from(profile);

  @override
  Future<Map<String, dynamic>> registerWallet({
    required String walletAddress,
    String? username,
  }) async =>
      <String, dynamic>{'success': true};

  @override
  Future<Map<String, dynamic>> getProfileByWallet(String walletAddress) async =>
      Map<String, dynamic>.from(profile);

  @override
  Future<Map<String, dynamic>> saveProfile(
          Map<String, dynamic> profileData) async =>
      Map<String, dynamic>.from(profileData);

  @override
  Future<Map<String, dynamic>> updateProfile(
    String walletAddress,
    Map<String, dynamic> updates,
  ) async =>
      <String, dynamic>{'success': true};

  @override
  Future<Map<String, dynamic>> uploadAvatarToProfile({
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
    Map<String, String>? metadata,
  }) async =>
      <String, dynamic>{};

  @override
  Future<bool> verifyImageUrl(String url) async => true;

  @override
  Future<void> followUser(String walletAddress) async {}

  @override
  Future<void> unfollowUser(String walletAddress) async {}

  @override
  Future<bool> isFollowing(String walletAddress) async => false;
}

/// The account the leak tests hold. An artist with a wallet, so every badge,
/// chip and owner affordance has something to show.
const String forcedSignOutWallet = 'WalletArtist111ForcedSignOut';
const String forcedSignOutUsername = 'qa088_artist';
const String forcedSignOutDisplayName = 'QA Artist Held';

Map<String, dynamic> forcedSignOutProfileJson({
  String wallet = forcedSignOutWallet,
  bool isArtist = true,
  bool isInstitution = false,
}) =>
    <String, dynamic>{
      'id': 'user-artist-held',
      'userId': 'user-artist-held',
      'walletAddress': wallet,
      'username': forcedSignOutUsername,
      'displayName': forcedSignOutDisplayName,
      'bio': 'Held bio that must not show without a session.',
      'avatar': '',
      'isArtist': isArtist,
      'isInstitution': isInstitution,
      'createdAt': '2026-03-31T00:00:00.000Z',
      'updatedAt': '2026-03-31T00:00:00.000Z',
    };

/// The state after a forced sign-out and a cold start: the stored wallet
/// survives, so the provider loads that wallet's profile, and no credential is
/// left behind it. The profile is held; nobody is signed in.
Future<ProfileProvider> loadForcedSignOutProfile(
  WidgetTester tester, {
  bool isArtist = true,
  bool isInstitution = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'wallet_address': forcedSignOutWallet,
    'has_wallet': true,
  });
  final profile = ProfileProvider(
    apiService: WalletProfileApi(
      forcedSignOutProfileJson(
        isArtist: isArtist,
        isInstitution: isInstitution,
      ),
    ),
  );
  // The load awaits real I/O, so it runs outside fake async.
  await tester.runAsync(() => profile.loadProfile(forcedSignOutWallet));
  return profile;
}
