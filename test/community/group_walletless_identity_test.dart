import 'dart:convert';

import 'package:art_kubus/community/community_upload_feedback.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/community_group.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/screens/community/group_feed_screen.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/secure_storage_absent.dart';
import '../support/product_surface_harness.dart';
import '../support/profile_fixtures.dart';

/// A signed-in account with no wallet. Its profile row id is not its account id.
const _ownerAccount = '6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f';
const _otherAccount = '0b9e8d7c-6a5b-4c3d-9e2f-1a2b3c4d5e6f';
const _groupId = '22222222-2222-4222-8222-222222222222';
const _legacyWallet = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';

final _l10n = lookupAppLocalizations(const Locale('en'));

UserProfile _walletlessProfile() => UserProfile(
      id: 'profile-row-1',
      userId: _ownerAccount,
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

CommunityGroupSummary _group({
  String? ownerUserId,
  String ownerWallet = '',
  required bool isOwner,
  required bool isMember,
}) {
  return CommunityGroupSummary(
    id: _groupId,
    name: 'Walletless group',
    isPublic: true,
    ownerWallet: ownerWallet,
    ownerUserId: ownerUserId,
    memberCount: 2,
    isMember: isMember,
    isOwner: isOwner,
  );
}

String _jwt(Map<String, Object?> claims) {
  String b64(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1));
  return '${b64({'alg': 'none'})}.'
      '${b64({...claims, 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

/// Pumps the group screen as the walletless account. The harness collects
/// render errors and installs its own handler; that handler is restored before
/// returning so a failing expect reports instead of hanging.
Future<void> _pumpGroup(
    WidgetTester tester, CommunityGroupSummary group) async {
  final prior = FlutterError.onError;
  await pumpProductSurface(
    tester,
    child: GroupFeedScreen(group: group),
    signedInProfile: _walletlessProfile(),
  );
  FlutterError.onError = prior;
}

BackendApiRequestException _groupPostError(
  int status,
  String body, {
  String path = '/api/groups/$_groupId/posts',
}) =>
    BackendApiRequestException(statusCode: status, path: path, body: body);

void main() {
  installEmptySecureStorage();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AccountIdentity.setAccountKey(_ownerAccount);
    BackendApiService()
      ..setHttpClient(MockClient.streaming((request, body) async {
        await body.toBytes();
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'success': true, 'data': []}))),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }))
      ..setPreferredWalletAddress(null, persist: false)
      ..setAuthTokenForTesting(_jwt({'user_id': _ownerAccount}));
  });

  tearDown(() {
    AccountIdentity.setAccountKey('');
    BackendApiService()
      ..setAuthTokenForTesting(null)
      ..setPreferredWalletAddress(null, persist: false);
  });

  group('group ownership for a session', () {
    test('an account id that owns the group owns it, with no wallet', () {
      final group = _group(
        ownerUserId: _ownerAccount,
        isOwner: false,
        isMember: false,
      );

      expect(
        group.isOwnedBySession(accountId: _ownerAccount, wallet: null),
        isTrue,
      );
      expect(
        group.isOwnedBySession(accountId: _otherAccount, wallet: null),
        isFalse,
      );
    });

    test(
        'an empty session never owns a group, and an empty owner never matches',
        () {
      final unowned = _group(isOwner: false, isMember: false);

      expect(unowned.isOwnedBySession(accountId: '', wallet: ''), isFalse);
      expect(
        _group(ownerUserId: _ownerAccount, isOwner: false, isMember: false)
            .isOwnedBySession(accountId: '', wallet: null),
        isFalse,
      );
    });

    test('a legacy group with only an owner wallet is owned by that wallet',
        () {
      final group = _group(
        ownerWallet: _legacyWallet,
        isOwner: false,
        isMember: false,
      );

      expect(
        group.isOwnedBySession(accountId: null, wallet: _legacyWallet),
        isTrue,
      );
    });
  });

  group('group post membership error', () {
    test('a 403 from the group posts route is a membership error', () {
      final error = _groupPostError(
        403,
        jsonEncode(
            {'success': false, 'error': 'Join the group before posting.'}),
      );

      expect(communityGroupPostMembershipRequired(error), isTrue);
    });

    test('a wallet requirement is not a membership error', () {
      final error = _groupPostError(
        403,
        jsonEncode({'success': false, 'code': 'WALLET_REQUIRED'}),
      );

      expect(communityGroupPostMembershipRequired(error), isFalse);
    });

    test('other statuses and other routes are not membership errors', () {
      expect(
        communityGroupPostMembershipRequired(_groupPostError(500, '{}')),
        isFalse,
      );
      expect(
        communityGroupPostMembershipRequired(
          _groupPostError(403, '{}', path: '/api/community/posts'),
        ),
        isFalse,
      );
    });
  });

  group('group feed for a walletless account', () {
    testWidgets('the owner sees the owner state, with no wallet',
        (tester) async {
      await _pumpGroup(
        tester,
        _group(ownerUserId: _ownerAccount, isOwner: false, isMember: false),
      );

      expect(find.text(_l10n.commonOwner), findsOneWidget);
      expect(find.text(_l10n.groupFeedJoinToPostLabel), findsNothing);
    });

    testWidgets('a member can post, with no wallet', (tester) async {
      await _pumpGroup(
        tester,
        _group(ownerUserId: _otherAccount, isOwner: false, isMember: true),
      );

      expect(find.text(_l10n.commonJoined), findsOneWidget);
      expect(find.text(_l10n.groupFeedJoinToPostLabel), findsNothing);
      expect(find.text(_l10n.commonPost), findsWidgets);
    });

    testWidgets('a non-member sees the join state, with no wallet',
        (tester) async {
      await _pumpGroup(
        tester,
        _group(ownerUserId: _otherAccount, isOwner: false, isMember: false),
      );

      expect(find.text(_l10n.commonJoin), findsWidgets);
      expect(find.text(_l10n.groupFeedJoinToPostLabel), findsOneWidget);
    });
  });
}
