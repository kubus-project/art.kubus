import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/kubus_node_models.dart';
import '../../models/spatial_upload_draft.dart';
import '../../providers/kubus_node_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/backend_api_service.dart';
import '../../services/kubus_node_service.dart';
import '../../services/spatial_device_class.dart';
import '../../services/spatial_web_delivery.dart';
import '../../utils/design_tokens.dart';
import '../../utils/node_state_presentation.dart';
import '../../widgets/inline_loading.dart';
import '../../widgets/spatial/spatial_viewer.dart';

class ArtworkSpatialReviewScreen extends StatefulWidget {
  const ArtworkSpatialReviewScreen({
    required this.draft,
    this.posterUrl,
    @visibleForTesting this.viewerBuilder,
    super.key,
  });

  final SpatialUploadDraft draft;

  /// The artwork's poster, shown while the preview loads and when it cannot.
  final String? posterUrl;

  /// Replaces the spatial viewer (widget tests only).
  final Widget Function(
    SpatialContent content,
    KubusNodeService nodeService,
    Future<Uint8List> Function() privateBytes,
    String? posterUrl,
  )? viewerBuilder;

  @override
  State<ArtworkSpatialReviewScreen> createState() =>
      _ArtworkSpatialReviewScreenState();
}

class _ArtworkSpatialReviewScreenState
    extends State<ArtworkSpatialReviewScreen> {
  final _api = BackendApiService();
  final _attribution = TextEditingController();
  final _summary = TextEditingController();
  final _document = TextEditingController();
  final _placement = TextEditingController();
  final _form = GlobalKey<FormState>();
  late final int _epoch = _api.authSessionEpoch;
  Map<String, dynamic>? _details;
  String? _markerId;
  DateTime? _captureDate;
  bool _confirmed = false;
  bool _showPreview = false;
  bool _busy = false;
  bool _failed = false;
  bool _previewFailed = false;

  /// The artist asked for the full-quality preview on a constrained device.
  bool _fullRequested = false;
  late final bool _constrained = SpatialDeviceClass.constrained;

  bool get _inSession => mounted && _api.authSessionEpoch == _epoch;
  SpatialUploadDraft get _draft => widget.draft;

  /// The companion a constrained device previews first, when the candidate
  /// has a complete one.
  SpatialUploadDraft? get _lightweight {
    final light = _draft.lightweight;
    return light != null && light.ready ? light : null;
  }

  bool get _previewIsLightweight =>
      _constrained && !_fullRequested && _lightweight != null;
  SpatialUploadDraft get _previewDraft =>
      _previewIsLightweight ? _lightweight! : _draft;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _attribution.dispose();
    _summary.dispose();
    _document.dispose();
    _placement.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!_inSession) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final details = await _api.getSpatialDraftReview(_draft);
      if (!_inSession) return;
      final prior = details['submission'] as Map<String, dynamic>?;
      final markers = (details['markers'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _details = details;
        _markerId = prior?['markerId'] as String? ??
            (markers.length == 1 ? markers.single['id'] as String : null);
        _captureDate =
            DateTime.tryParse(prior?['capturedAt'] as String? ?? '')?.toLocal();
        _attribution.text = prior?['capturedBy'] as String? ?? '';
      });
    } catch (_) {
      if (_inSession) setState(() => _failed = true);
    } finally {
      if (_inSession) setState(() => _busy = false);
    }
  }

  Future<Uint8List> _preview() async {
    if (!_inSession) throw StateError('Spatial preview session changed');
    final lightweight = _previewIsLightweight;
    final shown = _previewDraft;
    try {
      final bytes =
          await _api.getSpatialDraftPreview(_draft, lightweight: lightweight);
      if (!_inSession ||
          crypto.sha256.convert(bytes).toString() != shown.sha256) {
        throw StateError('Spatial preview could not be verified');
      }
      if (_previewFailed && mounted) setState(() => _previewFailed = false);
      return bytes;
    } catch (_) {
      if (mounted) setState(() => _previewFailed = true);
      rethrow;
    }
  }

  void _loadFullPreview() => setState(() {
        _fullRequested = true;
        _previewFailed = false;
      });

  Map<String, dynamic>? _newPlacement(String value) {
    try {
      final decoded = jsonDecode(value);
      return SpatialWebDelivery.decomposePlacementMatrix(
          decoded is Map ? decoded['matrix'] : decoded);
    } on FormatException {
      return null;
    }
  }

  Future<void> _submit() async {
    final details = _details;
    final capture = _captureDate;
    if (!_inSession ||
        _busy ||
        !_confirmed ||
        details == null ||
        _markerId == null ||
        capture == null ||
        !(_form.currentState?.validate() ?? false)) {
      return;
    }
    final grant = details['grant'] as Map<String, dynamic>;
    final prior = details['submission'] as Map<String, dynamic>?;
    final transform = _newPlacement(_placement.text) ?? prior?['transform'];
    final scopes = details['requiredScopes'] as Map<String, dynamic>;
    final owner = details['ownerAccountId'] as String;
    final holders =
        (details['attributions'] as List).cast<Map<String, dynamic>>();
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await _api.submitSpatialDraft(_draft, {
        'markerId': _markerId,
        'capturedAt': capture.toUtc().toIso8601String(),
        if (_attribution.text.trim().isNotEmpty)
          'capturedBy': _attribution.text.trim(),
        if (transform != null) 'transform': transform,
        if (prior != null) 'expectedSubmissionId': prior['id'],
        if (prior != null) 'expectedRevision': prior['revision'],
        'validFrom': grant['validFrom'],
        'validUntil': grant['validUntil'],
        'scopes': scopes,
        'claims': [
          for (final layer in [
            'underlying_work',
            'source_media',
            'spatial_representation'
          ])
            {
              'layer': layer,
              'basis': 'rights_holder_permission',
              'scopes': scopes,
              'holderRefs': [
                owner,
                if (layer == 'underlying_work')
                  for (final holder in holders) holder['id']
              ],
              'assessment': _summary.text.trim(),
            },
        ],
        'privateEvidence': {
          'summary': _summary.text.trim(),
          'documentReference': _document.text.trim()
        },
      });
      if (_inSession) await _refresh();
    } catch (_) {
      if (_inSession) {
        setState(() {
          _failed = true;
          _busy = false;
        });
      }
    }
  }

  Future<void> _newCandidate(Map<String, dynamic> prior) async {
    if (!_inSession || _busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await _api.retireSpatialDraft(
          _draft, prior['id'] as String, prior['revision'] as int);
      if (mounted && _inSession) Navigator.of(context).pop();
    } catch (_) {
      if (_inSession) {
        setState(() {
          _failed = true;
          _busy = false;
        });
      }
    }
  }

  List<Widget> _previewSection(
    AppLocalizations l10n,
    KubusNodeProvider node,
    Map<String, dynamic>? prior,
  ) {
    final shown = _previewDraft;
    final light = _previewIsLightweight;
    final content = SpatialContent(
      id: shown.id,
      type: 'gaussianSplat',
      artworkId: shown.artworkId,
      captureId: shown.id,
      capturedAt: _captureDate ?? DateTime.now(),
      transform: _newPlacement(_placement.text) ??
          (prior?['transform'] as Map<String, dynamic>?),
      variants: [
        SpatialVariant(
            role: 'spatial_preview',
            cid: shown.sha256,
            sizeBytes: shown.sizeBytes,
            mimeType: 'application/octet-stream',
            format: shown.format,
            storageClass: 'hot')
      ],
    );
    final builder = widget.viewerBuilder;
    final viewerKey =
        '${prior?['id'] ?? _draft.id}-${light ? 'light' : 'full'}';
    return [
      if (light)
        Padding(
          padding: const EdgeInsets.only(top: KubusSpacing.sm),
          child: Semantics(
              liveRegion: true,
              child: Text(l10n.spatialReviewLightweightNotice)),
        ),
      SizedBox(
          height: 370,
          child: builder != null
              ? KeyedSubtree(
                  key: ValueKey(viewerKey),
                  child: builder(
                      content, node.service, _preview, widget.posterUrl))
              : SpatialViewer(
                  key: ValueKey(viewerKey),
                  nodeService: node.service,
                  privateBytes: _preview,
                  posterUrl: widget.posterUrl,
                  content: content,
                )),
      if (_previewFailed)
        Semantics(
          liveRegion: true,
          child: Text(l10n.spatialReviewPreviewUnavailable,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      if (light)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Semantics(
            button: true,
            label: l10n.spatialLoadFullQualitySemantics,
            excludeSemantics: true,
            child: OutlinedButton.icon(
              onPressed: _loadFullPreview,
              icon: const Icon(Icons.threed_rotation_rounded),
              label: Text(l10n.spatialLoadFullQualityWithSize(
                  NodeStatePresentation.formatBytes(_draft.sizeBytes))),
            ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ProfileProvider?>();
    final l10n = AppLocalizations.of(context)!;
    final details = _details;
    final prior = details?['submission'] as Map<String, dynamic>?;
    final grant = details?['grant'] as Map<String, dynamic>?;
    final markers =
        (details?['markers'] as List? ?? const []).cast<Map<String, dynamic>>();
    final state = prior?['state'];
    final status = switch (prior?['deliveryState'] ?? state) {
      'publishing' => l10n.spatialReviewPublishing,
      'failed' => l10n.spatialReviewDeliveryFailed,
      'published' => l10n.spatialReviewPublished,
      'pending_verification' => l10n.spatialReviewPending,
      'information_required' => l10n.spatialReviewChanges,
      null => null,
      _ => l10n.spatialReviewHeld,
    };
    final editable =
        details != null && (prior == null || state == 'information_required');
    final node = context.read<KubusNodeProvider?>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.spatialReviewTitle)),
      body: !_inSession
          ? Center(child: Text(l10n.spatialDraftUploadUnavailable))
          : ListView(
              padding: const EdgeInsets.all(KubusSpacing.lg),
              children: [
                if (details?['artworkTitle'] case final String title)
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                Text(_draft.fileName),
                if (status != null)
                  Semantics(liveRegion: true, child: Text(status)),
                if (prior?['decisionNote'] case final String note
                    when note.isNotEmpty)
                  Text(note),
                if (_busy) const InlineLoading(height: 4),
                if (_failed)
                  Text(l10n.spatialReviewFailed,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                Wrap(spacing: KubusSpacing.sm, children: [
                  if (node != null)
                    OutlinedButton(
                        onPressed: () => setState(() {
                              _showPreview = !_showPreview;
                              _previewFailed = false;
                            }),
                        child: Text(_showPreview
                            ? l10n.spatialReviewClosePreview
                            : l10n.spatialReviewPreview)),
                  TextButton(
                      onPressed: _busy ? null : _refresh,
                      child: Text(l10n.spatialReviewRefresh)),
                ]),
                if (prior != null &&
                    (state == 'information_required' ||
                        state == 'withdrawn' ||
                        prior['deliveryState'] == 'published' ||
                        prior['deliveryState'] == 'held'))
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _newCandidate(prior),
                      child: Text(l10n.spatialReviewNewCandidate),
                    ),
                  ),
                if (_showPreview && node != null)
                  ..._previewSection(l10n, node, prior),
                if (editable && grant?['status'] != 'active')
                  Text(l10n.spatialReviewGrantRequired),
                if (editable && grant?['status'] == 'active')
                  Form(
                      key: _form,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: KubusSpacing.md),
                            DropdownButtonFormField<String>(
                              key: ValueKey(_markerId),
                              initialValue: markers.any(
                                      (marker) => marker['id'] == _markerId)
                                  ? _markerId
                                  : null,
                              decoration: InputDecoration(
                                  labelText: l10n.spatialReviewMarker),
                              isExpanded: true,
                              items: [
                                for (final marker in markers)
                                  DropdownMenuItem(
                                      value: marker['id'] as String,
                                      child: Text((marker['name'] as String?) ??
                                          marker['id'] as String))
                              ],
                              onChanged: _busy
                                  ? null
                                  : (value) =>
                                      setState(() => _markerId = value),
                            ),
                            TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      final now = DateTime.now();
                                      final date = await showDatePicker(
                                          context: context,
                                          initialDate: _captureDate ?? now,
                                          firstDate: DateTime(1900),
                                          lastDate: now);
                                      if (_inSession && date != null) {
                                        setState(() => _captureDate = date);
                                      }
                                    },
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text(_captureDate == null
                                  ? l10n.spatialReviewDate
                                  : MaterialLocalizations.of(context)
                                      .formatMediumDate(_captureDate!)),
                            ),
                            TextFormField(
                                controller: _attribution,
                                maxLength: 160,
                                decoration: InputDecoration(
                                    labelText: l10n.spatialReviewAttribution)),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(l10n.spatialReviewPlacement),
                              children: [
                                TextFormField(
                                  controller: _placement,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                      helperText:
                                          l10n.spatialReviewPlacementHelp),
                                  validator: (value) => value == null ||
                                          value.trim().isEmpty ||
                                          _newPlacement(value) != null
                                      ? null
                                      : l10n.spatialReviewPlacementInvalid,
                                ),
                              ],
                            ),
                            TextFormField(
                                controller: _summary,
                                maxLength: 2000,
                                maxLines: 3,
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? l10n.spatialReviewRequiredField
                                        : null,
                                decoration: InputDecoration(
                                    labelText: l10n.spatialReviewEvidence)),
                            TextFormField(
                                controller: _document,
                                maxLength: 128,
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? l10n.spatialReviewRequiredField
                                        : null,
                                decoration: InputDecoration(
                                    labelText: l10n.spatialReviewDocument)),
                            CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _confirmed,
                                onChanged: _busy
                                    ? null
                                    : (value) => setState(
                                        () => _confirmed = value == true),
                                title: Text(l10n.spatialReviewConfirm)),
                            FilledButton(
                              onPressed: _busy ||
                                      !_confirmed ||
                                      _markerId == null ||
                                      _captureDate == null
                                  ? null
                                  : _submit,
                              child: Text(l10n.spatialReviewSubmit),
                            ),
                          ])),
              ],
            ),
    );
  }
}
