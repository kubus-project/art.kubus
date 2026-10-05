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

  /// Force boot logging on in release/profile builds via
  /// `--dart-define=KUBUS_BOOT_TRACE=true`. Useful for measuring the real cold
  /// load of a deployed (release) web build without leaving logging on by
  /// default.
  static const bool _forceTrace =
      bool.fromEnvironment('KUBUS_BOOT_TRACE', defaultValue: false);

  /// Boot marks are logged in debug and profile builds (profile is the usual
  /// mode for performance measurement) and whenever [_forceTrace] is set.
  /// Plain release builds stay quiet unless the define opts in.
  static bool get _shouldLog => kDebugMode || kProfileMode || _forceTrace;

  /// Immutable, chronologically ordered view of every recorded mark.
  static List<StartupTraceMark> get marks =>
      List<StartupTraceMark>.unmodifiable(_marks);

  /// Milliseconds elapsed since the trace started (process start).
  static int get elapsedMs => _sw.elapsedMilliseconds;

  /// Deterministic entry diagnostics in debug/test or explicitly opted-in
  /// builds. Queries, fragments, user info and auth token paths are omitted.
  static void publicEntry(
    String stage, {
    Uri? uri,
    String? entityType,
    String? accessPolicy,
    bool? hasSession,
    String? route,
    String? caller,
  }) {
    if (!_shouldLog) return;
    mark('public_entry $stage '
        '${uri == null ? '' : 'uri=${safeEntryPath(uri)} '} '
        '${entityType == null ? '' : 'type=$entityType '} '
        '${accessPolicy == null ? '' : 'policy=$accessPolicy '} '
        '${hasSession == null ? '' : 'session=$hasSession '} '
        '${route == null ? '' : 'route=${safeEntryPath(Uri.parse(route))} '} '
        '${caller == null ? '' : 'caller=$caller'}');
  }

  @visibleForTesting
  static String safeEntryPath(Uri uri) {
    final parts = uri.pathSegments;
    const publicHeads = {
      'a',
      'u',
      'm',
      'e',
      'x',
      'p',
      'c',
      'n',
      'artworks',
      'umetnine',
      'profiles',
      'profili',
      'map',
      'zemljevid',
      'events',
      'dogodki',
      'exhibitions',
      'razstave',
      'posts',
      'objave',
      'collections',
      'zbirke',
      'collectibles',
      'zbirateljski-predmeti'
    };
    final offset =
        parts.isNotEmpty && {'en', 'sl'}.contains(parts.first) ? 1 : 0;
    if (parts.length > offset && publicHeads.contains(parts[offset])) {
      return '/${parts.take(offset + 2).map(Uri.encodeComponent).join('/')}';
    }
    return parts.isEmpty ? '/' : '/${Uri.encodeComponent(parts.first)}';
  }

  /// Records [label] at the current elapsed time and logs it when enabled.
  static void mark(String label) {
    final ms = _sw.elapsedMilliseconds;
    _marks.add(StartupTraceMark(label: label, elapsedMs: ms));
    if (_shouldLog) {
      // Use print() rather than debugPrint(): main() replaces debugPrint with a
      // no-op in every non-debug build, which would otherwise swallow boot
      // marks even when they are explicitly enabled (profile / KUBUS_BOOT_TRACE).
      // ignore: avoid_print
      print('[BOOT] ${ms}ms $label');
    }
  }

  /// Clears recorded marks. Intended for tests only.
  @visibleForTesting
  static void reset() => _marks.clear();
}
