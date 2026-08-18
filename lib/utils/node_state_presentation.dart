/// Turns kubus Node runtime state into the language the app shows.
///
/// This is the app-side counterpart of `src/gui/presentation.ts` in the node
/// runtime, and the two are deliberately kept in step: an operator who reads
/// "Network participation required" in the node interface must read the same
/// sentence in the app, not a second vocabulary for the same condition.
///
/// Everything here is pure — state in, localized text out — so the wording is
/// testable without building a widget.
library;

import '../l10n/app_localizations.dart';

/// Status severity. Colour is derived from this, but never carries the meaning
/// on its own: each description also has a title, so status survives without
/// colour perception.
enum NodeSeverity { neutral, good, attention, critical }

class NodeStateDescription {
  const NodeStateDescription({
    required this.title,
    required this.body,
    required this.severity,
    this.actionLabel,
  });

  /// Short label, safe to render next to a status dot.
  final String title;

  /// One sentence of plain explanation. Never a raw error or a state code.
  final String body;
  final NodeSeverity severity;

  /// Present only where there is something useful to do about it.
  final String? actionLabel;
}

class NodeStatePresentation {
  const NodeStatePresentation._();

  /// Participation is reciprocity, not enforcement. The copy explains what the
  /// operator gets and what the network needs; it never accuses, and the word
  /// "locked" does not appear even though the runtime state is `LOCKED`.
  static NodeStateDescription participation(
    AppLocalizations l10n,
    String state,
  ) {
    switch (state.toUpperCase()) {
      case 'CONTRIBUTING':
        return NodeStateDescription(
          title: l10n.kubusNodeStateContributing,
          body: l10n.kubusNodeStateContributingBody,
          severity: NodeSeverity.good,
        );
      case 'JOINING':
        return NodeStateDescription(
          title: l10n.kubusNodeStateJoining,
          body: l10n.kubusNodeStateJoiningBody,
          severity: NodeSeverity.neutral,
        );
      case 'DEGRADED':
        return NodeStateDescription(
          title: l10n.kubusNodeStateDegraded,
          body: l10n.kubusNodeStateDegradedBody,
          severity: NodeSeverity.attention,
          actionLabel: l10n.kubusNodeCheckStatusAction,
        );
      case 'LOCKED':
        return NodeStateDescription(
          title: l10n.kubusNodeStateLocked,
          body: l10n.kubusNodeStateLockedBody,
          severity: NodeSeverity.attention,
          actionLabel: l10n.kubusNodeCheckStatusAction,
        );
      case 'UNCONFIGURED':
      default:
        return NodeStateDescription(
          title: l10n.kubusNodeStateUnconfigured,
          body: l10n.kubusNodeStateUnconfiguredBody,
          severity: NodeSeverity.neutral,
        );
    }
  }

  /// The node is paired but unreachable. Distinct from a participation problem:
  /// nothing is wrong with the node's standing, the app just cannot see it.
  static NodeStateDescription unreachable(AppLocalizations l10n) =>
      NodeStateDescription(
        title: l10n.kubusNodeStateOffline,
        body: l10n.kubusNodeStateOfflineBody,
        severity: NodeSeverity.attention,
      );

  /// Answers one question: can a capture be processed on this node right now?
  ///
  /// CUDA and driver text stays out of the result entirely — it belongs in the
  /// node's own diagnostics, not in a consumer app.
  static NodeStateDescription worker(
    AppLocalizations l10n,
    Map<String, dynamic> worker,
  ) {
    final status = (worker['status'] ?? '').toString();
    final gpu = worker['gpu'];
    final gpuAvailable = gpu is Map && gpu['available'] == true;

    if (status == 'ready' && gpuAvailable) {
      return NodeStateDescription(
        title: l10n.kubusNodeWorkerReady,
        body: l10n.kubusNodeWorkerReadyBody,
        severity: NodeSeverity.good,
      );
    }
    // A detected GPU with no responding worker is a fixable problem; no GPU at
    // all is simply a fact about the hardware and not an alarm.
    if (gpuAvailable) {
      return NodeStateDescription(
        title: l10n.kubusNodeWorkerDown,
        body: l10n.kubusNodeWorkerDownBody,
        severity: NodeSeverity.attention,
      );
    }
    return NodeStateDescription(
      title: l10n.kubusNodeWorkerNoGpu,
      body: l10n.kubusNodeWorkerNoGpuBody,
      severity: NodeSeverity.neutral,
    );
  }

  /// "RTX 3080 Ti · 12 GB", or null when there is nothing worth showing.
  static String? gpuLabel(Map<String, dynamic> worker) {
    final gpu = worker['gpu'];
    if (gpu is! Map || gpu['available'] != true) return null;
    final name =
        (gpu['model'] ?? gpu['name'] ?? gpu['vendor'] ?? '').toString().trim();
    final vram = int.tryParse((gpu['totalVramBytes'] ?? 0).toString()) ?? 0;
    final vramLabel = vram > 0 ? formatBytes(vram) : null;
    if (name.isNotEmpty && vramLabel != null) return '$name · $vramLabel';
    if (name.isNotEmpty) return name;
    return vramLabel;
  }

  /// Local pipeline stages. Fewer than remote because there is no transfer, no
  /// provider and no verification round trip.
  static List<String> localStages(AppLocalizations l10n) => [
        l10n.spatialStagePreparing,
        l10n.spatialStageProcessingLocally,
        l10n.spatialStageOptimising,
        l10n.spatialStageCreatingPreview,
        l10n.spatialStageComplete,
      ];

