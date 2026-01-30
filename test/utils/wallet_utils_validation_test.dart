import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/utils/wallet_utils.dart';

void main() {
  group('WalletUtils.looksLikeWallet', () {
    group('valid wallet addresses', () {
      test('accepts valid Ethereum address', () {
        expect(
          WalletUtils.looksLikeWallet('0x742d35Cc6634C0532925a3b844Bc9e7595f88941'),
          isTrue,
        );
      });

      test('accepts valid Ethereum address (lowercase)', () {
        expect(
          WalletUtils.looksLikeWallet('0x742d35cc6634c0532925a3b844bc9e7595f88941'),
          isTrue,
        );
      });

      test('accepts valid Solana address (32 chars)', () {
        // Solana addresses are typically 32-44 base58 characters
        expect(
          WalletUtils.looksLikeWallet('7EYnhQoR9YM3N7UoaKRoA44Uy8JeaZV3qyouov87awMs'),
          isTrue,
        );
      });

      test('accepts valid Solana address (44 chars)', () {
        expect(
          WalletUtils.looksLikeWallet('5ZWj7a1f8tWkjBESHKgrLmXshuXxqeY9SYcfbshpAqPG'),
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
        expect(WalletUtils.looksLikeWallet('1107 Klan + local writers'), isFalse);
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
}
