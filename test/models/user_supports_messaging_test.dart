import 'package:art_kubus/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

const _wallet = 'So11111111111111111111111111111111111111112';
const _accountUuid = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

User _user({
  String? walletAddress,
  String? userId = _accountUuid,
  bool allowsMessages = true,
}) =>
    User(
      id: 'profile-id-not-a-wallet',
      userId: userId,
      walletAddress: walletAddress,
      allowsMessages: allowsMessages,
      name: 'City Museum',
      username: 'citymuseum',
      bio: '',
      followersCount: 0,
      followingCount: 0,
      postsCount: 0,
      isFollowing: false,
      isVerified: false,
      joinedDate: 'Joined recently',
    );

void main() {
  test('a profile with a wallet and allowed messages can be messaged', () {
    final user = _user(walletAddress: _wallet);
    expect(user.supportsMessaging, isTrue);
    expect(user.walletAddress, _wallet);
  });

  test(
      'without a wallet there is no message target, even when messages are allowed',
      () {
    final user = _user(walletAddress: null);
    expect(user.allowsMessages, isTrue);
    expect(user.supportsMessaging, isFalse,
        reason: 'the conversation API is wallet-keyed');
  });

  test('a blank wallet is no wallet', () {
    expect(_user(walletAddress: '   ').supportsMessaging, isFalse);
    expect(_user(walletAddress: '').supportsMessaging, isFalse);
  });

  test('the id and account UUID alone never make an account messageable', () {
    // The profile id and the users.id are present; neither is a wallet.
    final user = _user(walletAddress: null, userId: _accountUuid);
    expect(user.id, isNotEmpty);
    expect(user.userId, _accountUuid);
    expect(user.supportsMessaging, isFalse);
  });

  test('a disallowed preference hides messaging even with a wallet', () {
    final user = _user(walletAddress: _wallet, allowsMessages: false);
    expect(user.supportsMessaging, isFalse);
  });

  test('copyWith keeps the preference and the wallet rule together', () {
    final user = _user(walletAddress: null);
    final linked = user.copyWith(walletAddress: _wallet);
    expect(linked.supportsMessaging, isTrue);
    expect(linked.copyWith(allowsMessages: false).supportsMessaging, isFalse);
    expect(user.copyWith(walletAddress: null).supportsMessaging, isFalse);
  });
}
