import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/recording_socket.dart';
import '../helpers/secure_storage_absent.dart';

const _accountA = '11111111-1111-4111-8111-111111111111';
const _walletA = '0xAaAa000000000000000000000000000000000001';

/// The subscribe runs after the socket's connect future, so the emit lands a
/// few event-loop turns after the call.
Future<void> _waitForEmit(RecordingSocket socket, String event) async {
  for (var i = 0; i < 200; i++) {
    if (socket.emitsOf(event).isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  installEmptySecureStorage();

  final service = SocketService();
  late RecordingSocket socket;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    socket = RecordingSocket();
    service.debugAttachSocketForTesting(socket);
    service.debugSeedRoomsForTesting();
    service.debugRegisterHandlersForTesting();
  });

  tearDown(() {
    service.debugAttachSocketForTesting(null);
    service.debugSeedRoomsForTesting();
  });

  test('a walletless session subscribes its personal room by account id',
      () async {
    final provider = NotificationProvider();
    provider.setAuthenticatedSessionForTesting(accountId: _accountA);

    final subscribed = provider.subscribePersonalRoomForTesting();
    await _waitForEmit(socket, 'subscribe:user');

    expect(socket.emitsOf('subscribe:user'), <dynamic>[_accountA]);
    socket.fire('subscribe:ok', <String, dynamic>{
      'room': 'account:$_accountA',
      'rooms': <String>['account:$_accountA'],
    });
    await subscribed;

    expect(service.currentSubscribedAccountId, _accountA);
    expect(service.currentSubscribedWallet, isNull);
    provider.dispose();
  });

  test('a wallet session still subscribes by wallet and carries the account',
      () async {
    final provider = NotificationProvider();
    provider.setAuthenticatedSessionForTesting(
      wallet: _walletA,
      accountId: _accountA,
    );

    final subscribed = provider.subscribePersonalRoomForTesting();
    await _waitForEmit(socket, 'subscribe:user');

    expect(socket.emitsOf('subscribe:user'), <dynamic>[_walletA]);
    socket.fire('subscribe:ok', <String, dynamic>{
      'room': 'account:$_accountA',
      'rooms': <String>['account:$_accountA', 'user:$_walletA'],
    });
    await subscribed;

    expect(service.currentSubscribedWallet, _walletA);
    expect(service.currentSubscribedAccountId, _accountA);
    provider.dispose();
  });

  test('a session with neither a wallet nor an account id subscribes nothing',
      () async {
    final provider = NotificationProvider();
    provider.setAuthenticatedSessionForTesting();

    await provider.subscribePersonalRoomForTesting();

    expect(socket.emitsOf('subscribe:user'), isEmpty);
    provider.dispose();
  });
}
