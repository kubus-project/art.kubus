import 'dart:async';

/// Runs [body] exclusively with respect to other holders of the same lock.
abstract class BrowserSessionLock {
  Future<T> run<T>(Future<T> Function() body);
}

/// Single-holder queue inside one isolate or tab. Each body starts after the
/// previous one settles, whatever its outcome.
class InProcessBrowserSessionLock implements BrowserSessionLock {
  Future<void> _tail = Future<void>.value();

  @override
  Future<T> run<T>(Future<T> Function() body) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return previous.then((_) => body()).whenComplete(() => done.complete());
  }
}
