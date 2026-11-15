import 'package:art_kubus/services/socket_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/recording_socket.dart';

const _accountA = '11111111-1111-4111-8111-111111111111';
const _accountB = '22222222-2222-4222-8222-222222222222';
const _walletA = '0xAaAa000000000000000000000000000000000001';

Map<String, dynamic> _ackFor(String room, List<String> rooms) => {
      'room': room,
      'rooms': rooms,
    };

int _pendingAcks(SocketService service) =>
    service.debugResourceSnapshot['pendingSubscriptionAcks'] as int;

void main() {
  final service = SocketService();
  late RecordingSocket socket;

  setUp(() {
    socket = RecordingSocket();
    service.debugAttachSocketForTesting(socket);
    service.debugSeedRoomsForTesting();
    service.debugRegisterHandlersForTesting();
  });

  tearDown(() {
    service.debugAttachSocketForTesting(null);
    service.debugSeedRoomsForTesting();
  });

  group('walletless personal room', () {
    test('subscribes with the authenticated account UUID', () {
      service.subscribeUser('', accountId: _accountA);

      expect(socket.emitsOf('subscribe:user'), <dynamic>[_accountA]);
      expect(service.currentSubscribedAccountId, _accountA);
      expect(service.currentSubscribedWallet, isNull);

      socket.fire(
        'subscribe:ok',
        _ackFor('account:$_accountA', <String>['account:$_accountA']),
      );
      expect(_pendingAcks(service), 0);
    });

    test('a reconnect resubscribes the same account UUID', () {
      service.debugSeedRoomsForTesting(accountId: _accountA);

      service.debugHandleConnectForTesting();

      expect(socket.emitsOf('subscribe:user'), <dynamic>[_accountA]);
      expect(service.currentSubscribedAccountId, _accountA);
      socket.fire(
        'subscribe:ok',
        _ackFor('account:$_accountA', <String>['account:$_accountA']),
      );
    });

    test('a switch unsubscribes the previous UUID before the new one', () {
      service.subscribeUser('', accountId: _accountA);
      socket.fire(
        'subscribe:ok',
        _ackFor('account:$_accountA', <String>['account:$_accountA']),
      );

      service.subscribeUser('', accountId: _accountB);

      expect(socket.emitsOf('unsubscribe:user'), <dynamic>[_accountA]);
      expect(socket.emitsOf('subscribe:user'), <dynamic>[_accountA, _accountB]);
      socket.fire(
        'subscribe:ok',
        _ackFor('account:$_accountB', <String>['account:$_accountB']),
      );
    });

    test('a teardown leaves the UUID the socket subscribed, without a copy',
        () {
      service.subscribeUser('', accountId: _accountA);
      socket.fire(
        'subscribe:ok',
        _ackFor('account:$_accountA', <String>['account:$_accountA']),
      );

      service.leaveAccountRooms();

      expect(socket.emitsOf('unsubscribe:user'), <dynamic>[_accountA]);
      expect(service.currentSubscribedAccountId, isNull);
    });

    test('sends nothing for an empty or missing identity', () {
      service.subscribeUser('', accountId: '');
      service.subscribeUser('   ');
      service.subscribeUser('', accountId: null);
      service.debugHandleConnectForTesting();

      expect(socket.emitsOf('subscribe:user'), isEmpty);
      expect(_pendingAcks(service), 0);
    });
  });

  group('wallet session', () {
    test('subscribes by wallet and the server ack is read from rooms', () {
      service.subscribeUser(_walletA, accountId: _accountA);

      expect(socket.emitsOf('subscribe:user'), <dynamic>[_walletA]);
      expect(service.currentSubscribedWallet, _walletA);
      expect(service.currentSubscribedAccountId, _accountA);

      // The ack's primary room is the account room; the wallet room is only in
      // rooms[]. The wallet request must still be satisfied.
      socket.fire(
        'subscribe:ok',
        _ackFor(
          'account:$_accountA',
          <String>['account:$_accountA', 'user:$_walletA'],
        ),
      );
      expect(_pendingAcks(service), 0);
    });

    test('a wallet subscribe without an id keeps the account id it held',
        () async {
      service.subscribeUser(_walletA, accountId: _accountA);
      // A second wallet subscribe, sent while the first is still unacked.
      service.subscribeUser(_walletA);

      expect(service.currentSubscribedAccountId, _accountA);
      socket.fire(
          'subscribe:ok',
          _ackFor('user:$_walletA', <String>[
            'user:$_walletA',
          ]));
      // The superseded attempt completes as false and must not clear the
      // identity the newer attempt holds.
      await Future<void>.delayed(Duration.zero);
      expect(service.currentSubscribedWallet, _walletA);
      expect(service.currentSubscribedAccountId, _accountA);
    });

    test('a reconnect resubscribes the wallet and the account it held', () {
      service.debugSeedRoomsForTesting(wallet: _walletA, accountId: _accountA);

      service.debugHandleConnectForTesting();

      expect(socket.emitsOf('subscribe:user'), <dynamic>[_walletA]);
      expect(service.currentSubscribedWallet, _walletA);
      expect(service.currentSubscribedAccountId, _accountA);
      socket.fire(
        'subscribe:ok',
        _ackFor(
          'account:$_accountA',
          <String>['account:$_accountA', 'user:$_walletA'],
        ),
      );
    });
  });
}
