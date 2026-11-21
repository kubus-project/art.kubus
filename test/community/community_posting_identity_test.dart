import 'package:art_kubus/widgets/community/community_posting_wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _wallet = 'So11111111111111111111111111111111111111112';

/// Whether an account may post is the owner's answer (ProfileProvider
/// isSignedIn); this file only reads the wallet a wallet account posts with.
void main() {
  test('a walletless account has no stored posting wallet', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    expect(await readCommunityPostingWallet(), isNull);
  });

  test('the stored wallet is read for a wallet account', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'wallet': _wallet});

    expect(await readCommunityPostingWallet(), _wallet);
  });
}
