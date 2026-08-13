import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'diagnostics_client.dart';
import 'flutter_error_context.dart';

/// Error domain an unhandled error actually arrived from.
///
/// Attribution matters: a widget build failure reported by the Flutter
/// framework is a different class of event from a `Future` that nothing ever
/// listened to, and the debug overlay plus the diagnostics feed must not
/// conflate them. Each domain reports exactly once — no handler re-dispatches
/// into another domain.
enum UnhandledErrorSource {
  /// `FlutterError.onError` — framework, widget, and plugin errors that the
  /// framework already caught. Recoverable by default.
  flutterError('FlutterError', 'error'),

  /// `PlatformDispatcher.onError` — uncaught async errors that reached the
  /// root isolate without passing through a guarded zone.
  platformDispatcher('PlatformDispatcher', 'fatal'),

  /// `runZonedGuarded` — an error that escaped the guarded zone, i.e. a truly
  /// unobserved `Future` or an async gap nobody awaited.
  zone('Zone', 'fatal'),

  /// Background isolate error listener.
  isolate('Isolate', 'error'),

  /// `ErrorWidget.builder` — a build-time failure already surfaced in the UI.
  errorWidget('ErrorWidget', 'error');

  const UnhandledErrorSource(this.wireName, this.severity);

  /// Stable identifier used by the diagnostics backend and the debug overlay.
  final String wireName;

  /// Default severity for this domain.
  final String severity;
}

/// A single normalized unhandled-error report.
@immutable
class UnhandledErrorReport {
  const UnhandledErrorReport({
    required this.error,
    required this.stack,
    required this.source,
    required this.severity,
    this.metadata,
  });

  final Object error;
  final StackTrace stack;
  final UnhandledErrorSource source;
  final String severity;
  final Map<String, dynamic>? metadata;
}

/// Routes unhandled errors from every global Flutter error domain into
/// diagnostics exactly once.
///
/// Extracted from `main.dart` so the wiring is unit-testable: the previous
/// in-`main` closure could only be exercised by running the whole app.
class UnhandledErrorReporter {
  UnhandledErrorReporter({
    Future<void> Function(UnhandledErrorReport report)? sink,
    void Function(UnhandledErrorReport report)? debugSurface,
    DateTime Function()? clock,
    bool logInRelease = _logInReleaseDefault,
  })  : _sink = sink ?? _defaultSink,
        _debugSurface = debugSurface,
        _clock = clock ?? DateTime.now,
        _logInRelease = logInRelease;

  static const Duration dedupeWindow = Duration(seconds: 2);
  static const Duration debugSurfaceInterval = Duration(seconds: 4);

  static const bool _logInReleaseDefault = bool.fromEnvironment(
    'ERROR_STACK_LOG',
    defaultValue: false,
  );

  final Future<void> Function(UnhandledErrorReport report) _sink;
  final void Function(UnhandledErrorReport report)? _debugSurface;
  final DateTime Function() _clock;
  final bool _logInRelease;

  String? _lastSignature;
  DateTime? _lastReportedAt;
  int _suppressedCount = 0;
  DateTime? _lastDebugSurfaceAt;

  /// First error seen this run, retained for external stack-mapping tools.
  UnhandledErrorReport? firstReport;

  /// Number of duplicates suppressed since the last reported error.
  int get suppressedCount => _suppressedCount;

  /// Reports [error] as originating from [source].
  ///
  /// Returns `true` when the report was forwarded, `false` when it was
  /// suppressed as a duplicate.
  bool report(
    Object error,
    StackTrace stack, {
    required UnhandledErrorSource source,
    FlutterErrorDetails? details,
  }) {
    final signature = _signatureFor(error, stack);
    final now = _clock();
    final lastAt = _lastReportedAt;

    // Deliberately source-independent. If the same exception ever does reach
    // two domains, it is one incident and must produce one event.
    if (_lastSignature == signature &&
        lastAt != null &&
        now.difference(lastAt) < dedupeWindow) {
      _suppressedCount += 1;
      return false;
    }

    if (_suppressedCount > 0 && kDebugMode) {
      debugPrint(
        'UnhandledErrorReporter: suppressed $_suppressedCount duplicate '
        'error(s)',
      );
    }

    _suppressedCount = 0;
    _lastSignature = signature;
    _lastReportedAt = now;

    final report = UnhandledErrorReport(
      error: error,
      stack: stack,
      source: source,
      severity: source.severity,
      metadata: buildFlutterErrorContext(error, details),
    );
    firstReport ??= report;

    _log(report);
    _maybeSurfaceDebugUi(report, now);
    unawaited(_safeSink(report));
    return true;
  }

  Future<void> _safeSink(UnhandledErrorReport report) async {
    try {
      await _sink(report);
    } catch (error, stack) {
      // Diagnostics must never take the app down with it.
      if (kDebugMode) {
        debugPrint('UnhandledErrorReporter: sink failed: $error\n$stack');
      }
    }
  }

  void _log(UnhandledErrorReport report) {
    if (kDebugMode || _logInRelease) {
      debugPrint(
        'UnhandledErrorReporter: unhandled error (${report.source.wireName}) '
        '${report.error.runtimeType}: ${report.error}',
      );
      debugPrint('UnhandledErrorReporter: stack: ${report.stack}');
      return;
    }
    // Keep a minimal breadcrumb in release so errors are never fully silent.
    developer.log(
      'Unhandled error (${report.source.wireName}) '
      '${report.error.runtimeType}',
      name: 'UnhandledErrorReporter',
      error: report.error,
      stackTrace: report.stack,
    );
  }

  void _maybeSurfaceDebugUi(UnhandledErrorReport report, DateTime now) {
    final surface = _debugSurface;
    if (surface == null) return;
    final last = _lastDebugSurfaceAt;
    if (last != null && now.difference(last) < debugSurfaceInterval) return;
    _lastDebugSurfaceAt = now;
    try {
      surface(report);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('UnhandledErrorReporter: debug surface failed: $error');
      }
    }
  }

  String _signatureFor(Object error, StackTrace stack) {
    final stackLine = stack.toString().split('\n').first.trim();
    return '${error.runtimeType}|$error|$stackLine';
  }

  static Future<void> _defaultSink(UnhandledErrorReport report) {
    return DiagnosticsClient.instance.captureError(
      report.error,
      report.stack,
      source: report.source.wireName,
      severity: report.severity,
      metadata: report.metadata,
    );
  }
}
