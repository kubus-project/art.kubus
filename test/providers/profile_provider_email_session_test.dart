import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';

/// Serves one authenticated account at a time, so a test can swap the session
/// between accounts. No wallet is involved: the email session has no wallet.
class _SessionProfileApi implements ProfileBackendApi {
  Map<String, dynamic>? account;

  @override
  String get baseUrl => 'https://api.kubus.site';

  @override
  Future<Map<String, dynamic>> getMyProfile() async {
    final current = account;
    if (current == null) {
      return <String, dynamic>{'success': false, 'status': 401};
    }
    return Map<String, dynamic>.from(current);
  }

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

  @override
  Future<Map<String, dynamic>?> getDAOReview(
          {required String idOrWallet}) async =>
      null;
}

Map<String, dynamic> _emailAccount({
  required String userId,
  required String username,
  required String displayName,
}) =>
    <String, dynamic>{
      'id': userId,
      'userId': userId,
      'walletAddress': '',
      'username': username,
      'displayName': displayName,
      'bio': '',
      'avatar': '',
      'createdAt': '2026-03-31T00:00:00.000Z',
      'updatedAt': '2026-03-31T00:00:00.000Z',
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('(a) an email session without a wallet loads the account', () async {
    final api = _SessionProfileApi()
      ..account = _emailAccount(
        userId: 'user-a',
        username: 'alice',
        displayName: 'Alice',
      );
    final provider = ProfileProvider(apiService: api);

    await provider.loadAuthenticatedProfile();

    expect(provider.isSignedIn, isTrue);
    expect(provider.currentUser?.displayName, 'Alice');
    expect(provider.currentUser?.walletAddress, isEmpty);
  });

  test('(b) signing out clears the account so the guest state returns',
      () async {
    final api = _SessionProfileApi()
      ..account = _emailAccount(
        userId: 'user-a',
        username: 'alice',
        displayName: 'Alice',
      );
    final provider = ProfileProvider(apiService: api);
    await provider.loadAuthenticatedProfile();

    provider.signOut();

    expect(provider.isSignedIn, isFalse);
    expect(provider.currentUser, isNull);
  });

  test('(c) switching from account A to B shows only B', () async {
    final api = _SessionProfileApi()
      ..account = _emailAccount(
        userId: 'user-a',
        username: 'alice',
        displayName: 'Alice',
      );
    final provider = ProfileProvider(apiService: api);
    await provider.loadAuthenticatedProfile();
    expect(provider.currentUser?.displayName, 'Alice');

    // Sign-in as B replaces the session; the authenticated load follows it.
    api.account = _emailAccount(
      userId: 'user-b',
      username: 'bob',
      displayName: 'Bob',
    );
    await provider.loadAuthenticatedProfile();

    expect(provider.isSignedIn, isTrue);
    expect(provider.currentUser?.userId, 'user-b');
    expect(provider.currentUser?.displayName, 'Bob');
    expect(provider.currentUser?.username, 'bob');
  });

  test('(c) A, sign out, then B leaves no A remnants', () async {
    final api = _SessionProfileApi()
      ..account = _emailAccount(
        userId: 'user-a',
        username: 'alice',
        displayName: 'Alice',
      );
    final provider = ProfileProvider(apiService: api);
    await provider.loadAuthenticatedProfile();

    provider.signOut();
    api.account = _emailAccount(
      userId: 'user-b',
      username: 'bob',
      displayName: 'Bob',
    );
    await provider.loadAuthenticatedProfile();

    expect(provider.currentUser?.userId, 'user-b');
    expect(provider.currentUser?.displayName, isNot('Alice'));
    expect(provider.currentUser?.username, isNot('alice'));
  });

  test('a guest without a session stays signed out', () async {
    final provider = ProfileProvider(apiService: _SessionProfileApi());

    await expectLater(provider.loadAuthenticatedProfile(), throwsException);

    expect(provider.isSignedIn, isFalse);
    expect(provider.currentUser, isNull);
  });
}
