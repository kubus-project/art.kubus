import 'package:art_kubus/core/app_navigator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(AppStartupGate.reset);

  test('is not ready before markReady is called', () {
    expect(AppStartupGate.isReady, isFalse);
  });

  test('markReady flips isReady and completes ready', () async {
    expect(AppStartupGate.isReady, isFalse);
    AppStartupGate.markReady();
    expect(AppStartupGate.isReady, isTrue);
    await expectLater(AppStartupGate.ready, completes);
  });

  test('markReady is idempotent — a second call does not throw', () {
    AppStartupGate.markReady();
    expect(AppStartupGate.markReady, returnsNormally);
  });

  test(
    'runWhenReady defers the action until markReady is called — this is '
    'the mechanism that stops a notification tap or a live deep link from '
    'racing AppInitializer\'s own cold-start route decision (Part 15)',
    () async {
      var ran = false;
      AppStartupGate.runWhenReady(() => ran = true);

      // Not ready yet: the action must not have run synchronously nor after
      // yielding the event loop.
      expect(ran, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(ran, isFalse);

      AppStartupGate.markReady();
      // The completer's `.then` callback needs a microtask turn.
      await Future<void>.delayed(Duration.zero);
      expect(ran, isTrue);
    },
  );

  test('runWhenReady runs immediately once already ready', () {
    AppStartupGate.markReady();
    var ran = false;
    AppStartupGate.runWhenReady(() => ran = true);
    expect(ran, isTrue);
  });

  test('multiple runWhenReady callbacks all fire once ready', () async {
    final order = <int>[];
    AppStartupGate.runWhenReady(() => order.add(1));
    AppStartupGate.runWhenReady(() => order.add(2));
    AppStartupGate.runWhenReady(() => order.add(3));

    AppStartupGate.markReady();
    await Future<void>.delayed(Duration.zero);

    expect(order, <int>[1, 2, 3]);
  });
}
