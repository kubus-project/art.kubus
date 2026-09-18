import 'dart:async';

/// A one-way signal that the caller has abandoned a transfer.
///
/// Giving up on a transfer is not the same as it stopping. A caller that stops
/// waiting on a request it cannot cancel leaves that request writing to the
/// Node, calling progress callbacks into a screen that already says it failed,
/// and racing whatever retry the user starts next. Every rung that streams an
/// upload honours this signal, so when the caller says a transfer is over it
/// actually is.
class NodeTransferCancellation {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  /// Completes once, when [cancel] is first called.
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }

  /// Throws [NodeTransferCancelledException] if the transfer was abandoned.
  void throwIfCancelled() {
    if (isCancelled) throw const NodeTransferCancelledException();
  }
}

/// The transfer stopped because its caller abandoned it.
///
/// Deliberately not a transport failure: nothing is wrong with the route, and
/// trying the next rung would restart the very write the caller just stopped.
class NodeTransferCancelledException implements Exception {
  const NodeTransferCancelledException();

  @override
  String toString() => 'NodeTransferCancelledException: transfer cancelled';
}

/// An upload body that counts bytes as they are read and stops on [cancellation].
///
/// Shared by every rung, so the rule "nothing is read, sent or reported once
/// the transfer is abandoned" is written once. Cancelling stops reading the
/// file and ends the stream with [NodeTransferCancelledException], which is
/// what makes a transport that is mid-body notice without polling.
Stream<List<int>> guardedUploadBody(
  Stream<List<int>> source, {
  void Function(int sentBytes)? onBytesSent,
  NodeTransferCancellation? cancellation,
}) {
  if (cancellation == null) {
    if (onBytesSent == null) return source;
    var sent = 0;
    return source.map((chunk) {
      sent += chunk.length;
      onBytesSent(sent);
      return chunk;
    });
  }

  StreamSubscription<List<int>>? subscription;
  late final StreamController<List<int>> controller;
  var sent = 0;

  void stop() {
    unawaited(subscription?.cancel());
    subscription = null;
    if (!controller.isClosed) {
      controller.addError(const NodeTransferCancelledException());
      unawaited(controller.close());
    }
  }

  controller = StreamController<List<int>>(
    onListen: () {
      if (cancellation.isCancelled) {
        stop();
        return;
      }
      subscription = source.listen(
        (chunk) {
          if (cancellation.isCancelled) return;
          sent += chunk.length;
          onBytesSent?.call(sent);
          controller.add(chunk);
        },
        onError: controller.addError,
        onDone: () {
          if (!controller.isClosed) unawaited(controller.close());
        },
      );
      unawaited(cancellation.whenCancelled.then((_) => stop()));
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    onCancel: () {
      final active = subscription;
      subscription = null;
      return active?.cancel();
    },
  );
  return controller.stream;
}
