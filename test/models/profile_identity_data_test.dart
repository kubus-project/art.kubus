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

  test('community identity navigates by wallet before internal user UUID', () {
    final identity = ProfileIdentityData.fromIdentityPayload({
      'author': {
        'userId': '11111111-1111-4111-8111-111111111111',
        'walletAddress': 'ArtistWallet111111111111111111111111111111111',
        'displayName': 'Artist User',
        'username': 'artist_user',
      },
    }, fallbackLabel: 'Unknown author');

    expect(
      identity.navigationIdentifier,
      'ArtistWallet111111111111111111111111111111111',
    );
  });

  test('walletless identity navigates by its stable public UUID', () {
    final identity = ProfileIdentityData.fromIdentityPayload({
      'author': {
        'userId': '11111111-1111-4111-8111-111111111111',
        'displayName': 'Account User',
        'username': 'account_user',
      },
    }, fallbackLabel: 'Unknown author');

    expect(
      identity.navigationIdentifier,
      '11111111-1111-4111-8111-111111111111',
    );
  });

  test('display label is never treated as a public profile identifier', () {
    const identity = ProfileIdentityData(
      label: 'Display Name',
      walletSeed: 'Display Name',
    );

    expect(identity.navigationIdentifier, isNull);
    expect(identity.canOpenProfile, isFalse);
  });
}
