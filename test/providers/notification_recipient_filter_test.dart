import 'package:art_kubus/providers/notification_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isNotificationForCurrentIdentity', () {
    test('keeps a notification whose recipient user id matches the account',
        () {
      expect(
        isNotificationForCurrentIdentity(
          recipientUserId: 'user-1',
          sessionAccountId: 'user-1',
        ),
        isTrue,
      );
    });

    test('drops a notification addressed to a different account id', () {
      expect(
        isNotificationForCurrentIdentity(
          recipientUserId: 'user-2',
          sessionAccountId: 'user-1',
        ),
        isFalse,
      );
    });

    test('id mismatch wins over a matching wallet', () {
      expect(
        isNotificationForCurrentIdentity(
          recipientUserId: 'user-2',
          recipientWallet: '0xABC',
          sessionAccountId: 'user-1',
          sessionWallet: '0xabc',
        ),
        isFalse,
      );
    });

    test('drops a wallet-only recipient that differs from the session wallet',
        () {
      expect(
        isNotificationForCurrentIdentity(
          recipientWallet: '0xaaa',
          sessionWallet: '0xbbb',
        ),
        isFalse,
      );
    });

    test('wallet comparison is case-insensitive and trims whitespace', () {
      expect(
        isNotificationForCurrentIdentity(
          recipientWallet: ' 0xABCdef ',
          sessionWallet: '0xabcdef',
        ),
        isTrue,
      );
    });

    test('a payload that names an account is never matched by wallet alone',
        () {
      // The session has a wallet but no account id: the payload's account
      // cannot be verified against it, so the wallet match is not enough.
      expect(
        isNotificationForCurrentIdentity(
          recipientUserId: 'user-2',
          recipientWallet: '0xaaa',
          sessionWallet: '0xaaa',
        ),
        isFalse,
      );
      expect(
        isNotificationForCurrentIdentity(
          recipientUserId: 'user-2',
          recipientWallet: '0xaaa',
          sessionWallet: '0xbbb',
        ),
        isFalse,
      );
    });

    test(
        'a foreign recipientUserId is rejected even when both wallets are empty',
        () {
      expect(
        isNotificationForCurrentIdentity(
          recipientUserId: 'user-2',
          recipientWallet: '',
          sessionAccountId: 'user-1',
          sessionWallet: '',
        ),
        isFalse,
      );
      expect(
        isNotificationForCurrentIdentity(
          recipientUserId: 'user-2',
          sessionWallet: '',
        ),
        isFalse,
      );
    });

    test('a walletless session accepts its own UUID-addressed notification',
        () {
      expect(
        isNotificationForCurrentIdentity(
          recipientUserId: 'user-1',
          sessionAccountId: 'user-1',
          sessionWallet: null,
        ),
        isTrue,
      );
    });

    test('a legacy wallet-only payload is still accepted for a wallet session',
        () {
      expect(
        isNotificationForCurrentIdentity(
          recipientWallet: '0xABCdef',
          sessionWallet: '0xabcdef',
        ),
        isTrue,
      );
      expect(
        isNotificationForCurrentIdentity(
          recipientWallet: '0xABCdef',
          sessionAccountId: 'user-1',
          sessionWallet: '0xabcdef',
        ),
        isTrue,
      );
    });

    test('a late event for account A is ignored once the session is B', () {
      expect(
        isNotificationForCurrentIdentity(
          recipientUserId: 'account-a',
          recipientWallet: '0xaaa',
          sessionAccountId: 'account-b',
          sessionWallet: null,
        ),
        isFalse,
      );
    });

    test('a wallet-only payload is rejected when the session has no wallet',
        () {
      expect(
        isNotificationForCurrentIdentity(
          recipientWallet: '0xaaa',
          sessionAccountId: 'user-1',
          sessionWallet: '',
        ),
        isFalse,
      );
    });

    test('keeps an unaddressed payload: the account socket room is the gate',
        () {
      expect(isNotificationForCurrentIdentity(), isTrue);
      expect(
        isNotificationForCurrentIdentity(
          recipientUserId: '   ',
          recipientWallet: '',
          sessionAccountId: 'user-1',
          sessionWallet: '',
        ),
        isTrue,
      );
    });
  });
}
