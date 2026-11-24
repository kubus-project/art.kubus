import 'dart:convert';

import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/recording_socket.dart';
import '../helpers/secure_storage_absent.dart';
import '../support/signed_in_profile.dart';

const _accountA = '11111111-1111-4111-8111-111111111111';
const _accountB = '22222222-2222-4222-8222-222222222222';

/// A session token carrying only the canonical account id, as a walletless
/// account has.
String _walletlessToken(String accountId) {
  final payload = jsonEncode({
    'id': accountId,
    'exp':
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000,
  });
  return 'e30.${base64Url.encode(utf8.encode(payload)).replaceAll('=', '')}.synthetic';
}

/// A live message in [conversationId], addressed to [recipientUserId] when
/// given, sent by account B.
Map<String, dynamic> _liveMessage(
  String id,
  String conversationId, {
  String? recipientUserId,
}) =>
    {
      'id': id,
      'conversationId': conversationId,
      'senderUserId': _accountB,
      'senderWallet': '',
      'message': 'hello',
      'createdAt': DateTime.utc(2026, 11, 15).toIso8601String(),
      if (recipientUserId != null) 'recipientUserId': recipientUserId,
    };

void main() {
  installEmptySecureStorage();
  TestWidgetsFlutterBinding.ensureInitialized();

  final socketService = SocketService();
  late RecordingSocket socket;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    socket = RecordingSocket();
    socketService.debugAttachSocketForTesting(socket);
    socketService.debugSeedRoomsForTesting();
    BackendApiService().setAuthTokenForTesting(null);
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    socketService.debugAttachSocketForTesting(null);
    socketService.debugSeedRoomsForTesting();
  });

  test('a walletless session accepts a live message addressed to its account',
      () {
    BackendApiService().setAuthTokenForTesting(_walletlessToken(_accountA));
    final provider = ChatProvider();
    provider.setCurrentWalletForTesting(null);

    provider.handleIncomingMessageForTesting(
      _liveMessage('m1', 'convA', recipientUserId: _accountA),
    );

    expect(provider.messages['convA']?.map((m) => m.id), <String>['m1']);
    provider.dispose();
  });

  test('a walletless session drops a message addressed to a previous account',
      () async {
    BackendApiService().setAuthTokenForTesting(_walletlessToken(_accountA));
    final provider = ChatProvider();
    provider.setCurrentWalletForTesting(null);

    BackendApiService().setAuthTokenForTesting(_walletlessToken(_accountB));
    AccountIdentity.notifyListenersChanged();

    provider.handleIncomingMessageForTesting(
      _liveMessage('m2', 'convA', recipientUserId: _accountA),
    );
    expect(provider.messages['convA'] ?? const <dynamic>[], isEmpty);

    provider.handleIncomingMessageForTesting(
      _liveMessage('m3', 'convB', recipientUserId: _accountB),
    );
    expect(provider.messages['convB']?.map((m) => m.id), <String>['m3']);
    provider.dispose();
  });

  test('a walletless reader by account id leaves a receipt on the message', () {
    BackendApiService().setAuthTokenForTesting(_walletlessToken(_accountA));
    final provider = ChatProvider();
    provider.setCurrentWalletForTesting(null);
    // Account A's own message, which account B (walletless) reads.
    provider.handleIncomingMessageForTesting({
      'id': 'mine1',
      'conversationId': 'convA',
      'senderUserId': _accountA,
      'senderWallet': '',
      'message': 'mine',
      'createdAt': DateTime.utc(2026, 11, 15).toIso8601String(),
    });

    provider.handleMessageReadForTesting({
      'message_id': 'mine1',
      'conversation_id': 'convA',
      'reader': _accountB,
      'wallet': null,
      'userId': _accountB,
      'read_at': DateTime.utc(2026, 11, 15, 1).toIso8601String(),
    });

    final message = provider.messages['convA']!.single;
    expect(message.readersCount, 1);
    expect(message.readers.single['user_id'], _accountB);
    expect(
      message.readByCurrent,
      isFalse,
      reason: 'the peer read it, not the session account',
    );
    provider.dispose();
  });

  test('a walletless session reading a message marks it read for itself', () {
    BackendApiService().setAuthTokenForTesting(_walletlessToken(_accountA));
    final provider = ChatProvider()
      ..setIdentityOwnerForTesting(signedInProfile(accountId: _accountA));
    provider.setCurrentWalletForTesting(null);
    provider.handleIncomingMessageForTesting(
      _liveMessage('m5', 'convA', recipientUserId: _accountA),
    );

    provider.handleMessageReadForTesting({
      'message_id': 'm5',
      'conversation_id': 'convA',
      'reader': _accountA,
      'wallet': null,
      'userId': _accountA,
      'read_at': DateTime.utc(2026, 11, 15, 1).toIso8601String(),
    });

    final message = provider.messages['convA']!.single;
    expect(message.readByCurrent, isTrue);
    expect(message.readers.single['user_id'], _accountA);
    provider.dispose();
  });

  test('a session with neither wallet nor account id drops every event', () {
    final provider = ChatProvider();
    provider.setCurrentWalletForTesting(null);

    provider.handleIncomingMessageForTesting(_liveMessage('m4', 'convX'));

    expect(provider.messages, isEmpty);
    provider.dispose();
  });

  test(
      'a same-account reset keeps the account room, so the next switch '
      'still leaves it', () {
    BackendApiService().setAuthTokenForTesting(_walletlessToken(_accountA));
    final provider = ChatProvider();
    provider.setCurrentWalletForTesting(null);
    provider.bindSocketAccountForTesting(_accountA);

    // Same-account reset: a wallet change keeps the account.
    provider.resetSessionForTesting('walletChanged');
    socket.emits.clear();

    // The switch to B leaves account A's room.
    BackendApiService().setAuthTokenForTesting(_walletlessToken(_accountB));
    AccountIdentity.notifyListenersChanged();

    expect(socket.emitsOf('unsubscribe:user'), <dynamic>[_accountA]);
    provider.dispose();
  });
}
