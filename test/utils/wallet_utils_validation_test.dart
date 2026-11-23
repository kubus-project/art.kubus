import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/utils/wallet_utils.dart';

void main() {
  group('WalletUtils.looksLikeWallet', () {
    group('valid wallet addresses', () {
      test('accepts valid Ethereum address', () {
        expect(
          WalletUtils.looksLikeWallet(
              '0x742d35Cc6634C0532925a3b844Bc9e7595f88941'),
          isTrue,
        );
      });

      test('accepts valid Ethereum address (lowercase)', () {
        expect(
          WalletUtils.looksLikeWallet(
              '0x742d35cc6634c0532925a3b844bc9e7595f88941'),
          isTrue,
        );
      });

      test('accepts valid Solana address (32 chars)', () {
        // Solana addresses are typically 32-44 base58 characters
        expect(
          WalletUtils.looksLikeWallet(
              '7EYnhQoR9YM3N7UoaKRoA44Uy8JeaZV3qyouov87awMs'),
          isTrue,
        );
      });

      test('accepts valid Solana address (44 chars)', () {
        expect(
          WalletUtils.looksLikeWallet(
              '5ZWj7a1f8tWkjBESHKgrLmXshuXxqeY9SYcfbshpAqPG'),
          isTrue,
        );
      });

      test('accepts long alphanumeric identifier', () {
        expect(
          WalletUtils.looksLikeWallet('abcdef1234567890abcdef1234567890'),
          isTrue,
        );
      });
    });

    group('invalid wallet addresses (display names)', () {
      test('rejects display name with spaces', () {
        expect(WalletUtils.looksLikeWallet('Franc Purg'), isFalse);
      });

      test('rejects display name with plus sign', () {
        expect(
            WalletUtils.looksLikeWallet('1107 Klan + local writers'), isFalse);
      });

      test('rejects artist name "Jakov Brdar"', () {
        expect(WalletUtils.looksLikeWallet('Jakov Brdar'), isFalse);
      });

      test('rejects artist name "Escif"', () {
        // Short single-word name - less than 32 chars
        expect(WalletUtils.looksLikeWallet('Escif'), isFalse);
      });

      test('rejects short username', () {
        expect(WalletUtils.looksLikeWallet('john_doe'), isFalse);
      });

      test('rejects email-like string', () {
        expect(WalletUtils.looksLikeWallet('user@example.com'), isFalse);
      });
    });

    group('edge cases', () {
      test('rejects null', () {
        expect(WalletUtils.looksLikeWallet(null), isFalse);
      });

      test('rejects empty string', () {
        expect(WalletUtils.looksLikeWallet(''), isFalse);
      });

      test('rejects whitespace-only string', () {
        expect(WalletUtils.looksLikeWallet('   '), isFalse);
      });

      test('rejects placeholder "unknown"', () {
        expect(WalletUtils.looksLikeWallet('unknown'), isFalse);
      });

      test('rejects placeholder "anonymous"', () {
        expect(WalletUtils.looksLikeWallet('anonymous'), isFalse);
      });

      test('rejects placeholder "n/a"', () {
        expect(WalletUtils.looksLikeWallet('n/a'), isFalse);
      });

      test('rejects placeholder "none"', () {
        expect(WalletUtils.looksLikeWallet('none'), isFalse);
      });

      test('rejects placeholder "UNKNOWN" (case insensitive)', () {
        expect(WalletUtils.looksLikeWallet('UNKNOWN'), isFalse);
      });
    });
  });

  group('WalletUtils.isAccountUuid', () {
    test('accepts a canonical account UUID in either case', () {
      expect(WalletUtils.isAccountUuid('6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f'),
          isTrue);
      expect(WalletUtils.isAccountUuid('6F1C1D2E-3A4B-4C5D-8E9F-0A1B2C3D4E5F'),
          isTrue);
    });

    test('rejects wallets, empty and null values', () {
      expect(WalletUtils.isAccountUuid(null), isFalse);
      expect(WalletUtils.isAccountUuid(''), isFalse);
      expect(
          WalletUtils.isAccountUuid(
              '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU'),
          isFalse);
    });

    test('a UUID is excluded from wallets although looksLikeWallet accepts it',
        () {
      const uuid = '6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f';
      expect(WalletUtils.looksLikeWallet(uuid), isTrue);
      expect(WalletUtils.isAccountUuid(uuid), isTrue);
    });
  });

  group('WalletUtils.sameIdentity', () {
    test('an empty or null side never matches', () {
      expect(WalletUtils.sameIdentity(null, null), isFalse);
      expect(WalletUtils.sameIdentity('', ''), isFalse);
      expect(WalletUtils.sameIdentity('', null), isFalse);
      expect(
          WalletUtils.sameIdentity('6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f', ''),
          isFalse);
    });

    test('UUIDs and 0x wallets compare case-insensitively', () {
      expect(
          WalletUtils.sameIdentity('6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f',
              '6F1C1D2E-3A4B-4C5D-8E9F-0A1B2C3D4E5F'),
          isTrue);
      expect(
          WalletUtils.sameIdentity('0xABCDEF0123456789abcdef0123456789ABCDEF01',
              '0xabcdef0123456789ABCDEF0123456789abcdef01'),
          isTrue);
    });

    test('base58 wallets compare case-sensitively', () {
      const wallet = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';
      expect(WalletUtils.sameIdentity(wallet, wallet), isTrue);
      expect(WalletUtils.sameIdentity(wallet, wallet.toLowerCase()), isFalse);
    });
  });
}
