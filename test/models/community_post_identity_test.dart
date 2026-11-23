import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/account_session_fixture.dart';
import '../support/signed_in_profile.dart';

const _accountA = '6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f';
const _accountB = '0b9e8d7c-6a5b-4c3d-9e2f-1a2b3c4d5e6f';
const _walletW = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';

CommunityPost _post(Map<String, dynamic> author) => CommunityPost(
      id: 'post-1',
      authorIdentityData: ProfileIdentityData.fromIdentityPayload(
        {'author': author},
        fallbackLabel: 'Unknown author',
      ),
      content: 'hello',
      timestamp: DateTime(2026, 11, 15),
    );

/// Whether [post] belongs to the account the owner holds as signed in, which is
/// [accountId] with [wallet] (none for either means a guest on the device).
bool owns(CommunityPost post, String? accountId, String? wallet) {
  final profile = (accountId == null && wallet == null)
      ? signedInProfile(accountId: 'someone-unrelated')
      : signedInProfile(accountId: accountId, wallet: wallet);
  return profile.isCurrentAccountActor(
    accountId: post.authorUserId,
    wallet: post.authorWallet,
  );
}

void main() {
  tearDown(AccountSessionFixture.end);

  group('a walletless author', () {
    final postByA = _post({'id': _accountA, 'displayName': 'Ana'});

    test('authorWallet is never the account UUID', () {
      expect(postByA.authorWallet, isNull);
    });

    test('authorUserId is the account UUID', () {
      expect(postByA.authorUserId, _accountA);
    });

    test('the author owns the post and another walletless account does not',
        () {
      expect(
        owns(postByA, _accountA, null),
        isTrue,
      );
      expect(
        owns(postByA, _accountB, null),
        isFalse,
      );
    });

    test('account UUIDs compare case-insensitively', () {
      expect(
        owns(postByA, _accountA.toUpperCase(), null),
        isTrue,
      );
    });

    test('empty and null identities never match', () {
      expect(
        owns(postByA, null, null),
        isFalse,
      );
      expect(
        owns(postByA, '', ''),
        isFalse,
      );
      final anonymous = _post({'displayName': 'Someone'});
      expect(
        owns(anonymous, null, null),
        isFalse,
      );
      expect(
        owns(anonymous, '', ''),
        isFalse,
      );
    });

    test('a comment by the same account is not its wallet', () {
      final comment = Comment(
        id: 'comment-1',
        authorIdentityData: ProfileIdentityData.fromIdentityPayload(
          {
            'author': {'id': _accountA, 'displayName': 'Ana'},
          },
          fallbackLabel: 'Unknown author',
        ),
        content: 'reply',
        timestamp: DateTime(2026, 11, 15),
      );
      expect(comment.authorWallet, isNull);
      expect(comment.authorUserId, _accountA);
    });
  });

  group('a wallet author', () {
    test('the account and the wallet are both exposed', () {
      final post = _post({'walletAddress': _walletW, 'userId': _accountA});
      expect(post.authorWallet, _walletW);
      expect(post.authorUserId, _accountA);
      expect(
        owns(post, _accountA, _walletW),
        isTrue,
      );
      expect(
        owns(post, _accountB, null),
        isFalse,
      );
    });

    test('a legacy token keyed by its wallet still owns a UUID-carrying post',
        () {
      // A legacy token has no id claim, so its account key is the wallet.
      final post = _post({'walletAddress': _walletW, 'userId': _accountA});
      expect(
        owns(post, _walletW, _walletW),
        isTrue,
      );
    });

    test('a legacy wallet-only post is owned through the wallet', () {
      final post = _post({'walletAddress': _walletW});
      expect(post.authorUserId, isNull);
      expect(
        owns(post, _accountA, _walletW),
        isTrue,
      );
      expect(
        owns(post, _accountA, null),
        isFalse,
      );
    });
  });
}
