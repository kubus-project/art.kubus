import 'package:art_kubus/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

const _wallet = 'So11111111111111111111111111111111111111112';
const _accountUuid = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

User _user({
  String? walletAddress,
  String? userId = _accountUuid,
  bool allowsMessages = true,
  String id = 'profile-id-not-a-wallet',
}) =>
    User(
      id: id,
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

  test('a walletless account can be messaged by its account UUID', () {
    final user = _user(walletAddress: null);
    expect(user.allowsMessages, isTrue);
    expect(user.messageTargetId, _accountUuid);
    expect(user.supportsMessaging, isTrue);
  });

  test('a blank wallet is no wallet', () {
    expect(
        _user(walletAddress: '   ', userId: null).supportsMessaging, isFalse);
    expect(_user(walletAddress: '', userId: null).supportsMessaging, isFalse);
  });

  test('the profile id is never used instead of the account UUID', () {
    // The account UUID is a valid account target; the profile id is not used.
    final user = _user(walletAddress: null, userId: _accountUuid);
    expect(user.id, isNotEmpty);
    expect(user.userId, _accountUuid);
    expect(user.messageTargetId, _accountUuid);
    expect(user.messageTargetId, isNot(user.id));
    expect(user.supportsMessaging, isTrue);
  });

  test('without wallet or account UUID a profile cannot be messaged', () {
    final user = _user(walletAddress: null, userId: null);
    expect(user.messageTargetId, isNull);
    expect(user.supportsMessaging, isFalse);
  });

  test('a disallowed preference hides messaging even with a wallet', () {
    final user = _user(walletAddress: _wallet, allowsMessages: false);
    expect(user.supportsMessaging, isFalse);
  });

  test('copyWith keeps the preference and account target together', () {
    final user = _user(walletAddress: null);
    final linked = user.copyWith(walletAddress: _wallet);
    expect(linked.supportsMessaging, isTrue);
    expect(linked.copyWith(allowsMessages: false).supportsMessaging, isFalse);
    final walletless = user.copyWith(walletAddress: null);
    expect(walletless.messageTargetId, _accountUuid);
    expect(walletless.supportsMessaging, isTrue);
  });

  // Review 5 P1: username routes, the persisted user cache and profile packages
  // build wallet-keyed users that carry the wallet only in `id`.
  test('a legacy wallet-keyed user without walletAddress can still be messaged',
      () {
    final user = _user(id: _wallet, walletAddress: null, userId: null);
    expect(user.messagingWallet, _wallet);
    expect(user.supportsMessaging, isTrue);
  });

  test('an account or profile UUID in id is never treated as a wallet', () {
    final user = _user(id: _accountUuid, walletAddress: null, userId: null);
    expect(user.messagingWallet, isNull);
    expect(user.supportsMessaging, isFalse);
    expect(user.followTargetId, isNull);
  });

  test('messages disallowed hides messaging even for a wallet-keyed user', () {
    final user = _user(id: _wallet, walletAddress: null, allowsMessages: false);
    expect(user.supportsMessaging, isFalse);
  });

  // Review 5 P2: a queued follow must target what the live follow targets.
  test('the follow target is the account UUID when known, else the wallet', () {
    expect(_user(walletAddress: _wallet).followTargetId, _accountUuid);
    expect(_user(id: _wallet, walletAddress: null, userId: null).followTargetId,
        _wallet);
    expect(_user(walletAddress: _wallet, userId: 'not-a-uuid').followTargetId,
        _wallet);
  });
}
