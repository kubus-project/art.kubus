import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';

const MethodChannel _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Privacy and preference mirrors that a profile load writes for the account.
const List<String> _mirrorKeys = <String>[
  'private_profile',
  'allow_messages',
  'show_activity_status',
  'show_achievements',
  'showAchievements',
  'share_last_visited_location',
  'show_collection',
];

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

/// Answers the account at once and holds the role review open, so a test can
/// end the session while the review is still in flight.
class _HeldReviewApi implements ProfileBackendApi {
  final Completer<void> reviewStarted = Completer<void>();
  final Completer<Map<String, dynamic>?> _review =
      Completer<Map<String, dynamic>?>();

  void answerReview(Map<String, dynamic>? review) => _review.complete(review);

  @override
  String get baseUrl => 'https://api.kubus.site';

  @override
  Future<Map<String, dynamic>> getMyProfile() async => _account();

  @override
  Future<Map<String, dynamic>?> getDAOReview({required String idOrWallet}) {
    if (!reviewStarted.isCompleted) reviewStarted.complete();
    return _review.future;
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
}

/// Holds the account save open so a test can end the session while the save
/// is still in flight.
class _HeldSaveApi extends _HeldReviewApi {
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

  test('a load for a session that stays open keeps its privacy mirrors',
      () async {
    final api = _HeldReviewApi();
    final provider = ProfileProvider(apiService: api);
    final load = provider.loadAuthenticatedProfile();
    await api.reviewStarted.future;
    api.answerReview(null);
    await load;

    final prefs = await SharedPreferences.getInstance();
    for (final key in _mirrorKeys) {
      expect(prefs.get(key), isNotNull,
          reason: '$key missing for a live session');
    }
  });

  test('a role review answered after sign-out writes no privacy mirror',
      () async {
    final api = _HeldReviewApi();
    final provider = ProfileProvider(apiService: api);
    final load = provider.loadAuthenticatedProfile();
    await api.reviewStarted.future;

    // Sign-out lands while the review is in flight. SettingsService.logout
    // removes the mirrors at that point.
    await BackendApiService().clearAuth();
    provider.signOut();
    final prefs = await SharedPreferences.getInstance();
    for (final key in _mirrorKeys) {
      await prefs.remove(key);
    }

    api.answerReview(<String, dynamic>{
      'id': 'review-1',
      'walletAddress': 'WalletAddr111',
      'status': 'approved',
      'createdAt': '2026-03-31T00:00:00.000Z',
    });
    await load;

    for (final key in _mirrorKeys) {
      expect(prefs.get(key), isNull, reason: '$key written after sign-out');
    }
  });

  test('a load superseded by a session change releases the loading flag',
      () async {
    final api = _HeldReviewApi();
    final provider = ProfileProvider(apiService: api);
    final load = provider.loadAuthenticatedProfile();
    await api.reviewStarted.future;

    // A wallet switch re-issues the token without a sign-out, so nothing else
    // clears the spinner for this load.
    await BackendApiService().clearAuth();
    api.answerReview(null);
    await load;

    expect(provider.isLoading, isFalse);
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
