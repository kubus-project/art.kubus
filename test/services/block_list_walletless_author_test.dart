import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/block_list_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The signed-in viewer, a walletless account.
const _viewer = '6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f';

/// A walletless author, blocked by account id.
const _walletlessAuthor = '0b9e8d7c-6a5b-4c3d-9e2f-1a2b3c4d5e6f';
const _otherWalletlessAuthor = '1c2d3e4f-5a6b-4c7d-8e9f-0a1b2c3d4e5f';

/// A wallet author, blocked by wallet.
const _walletAuthor = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';

CommunityPost _post(Map<String, dynamic> author) => CommunityPost(
      id: 'post-1',
      authorIdentityData: ProfileIdentityData.fromIdentityPayload(
        {'author': author},
        fallbackLabel: 'Unknown author',
      ),
      content: 'hello',
      timestamp: DateTime(2026, 11, 16),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AccountIdentity.setAccountKey(_viewer);
  });

  tearDown(() {
    AccountIdentity.setAccountKey('');
  });

  test('a walletless author blocked by account id is hidden, with no wallet',
      () async {
    await BlockListService().blockWallet(_walletlessAuthor);
    final blocked = await BlockListService().loadBlockedWallets();
    final post = _post({'id': _walletlessAuthor, 'displayName': 'Ana'});

    expect(post.authorWallet, isNull);
    expect(
      BlockListService.blocksAuthor(
        blocked,
        wallet: post.authorWallet,
        accountId: post.authorUserId,
      ),
      isTrue,
    );
  });

  test('another walletless author is not hidden by that block', () async {
    await BlockListService().blockWallet(_walletlessAuthor);
    final blocked = await BlockListService().loadBlockedWallets();
    final other = _post({'id': _otherWalletlessAuthor, 'displayName': 'Ivo'});

    expect(
      BlockListService.blocksAuthor(
        blocked,
        wallet: other.authorWallet,
        accountId: other.authorUserId,
      ),
      isFalse,
    );
  });

  test('a wallet author is still hidden by a wallet block', () {
    final blocked = <String>{_walletAuthor};
    final post = _post({'walletAddress': _walletAuthor, 'userId': _viewer});

    expect(
      BlockListService.blocksAuthor(
        blocked,
        wallet: post.authorWallet,
        accountId: post.authorUserId,
      ),
      isTrue,
    );
  });

  test('an account id matches a stored block without regard to case', () {
    final blocked = <String>{_walletlessAuthor.toUpperCase()};

    expect(
      BlockListService.blocksAuthor(
        blocked,
        wallet: null,
        accountId: _walletlessAuthor,
      ),
      isTrue,
    );
  });

  test('blank identities never match a block', () {
    final blocked = <String>{_walletAuthor, ''};

    expect(
      BlockListService.blocksAuthor(blocked, wallet: null, accountId: null),
      isFalse,
    );
    expect(
      BlockListService.blocksAuthor(blocked, wallet: '', accountId: ''),
      isFalse,
    );
  });
}
