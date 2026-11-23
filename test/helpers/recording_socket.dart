import 'package:socket_io_client/socket_io_client.dart' as io;

class RecordedEmit {
  const RecordedEmit(this.event, this.data);

  final String event;
  final dynamic data;
}

/// A socket that never connects. It records every emit and keeps the handlers
/// registered with `on`, so a test can deliver a server event to them.
class RecordingSocket implements io.Socket {
  final List<RecordedEmit> emits = <RecordedEmit>[];
  final Map<String, Function> handlers = <String, Function>{};

  @override
  bool connected = true;

  @override
  void emit(String event, [dynamic data]) =>
      emits.add(RecordedEmit(event, data));

  /// The data of every emit named [event], in order.
  List<dynamic> emitsOf(String event) => emits
      .where((emit) => emit.event == event)
      .map((emit) => emit.data)
      .toList(growable: false);

  /// Delivers [payload] to the handler registered for [event].
  void fire(String event, dynamic payload) {
    final handler = handlers[event];
    if (handler == null) {
      throw StateError('no handler registered for $event');
    }
    Function.apply(handler, <dynamic>[payload]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #on) {
      handlers[invocation.positionalArguments[0] as String] =
          invocation.positionalArguments[1] as Function;
      // `on` returns the function that removes the handler; it is never called.
      return () {};
    }
    return super.noSuchMethod(invocation);
  }
}
