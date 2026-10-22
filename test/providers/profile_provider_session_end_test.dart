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
}
