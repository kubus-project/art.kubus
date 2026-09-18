import 'dart:collection';

/// Measured throughput, and an ETA only once one can be defended.
///
/// Every number here comes from observed bytes and a clock. Nothing is
/// interpolated and nothing is reported early: a countdown invented from a
/// single sample is worse than no countdown, because the user believes it and
/// then watches it lie. The meter answers `null` until it has seen enough of
/// the transfer to say something true, and reports a stall rather than
/// continuing to count down against a transfer that has stopped moving.
class SpatialTransferMeter {
  SpatialTransferMeter({
    this.window = const Duration(seconds: 10),
    this.minimumSampleSpan = const Duration(seconds: 2),
    this.stallAfter = const Duration(seconds: 12),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// How far back throughput is averaged. Long enough to ride out one slow
  /// chunk, short enough to follow a route that genuinely changed speed.
  final Duration window;

  /// The span of evidence required before any rate is reported.
  final Duration minimumSampleSpan;

  /// How long without a single delivered byte before the transfer is called
  /// stalled rather than slow.
  final Duration stallAfter;

  final DateTime Function() _clock;
  final Queue<_Sample> _samples = Queue<_Sample>();

  int _delivered = 0;
  DateTime? _lastProgressAt;

  /// Total bytes the meter has been told are delivered.
  int get deliveredBytes => _delivered;

  /// Records cumulative delivered bytes.
  ///
  /// Cumulative rather than incremental so a caller that recomputes its total
  /// — after a resume, or after a route change rewound an in-flight file —
  /// cannot double-count. A total that moves backwards is treated as a
  /// correction, not as negative throughput.
  void record(int deliveredBytes) {
    final now = _clock();
    if (deliveredBytes > _delivered) {
      _lastProgressAt = now;
    } else if (deliveredBytes < _delivered) {
      // A correction: the evidence gathered against the old total no longer
      // describes this transfer, so the rate is rebuilt from here.
      _samples.clear();
    }
    _delivered = deliveredBytes;
    _lastProgressAt ??= now;
    _samples.addLast(_Sample(at: now, bytes: deliveredBytes));
    _trim(now);
  }

  void _trim(DateTime now) {
    final cutoff = now.subtract(window);
    while (_samples.length > 2 && _samples.first.at.isBefore(cutoff)) {
      _samples.removeFirst();
    }
  }

  /// Smoothed throughput, or null while the evidence is too thin to claim one.
  double? get bytesPerSecond {
    if (_samples.length < 2) return null;
    final first = _samples.first;
    final last = _samples.last;
    final span = last.at.difference(first.at);
    if (span < minimumSampleSpan) return null;
    final bytes = last.bytes - first.bytes;
    if (bytes <= 0) return null;
    final seconds = span.inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds <= 0) return null;
    return bytes / seconds;
  }

  /// Time remaining for [remainingBytes], or null when it cannot be measured.
  ///
  /// Null while throughput is unknown and null while the transfer is stalled:
  /// in both cases the honest thing to show is what is happening, not a
  /// number.
  Duration? etaFor(int remainingBytes) {
    if (remainingBytes <= 0) return Duration.zero;
    if (isStalled) return null;
    final rate = bytesPerSecond;
    if (rate == null || rate <= 0) return null;
    final seconds = remainingBytes / rate;
    if (!seconds.isFinite) return null;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  /// Whether no byte has been delivered for longer than [stallAfter].
  bool get isStalled {
    final last = _lastProgressAt;
    if (last == null) return false;
    return _clock().difference(last) >= stallAfter;
  }

  /// Forgets measured history while keeping the delivered total.
  ///
  /// Used when the transfer changes route: the old rung's rate says nothing
  /// about the new one, and carrying it over would produce a confident ETA
  /// for a transfer that is now moving at a completely different speed.
  void resetRate() => _samples.clear();
}

class _Sample {
  const _Sample({required this.at, required this.bytes});

  final DateTime at;
  final int bytes;
}
