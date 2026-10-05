import 'package:art_kubus/core/app_navigator.dart';
import 'package:art_kubus/providers/deep_link_provider.dart';
import 'package:art_kubus/providers/auth_deep_link_provider.dart';
import 'package:art_kubus/services/auth/auth_deep_link_parser.dart';
import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(AppStartupGate.reset);

  test('late explicit auth link has the same owned handoff', () async {
    final provider = AuthDeepLinkProvider();
    const target = AuthDeepLinkTarget.signIn();
    provider.setPending(target);
    var replayed = false;
    AppStartupGate.runWhenReadyIfOwned(
      stillOwns: () => identical(provider.pending, target),
      action: () {
        provider.consumePending();
        replayed = true;
      },
    );
    AppStartupGate.markReady();
    await Future<void>.delayed(Duration.zero);
    expect(replayed, isTrue);
    expect(provider.pending, isNull);
  });

  test('late initial public link replays once after the startup handoff',
      () async {
    final provider = DeepLinkProvider();
    const target =
        ShareDeepLinkTarget(type: ShareEntityType.artwork, id: 'record');
    provider.setPending(target);
    var replays = 0;
    AppStartupGate.runWhenReadyIfOwned(
      stillOwns: () => identical(provider.pending, target),
      action: () {
        provider.consumePending();
        replays++;
      },
    );
    expect(replays, 0);
    AppStartupGate.markReady();
    await Future<void>.delayed(Duration.zero);
    expect(replays, 1);
    expect(provider.pending, isNull);
    AppStartupGate.markReady();
    expect(replays, 1);
  });

  test('initializer consumption or a replacement link prevents an old replay',
      () async {
    for (final replacement in [false, true]) {
      AppStartupGate.reset();
      final provider = DeepLinkProvider();
      const original =
          ShareDeepLinkTarget(type: ShareEntityType.artwork, id: 'old');
      provider.setPending(original);
      var replayed = false;
      AppStartupGate.runWhenReadyIfOwned(
        stillOwns: () => identical(provider.pending, original),
        action: () => replayed = true,
      );
      if (replacement) {
        provider.setPending(const ShareDeepLinkTarget(
            type: ShareEntityType.profile, id: 'new'));
      } else {
        provider.consumePending();
      }
      AppStartupGate.markReady();
      await Future<void>.delayed(Duration.zero);
      expect(replayed, isFalse);
    }
  });

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
