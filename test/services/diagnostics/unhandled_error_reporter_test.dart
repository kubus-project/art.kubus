import 'package:art_kubus/services/diagnostics/unhandled_error_reporter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<UnhandledErrorReport> captured;
  late List<UnhandledErrorReport> surfaced;
  late DateTime now;

  UnhandledErrorReporter buildReporter({
    Future<void> Function(UnhandledErrorReport)? sink,
  }) {
    return UnhandledErrorReporter(
      sink: sink ??
          (report) async {
            captured.add(report);
          },
      debugSurface: surfaced.add,
      clock: () => now,
    );
  }

  setUp(() {
    captured = <UnhandledErrorReport>[];
    surfaced = <UnhandledErrorReport>[];
    now = DateTime(2026, 1, 1);
  });

  group('source attribution', () {
    test('a Flutter framework error is captured once as FlutterError',
        () async {
      final reporter = buildReporter();
      final error = StateError('widget build failed');
      final stack =
          StackTrace.fromString('#0 build (package:art_kubus/x.dart)');

      final accepted = reporter.report(
        error,
        stack,
        source: UnhandledErrorSource.flutterError,
        details: FlutterErrorDetails(exception: error, stack: stack),
      );
      await Future<void>.delayed(Duration.zero);

      expect(accepted, isTrue);
      expect(captured, hasLength(1));
      expect(captured.single.source, UnhandledErrorSource.flutterError);
      expect(captured.single.source.wireName, 'FlutterError');
    });

    test(
      'a Flutter framework error is never reclassified as a fatal Zone error',
      () async {
        final reporter = buildReporter();
        final error = StateError('widget build failed');
        final stack =
            StackTrace.fromString('#0 build (package:art_kubus/x.dart)');

        reporter.report(
          error,
          stack,
          source: UnhandledErrorSource.flutterError,
          details: FlutterErrorDetails(exception: error, stack: stack),
        );
        await Future<void>.delayed(Duration.zero);

        // The regression: main.dart used to call
        // Zone.current.handleUncaughtError() from FlutterError.onError, so one
        // framework error produced a second 'Zone' event at 'fatal' severity
        // and the debug overlay read "Unhandled Zone error".
        expect(
          captured.map((r) => r.source),
          everyElement(isNot(UnhandledErrorSource.zone)),
        );
        expect(captured.single.severity, 'error');
        expect(
          surfaced.single.source.wireName,
          'FlutterError',
          reason: 'debug overlay must name the true origin domain',
        );
      },
    );

    test('a genuinely escaped async error is captured as a fatal Zone error',
        () async {
      final reporter = buildReporter();

      reporter.report(
        StateError('nobody awaited this'),
        StackTrace.fromString('#0 dispose (package:arcore/controller.dart)'),
        source: UnhandledErrorSource.zone,
      );
      await Future<void>.delayed(Duration.zero);

      expect(captured.single.source, UnhandledErrorSource.zone);
      expect(captured.single.severity, 'fatal');
    });

    test('a root-isolate platform error is attributed to PlatformDispatcher',
        () async {
      final reporter = buildReporter();

      reporter.report(
        StateError('platform'),
        StackTrace.fromString('#0 platform'),
        source: UnhandledErrorSource.platformDispatcher,
      );
      await Future<void>.delayed(Duration.zero);

      expect(captured.single.source, UnhandledErrorSource.platformDispatcher);
      expect(captured.single.severity, 'fatal');
    });
  });

  group('deduplication', () {
    test('the same error arriving twice inside the window reports once',
        () async {
      final reporter = buildReporter();
      final error = StateError('repeated');
      final stack = StackTrace.fromString('#0 repeated');

      final first = reporter.report(error, stack,
          source: UnhandledErrorSource.flutterError);
      now = now.add(const Duration(milliseconds: 500));
      final second = reporter.report(error, stack,
          source: UnhandledErrorSource.flutterError);
      await Future<void>.delayed(Duration.zero);

      expect(first, isTrue);
      expect(second, isFalse);
      expect(captured, hasLength(1));
      expect(reporter.suppressedCount, 1);
    });

    test('dedupe ignores the source so cross-domain echoes collapse', () async {
      final reporter = buildReporter();
      final error = StateError('echoed');
      final stack = StackTrace.fromString('#0 echoed');

      reporter.report(error, stack, source: UnhandledErrorSource.flutterError);
      now = now.add(const Duration(milliseconds: 10));
      final echoed =
          reporter.report(error, stack, source: UnhandledErrorSource.zone);
      await Future<void>.delayed(Duration.zero);

      expect(echoed, isFalse);
      expect(captured, hasLength(1));
      expect(captured.single.source, UnhandledErrorSource.flutterError);
    });

    test('the same error after the window reports again', () async {
      final reporter = buildReporter();
      final error = StateError('later');
      final stack = StackTrace.fromString('#0 later');

      reporter.report(error, stack, source: UnhandledErrorSource.flutterError);
      now = now.add(UnhandledErrorReporter.dedupeWindow +
          const Duration(milliseconds: 1));
      reporter.report(error, stack, source: UnhandledErrorSource.flutterError);
      await Future<void>.delayed(Duration.zero);

      expect(captured, hasLength(2));
    });

    test('distinct errors are never collapsed', () async {
      final reporter = buildReporter();

      reporter.report(StateError('a'), StackTrace.fromString('#0 a'),
          source: UnhandledErrorSource.flutterError);
      reporter.report(StateError('b'), StackTrace.fromString('#0 b'),
          source: UnhandledErrorSource.flutterError);
      await Future<void>.delayed(Duration.zero);

      expect(captured, hasLength(2));
    });
  });

  group('resilience', () {
    test('a throwing diagnostics sink does not propagate to the caller',
        () async {
      final reporter = buildReporter(
        sink: (_) async => throw StateError('diagnostics backend down'),
      );

      expect(
        () => reporter.report(
          StateError('original'),
          StackTrace.fromString('#0 original'),
          source: UnhandledErrorSource.flutterError,
        ),
        returnsNormally,
      );
      await Future<void>.delayed(Duration.zero);
    });

    test('a throwing debug surface does not propagate to the caller', () {
      final reporter = UnhandledErrorReporter(
        sink: (report) async => captured.add(report),
        debugSurface: (_) => throw StateError('no navigator'),
        clock: () => now,
      );

      expect(
        () => reporter.report(
          StateError('original'),
          StackTrace.fromString('#0 original'),
          source: UnhandledErrorSource.flutterError,
        ),
        returnsNormally,
      );
    });

    test('the debug surface is throttled but diagnostics capture is not',
        () async {
      final reporter = buildReporter();

      reporter.report(StateError('a'), StackTrace.fromString('#0 a'),
          source: UnhandledErrorSource.flutterError);
      now = now.add(const Duration(seconds: 1));
      reporter.report(StateError('b'), StackTrace.fromString('#0 b'),
          source: UnhandledErrorSource.flutterError);
      await Future<void>.delayed(Duration.zero);

      expect(captured, hasLength(2), reason: 'diagnostics keeps every event');
      expect(surfaced, hasLength(1), reason: 'overlay stays quiet');
    });
  });

  test('the first report of the run is retained for stack mapping', () async {
    final reporter = buildReporter();

    reporter.report(StateError('first'), StackTrace.fromString('#0 first'),
        source: UnhandledErrorSource.flutterError);
    now = now.add(const Duration(seconds: 10));
    reporter.report(StateError('second'), StackTrace.fromString('#0 second'),
        source: UnhandledErrorSource.zone);

    expect(reporter.firstReport, isNotNull);
    expect(reporter.firstReport!.source, UnhandledErrorSource.flutterError);
    expect('${reporter.firstReport!.error}', contains('first'));
  });
}
