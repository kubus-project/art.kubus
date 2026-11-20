import 'dart:convert';

import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two walletless accounts on one device. Each account id is its own identity.
const _accountA = '6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f';
const _accountB = '0b9e8d7c-6a5b-4c3d-9e2f-1a2b3c4d5e6f';

CommunityPost _post(String id) => CommunityPost(
      id: id,
      authorName: 'Ana',
      content: 'A mural on the riverside wall.',
      timestamp: DateTime.utc(2026, 11, 16),
    );

/// The liked-post ids stored for [accountKey] on this device.
Future<List<String>> _likedFor(String accountKey) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('community_likes_$accountKey') ?? <String>[];
}

/// Likes [postId] as the account signed in right now, with no wallet.
Future<void> _like(String postId) => CommunityService.togglePostLike(
      _post(postId),
      trackUserAction: false,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService()
      ..setHttpClient(MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object>{'success': true, 'likesCount': 1}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }))
      ..setAuthTokenForTesting(null);
  });

  tearDown(() {
    AccountIdentity.setAccountKey('');
    BackendApiService().setAuthTokenForTesting(null);
  });

  test('a walletless account keeps its likes under its own account id',
      () async {
    AccountIdentity.setAccountKey(_accountA);

    await _like('post-1');

    expect(await _likedFor(_accountA), ['post-1']);
    expect(await _likedFor('guest'), isEmpty);
  });

  test('two walletless accounts on one device never share liked posts',
      () async {
    AccountIdentity.setAccountKey(_accountA);
    await _like('post-1');

    AccountIdentity.setAccountKey(_accountB);
    await _like('post-2');

    expect(await _likedFor(_accountB), ['post-2']);
    expect(await _likedFor(_accountA), ['post-1']);
  });

  test('A signs out, B signs in, and A signing back in keeps its own likes',
      () async {
    AccountIdentity.setAccountKey(_accountA);
    await _like('post-1');

    AccountIdentity.setAccountKey('');
    AccountIdentity.setAccountKey(_accountB);
    expect(await _likedFor(_accountB), isEmpty);
    await _like('post-2');

    AccountIdentity.setAccountKey('');
    AccountIdentity.setAccountKey(_accountA);
    expect(await _likedFor(_accountA), ['post-1']);
    expect(await _likedFor(_accountB), ['post-2']);
  });
}
