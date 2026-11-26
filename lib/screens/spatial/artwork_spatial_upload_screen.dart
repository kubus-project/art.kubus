import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/spatial_upload_draft.dart';
import '../../providers/profile_provider.dart';
import '../../services/backend_api_service.dart';
import '../../services/spatial_upload_source.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/detail/detail_shell_components.dart';
import '../../widgets/inline_loading.dart';

class ArtworkSpatialUploadScreen extends StatefulWidget {
  const ArtworkSpatialUploadScreen({
    required this.artworkId,
    this.pickFile = pickSpatialUploadFile,
    super.key,
  });

  final String artworkId;
  @visibleForTesting
  final Future<SpatialUploadSource?> Function() pickFile;

  @override
  State<ArtworkSpatialUploadScreen> createState() =>
      _ArtworkSpatialUploadScreenState();
}

enum _UploadPhase { loading, idle, choosing, checking, sending, removing }

enum _UploadProblem {
  unavailable,
  failed,
  unsupported,
  tooLarge,
  differentFile
}

class _UploadPaused implements Exception {
  const _UploadPaused();
}

class _ArtworkSpatialUploadScreenState
    extends State<ArtworkSpatialUploadScreen> {
  final _api = BackendApiService();
  late final int _sessionEpoch;
  bool get _currentSession => mounted && _api.authSessionEpoch == _sessionEpoch;
  SpatialUploadDraft? _draft;
  _UploadPhase _phase = _UploadPhase.loading;
  _UploadProblem? _problem;
  bool _pauseRequested = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _sessionEpoch = _api.authSessionEpoch;
    _load();
  }

  Future<void> _load() async {
    if (!_currentSession) return;
    setState(() {
      _phase = _UploadPhase.loading;
      _problem = null;
    });
    try {
      final draft = await _api.getSpatialUploadDraft(widget.artworkId);
      if (!_currentSession) return;
      if (draft != null && draft.artworkId != widget.artworkId) {
        throw const FormatException('Unexpected spatial draft identity');
      }
      setState(() {
        _draft = draft;
        _loaded = true;
      });
    } on BackendApiRequestException catch (error) {
      _setProblem(error.statusCode == 404
          ? _UploadProblem.unavailable
          : _UploadProblem.failed);
    } catch (_) {
      _setProblem(_UploadProblem.failed);
    } finally {
      if (mounted) setState(() => _phase = _UploadPhase.idle);
    }
  }

  void _setProblem(_UploadProblem problem) {
    if (mounted) setState(() => _problem = problem);
  }

  void _ensureRunning() {
    if (!_currentSession || _pauseRequested) throw const _UploadPaused();
  }

  Future<Uint8List> _read(
    SpatialUploadSource source,
    int offset,
    int chunkSize,
  ) async {
    _ensureRunning();
    final end = math.min(offset + chunkSize, source.size);
    final bytes = await source.read(offset, end);
    _ensureRunning();
    if (bytes.length != end - offset) {
      throw const FormatException('Unexpected local spatial asset size');
    }
    return bytes;
  }

  Stream<List<int>> _digestInput(SpatialUploadSource source) async* {
    const chunkSize = SpatialUploadDraft.maxChunkSizeBytes;
    for (var offset = 0; offset < source.size; offset += chunkSize) {
      yield await _read(source, offset, chunkSize);
    }
  }

  Future<void> _upload() async {
    if (!_currentSession) return;
    setState(() {
      _problem = null;
      _phase = _UploadPhase.choosing;
      _pauseRequested = false;
    });
    try {
      final source = await widget.pickFile();
      if (source == null || !_currentSession) return;
      if (source.size == 0 ||
          !SpatialUploadDraft.formats.contains(source.format)) {
        _setProblem(_UploadProblem.unsupported);
        return;
      }
      if (source.size > SpatialUploadDraft.maxSizeBytes) {
        _setProblem(_UploadProblem.tooLarge);
        return;
      }
      if (_draft case final existing?) {
        if (existing.sizeBytes != source.size ||
            existing.fileName != source.name ||
            existing.format != source.format) {
          _setProblem(_UploadProblem.differentFile);
          return;
        }
      }
      setState(() => _phase = _UploadPhase.checking);
      final digest =
          (await crypto.sha256.bind(_digestInput(source)).first).toString();
      _ensureRunning();
      if (_draft case final existing?) {
        if (existing.sha256 != digest) {
          _setProblem(_UploadProblem.differentFile);
          return;
        }
      }

      var draft = await _api.createSpatialUploadDraft(
        artworkId: widget.artworkId,
        fileName: source.name,
        format: source.format,
        sizeBytes: source.size,
        sha256: digest,
      );
      if (!_currentSession) return;
      if (draft.artworkId != widget.artworkId ||
          draft.sha256 != digest ||
          draft.sizeBytes != source.size) {
        throw const FormatException('Unexpected spatial draft identity');
      }
      setState(() {
        _draft = draft;
        _phase = _UploadPhase.sending;
      });
      while (!draft.ready && draft.receivedBytes < source.size) {
        final bytes =
            await _read(source, draft.receivedBytes, draft.chunkSizeBytes);
        draft = await _api.uploadSpatialDraftChunk(draft: draft, bytes: bytes);
        if (!_currentSession) return;
        setState(() => _draft = draft);
      }
      if (!draft.ready) throw const FormatException('Spatial draft not ready');
    } on _UploadPaused {
      // A completed chunk remains part of the resumable private draft.
    } catch (_) {
      _setProblem(_UploadProblem.failed);
    } finally {
      if (mounted) setState(() => _phase = _UploadPhase.idle);
    }
  }

  Future<void> _remove() async {
    final draft = _draft;
    if (draft == null || !_currentSession) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.spatialDraftUploadRemoveTitle),
        content: Text(l10n.spatialDraftUploadRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonRemove),
          ),
        ],
      ),
    );
    if (!_currentSession || confirmed != true) return;
    setState(() => _phase = _UploadPhase.removing);
    try {
      await _api.deleteSpatialUploadDraft(draft);
      if (!_currentSession) return;
      setState(() {
        _draft = null;
        _problem = null;
      });
    } catch (_) {
      _setProblem(_UploadProblem.failed);
    } finally {
      if (mounted) setState(() => _phase = _UploadPhase.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    context.watch<ProfileProvider?>();
    if (!_currentSession) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.spatialDraftUploadTitle)),
        body: Center(child: Text(l10n.spatialDraftUploadUnavailable)),
      );
    }
    final draft = _draft;
    final busy = _phase != _UploadPhase.idle;
    final progress =
        draft == null ? null : draft.receivedBytes / draft.sizeBytes;
    final status = switch (_phase) {
      _UploadPhase.loading => l10n.spatialDraftUploadLoading,
      _UploadPhase.checking => l10n.spatialDraftUploadChecking,
      _UploadPhase.sending => l10n.spatialDraftUploadSending,
      _ => draft == null
          ? null
          : draft.ready
              ? l10n.spatialDraftUploadReady
              : l10n.spatialDraftUploadIncomplete,
    };
    final problem = switch (_problem) {
      _UploadProblem.unavailable => l10n.spatialDraftUploadUnavailable,
      _UploadProblem.failed => l10n.spatialDraftUploadFailed,
      _UploadProblem.unsupported => l10n.spatialDraftUploadUnsupported,
      _UploadProblem.tooLarge => l10n.spatialDraftUploadTooLarge,
      _UploadProblem.differentFile => l10n.spatialDraftUploadDifferentFile,
      null => null,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.spatialDraftUploadTitle)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(KubusSpacing.lg),
              children: [
                DetailCard(
                  padding: const EdgeInsets.all(KubusSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.spatialDraftUploadPrivateTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: KubusSpacing.sm),
                      Text(l10n.spatialDraftUploadIntro),
                      const SizedBox(height: KubusSpacing.sm),
                      Text(l10n.spatialDraftUploadFormats),
                      if (draft != null) ...[
                        const SizedBox(height: KubusSpacing.lg),
                        Text(draft.fileName,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: KubusSpacing.sm),
                        Semantics(
                          label: status,
                          value: '${(progress! * 100).floor()}%',
                          child: InlineLoading(
                              height: 4, progress: progress, animate: false),
                        ),
                      ],
                      if (status != null) ...[
                        const SizedBox(height: KubusSpacing.sm),
                        Semantics(liveRegion: true, child: Text(status)),
                      ],
                      if (problem != null) ...[
                        const SizedBox(height: KubusSpacing.sm),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            problem,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      ],
                      const SizedBox(height: KubusSpacing.lg),
                      Wrap(
                        spacing: KubusSpacing.sm,
                        runSpacing: KubusSpacing.sm,
                        children: [
                          if (_phase == _UploadPhase.checking ||
                              _phase == _UploadPhase.sending)
                            OutlinedButton(
                              onPressed: _pauseRequested
                                  ? null
                                  : () =>
                                      setState(() => _pauseRequested = true),
                              child: Text(l10n.spatialDraftUploadPause),
                            ),
                          if (_loaded && draft?.ready != true)
                            FilledButton.icon(
                              onPressed: busy ? null : _upload,
                              icon: const Icon(Icons.upload_file_outlined),
                              label: Text(draft == null
                                  ? l10n.spatialDraftUploadChoose
                                  : l10n.spatialDraftUploadResume),
                            ),
                          if (!_loaded && !busy)
                            OutlinedButton(
                              onPressed: busy ? null : _load,
                              child: Text(l10n.commonRetry),
                            ),
                          if (draft != null)
                            TextButton(
                              onPressed: busy ? null : _remove,
                              child: Text(l10n.spatialDraftUploadRemoveTitle),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
