import 'package:art_kubus/services/socket_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

const _accountA = '11111111-1111-4111-8111-111111111111';
const _walletA = '0xAaAa000000000000000000000000000000000001';
const _conversationOne = 'conversation-one';
const _conversationTwo = 'conversation-two';

class _Emit {
  const _Emit(this.event, this.data);

  final String event;
  final dynamic data;
}

/// Records every outgoing event. The socket is never connected to a server.
class _RecordingSocket implements io.Socket {
  final List<_Emit> emits = <_Emit>[];

  @override
  bool connected = true;

  @override
  void emit(String event, [dynamic data]) => emits.add(_Emit(event, data));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<dynamic> _dataOf(_RecordingSocket socket, String event) => socket.emits
    .where((emit) => emit.event == event)
    .map((emit) => emit.data)
    .toList(growable: false);

void main() {
  final service = SocketService();
  late _RecordingSocket socket;

  setUp(() {
    socket = _RecordingSocket();
    service.debugAttachSocketForTesting(socket);
    service.debugSeedRoomsForTesting();
  });

  tearDown(() {
    service.debugAttachSocketForTesting(null);
    service.debugSeedRoomsForTesting();
  });

  group('leaving the previous account on a switch or a sign-out', () {
    test('unsubscribes the previous wallet and the previous account UUID', () {
      service.debugSeedRoomsForTesting(wallet: _walletA);

      service.leaveAccountRooms(walletAddress: _walletA, accountId: _accountA);

      expect(
        _dataOf(socket, 'unsubscribe:user'),
        <dynamic>[_walletA, _accountA],
      );
      expect(service.currentSubscribedWallet, isNull);
    });

    test('a walletless account unsubscribes its UUID and sends no empty id',
        () {
      service.leaveAccountRooms(accountId: _accountA);

      expect(_dataOf(socket, 'unsubscribe:user'), <dynamic>[_accountA]);
    });

    test('leaves every joined conversation room', () {
      service.debugSeedRoomsForTesting(
        conversations: const <String>[_conversationOne, _conversationTwo],
      );

      service.leaveAccountRooms(accountId: _accountA);

      expect(
        _dataOf(socket, 'leave:conversation').toSet(),
        <dynamic>{_conversationOne, _conversationTwo},
      );
      expect(service.subscribedConversationIds, isEmpty);
    });

    test('drops the subscribed wallet even when the socket is not attached',
        () {
      // A subscription queued before the socket exists must not survive into
      // the next session: a later reconnect would resubscribe the old wallet.
      service.debugAttachSocketForTesting(null);
      service.debugSeedRoomsForTesting(wallet: _walletA);

      service.leaveAccountRooms(walletAddress: _walletA, accountId: _accountA);

      expect(service.currentSubscribedWallet, isNull);
      expect(socket.emits, isEmpty);
    });
  });
}
