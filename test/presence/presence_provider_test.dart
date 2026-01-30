import 'dart:async';

import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/presence_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/presence_api.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePresenceApi implements PresenceApi {
  int batchCalls = 0;
  List<List<String>> requestedWallets = <List<String>>[];
  Completer<Map<String, dynamic>>? batchCompleter;

  @override
  Future<Map<String, dynamic>> getPresenceBatch(List<String> wallets) {
    batchCalls += 1;
    requestedWallets.add(List<String>.from(wallets));
    final completer = batchCompleter;
    if (completer != null) return completer.future;
    return Future.value({
      'success': true,
      'data': [
        {
          'walletAddress': wallets.isNotEmpty ? wallets.first : 'wallet_1',
          'exists': true,
          'visible': true,
        }
      ],
    });
  }

  @override
  Future<void> ensureAuthLoaded({String? walletAddress}) async {}

  @override
  Future<Map<String, dynamic>> pingPresence({String? walletAddress}) async {
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> recordPresenceVisit({
    required String type,
    required String id,
    String? walletAddress,
  }) async {
    return {'success': true};
  }
}

class _FakeProfileApi implements ProfileBackendApi {
  @override
  String get baseUrl => 'http://localhost';

  @override
  Future<Map<String, dynamic>> registerWallet({required String walletAddress, String? username}) async {
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> getProfileByWallet(String walletAddress) async {
    return {};
  }

  @override
  Future<Map<String, dynamic>> saveProfile(Map<String, dynamic> profileData) async {
    return {};
  }

  @override
  Future<Map<String, dynamic>> updateProfile(String walletAddress, Map<String, dynamic> updates) async {
    return {};
  }

  @override
  Future<Map<String, dynamic>> uploadAvatarToProfile({
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
    Map<String, String>? metadata,
  }) async {
    return {};
  }

  @override
  Future<void> followUser(String walletAddress) async {}

  @override
  Future<void> unfollowUser(String walletAddress) async {}

  @override
  Future<bool> isFollowing(String walletAddress) async => false;

  @override
  Future<Map<String, dynamic>?> getDAOReview({required String idOrWallet}) async => null;
}

void main() {
  test('PresenceProvider auth change triggers immediate refresh', () {
    fakeAsync((async) {
      final api = _FakePresenceApi();
      final provider = PresenceProvider(api: api);
      final profileProvider = ProfileProvider(apiService: _FakeProfileApi());

      provider.bindProfileProvider(profileProvider);
      unawaited(provider.initialize());

      provider.prefetch(['wallet_1']);
      async.elapse(const Duration(milliseconds: 80));
      expect(api.batchCalls, 1);

      BackendApiService().setAuthTokenForTesting('token');
      profileProvider.setCurrentUser(
        UserProfile(
          id: 'p1',
          walletAddress: 'wallet_1',
          username: 'user_1',
          displayName: 'User 1',
          bio: '',
          avatar: '',
          preferences: ProfilePreferences(showActivityStatus: true),
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        ),
      );

      async.elapse(const Duration(milliseconds: 80));
      expect(api.batchCalls, 2);

      BackendApiService().setAuthTokenForTesting(null);
    });
  });
}