  /// Remote pipeline stages, aligned to the backend state machine.
  static List<String> remoteStages(AppLocalizations l10n) => [
        l10n.spatialStagePreparing,
        l10n.spatialStageEncrypting,
        l10n.spatialStageSending,
        l10n.spatialStageWaitingForGpu,
        l10n.spatialStageProcessing,
        l10n.spatialStagePreparingArchive,
        l10n.spatialStageReceiving,
        l10n.spatialStageVerifying,
        l10n.spatialStageComplete,
      ];

  /// The local worker reports a real fraction, so a determinate bar is honest.
  static NodeJobProgress localJob(
    AppLocalizations l10n,
    String state,
    double progress,
  ) {
    switch (state) {
      case 'queued':
        return NodeJobProgress(
          stageIndex: 0,
          determinate: false,
          body: l10n.spatialProgressLocalBody,
        );
      case 'running':
        return NodeJobProgress(
          stageIndex: progress >= 0.9
              ? 3
              : progress >= 0.6
                  ? 2
                  : 1,
          determinate: true,
          fraction: progress.clamp(0.0, 1.0),
          body: l10n.spatialProgressLocalBody,
        );
      case 'completed':
        return NodeJobProgress(
          stageIndex: 4,
          determinate: true,
          fraction: 1,
          complete: true,
          body: l10n.spatialStageComplete,
        );
      case 'cancelled':
        return NodeJobProgress(
          stageIndex: 0,
          determinate: false,
          terminal: true,
          body: l10n.spatialProgressLocalBody,
        );
      default:
        return NodeJobProgress(
          stageIndex: 0,
          determinate: false,
          terminal: true,
          failed: true,
          body: l10n.spatialFailedLocalBody,
        );
    }
  }

  /// Remote progress is stage-based, never a percentage: the backend cannot
  /// estimate remaining time, and a smooth bar would be a fabrication.
  static NodeJobProgress remoteJob(AppLocalizations l10n, String state) {
    const stageByState = <String, int>{
      'REQUESTED': 0,
      'MATCHED': 2,
      'ACCEPTED': 3,
      'INPUT_READY': 3,
      'RUNNING': 4,
      'OUTPUT_READY': 5,
      'RECEIVING': 6,
      'VERIFYING': 7,
      'VERIFIED': 7,
      'COMPLETED': 8,
    };
    final normalized = state.toUpperCase();
    final stage = stageByState[normalized];
    if (stage != null) {
      return NodeJobProgress(
        stageIndex: stage,
        determinate: false,
        complete: normalized == 'COMPLETED',
        terminal: normalized == 'COMPLETED',
        body: l10n.spatialProgressRemoteBody,
      );
    }
    return NodeJobProgress(
      stageIndex: 0,
      determinate: false,
      terminal: true,
      failed: normalized != 'CANCELLED',
      body: normalized == 'CANCELLED'
          ? l10n.spatialProgressRemoteBody
          : l10n.spatialFailedRemoteBody,
    );
  }

  /// API and runtime codes become sentences. The raw code stays available to
  /// the caller for a "technical details" disclosure, but is never the headline.
  static String translateError(AppLocalizations l10n, String? code) {
    switch ((code ?? '').trim()) {
      case 'NETWORK_PARTICIPATION_REQUIRED':
        return l10n.spatialErrorParticipation;
      case 'NO_COMPATIBLE_PROVIDER':
        return l10n.spatialErrorNoProvider;
      case 'COMPUTE_JOB_EXPIRED':
        return l10n.spatialErrorExpired;
      case 'PAYLOAD_RETRIEVAL_FAILED':
        return l10n.spatialErrorRetrieval;
      case 'backend_authorization_required':
        return l10n.spatialErrorSignIn;
      default:
        return l10n.spatialErrorGeneric;
    }
  }

  static const List<String> _byteUnits = ['B', 'KB', 'MB', 'GB', 'TB'];

  /// Storage is shown in whole human units. Operators read "12.4 GB", never a
  /// byte count.
  static String formatBytes(num? bytes) {
    final value = (bytes ?? 0).toDouble();
    if (!value.isFinite || value <= 0) return '0 B';
    var exponent = 0;
    var scaled = value;
    while (scaled >= 1024 && exponent < _byteUnits.length - 1) {
      scaled /= 1024;
      exponent += 1;
    }
    final digits = exponent == 0 || scaled >= 100 ? 0 : 1;
    return '${scaled.toStringAsFixed(digits)} ${_byteUnits[exponent]}';
  }

  /// Ratios arrive as 0..1 fractions from the runtime.
  static String formatPercent(num? fraction) {
    final value = ((fraction ?? 0).toDouble()).clamp(0.0, 1.0) * 100;
    final digits = value >= 99.95 || value == value.roundToDouble() ? 0 : 1;
    return '${value.toStringAsFixed(digits)}%';
  }

  /// KUB8 is a contribution record, not a price: fixed precision, no currency.
  static String formatKub8(num? value) =>
      ((value ?? 0).toDouble()).toStringAsFixed(2);

  /// Technical identifiers are truncated in the middle so both ends stay
  /// recognisable, and are always paired with a copy control in the UI.
  static String shortId(String? value, {int head = 8, int tail = 6}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '—';
    if (text.length <= head + tail + 1) return text;
    return '${text.substring(0, head)}…${text.substring(text.length - tail)}';
  }
}

/// Where a job has reached, in terms the progress UI can render directly.
class NodeJobProgress {
  const NodeJobProgress({
    required this.stageIndex,
    required this.determinate,
    required this.body,
    this.fraction,
    this.complete = false,
    this.terminal = false,
    this.failed = false,
  });

  final int stageIndex;

  /// False when the runtime cannot estimate progress; the UI then shows stages
  /// rather than an invented percentage.
  final bool determinate;
  final double? fraction;
  final String body;
  final bool complete;
  final bool terminal;
  final bool failed;
}
