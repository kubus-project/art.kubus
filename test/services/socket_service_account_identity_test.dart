import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class _MockSocket implements io.Socket {
  @override
  bool connected = false;
  final Map<String, List<void Function(dynamic)>> _handlers = {};
  final List<(String event, dynamic payload)> emitted = [];

  void trigger(String event, [dynamic payload]) {
    for (final handler in List<void Function(dynamic)>.from(
      _handlers[event] ?? const <void Function(dynamic)>[],
    )) {
      handler(payload);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #on) {
      final event = invocation.positionalArguments[0] as String;
      final handler =
          invocation.positionalArguments[1] as void Function(dynamic);
      _handlers
          .putIfAbsent(event, () => <void Function(dynamic)>[])
          .add(handler);
      return () {};
    }
    if (invocation.memberName == #connect) {
      connected = true;
      Future<void>.delayed(Duration.zero, () => trigger('connect'));
      return this;
    }
    if (invocation.memberName == #disconnect) {
      connected = false;
      trigger('disconnect', 'client namespace disconnect');
      return this;
    }
    if (invocation.memberName == #emit) {
      final event = invocation.positionalArguments[0] as String;
      final payload = invocation.positionalArguments.length > 1
          ? invocation.positionalArguments[1]
          : null;
      emitted.add((event, payload));
      if (event == 'subscribe:user') {
        final identity = payload.toString();
        final isAccountId = identity.contains('-') && identity.length == 36;
        trigger('subscribe:ok', <String, dynamic>{
          'room': isAccountId ? 'account:$identity' : 'user:$identity',
        });
      }
      return null;
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final socket = SocketService();
  const accountA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const accountB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  late _MockSocket mockSocket;
  late BackendApiService api;

  setUp(() {
    socket.disconnect();
    api = BackendApiService();
    mockSocket = _MockSocket();
    socket.setSocketFactoryForTesting((_, __) => mockSocket);
    api.setAuthTokenForTesting('socket-test-token');
  });

  tearDown(() {
    socket.disconnect();
    socket.setSocketFactoryForTesting(null);
    api.setAuthTokenForTesting(null);
  });

  test('account room subscribes, reconnects and dispatches live messages',
      () async {
    final received = <Map<String, dynamic>>[];
    void onMessage(Map<String, dynamic> payload) => received.add(payload);
    socket.addMessageListener(onMessage);

    expect(
      await socket.connectAndSubscribeAccount(
        'https://backend.example.test',
        accountA,
        timeout: const Duration(milliseconds: 100),
      ),
      isTrue,
    );
    expect(socket.currentSubscribedAccountId, accountA);
    expect(socket.currentSubscribedWallet, isNull);
    expect(
      mockSocket.emitted,
      contains(('subscribe:user', accountA)),
    );

    mockSocket.connected = false;
    mockSocket.trigger('disconnect', 'transport close');
    mockSocket.connected = true;
    mockSocket.trigger('connect');
    await Future<void>.delayed(Duration.zero);

    expect(
      mockSocket.emitted
          .where((entry) => entry == ('subscribe:user', accountA)),
      hasLength(2),
    );
    mockSocket.trigger('message:received', <String, dynamic>{
      'id': 'live-message',
      'conversationId': 'conversation-1',
    });
    expect(received.single['id'], 'live-message');

    expect(
      await socket.connectAndSubscribeAccount(
        'https://backend.example.test',
        accountB,
        timeout: const Duration(milliseconds: 100),
      ),
      isTrue,
    );
    expect(socket.currentSubscribedAccountId, accountB);
    expect(mockSocket.emitted, contains(('unsubscribe:user', accountA)));
    socket.removeMessageListener(onMessage);
  });
}
