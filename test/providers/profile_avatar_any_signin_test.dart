import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/profile_edit_error_messages.dart';

/// Email/Google sessions have no wallet. The fake records what the provider
/// sends so tests can assert the wallet is omitted and the URL is persisted.
class _EmailSessionApi implements ProfileBackendApi {
  Map<String, dynamic>? lastSavedProfile;
  Map<String, String>? lastUploadMetadata;
  Object? uploadError;
  Object? saveError;
  Map<String, dynamic> uploadResponse = <String, dynamic>{
    'uploadedUrl': '/uploads/profiles/avatars/fresh.png',
  };

  @override
  String get baseUrl => 'https://api.kubus.site';

  @override
  Future<Map<String, dynamic>> saveProfile(
    Map<String, dynamic> profileData,
  ) async {
    final error = saveError;
    if (error != null) throw error;
    lastSavedProfile = Map<String, dynamic>.from(profileData);
    return <String, dynamic>{
      'username': profileData['username'] ?? 'alice',
      'displayName': profileData['displayName'] ?? 'Alice',
      'bio': profileData['bio'] ?? '',
      'avatar': profileData['avatar'] ?? '',
      'createdAt': '2026-03-31T00:00:00.000Z',
      'updatedAt': '2026-03-31T00:00:00.000Z',
    };
  }

  @override
  Future<Map<String, dynamic>> uploadAvatarToProfile({
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
    Map<String, String>? metadata,
  }) async {
    lastUploadMetadata =
        metadata == null ? null : Map<String, String>.from(metadata);
    final error = uploadError;
    if (error != null) throw error;
    return uploadResponse;
  }

  @override
  Future<bool> verifyImageUrl(String url) async => true;

  @override
  Future<Map<String, dynamic>> registerWallet({
    required String walletAddress,
    String? username,
  }) async =>
      <String, dynamic>{'success': true};

  @override
  Future<Map<String, dynamic>> getProfileByWallet(String walletAddress) async =>
      <String, dynamic>{'success': false, 'status': 404};

  @override
  Future<Map<String, dynamic>> getMyProfile() async =>
      <String, dynamic>{'success': false, 'status': 404};

  @override
  Future<Map<String, dynamic>> updateProfile(
    String walletAddress,
    Map<String, dynamic> updates,
  ) async =>
      <String, dynamic>{'success': true};

  @override
  Future<void> followUser(String walletAddress) async {}

  @override
  Future<void> unfollowUser(String walletAddress) async {}

  @override
  Future<bool> isFollowing(String walletAddress) async => false;

  @override
  Future<Map<String, dynamic>?> getDAOReview({
    required String idOrWallet,
  }) async =>
      null;
}

UserProfile _emailAccount() => UserProfile(
      id: 'user-email',
      walletAddress: '',
      username: 'alice',
      displayName: 'Alice',
      bio: '',
      avatar: '',
      createdAt: DateTime.parse('2026-03-31T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-03-31T00:00:00.000Z'),
    );

ProfileProvider _emailProvider(_EmailSessionApi api) {
  final provider = ProfileProvider(apiService: api);
  provider.setCurrentUser(_emailAccount());
  return provider;
}

