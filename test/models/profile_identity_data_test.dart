import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compact author payload prefers displayName', () {
    final identity = ProfileIdentityData.fromIdentityPayload({
      'author': {
        'walletAddress': 'wallet-1234567890',
        'displayName': 'Human Name',
        'username': 'human',
      },
    }, fallbackLabel: 'Unknown author');

    expect(identity.label, 'Human Name');
    expect(identity.handle, '@human');
    expect(identity.walletSeed, 'wallet-1234567890');
  });

  test('repost original author payload renders displayName', () {
    final identity = ProfileIdentityData.fromIdentityPayload({
      'author': {
        'walletAddress': 'original-wallet',
        'displayName': 'Original Creator',
        'username': 'original',
      },
    }, fallbackLabel: 'Unknown creator');

    expect(identity.label, 'Original Creator');
    expect(identity.handle, '@original');
  });

  test('comment author legacy fields render displayName', () {
    final identity = ProfileIdentityData.fromIdentityPayload({
      'authorWallet': 'legacy-wallet',
      'authorName': 'Legacy Commenter',
      'authorUsername': 'commenter',
      'authorAvatar': '/uploads/avatar.png',
    }, fallbackLabel: 'Unknown author');

    expect(identity.label, 'Legacy Commenter');
    expect(identity.handle, '@commenter');
    expect(identity.avatarUrl, '/uploads/avatar.png');
  });

  test('provisional names do not hide a real username', () {
    final identity = ProfileIdentityData.fromIdentityPayload({
      'author': {
        'walletAddress': 'abcdef1234567890',
        'displayName': 'user_abcdef1234567890',
        'username': 'real_user',
      },
    }, fallbackLabel: 'Unknown author');

    expect(identity.label, '@real_user');
    expect(identity.handle, isNull);
  });

  test('wallet fallback is compact when no display name or username exists',
      () {
    final identity = ProfileIdentityData.fromIdentityPayload({
      'author': {
        'walletAddress': 'abcdef1234567890',
      },
    }, fallbackLabel: 'Unknown author');

    expect(identity.label, 'abcdef...7890');
  });
}
