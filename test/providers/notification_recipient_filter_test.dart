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

    test('legacy session without account id falls back to the wallet rule', () {
      expect(
        isNotificationForCurrentIdentity(
          recipientUserId: 'user-2',
          recipientWallet: '0xaaa',
          sessionWallet: '0xaaa',
        ),
        isTrue,
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

    test('keeps the event when neither side exposes a comparable identity', () {
      expect(isNotificationForCurrentIdentity(), isTrue);
      expect(
        isNotificationForCurrentIdentity(
          recipientUserId: 'user-2',
          sessionWallet: '0xbbb',
        ),
        isTrue,
      );
      expect(
        isNotificationForCurrentIdentity(
          recipientWallet: '0xaaa',
          sessionAccountId: 'user-1',
        ),
        isTrue,
      );
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
