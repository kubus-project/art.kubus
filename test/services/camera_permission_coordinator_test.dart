import 'dart:async';

import 'package:art_kubus/services/camera_permission_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  late int checkCalls;
  late int requestCalls;
  late int settingsCalls;

  CameraPermissionCoordinator build({
    required PermissionStatus initial,
    PermissionStatus? afterRequest,
    Future<PermissionStatus> Function()? checkStatus,
    bool settingsResult = true,
  }) {
    return CameraPermissionCoordinator(
      checkStatus: checkStatus ??
          () async {
            checkCalls++;
            return initial;
          },
      request: () async {
        requestCalls++;
        return afterRequest ?? initial;
      },
      openSettings: () async {
        settingsCalls++;
        return settingsResult;
      },
    );
  }

  setUp(() {
    checkCalls = 0;
    requestCalls = 0;
    settingsCalls = 0;
  });

  group('granting', () {
    test('an already granted permission never prompts', () async {
      final coordinator = build(initial: PermissionStatus.granted);

      final state = await coordinator.ensureGranted();

      expect(state, CameraPermissionState.granted);
      expect(checkCalls, 1, reason: 'the current status is read first');
      expect(requestCalls, isZero, reason: 'no prompt when already granted');
    });

    test('a denied permission prompts once and can be granted', () async {
      final coordinator = build(
        initial: PermissionStatus.denied,
        afterRequest: PermissionStatus.granted,
      );

      final state = await coordinator.ensureGranted();

      expect(state, CameraPermissionState.granted);
      expect(requestCalls, 1);
    });

    test('iOS limited access counts as granted', () async {
      final coordinator = build(initial: PermissionStatus.limited);

      expect(await coordinator.ensureGranted(), CameraPermissionState.granted);
    });
  });

  group('refusal', () {
    test('a still-denied permission reports denied and can prompt again',
        () async {
      final coordinator = build(initial: PermissionStatus.denied);

      final state = await coordinator.ensureGranted();

      expect(state, CameraPermissionState.denied);
      expect(state.canPrompt, isTrue);
      expect(state.needsSettings, isFalse);
    });

    test('a permanent denial is never prompted again', () async {
      final coordinator = build(initial: PermissionStatus.permanentlyDenied);

      final state = await coordinator.ensureGranted();

      expect(state, CameraPermissionState.permanentlyDenied);
      expect(state.needsSettings, isTrue);
      expect(requestCalls, isZero,
          reason: 'the OS shows nothing, so prompting again is pointless');
    });

    test('a restricted permission is not prompted either', () async {
      final coordinator = build(initial: PermissionStatus.restricted);

      final state = await coordinator.ensureGranted();

      expect(state, CameraPermissionState.restricted);
      expect(state.canPrompt, isFalse);
      expect(requestCalls, isZero);
    });
  });

  group('single ownership', () {
    test('concurrent callers share one prompt', () async {
      final gate = Completer<PermissionStatus>();
      final coordinator = CameraPermissionCoordinator(
        checkStatus: () async {
          checkCalls++;
          return PermissionStatus.denied;
        },
        request: () {
          requestCalls++;
          return gate.future;
        },
        openSettings: () async => true,
      );

      // The scanner and the AR session both asking at once.
      final both = Future.wait([
        coordinator.ensureGranted(),
        coordinator.ensureGranted(),
        coordinator.ensureGranted(),
      ]);
      gate.complete(PermissionStatus.granted);
      final results = await both;

      expect(requestCalls, 1, reason: 'the user must be prompted only once');
      expect(results, everyElement(CameraPermissionState.granted));
    });

    test('a later call after completion can prompt again', () async {
      final coordinator = build(initial: PermissionStatus.denied);

      await coordinator.ensureGranted();
      await coordinator.ensureGranted();

      expect(requestCalls, 2, reason: 'a fresh attempt is a new decision');
    });
  });

  group('recovery via settings', () {
    test('refresh picks up a grant made in system settings', () async {
      var status = PermissionStatus.permanentlyDenied;
      final coordinator = CameraPermissionCoordinator(
        checkStatus: () async => status,
        request: () async => status,
        openSettings: () async => true,
      );
      expect(
        await coordinator.ensureGranted(),
        CameraPermissionState.permanentlyDenied,
      );

      // The user grants it in settings while the app is backgrounded.
      status = PermissionStatus.granted;
      final state = await coordinator.refresh();

      expect(state, CameraPermissionState.granted);
    });

    test('refresh never prompts', () async {
      final coordinator = build(initial: PermissionStatus.denied);

      await coordinator.refresh();

      expect(requestCalls, isZero);
    });

    test('openSettings is delegated to the platform', () async {
      final coordinator = build(initial: PermissionStatus.permanentlyDenied);

      expect(await coordinator.openSettings(), isTrue);
      expect(settingsCalls, 1);
    });

    test('a failing settings launch reports false rather than throwing',
        () async {
      final coordinator = CameraPermissionCoordinator(
        checkStatus: () async => PermissionStatus.denied,
        request: () async => PermissionStatus.denied,
        openSettings: () async => throw StateError('no activity'),
      );

      expect(await coordinator.openSettings(), isFalse);
    });
  });

  group('platform failures', () {
    test('a throwing status check is treated as denied, never granted',
        () async {
      final coordinator = CameraPermissionCoordinator(
        checkStatus: () async => throw StateError('channel down'),
        request: () async => PermissionStatus.denied,
        openSettings: () async => true,
      );

      final state = await coordinator.ensureGranted();

      expect(state, CameraPermissionState.denied);
      expect(state.isGranted, isFalse,
          reason: 'a platform failure must never unlock the camera');
    });
  });
}
