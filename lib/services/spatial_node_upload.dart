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
  })  : _service = service,
        _source = source,
        _meter = meter ?? SpatialTransferMeter();

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
    var progress = SpatialTransferProgress(
      phase: SpatialTransferPhase.preparing,
      route: _service.activeTransport,
    );
    onProgress?.call(progress);

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

    var draft = draftId;
    var alreadyUploaded = const <String>{};
    if (draft != null) {
      try {
        alreadyUploaded = (await _service.getCaptureDraft(draft)).files.toSet();
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
      // Recorded before the first byte moves, so a crash mid-upload leaves a
      // draft the next attempt can find instead of orphaning it on the node.
      await rememberDraftId(draft);
    }

    var confirmedBytes = 0;
    var uploadedFiles = 0;

    void publish(SpatialTransferPhase phase, {int inFlight = 0}) {
      _meter.record(confirmedBytes + inFlight);
      final remaining = totalBytes - confirmedBytes - inFlight;
      progress = SpatialTransferProgress(
        phase: phase,
        uploadedFiles: uploadedFiles,
        totalFiles: entries.length,
        confirmedBytes: confirmedBytes,
        inFlightBytes: inFlight,
        totalBytes: totalBytes,
        bytesPerSecond: _meter.bytesPerSecond,
        eta: _meter.etaFor(remaining > 0 ? remaining : 0),
        route: _service.activeTransport,
        stalled: _meter.isStalled,
      );
      onProgress?.call(progress);
    }

    publish(SpatialTransferPhase.uploading);

    for (final entry in entries) {
      final length = sizes[entry.path]!;
      if (!alreadyUploaded.contains(entry.path)) {
        await _service.uploadCaptureDraftFile(
          draftId: draft,
          path: entry.path,
          file: _source.fileAt(entry.path),
          mimeType: entry.mimeType,
          onBytesSent: (sent) =>
              publish(SpatialTransferPhase.uploading, inFlight: sent),
        );
      }
      // Confirmed only now: the response is what makes these bytes durable.
      confirmedBytes += length;
      uploadedFiles++;
      publish(SpatialTransferPhase.uploading);
    }

    publish(SpatialTransferPhase.validating);
    return _commit(
      draftId: draft,
      entries: entries,
      sizes: sizes,
      onRepairProgress: (inFlight) =>
          publish(SpatialTransferPhase.repairing, inFlight: inFlight),
      onValidating: () => publish(SpatialTransferPhase.validating),
    );
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
    required void Function(int inFlightBytes) onRepairProgress,
    required void Function() onValidating,
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

      for (final entry in repairable) {
        await _service.uploadCaptureDraftFile(
          draftId: draftId,
          path: entry.path,
          file: _source.fileAt(entry.path),
          mimeType: entry.mimeType,
          onBytesSent: onRepairProgress,
        );
      }
      onValidating();
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
