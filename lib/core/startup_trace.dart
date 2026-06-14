import 'package:flutter/foundation.dart';

/// A single recorded startup checkpoint.
@immutable
class StartupTraceMark {
  const StartupTraceMark({required this.label, required this.elapsedMs});

  final String label;
  final int elapsedMs;

  @override
  String toString() => '[BOOT] ${elapsedMs}ms $label';
}

/// Lightweight cold-boot tracing utility.
///
/// Use [StartupTrace.mark] at the boundaries of the startup pipeline so the
/// time spent in each phase is visible. In debug builds every mark is printed
/// as `[BOOT] <ms>ms <label>` (the elapsed time is measured from the first
/// access of this class, i.e. process start). Recording is always on and very
/// cheap; only the logging is gated to debug builds so release stays quiet.
///
/// The goal is to make it possible to identify exactly where startup time is
/// spent: critical bootstrap, first frame, auth/session restore, route
/// decision, deferred warm-up, map init, marker fetch, etc.
class StartupTrace {
  StartupTrace._();

  static final Stopwatch _sw = Stopwatch()..start();
  static final List<StartupTraceMark> _marks = <StartupTraceMark>[];

  /// Immutable, chronologically ordered view of every recorded mark.
  static List<StartupTraceMark> get marks => List<StartupTraceMark>.unmodifiable(_marks);

  /// Milliseconds elapsed since the trace started (process start).
  static int get elapsedMs => _sw.elapsedMilliseconds;

  /// Records [label] at the current elapsed time and prints it in debug builds.
  static void mark(String label) {
    final ms = _sw.elapsedMilliseconds;
    _marks.add(StartupTraceMark(label: label, elapsedMs: ms));
    if (kDebugMode) {
      debugPrint('[BOOT] ${ms}ms $label');
    }
  }

  /// Clears recorded marks. Intended for tests only.
  @visibleForTesting
  static void reset() => _marks.clear();
}
