import 'dart:async';

import 'kubus_node_service.dart';
import 'node/kubus_node_transport.dart';
import 'spatial_capture_store.dart';
import 'spatial_transfer_meter.dart';

/// Stage of a streaming transfer to the paired node.
///
/// Distinct stages rather than one "Processing…": a user who cannot tell
/// uploading from validating from queued cannot tell a stalled transfer from a
/// busy GPU, and cannot know whether their phone still needs to be nearby.
enum SpatialTransferPhase {
  idle,

  /// Checking the capture on this device before anything leaves it.
  preparing,

  /// Bytes on the wire.
  uploading,

  /// The node is checking the package it received.
  validating,

  /// Filling a gap the node reported, rather than restarting the transfer.
  repairing,

  complete,
}

/// Honest progress of a streaming capture transfer.
///
/// Every field is measured. [confirmedBytes] counts only what the node has
/// acknowledged, so it survives a restart and never moves backwards;
/// [inFlightBytes] is the part of the current file already handed to the wire,
/// which a route change can legitimately rewind. Keeping them apart is what
/// lets the bar advance smoothly through a large file without ever claiming
/// delivery that has not happened.
class SpatialTransferProgress {
  const SpatialTransferProgress({
    this.phase = SpatialTransferPhase.idle,
    this.uploadedFiles = 0,
    this.totalFiles = 0,
    this.confirmedBytes = 0,
    this.inFlightBytes = 0,
    this.totalBytes = 0,
    this.bytesPerSecond,
    this.eta,
    this.route,
    this.stalled = false,
  });

  final SpatialTransferPhase phase;
  final int uploadedFiles;
  final int totalFiles;

  /// Bytes the node has acknowledged. Durable.
  final int confirmedBytes;

  /// Bytes of the current file already written to the wire. Speculative.
  final int inFlightBytes;

  final int totalBytes;

  /// Smoothed measured throughput, or null while it cannot be claimed.
  final double? bytesPerSecond;

  /// Remaining time, or null when there is not yet evidence for one.
  final Duration? eta;

  /// The rung actually carrying the transfer, for restrained diagnostics.
  final KubusNodeTransportKind? route;

  /// No byte has moved for long enough that a countdown would be a lie.
  final bool stalled;

  /// What the meter should show: confirmed plus the part in flight.
  int get uploadedBytes => confirmedBytes + inFlightBytes;

  bool get isActive =>
      phase != SpatialTransferPhase.idle &&
      phase != SpatialTransferPhase.complete;

