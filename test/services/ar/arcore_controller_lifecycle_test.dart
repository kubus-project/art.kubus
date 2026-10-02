import 'dart:async';

import 'package:arcore_flutter_plugin/src/arcore_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lifecycle contract for the vendored ARCore controller.
///
/// These guard the two failure modes that reached users on device: a
/// controller that reported itself usable while native initialization was
/// still in flight, and fire-and-forget platform calls whose rejected Futures
/// escaped to the root zone as "Unhandled Zone error".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const id = 7;
  final channel = MethodChannel('arcore_flutter_plugin_$id');
  late List<String> nativeCalls;
  late Map<String, Object?> Function(MethodCall call)? responder;
  late Object? Function(MethodCall call)? thrower;

  void installHandler() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call.method);
      final failure = thrower?.call(call);
      if (failure != null) throw failure;
      return responder?.call(call);
    });
  }

  /// Delivers a call from the native side to the controller's handler.
  Future<void> emitFromNative(MethodCall call) {
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(call),
      (_) {},
    );
  }

  setUp(() {
    nativeCalls = <String>[];
    responder = null;
    thrower = null;
    installHandler();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('initialization', () {
    test('a freshly constructed controller is not ready', () {
      final controller = ArCoreController(id: id, debug: false);

      expect(controller.lifecycle, ArCoreControllerLifecycle.created);
      expect(controller.isReady, isFalse,
          reason: 'existence must never imply readiness');
      expect(nativeCalls, isEmpty,
          reason: 'the constructor must not start native init implicitly');
    });

    test('the controller only becomes ready after initialize() completes',
        () async {
      final gate = Completer<void>();
      responder = (_) => <String, Object?>{};
      thrower = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        nativeCalls.add(call.method);
        await gate.future;
        return null;
      });

      final controller = ArCoreController(id: id, debug: false);
      final pending = controller.initialize();

      expect(controller.lifecycle, ArCoreControllerLifecycle.initializing);
      expect(controller.isReady, isFalse);

      gate.complete();
      await pending;

      expect(controller.isReady, isTrue);
      expect(controller.lifecycle, ArCoreControllerLifecycle.ready);
    });

    test('create() returns an already-initialized controller', () async {
      final controller = await ArCoreController.create(id: id, debug: false);

      expect(controller.isReady, isTrue);
      expect(nativeCalls, contains('init'));
    });

    test('initialize() is idempotent across concurrent callers', () async {
      final controller = ArCoreController(id: id, debug: false);

      await Future.wait([controller.initialize(), controller.initialize()]);

      expect(nativeCalls.where((c) => c == 'init'), hasLength(1));
    });

    test('a native failure surfaces as a typed AR error, not PlatformException',
        () async {
      thrower = (call) => call.method == 'init'
          ? PlatformException(code: 'CAMERA_UNAVAILABLE', message: 'busy')
          : null;
      final controller = ArCoreController(id: id, debug: false);

      await expectLater(
        controller.initialize(),
        throwsA(isA<ArCoreInitializationException>()
            .having((e) => e.code, 'code', 'CAMERA_UNAVAILABLE')),
      );
      expect(controller.isReady, isFalse);
      expect(controller.lifecycle, ArCoreControllerLifecycle.error);
    });

    test('a missing platform view surfaces as a typed AR error', () async {
      thrower = (call) =>
          call.method == 'init' ? MissingPluginException('no view') : null;
      final controller = ArCoreController(id: id, debug: false);

      await expectLater(
        controller.initialize(),
        throwsA(isA<ArCoreInitializationException>()
            .having((e) => e.code, 'code', 'missing_plugin')),
      );
      expect(controller.isReady, isFalse);
    });
  });

  group('disposal', () {
    test('dispose() tears the controller down and clears readiness', () async {
      final controller = await ArCoreController.create(id: id, debug: false);

      await controller.dispose();

      expect(controller.isReady, isFalse);
      expect(controller.isDisposed, isTrue);
      expect(controller.lifecycle, ArCoreControllerLifecycle.disposed);
      expect(controller.trackingState, isEmpty);
      expect(nativeCalls, contains('dispose'));
    });

    test('dispose() is idempotent and calls native teardown once', () async {
      final controller = await ArCoreController.create(id: id, debug: false);

      await Future.wait([controller.dispose(), controller.dispose()]);
      await controller.dispose();

      expect(nativeCalls.where((c) => c == 'dispose'), hasLength(1));
      expect(controller.lifecycle, ArCoreControllerLifecycle.disposed);
    });

    test('a native failure during dispose never throws', () async {
      final controller = await ArCoreController.create(id: id, debug: false);
      thrower = (call) => call.method == 'dispose'
          ? PlatformException(code: 'GONE', message: 'view destroyed')
          : null;

      await expectLater(controller.dispose(), completes);
      expect(controller.isDisposed, isTrue);
    });

    test('dispose() landing during initialize() does not resurrect readiness',
        () async {
      final gate = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        nativeCalls.add(call.method);
        if (call.method == 'init') await gate.future;
        return null;
      });

      final controller = ArCoreController(id: id, debug: false);
      final init = controller.initialize();
      final disposal = controller.dispose();
      gate.complete();
      await Future.wait([init, disposal]);

      expect(controller.isReady, isFalse,
          reason: 'an abandoned controller must never report ready');
      expect(controller.lifecycle, ArCoreControllerLifecycle.disposed);
    });

    test('initialize() after disposal is rejected', () async {
      final controller = await ArCoreController.create(id: id, debug: false);
      await controller.dispose();

      expect(() => controller.initialize(), throwsStateError);
    });
  });

  group('late native callbacks', () {
    test('a tracking update after dispose is ignored', () async {
      final controller = await ArCoreController.create(id: id, debug: false);
      final seen = <ArCoreTrackingState>[];
      controller.onTrackingStateChanged = seen.add;

      await emitFromNative(const MethodCall('onTrackingStateChanged', {
        'state': 'TRACKING',
      }));
      expect(seen, hasLength(1), reason: 'sanity: callbacks work while alive');

      await controller.dispose();
      await emitFromNative(const MethodCall('onTrackingStateChanged', {
        'state': 'TRACKING',
      }));

      expect(seen, hasLength(1), reason: 'no callback after disposal');
      expect(controller.trackingState, isEmpty);
      expect(controller.isReady, isFalse);
    });

    test('a plane detection callback after dispose is ignored', () async {
      final controller = await ArCoreController.create(id: id, debug: false);
      var planeTaps = 0;
      controller.onNodeTap = (_) => planeTaps++;

      await controller.dispose();
      await emitFromNative(const MethodCall('onNodeTap', 'node'));

      expect(planeTaps, isZero);
    });
  });

  group('fire-and-forget platform calls', () {
    test('resume() after disposal completes without touching the channel',
        () async {
      final controller = await ArCoreController.create(id: id, debug: false);
      await controller.dispose();
      nativeCalls.clear();

      await expectLater(controller.resume(), completes);
      expect(nativeCalls, isEmpty);
    });

    test('a rejected resume() is absorbed instead of escaping the zone',
        () async {
      final controller = await ArCoreController.create(id: id, debug: false);
      thrower = (call) => call.method == 'resume'
          ? PlatformException(code: 'GONE', message: 'view destroyed')
          : null;

      // The regression: this used to be `_channel.invokeMethod('resume')` with
      // no await and no catch, so the rejection became an unobserved Future
      // and surfaced to the user as "Unhandled Zone error".
      await expectLater(controller.resume(), completes);
    });

    test('an unobserved rejection never reaches the surrounding zone',
        () async {
      final controller = await ArCoreController.create(id: id, debug: false);
      thrower = (call) => call.method == 'resume'
          ? PlatformException(code: 'GONE', message: 'view destroyed')
          : null;

      final escaped = <Object>[];
      await runZonedGuarded(() async {
        controller.resume(); // deliberately not awaited
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }, (error, _) => escaped.add(error));

      expect(escaped, isEmpty);
    });
  });
}
