import 'dart:convert';

import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/screens/community/post_detail_screen.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/community/community_comment_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';
import '../../support/profile_fixtures.dart';

/// Two signed-in accounts with no wallet. Each account id is its own identity.
const _accountA = '6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f';
const _accountB = '0b9e8d7c-6a5b-4c3d-9e2f-1a2b3c4d5e6f';

UserProfile _walletlessProfile(String accountId) => UserProfile(
      id: 'profile-row-$accountId',
      userId: accountId,
      walletAddress: '',
      username: 'walletless_account',
      displayName: 'Walletless account',
      bio: '',
      avatar: '',
      isArtist: false,
      isInstitution: false,
      createdAt: ProfileFixtures.fetchedAt,
      updatedAt: ProfileFixtures.fetchedAt,
    );

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: const {'content-type': 'application/json'},
    );

/// Comment c1 is by account A and c2 by account B.
Future<http.Response> _handle(http.Request request) async {
  final path = request.url.path;
  if (request.method == 'GET' &&
      path == '/api/community/posts/post-1/comments') {
    return _json(<String, dynamic>{
      'success': true,
      'data': <dynamic>[
        <String, dynamic>{
          'id': 'c1',
          'postId': 'post-1',
          'content': 'Comment by account A',
          'authorId': _accountA,
          'authorName': 'Account A',
          'createdAt': '2026-10-01T12:05:00.000Z',
        },
        <String, dynamic>{
          'id': 'c2',
          'postId': 'post-1',
          'content': 'Comment by account B',
          'authorId': _accountB,
          'authorName': 'Account B',
          'createdAt': '2026-10-01T12:06:00.000Z',
        },
      ],
    });
  }
  if (request.method == 'GET' && path == '/api/community/interactions/state') {
    return _json(<String, dynamic>{
      'success': true,
      'data': <String, dynamic>{'posts': <String, dynamic>{}},
    });
  }
  if (request.method == 'POST' && path == '/api/analytics/app') {
    return _json(<String, dynamic>{'success': true});
  }
  return http.Response('{}', 404);
}

Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 80; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// The edit and delete menu of the comment row for [commentId].
Finder _menuOf(String commentId) => find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is CommunityCommentRow && w.comment.id == commentId,
      ),
      matching: find.byType(PopupMenuButton<String>),
    );

/// Pumps the post as [accountId], a walletless session, and waits for comments.
CommunityPost _post() => CommunityPost(
      id: 'post-1',
      authorName: 'Account B',
      content: 'A mural on the riverside wall.',
      timestamp: DateTime.utc(2026, 10, 1, 12),
    );

Future<void> _pumpAs(WidgetTester tester, String accountId) async {
  AccountIdentity.setAccountKey(accountId);
  final prior = FlutterError.onError;
  await pumpProductSurface(
    tester,
    child: PostDetailScreen(post: _post()),
    size: const Size(390, 844),
    signedInProfile: _walletlessProfile(accountId),
    settle: const Duration(milliseconds: 500),
  );
  FlutterError.onError = prior;
  await _drain(tester);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService()
      ..setHttpClient(MockClient(_handle))
      ..setAuthTokenForTesting('test-token');
  });

  tearDown(() {
    AccountIdentity.setAccountKey('');
    BackendApiService()
      ..setAuthTokenForTesting(null)
      ..setHttpClient(http.Client());
  });

  testWidgets(
      'a walletless author edits and deletes own comment, not another account\'s',
      (tester) async {
    await _pumpAs(tester, _accountA);

    expect(find.byType(CommunityCommentRow), findsNWidgets(2));
    expect(_menuOf('c1'), findsOneWidget);
    expect(_menuOf('c2'), findsNothing);
  });

  testWidgets(
      'the other walletless account gets the menu only on its own comment',
      (tester) async {
    await _pumpAs(tester, _accountB);

    expect(find.byType(CommunityCommentRow), findsNWidgets(2));
    expect(_menuOf('c1'), findsNothing);
    expect(_menuOf('c2'), findsOneWidget);
  });
}
