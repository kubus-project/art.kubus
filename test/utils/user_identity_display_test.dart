import 'package:art_kubus/utils/user_identity_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserIdentityDisplayUtils.fromProfileMap', () {
    test('never uses wallet-like displayName', () {
      final identity = UserIdentityDisplayUtils.fromProfileMap({
        'displayName': '0x742d35Cc6634C0532925a3b844Bc9e7595f88941',
      });
      expect(identity.name, 'Unknown creator');
      expect(identity.username, isNull);
      expect(identity.handle, isNull);
    });

    test('derives a handle from displayName when username missing', () {
      final identity = UserIdentityDisplayUtils.fromProfileMap({
        'displayName': 'Franc Purg',
      });
      expect(identity.name, 'Franc Purg');
      expect(identity.username, 'franc_purg');
      expect(identity.handle, '@franc_purg');
    });

    test('uses username as both name and handle when name missing', () {
      final identity = UserIdentityDisplayUtils.fromProfileMap({
        'username': 'john_doe',
      });
      expect(identity.name, 'john_doe');
      expect(identity.username, 'john_doe');
      expect(identity.handle, '@john_doe');
    });

    test('normalizes @username and strips unsupported chars', () {
      final identity = UserIdentityDisplayUtils.fromProfileMap({
        'username': '@John Doe!',
        'displayName': '',
      });
      expect(identity.name, 'john_doe');
      expect(identity.username, 'john_doe');
      expect(identity.handle, '@john_doe');
    });

    test('prefixes numeric usernames for UI safety', () {
      final identity = UserIdentityDisplayUtils.fromProfileMap({
        'displayName': '123 abc',
      });
      expect(identity.name, '123 abc');
      expect(identity.username, 'u123_abc');
      expect(identity.handle, '@u123_abc');
    });
  });
}

