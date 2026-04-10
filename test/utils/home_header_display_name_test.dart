import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/utils/home_header_display_name.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _user({
  required String displayName,
  required String username,
  required String walletAddress,
}) {
  final now = DateTime(2026, 4, 10);
  return UserProfile(
    id: 'user_1',
    walletAddress: walletAddress,
    username: username,
    displayName: displayName,
    bio: '',
    avatar: '',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('resolveHomeHeaderDisplayName', () {
    test('uses display name when present', () {
      final result = resolveHomeHeaderDisplayName(
        user: _user(
          displayName: 'Maya Chen',
          username: 'maya_chen',
          walletAddress: '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
        ),
        fallbackLabel: 'there',
      );

      expect(result, 'Maya Chen');
    });

    test('falls back to normalized username when display name is empty', () {
      final result = resolveHomeHeaderDisplayName(
        user: _user(
          displayName: '',
          username: '@maya_chen',
          walletAddress: '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
        ),
        fallbackLabel: 'there',
      );

      expect(result, '@maya_chen');
    });

    test('falls back to localized default when identity is empty', () {
      final result = resolveHomeHeaderDisplayName(
        user: _user(
          displayName: '',
          username: '',
          walletAddress: '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
        ),
        fallbackLabel: 'there',
      );

      expect(result, 'there');
    });

    test('does not surface a wallet-looking value as the primary label', () {
      final result = resolveHomeHeaderDisplayName(
        user: _user(
          displayName: '0x742d35Cc6634C0532925a3b844Bc9e7595f88941',
          username: '0x742d35Cc6634C0532925a3b844Bc9e7595f88941',
          walletAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f88941',
        ),
        fallbackLabel: 'there',
      );

      expect(result, 'there');
    });
  });
}
