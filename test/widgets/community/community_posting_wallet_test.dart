import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:art_kubus/widgets/community/community_posting_wallet.dart';

void main() {
  group('communityPostingRequiresWallet', () {
    test('ordinary account-owned posts do not require a wallet', () {
      expect(communityPostingRequiresWallet(isGroupPost: false), isFalse);
    });

    test('group posts keep the wallet membership gate', () {
      expect(communityPostingRequiresWallet(isGroupPost: true), isTrue);
    });
  });

  group('readCommunityPostingWallet', () {
    test('returns null when no wallet key is stored', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await readCommunityPostingWallet(), isNull);
    });

    test('trims the wallet_address value', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'wallet_address': ' abc ',
      });
      expect(await readCommunityPostingWallet(), 'abc');
    });

    test('skips empty keys and falls through to walletAddress', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'wallet': '',
        'walletAddress': 'xyz',
      });
      expect(await readCommunityPostingWallet(), 'xyz');
    });

    test('treats whitespace-only values as missing', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'wallet': '   ',
      });
      expect(await readCommunityPostingWallet(), isNull);
    });
  });

  group('isCommunityWalletRequiredError', () {
    test('matches an error mentioning WALLET_REQUIRED', () {
      expect(
        isCommunityWalletRequiredError(
          Exception('{"errorCode":"WALLET_REQUIRED"}'),
        ),
        isTrue,
      );
    });

    test('does not match other errors', () {
      expect(
        isCommunityWalletRequiredError(Exception('Request failed: 500')),
        isFalse,
      );
    });
  });
}
