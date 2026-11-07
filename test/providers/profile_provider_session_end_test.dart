import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';

const MethodChannel _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

Map<String, dynamic> _account() => <String, dynamic>{
      'id': 'user-person',
      'userId': 'user-person',
      'walletAddress': 'WalletAddr111',
      'username': 'person',
      'displayName': 'Person',
      'bio': '',
      'avatar': '',
      'createdAt': '2026-03-31T00:00:00.000Z',
      'updatedAt': '2026-03-31T00:00:00.000Z',
    };

/// Answers the account at once; subclasses hold one call open so a test can end
/// the session while it is still in flight.
class _HeldApi implements ProfileBackendApi {
  @override
  String get baseUrl => 'https://api.kubus.site';

  @override
  Future<Map<String, dynamic>> getMyProfile() async => _account();

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

/// Holds the account save open so a test can end the session while the save
/// is still in flight.
class _HeldSaveApi extends _HeldApi {
  final Completer<void> saveStarted = Completer<void>();
  final Completer<Map<String, dynamic>> _save =
      Completer<Map<String, dynamic>>();

  void answerSave(Map<String, dynamic> saved) => _save.complete(saved);

  @override
  Future<Map<String, dynamic>> saveProfile(
    Map<String, dynamic> profileData,
  ) {
    if (!saveStarted.isCompleted) saveStarted.complete();
    return _save.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  test('a profile save that finishes after sign-out restores no account state',
      () async {
    final api = _HeldSaveApi();
    final provider = ProfileProvider(apiService: api);
    final save = provider.saveProfile(
      walletAddress: 'WalletAddr111',
      username: 'person',
      reloadStats: false,
    );
    await api.saveStarted.future;

    // Sign-out lands while the save is in flight.
    await BackendApiService().clearAuth();
    provider.signOut();
    api.answerSave(_account());

    expect(await save, isFalse);
    expect(provider.isSignedIn, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wallet_address'), isNull);
    expect(prefs.getString('username'), isNull);
  });

  test('a profile save for a session that stays open persists the account',
      () async {
    final api = _HeldSaveApi();
    final provider = ProfileProvider(apiService: api);
    final save = provider.saveProfile(
      walletAddress: 'WalletAddr111',
      username: 'person',
      reloadStats: false,
    );
    await api.saveStarted.future;
    api.answerSave(_account());

    expect(await save, isTrue);
    expect(provider.isSignedIn, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wallet_address'), 'WalletAddr111');
    expect(prefs.getString('username'), 'person');
  });
}