  /// Fraction of bytes delivered, or `null` while the total is not yet known.
  double? get fraction {
    if (totalBytes <= 0) return null;
    return (uploadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  int get remainingBytes {
    final remaining = totalBytes - uploadedBytes;
    return remaining > 0 ? remaining : 0;
  }
}

/// Streams one validated capture package into a node draft and commits it.
///
/// Shared by the capture flow and the library flow so the two cannot drift:
/// the rules about what may be skipped, what a resume re-sends and how a
/// rejected commit is repaired are the same transfer either way.
class SpatialNodeUpload {
  SpatialNodeUpload({
    required KubusNodeService service,
    required SpatialCaptureStore source,
    SpatialTransferMeter? meter,
    this.stallTimeout = const Duration(seconds: 90),
    this.fileTimeout = const Duration(hours: 1),
    this.progressInterval = const Duration(milliseconds: 120),
    this.progressTick = const Duration(seconds: 1),
  })  : _service = service,
        _source = source,
        _meter = meter ?? SpatialTransferMeter();

  /// How long one file may make no progress at all before it is abandoned.
  ///
  /// A transfer is judged on whether it is moving, not on how big it is. A
  /// wall clock fails a healthy upload of a large frame over a relay while
  /// letting a genuinely dead connection hang for just as long; this fails the
  /// dead one quickly and lets the slow one finish.
  final Duration stallTimeout;

  /// The outer bound on a single file, so nothing can hang forever.
  ///
  /// Deliberately generous: [stallTimeout] is the real guard, and this only
  /// exists so a connection that somehow dribbles bytes without ever
  /// finishing still terminates.
  final Duration fileTimeout;

  /// The shortest gap between two byte-driven progress frames.
  ///
  /// A chunk callback fires far above frame rate on a fast link, and every
  /// frame rebuilds whatever is watching.
  final Duration progressInterval;

  /// How often a live transfer republishes even when nothing has happened, so
  /// a stall reaches the screen instead of leaving the last frame standing.
  final Duration progressTick;

  final KubusNodeService _service;
  final SpatialCaptureStore _source;
  final SpatialTransferMeter _meter;

  /// Uploads and commits, reporting progress as it goes.
  ///
  /// Throws [SpatialSourceIncomplete] when the capture on this device cannot
  /// make a complete package — a failure the node and the processor can do
  /// nothing about, and which must never be presented as either.
  Future<Map<String, dynamic>> run({
    required Map<String, dynamic> draftMetadata,
    required String localCaptureId,
    required Future<void> Function(String? draftId) rememberDraftId,
    String? draftId,
    void Function(SpatialTransferProgress progress)? onProgress,
  }) async {
    final reporter = _ProgressReporter(
      meter: _meter,
      route: () => _service.activeTransport,
      onProgress: onProgress,
      minimumInterval: progressInterval,
      tick: progressTick,
    );
    try {
      reporter.enter(SpatialTransferPhase.preparing);

      // Validated before a draft is opened: a capture that cannot make a
      // complete package must not reach the node at all.
      final entries = await _source.validateTransferPackage();
      final sizes = <String, int>{};
      var totalBytes = 0;
      for (final entry in entries) {
        final length = await _source.fileAt(entry.path).length();
        sizes[entry.path] = length;
        totalBytes += length;
      }
      reporter.setWork(totalFiles: entries.length, totalBytes: totalBytes);

      var draft = draftId;
      var alreadyUploaded = const <String>{};
      if (draft != null) {
        try {
          alreadyUploaded =
              (await _service.getCaptureDraft(draft)).files.toSet();
        } on KubusNodeRequestException catch (error) {
          // A draft the node no longer knows about is the only one worth
          // abandoning. Drafts live in memory there, so a node restart drops
          // them and the transfer starts again rather than pretending.
          if (error.code != 'capture_draft_not_found') rethrow;
          draft = null;
          await rememberDraftId(null);
        }
      }

      if (draft == null) {
        final opened = await _service.beginCaptureDraft(
          draftMetadata,
          localCaptureId: localCaptureId,
        );
        draft = opened.id;
        // Recorded before the first byte moves, so a crash mid-upload leaves
        // a draft the next attempt can find instead of orphaning it.
        await rememberDraftId(draft);
      }

      reporter.enter(SpatialTransferPhase.uploading);
      for (final entry in entries) {
        if (!alreadyUploaded.contains(entry.path)) {
          await _uploadFile(
            draftId: draft,
            entry: entry,
            onBytesSent: reporter.inFlight,
          );
        }
        // Confirmed only now: the response is what makes these bytes durable.
        reporter.fileDelivered(sizes[entry.path]!);
      }

      reporter.enter(SpatialTransferPhase.validating);
      return await _commit(
        draftId: draft,
        entries: entries,
        sizes: sizes,
        reporter: reporter,
      );
    } finally {
      reporter.dispose();
    }
  }

  /// Streams one file, failing it only once it has actually stopped moving.
  ///
  /// The abandoned request is not cancelled — the transport offers no handle
  /// for that — so it may still complete in the background. That is harmless:
  /// a draft file write is keyed by path and the node overwrites it, and the
  /// node serializes writes within one draft, so a late arrival can only
  /// rewrite the same bytes. [fileTimeout] is what bounds it.
  Future<void> _uploadFile({
    required String draftId,
    required SpatialCaptureUploadEntry entry,
    required void Function(int sentBytes) onBytesSent,
  }) async {
    final stalled = Completer<void>();
    Timer? watchdog;
    void arm() {
      watchdog?.cancel();
      watchdog = Timer(stallTimeout, () {
        if (!stalled.isCompleted) {
          stalled.completeError(
            TimeoutException('upload_stalled', stallTimeout),
          );
        }
      });
    }

    arm();
    try {
      await Future.any<void>(<Future<void>>[
        _service.uploadCaptureDraftFile(
          draftId: draftId,
          path: entry.path,
          file: _source.fileAt(entry.path),
          mimeType: entry.mimeType,
          timeout: fileTimeout,
          onBytesSent: (sent) {
            // Every byte is evidence the transfer is alive.
            arm();
            onBytesSent(sent);
          },
        ),
        stalled.future,
      ]);
    } finally {
      watchdog?.cancel();
      // Nothing awaits this once the upload has settled; completing it keeps
      // an unhandled error from surfacing later.
      if (!stalled.isCompleted) stalled.complete();
    }
  }

  /// Commits, filling any gap the node reports rather than starting over.
  ///
  /// The node refuses an incomplete package and deliberately keeps the draft,
  /// so the remedy is to send the few files it names. Restarting a transfer
  /// of hundreds of megabytes because one file did not land is not a remedy.
  Future<Map<String, dynamic>> _commit({
    required String draftId,
    required List<SpatialCaptureUploadEntry> entries,
    required Map<String, int> sizes,
    required _ProgressReporter reporter,
  }) async {
    try {
      return await _service.commitCaptureDraft(draftId);
    } on KubusNodeRequestException catch (error) {
      if (!_repairableCommitCodes.contains(error.code)) rethrow;
      final missing = error.missingPaths.toSet();
      final repairable =
          entries.where((entry) => missing.contains(entry.path)).toList();
      // Nothing the node named is ours to resend: repeating the commit would
      // only produce the same refusal.
      if (repairable.isEmpty || repairable.length != missing.length) rethrow;

      // Those files were counted as delivered and are not. Taking them back
      // out of the confirmed total is what keeps the meter honest: without
      // it the bar sits at 100% and the readout claims more bytes delivered
      // than the capture contains.
      reporter.enter(SpatialTransferPhase.repairing);
      for (final entry in repairable) {
        reporter.fileWithdrawn(sizes[entry.path]!);
      }
      for (final entry in repairable) {
        await _uploadFile(
          draftId: draftId,
          entry: entry,
          onBytesSent: reporter.inFlight,
        );
        reporter.fileDelivered(sizes[entry.path]!, countsAsNewFile: false);
      }
      reporter.enter(SpatialTransferPhase.validating);
      // One repair attempt. A second refusal is a real disagreement about the
      // package, not a transfer that needs another nudge.
      return _service.commitCaptureDraft(draftId);
    }
  }

  static const Set<String> _repairableCommitCodes = <String>{
    'capture_package_incomplete',
    'capture_frame_file_missing',
    'capture_frames_missing',
  };
}

/// Turns transfer events into progress frames the UI can afford to watch.
///
/// Three jobs the upload itself should not be doing:
///
/// - **Keeping the totals honest.** Confirmed bytes only ever move by a whole
///   delivered file, and a file the node turns out not to have is taken back
///   out, so the meter cannot exceed the work or claim delivery that was
///   withdrawn.
/// - **Noticing silence.** A transfer that stops moving publishes nothing, so
///   without a clock the last frame would sit there with its countdown intact.
///   A ticker republishes while a transfer is live, which is the only way a
///   stall can ever reach the screen.
/// - **Not flooding the frame budget.** A 64 KiB chunk callback fires over a
///   hundred times a second on a LAN; rebuilding the library screen and the
///   live AR overlay that often is worse than useless. Byte updates are
///   coalesced; anything structural is published at once.
class _ProgressReporter {
  _ProgressReporter({
    required SpatialTransferMeter meter,
    required KubusNodeTransportKind? Function() route,
    required void Function(SpatialTransferProgress progress)? onProgress,
    this.minimumInterval = const Duration(milliseconds: 120),
    this.tick = const Duration(seconds: 1),
  })  : _meter = meter,
        _route = route,
        _onProgress = onProgress;

  /// The shortest gap between two byte-driven frames.
  final Duration minimumInterval;

  /// How often a live transfer republishes even when nothing has happened.
  final Duration tick;

  final SpatialTransferMeter _meter;
  final KubusNodeTransportKind? Function() _route;
  final void Function(SpatialTransferProgress progress)? _onProgress;

  SpatialTransferPhase _phase = SpatialTransferPhase.idle;
  int _totalFiles = 0;
  int _totalBytes = 0;
  int _confirmedBytes = 0;
  int _deliveredFiles = 0;
  int _inFlightBytes = 0;
  bool _stalled = false;
  Stopwatch? _sinceEmit;
  Timer? _ticker;
  bool _disposed = false;

  void enter(SpatialTransferPhase phase) {
    _phase = phase;
    _inFlightBytes = 0;
    _ticker ??= Timer.periodic(tick, (_) => _emit(force: true));
    _emit(force: true);
  }

  void setWork({required int totalFiles, required int totalBytes}) {
    _totalFiles = totalFiles;
    _totalBytes = totalBytes;
    _emit(force: true);
  }

  /// Bytes of the current file handed to the wire. Speculative until the
  /// response arrives.
  void inFlight(int sentBytes) {
    _inFlightBytes = sentBytes;
    _emit();
  }

  /// One file the node has acknowledged.
  void fileDelivered(int bytes, {bool countsAsNewFile = true}) {
    _confirmedBytes += bytes;
    if (countsAsNewFile) _deliveredFiles++;
    _inFlightBytes = 0;
    _emit(force: true);
  }

  /// A file that was counted as delivered and turns out not to be there.
  void fileWithdrawn(int bytes) {
    _confirmedBytes -= bytes;
    if (_confirmedBytes < 0) _confirmedBytes = 0;
    if (_deliveredFiles > 0) _deliveredFiles--;
    _emit(force: true);
  }

  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _ticker = null;
  }

  void _emit({bool force = false}) {
    if (_disposed) return;
    _meter.record(_confirmedBytes + _inFlightBytes);
    final stalled = _meter.isStalled;
    // A transfer falling silent, or finding its voice again, is exactly what
    // the user needs to see — never coalesced away.
    final changed = stalled != _stalled;
    _stalled = stalled;

    final elapsed = _sinceEmit;
    if (!force &&
        !changed &&
        elapsed != null &&
        elapsed.elapsed < minimumInterval) {
      return;
    }
    _sinceEmit = Stopwatch()..start();

    final remaining = _totalBytes - _confirmedBytes - _inFlightBytes;
    _onProgress?.call(
      SpatialTransferProgress(
        phase: _phase,
        uploadedFiles: _deliveredFiles,
        totalFiles: _totalFiles,
        confirmedBytes: _confirmedBytes,
        inFlightBytes: _inFlightBytes,
        totalBytes: _totalBytes,
        bytesPerSecond: _meter.bytesPerSecond,
        eta: _meter.etaFor(remaining > 0 ? remaining : 0),
        route: _route(),
        stalled: stalled,
      ),
    );
  }
}