BackendApiRequestException _httpError(int status, String body) =>
    BackendApiRequestException(
      statusCode: status,
      path: '/api/profiles/avatars',
      body: body,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('(a) an email session uploads without a wallet or wallet metadata',
      () async {
    final api = _EmailSessionApi();
    final provider = _emailProvider(api);

    final url = await provider.uploadAvatarBytes(
      fileBytes: <int>[1, 2, 3],
      fileName: 'avatar.png',
      walletAddress: '',
    );

    expect(url, isNotEmpty);
    expect(api.lastUploadMetadata?.containsKey('walletAddress'), isFalse);
  });

  test('(a) an email-session save omits walletAddress from the body', () async {
    final api = _EmailSessionApi();
    final provider = _emailProvider(api);

    final saved = await provider.saveProfile(
      walletAddress: '',
      displayName: 'Alice',
      reloadStats: false,
    );

    expect(saved, isTrue);
    expect(api.lastSavedProfile?.containsKey('walletAddress'), isFalse);
  });

  test('(b) an upload error code is kept on the thrown failure', () async {
    final api = _EmailSessionApi()
      ..uploadError = _httpError(
        403,
        '{"errorCode":"PROFILE_OWNERSHIP_MISMATCH"}',
      );
    final provider = _emailProvider(api);

    await expectLater(
      provider.uploadAvatarBytes(
        fileBytes: <int>[1],
        fileName: 'avatar.png',
        walletAddress: '',
      ),
      throwsA(
        isA<ProfileRequestFailure>()
            .having(
                (f) => f.errorCode, 'errorCode', 'PROFILE_OWNERSHIP_MISMATCH')
            .having((f) => f.statusCode, 'statusCode', 403),
      ),
    );
  });

  test('(b) a save error code is exposed as lastSaveFailure', () async {
    final api = _EmailSessionApi()
      ..saveError = _httpError(
        403,
        '{"errorCode":"WALLET_SIGNATURE_REQUIRED"}',
      );
    final provider = _emailProvider(api);

    final saved = await provider.saveProfile(
      walletAddress: '',
      displayName: 'Alice',
      reloadStats: false,
    );

    expect(saved, isFalse);
    expect(provider.lastSaveFailure?.errorCode, 'WALLET_SIGNATURE_REQUIRED');
  });

  test('(b) an error code maps to the specific localized message', () async {
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(
      profileEditAvatarUploadErrorMessage(
        l10n,
        const ProfileRequestFailure(errorCode: 'FILE_TOO_LARGE'),
      ),
      l10n.profileEditAvatarErrorTooLargeToast,
    );
    expect(
      profileEditSaveErrorMessage(
        l10n,
        const ProfileRequestFailure(errorCode: 'PROFILE_OWNERSHIP_MISMATCH'),
      ),
      l10n.profileEditErrorOwnershipMismatchToast,
    );
    expect(
      profileEditAvatarUploadErrorMessage(
        l10n,
        const ProfileRequestFailure(statusCode: 415),
      ),
      l10n.profileEditAvatarErrorUnsupportedTypeToast,
    );
    expect(
      profileEditAvatarUploadErrorMessage(
        l10n,
        const ProfileRequestFailure(errorCode: 'SOMETHING_ELSE'),
      ),
      l10n.profileEditAvatarUploadFailedToast,
    );
  });

  test('an upload without a returned URL throws instead of returning empty',
      () async {
    final api = _EmailSessionApi()..uploadResponse = <String, dynamic>{};
    final provider = _emailProvider(api);

    await expectLater(
      provider.uploadAvatarBytes(
        fileBytes: <int>[1],
        fileName: 'avatar.png',
        walletAddress: '',
      ),
      throwsA(isA<ProfileRequestFailure>()),
    );
  });

  test('(c) the uploaded URL reaches the save payload and the provider cache',
      () async {
    final api = _EmailSessionApi();
    final provider = _emailProvider(api);

    final uploaded = await provider.uploadAvatarBytes(
      fileBytes: <int>[1, 2, 3],
      fileName: 'fresh.png',
      walletAddress: '',
    );
    final saved = await provider.saveProfile(
      walletAddress: '',
      avatar: uploaded,
      reloadStats: false,
    );

    expect(saved, isTrue);
    expect(
        api.lastSavedProfile?['avatar'], '/uploads/profiles/avatars/fresh.png');
    expect(provider.currentUser?.avatar,
        contains('/uploads/profiles/avatars/fresh.png'));
  });

  test('(c) the cache keeps the submitted avatar when the response omits it',
      () async {
    final api = _EmailSessionApi();
    final provider = _emailProvider(api);

    await provider.saveProfile(
      walletAddress: '',
      avatar: '/uploads/profiles/avatars/kept.png',
      reloadStats: false,
    );

    expect(provider.currentUser?.avatar,
        contains('/uploads/profiles/avatars/kept.png'));
  });
}
