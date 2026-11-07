import 'package:art_kubus/models/user_persona.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the profile saves a provider makes, and serves a fixed `/me` body.
class _RecordingProfileApi implements ProfileBackendApi {
  _RecordingProfileApi({this.myProfile = const <String, dynamic>{}});

  final Map<String, dynamic> myProfile;
  final List<Map<String, dynamic>> saveCalls = <Map<String, dynamic>>[];

  @override
  String get baseUrl => 'http://localhost';

  @override
  Future<Map<String, dynamic>> registerWallet({
    required String walletAddress,
    String? username,
  }) async =>
      {'success': true};

  @override
  Future<Map<String, dynamic>> getMyProfile() async => myProfile;

  @override
  Future<Map<String, dynamic>> getProfileByWallet(String walletAddress) async =>
      {};

  @override
  Future<Map<String, dynamic>> saveProfile(
    Map<String, dynamic> profileData,
  ) async {
    saveCalls.add(Map<String, dynamic>.from(profileData));
    // Echo the saved profile back as the backend does: the account id is the
    // only identity a walletless save gets.
    return {...profileData, 'id': 'acc-1', 'userId': 'acc-1'};
  }

  @override
  Future<Map<String, dynamic>> updateProfile(
    String walletAddress,
    Map<String, dynamic> updates,
  ) async =>
      {};

  @override
  Future<Map<String, dynamic>> uploadAvatarToProfile({
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
    Map<String, String>? metadata,
  }) async =>
      {};

  @override
  Future<bool> verifyImageUrl(String url) async => true;

  @override
  Future<void> followUser(String walletAddress) async {}

  @override
  Future<void> unfollowUser(String walletAddress) async {}

  @override
  Future<bool> isFollowing(String walletAddress) async => false;
}

UserProfile _walletlessAccount() => UserProfile.fromJson(<String, dynamic>{
      'id': 'acc-1',
      'userId': 'acc-1',
      'username': 'walker',
      'displayName': 'Walker',
      'bio': '',
      'avatar': '',
    });

UserProfile _walletAccount() => UserProfile.fromJson(<String, dynamic>{
      'id': 'profile_wallet',
      'walletAddress': 'WalletAbc123',
      'username': 'walletuser',
      'displayName': 'Wallet User',
      'bio': '',
      'avatar': '',
    });

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('walletless account role choice is saved, not dropped', () async {
    final api = _RecordingProfileApi();
    final provider = ProfileProvider(apiService: api)
      ..setCurrentUser(_walletlessAccount());

    expect(provider.needsStructuredRoleSelection, isTrue);

    await provider.setUserPersona(
      UserPersona.creator,
      persistToBackend: true,
      throwOnBackendFailure: true,
    );

    expect(provider.userPersona, UserPersona.creator);
    expect(provider.needsStructuredRoleSelection, isFalse);

    // The save goes through the account-scoped profile path: no wallet is
    // sent, and the persona travels in the preferences.
    expect(api.saveCalls, hasLength(1));
    final saved = api.saveCalls.single;
    expect(saved.containsKey('walletAddress'), isFalse);
    expect(
      (saved['preferences'] as Map<String, dynamic>)['persona'],
      UserPersona.creator.storageValue,
    );
  });

  test('walletless role choice survives a restart of the session', () async {
    final first = ProfileProvider(apiService: _RecordingProfileApi())
      ..setCurrentUser(_walletlessAccount());
    await first.setUserPersona(
      UserPersona.institution,
      persistToBackend: false,
    );

    // A fresh provider for the same account whose backend /me body carries no
    // persona: the locally kept, account-keyed choice must be restored.
    final restarted = ProfileProvider(
      apiService: _RecordingProfileApi(
        myProfile: <String, dynamic>{
          'id': 'acc-1',
          'userId': 'acc-1',
          'username': 'walker',
          'displayName': 'Walker',
          'bio': '',
          'avatar': '',
        },
      ),
    );
    await restarted.loadAuthenticatedProfile();

    expect(restarted.userPersona, UserPersona.institution);
    expect(restarted.needsStructuredRoleSelection, isFalse);
  });

  test('wallet account keeps saving its persona with the wallet', () async {
    final api = _RecordingProfileApi();
    final provider = ProfileProvider(apiService: api)
      ..setCurrentUser(_walletAccount());

    await provider.setUserPersona(
      UserPersona.institution,
      persistToBackend: true,
      throwOnBackendFailure: true,
    );

    expect(provider.userPersona, UserPersona.institution);
    expect(provider.needsStructuredRoleSelection, isFalse);
    expect(api.saveCalls, hasLength(1));
    expect(api.saveCalls.single['walletAddress'], 'WalletAbc123');
  });
}
