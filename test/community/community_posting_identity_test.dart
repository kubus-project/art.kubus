import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/widgets/community/community_posting_wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accountId = '6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f';
const _wallet = 'So11111111111111111111111111111111111111112';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AccountIdentity.resetForTesting();
  });

  tearDown(AccountIdentity.resetForTesting);

  test('a guest has no identity to publish as', () async {
    expect(await communityPostingHasIdentity(), isFalse);
  });

  test('a walletless signed-in account can publish as itself', () async {
    AccountIdentity.setAccountKey(_accountId);

    expect(await readCommunityPostingWallet(), isNull);
    expect(await communityPostingHasIdentity(), isTrue);
  });

  test('a stored wallet is an identity on its own', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'wallet': _wallet});

    expect(await communityPostingHasIdentity(), isTrue);
  });

  test('a blank account id never counts as an identity', () async {
    AccountIdentity.setAccountKey('   ');

    expect(await communityPostingHasIdentity(), isFalse);
  });
}
