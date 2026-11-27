import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/spatial_source_intake.dart';
import '../../providers/profile_provider.dart';
import '../../services/backend_api_service.dart';
import '../../services/spatial_upload_source.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/inline_loading.dart';
import 'artwork_spatial_review_screen.dart';

class ArtworkSpatialSourceScreen extends StatefulWidget {
  const ArtworkSpatialSourceScreen({required this.artworkId, super.key});

  final String artworkId;

  @override
  State<ArtworkSpatialSourceScreen> createState() =>
      _ArtworkSpatialSourceScreenState();
}

class _ArtworkSpatialSourceScreenState
    extends State<ArtworkSpatialSourceScreen> {
  final _api = BackendApiService();
  late final int _epoch = _api.authSessionEpoch;
  SpatialSourceIntake? _intake;
  SpatialReconstructionStatus? _status;
  Timer? _poll;
  final _progress = <String, SpatialSourceFile>{};
  bool _accepted = false;
  bool _busy = false;
  bool _paused = false;
  bool _transferring = false;
  bool _failed = false;
  bool _overLimit = false;

  bool get _activeSession => mounted && _epoch == _api.authSessionEpoch;
  String get _artwork => widget.artworkId;
  SpatialReconstruction? get _attempt => _status?.reconstruction;
  bool get _locked => _attempt?.active == true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  // An attempt runs for minutes to hours on another Node; follow it while it is active.
  void _schedulePoll() {
    _poll?.cancel();
    if (_locked && _activeSession) {
      _poll = Timer(const Duration(seconds: 10), _refresh);
    }
  }

  Future<void> _refresh() async {
    if (!_activeSession) return;
    setState(() => _busy = true);
    try {
      final intake = await _api.getSpatialSourceIntake(_artwork);
      final status =
          intake == null ? null : await _api.getSpatialReconstruction(_artwork);
      if (!_activeSession) return;
      setState(() {
        _intake = intake;
        _status = status;
        _failed = false;
        _accepted = intake?.workspaceId != null;
        _progress
          ..clear()
          ..addEntries((intake?.files ?? const [])
              .map((file) => MapEntry(file.id, file)));
      });
    } catch (_) {
      if (_activeSession) setState(() => _failed = true);
    } finally {
      if (_activeSession) {
        setState(() => _busy = false);
        _schedulePoll();
      }
    }
  }

  Future<void> _startReconstruction() async {
    final intake = _intake;
    final workspaceId = intake?.workspaceId;
    final revision = intake?.revision;
    if (!_activeSession || _busy || workspaceId == null || revision == null) {
      return;
    }
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await _api.startSpatialReconstruction(_artwork, workspaceId, revision);
    } catch (_) {
      if (_activeSession) setState(() => _failed = true);
    } finally {
      if (_activeSession) await _refresh();
    }
  }

  Future<void> _cancelReconstruction() async {
    final attempt = _attempt;
    if (!_activeSession || _busy || attempt == null) return;
    setState(() => _busy = true);
    try {
      await _api.cancelSpatialReconstruction(_artwork, attempt.id);
    } catch (_) {
      if (_activeSession) setState(() => _failed = true);
    } finally {
      if (_activeSession) await _refresh();
    }
  }

  Future<void> _openCandidate() async {
    final attempt = _attempt;
    if (!_activeSession || _busy || attempt == null) return;
    try {
      final draft =
          await _api.getSpatialReconstructionCandidate(_artwork, attempt.id);
      if (!mounted || !_activeSession) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ArtworkSpatialReviewScreen(draft: draft)));
    } catch (_) {
      if (_activeSession) setState(() => _failed = true);
    }
  }

  String _statusText(AppLocalizations l10n, SpatialReconstruction attempt) {
    if (attempt.cancelRequested && attempt.active) {
      return l10n.spatialReconstructionCancelling;
    }
    return switch (attempt.state) {
      'queued' => l10n.spatialReconstructionQueued,
      'preparing' => l10n.spatialReconstructionPreparing,
      'waiting_for_node' => l10n.spatialReconstructionWaiting,
      'processing' => l10n.spatialReconstructionProcessing,
      'importing' => l10n.spatialReconstructionImporting,
      'ready' => l10n.spatialReconstructionReady,
      'needs_more_views' => l10n.spatialReconstructionNeedsViews(
          attempt.usableViews ?? 0, attempt.requiredViews ?? 24),
      'cancelled' => l10n.spatialReconstructionCancelled,
      _ => l10n.spatialReconstructionFailed,
    };
  }

  List<Widget> _reconstructionSection(
      AppLocalizations l10n, List<SpatialSourceFile> files) {
    final status = _status;
    if (status == null) return const [];
    if (!status.remoteProcessingEnabled && !_locked) {
      return [Text(l10n.spatialSourceProcessingPaused)];
    }
    final attempt = _attempt;
    final ready = files.isNotEmpty &&
        files.every((file) => file.ready) &&
        _intake?.workspaceId != null;
    final retry = attempt != null && !attempt.active;
    final canStart =
        status.remoteProcessingEnabled && (attempt == null || retry);
    final running = attempt != null && attempt.active;
    return [
      if (attempt != null)
        Semantics(liveRegion: true, child: Text(_statusText(l10n, attempt))),
      if (running && !attempt.cancelRequested) const InlineLoading(height: 4),
      if (canStart) Text(l10n.spatialReconstructionFree),
      const SizedBox(height: KubusSpacing.sm),
      Wrap(spacing: KubusSpacing.sm, runSpacing: KubusSpacing.sm, children: [
        if (canStart)
          FilledButton.icon(
              onPressed: ready && !_busy && !_transferring
                  ? _startReconstruction
                  : null,
              icon: const Icon(Icons.view_in_ar_outlined),
              label: Text(attempt?.state == 'needs_more_views'
                  ? l10n.spatialReconstructionAddViews
                  : attempt == null || attempt.state == 'ready'
                      ? l10n.spatialReconstructionStart
                      : l10n.commonRetry)),
        if (running && !attempt.cancelRequested)
          OutlinedButton(
              onPressed: _busy ? null : _cancelReconstruction,
              child: Text(l10n.spatialReconstructionCancel)),
        if (attempt?.state == 'ready' && attempt?.candidateDraftId != null)
          FilledButton.tonal(
              onPressed: _busy ? null : _openCandidate,
              child: Text(l10n.spatialReconstructionOpen)),
      ]),
      if (_locked) Text(l10n.spatialSourceLocked),
      Text(l10n.spatialSourceRetention),
    ];
  }

  // Usable-view counts from the latest attempt, so the artist can see what to reshoot.
  String _fileFeedback(AppLocalizations l10n, SpatialSourceFile file) {
    final feedback = _attempt?.inputs[file.id];
    if (feedback == null) return l10n.spatialSourceVerified;
    if (!feedback.usable) return l10n.spatialSourceNotUsable;
    return l10n.spatialSourceUsableViews(feedback.usableViews ?? 0);
  }

  Future<Uint8List> _read(
      SpatialUploadSource source, int offset, int chunkSize) async {
    if (!_activeSession || _paused) throw StateError('Source upload paused');
    final end = math.min(source.size, offset + chunkSize);
    final bytes = await source.read(offset, end);
    if (!_activeSession || _paused || bytes.length != end - offset) {
      throw StateError('Source upload interrupted');
    }
    return bytes;
  }

  Stream<List<int>> _digestInput(
      SpatialUploadSource source, int chunkSize) async* {
    for (var offset = 0; offset < source.size; offset += chunkSize) {
      yield await _read(source, offset, chunkSize);
    }
  }

  Future<void> _choose() async {
    final intake = _intake;
    if (!_activeSession || _busy || !_accepted || intake == null) return;
    setState(() {
      _busy = true;
      _paused = _failed = _overLimit = false;
    });
    try {
      final files = await pickSpatialSourceMedia();
      if (!_activeSession || files.isEmpty) return;
      if (files.length > intake.maxFiles ||
          files.any((file) => file.size <= 0) ||
          files.fold<int>(0, (total, file) => total + file.size) >
              intake.maxBytes) {
        setState(() => _overLimit = true);
        return;
      }
      final workspace = intake.workspaceId ??
          await _api.startSpatialSourceWorkspace(_artwork);
      if (!_activeSession) return;
      setState(() => _transferring = true);
      for (final source in files) {
        if (!_activeSession || _paused) break;
        final format = source.format == 'jpg' ? 'jpeg' : source.format;
        final sha = (await crypto.sha256
                .bind(_digestInput(source, intake.chunkSize))
                .first)
            .toString();
        if (!_activeSession || _paused) break;
        var file = await _api.stageSpatialSourceFile(_artwork, workspace,
            fileName: source.name,
            size: source.size,
            format: format,
            sha256: sha);
        if (!_activeSession || _paused) break;
        if (file.sha256 != sha ||
            file.size != source.size ||
            file.received < 0 ||
            file.received > file.size) {
          throw const FormatException('Unexpected spatial source upload');
        }
        setState(() => _progress[file.id] = file);
        while (!file.ready && _activeSession && !_paused) {
          final bytes = await _read(source, file.received, intake.chunkSize);
          file = await _api.appendSpatialSourceFile(
              _artwork, workspace, file, bytes);
          if (_activeSession) setState(() => _progress[file.id] = file);
        }
      }
    } catch (_) {
      if (_activeSession && !_paused) setState(() => _failed = true);
    } finally {
      if (_activeSession) {
        setState(() => _transferring = false);
        await _refresh();
      }
    }
  }

  Future<void> _delete({SpatialSourceFile? file}) async {
    final workspaceId = _intake?.workspaceId;
    if (!_activeSession || _busy || workspaceId == null) return;
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.spatialSourceDelete),
        content: Text(file?.name ?? l10n.spatialSourceDeleteConfirmation),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.spatialSourceDelete)),
        ],
      ),
    );
    if (confirm != true || !_activeSession) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await _api.deleteSpatialSourceWorkspace(_artwork, workspaceId,
          fileId: file?.id);
    } catch (_) {
      if (_activeSession) setState(() => _failed = true);
    } finally {
      if (_activeSession) await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ProfileProvider?>();
    final l10n = AppLocalizations.of(context)!;
    final intake = _intake;
    final files = _progress.values.toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.spatialSourceTitle)),
      body: !_activeSession
          ? Center(child: Text(l10n.spatialDraftUploadUnavailable))
          : ListView(padding: const EdgeInsets.all(KubusSpacing.lg), children: [
              Text(l10n.spatialSourceFormats),
              const SizedBox(height: KubusSpacing.sm),
              ..._reconstructionSection(l10n, files),
              const SizedBox(height: KubusSpacing.md),
              if (intake != null && intake.workspaceId == null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _accepted,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _accepted = value == true),
                  title: Text(l10n.spatialSourceProviderDisclosure),
                ),
              if (_busy) const InlineLoading(height: 4),
              if (_failed || _overLimit)
                Semantics(
                    liveRegion: true,
                    child: Text(_overLimit
                        ? l10n.spatialSourceTooLarge
                        : l10n.spatialDraftUploadFailed)),
              Wrap(
                  spacing: KubusSpacing.sm,
                  runSpacing: KubusSpacing.sm,
                  children: [
                    if (intake != null)
                      FilledButton.icon(
                          onPressed:
                              _accepted && !_busy && !_locked ? _choose : null,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: Text(l10n.spatialSourceChoose)),
                    if (_transferring)
                      OutlinedButton(
                          onPressed: _paused
                              ? null
                              : () => setState(() => _paused = true),
                          child: Text(l10n.spatialDraftUploadPause)),
                    if (intake?.workspaceId != null)
                      TextButton(
                          onPressed: _busy || _locked ? null : _delete,
                          child: Text(l10n.spatialSourceDelete)),
                    if (intake == null && !_busy)
                      TextButton(
                          onPressed: _refresh, child: Text(l10n.commonRetry)),
                  ]),
              for (final file in files)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(file.name),
                  subtitle: !file.ready
                      ? InlineLoading(
                          height: 4,
                          progress: file.received / file.size,
                          animate: false)
                      : Text(_fileFeedback(l10n, file)),
                  trailing: IconButton(
                      tooltip: l10n.spatialSourceDeleteFile,
                      icon: const Icon(Icons.delete_outline),
                      onPressed:
                          _busy || _locked ? null : () => _delete(file: file)),
                ),
            ]),
    );
  }
}
