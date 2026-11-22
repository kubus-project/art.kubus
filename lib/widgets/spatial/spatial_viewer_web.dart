import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../l10n/app_localizations.dart';
import '../../models/kubus_node_models.dart';
import '../../services/kubus_node_service.dart';
import '../../services/spatial_web_delivery.dart';
import '../../services/spatial_web_load_session.dart';
import '../../utils/node_state_presentation.dart';
import '../inline_loading.dart';

/// Flutter web splat viewer.
///
/// The bundled Spark viewer (`assets/spatial_viewer`) runs in a same-origin
/// iframe whose page carries a closed CSP (`default-src 'none'`, scripts only
/// from `'self'`). The iframe is not a security boundary: `allow-same-origin`
/// is required for the postMessage origin check, so a script that escaped the
/// page would share the app's origin. What keeps the risk small is that the
/// page only runs this app's own bundle, parses the splat bytes in Spark's WASM
/// (never executes them), and is handed no credential: the host sends URLs, a
/// file type and a transform, nothing else.
///
/// This widget only chooses the bytes and relays a few messages. Bytes come
/// from the one route the backend serves for published spatial variants
/// (`/api/upload/file/<cid>`), which is the publication gate; there is no
/// public-gateway fallback, and never a LAN node, so a secure page cannot issue
/// mixed content. A tier that fails falls back to the next default tier. The
/// archive tier is never the default; the visitor asks for it, and is asked to
/// confirm when it is large.
Widget buildSpatialViewer({
  required BuildContext context,
  required SpatialContent content,
  required KubusNodeService nodeService,
  String? posterUrl,
}) =>
    WebSpatialViewer(content: content, posterUrl: posterUrl);

class WebSpatialViewer extends StatefulWidget {
  const WebSpatialViewer({required this.content, this.posterUrl, super.key});

  final SpatialContent content;
  final String? posterUrl;

  @override
  State<WebSpatialViewer> createState() => _WebSpatialViewerState();
}

/// One view factory for every viewer: a registered factory can never be
/// unregistered, so registering one per instance leaks. Each instance instead
/// puts its iframe in this map and passes its key as the creation parameter.
const String _viewType = 'kubus-spatial-viewer';
final Map<int, web.HTMLIFrameElement> _iframes = <int, web.HTMLIFrameElement>{};
int _viewerSequence = 0;
bool _factoryRegistered = false;

void _ensureViewFactory() {
  if (_factoryRegistered) return;
  _factoryRegistered = true;
  ui_web.platformViewRegistry.registerViewFactory(
    _viewType,
    (int viewId, {Object? params}) => _iframes[params as int]!,
  );
}

String _contentKey(SpatialContent content) => <String>[
      content.id,
      content.manifestCid ?? '',
      for (final v in content.variants) '${v.role}:${v.cid}:${v.format}',
    ].join('|');

class _WebSpatialViewerState extends State<WebSpatialViewer> {
  final int _viewKey = _viewerSequence++;
  late final web.HTMLIFrameElement _iframe;
  JSFunction? _messageListener;
  Timer? _timeout;
  late SpatialWebLoadSession _session;

  @override
  void initState() {
    super.initState();
    _ensureViewFactory();
    _iframe = web.HTMLIFrameElement()
      ..title = 'Interactive spatial archive'
      ..setAttribute('sandbox', 'allow-scripts allow-same-origin')
      ..setAttribute('referrerpolicy', 'no-referrer')
      ..setAttribute('allow', '')
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.visibility = 'hidden';
    _iframe.addEventListener(
      'load',
      ((web.Event _) {
        unawaited(_sendLoad());
      }).toJS,
    );
    _iframes[_viewKey] = _iframe;
    _messageListener = ((web.MessageEvent event) => _onMessage(event)).toJS;
    web.window.addEventListener('message', _messageListener);

    _session = SpatialWebLoadSession(widget.content);
    if (_session.variant != null) _startIframe();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _iframe.title = AppLocalizations.of(context)!.spatialArchiveTitle;
  }

  @override
  void didUpdateWidget(covariant WebSpatialViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_contentKey(oldWidget.content) == _contentKey(widget.content)) return;
    // Same widget slot, different piece (or a refreshed record): start over
    // instead of keeping the old piece on screen.
    _timeout?.cancel();
    _session = SpatialWebLoadSession(widget.content);
    _iframe.style.visibility = 'hidden';
    if (_session.variant != null) {
      _startIframe();
    } else {
      _iframe.src = 'about:blank';
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _iframes.remove(_viewKey);
    final listener = _messageListener;
    if (listener != null) {
      web.window.removeEventListener('message', listener);
    }
    _iframe.src = 'about:blank';
    super.dispose();
  }

  static String get _viewerUrl {
    final assetUrl =
        ui_web.assetManager.getAssetUrl('assets/spatial_viewer/index.html');
    return Uri.base.resolve(assetUrl).toString();
  }

  /// (Re)loads the viewer page for the session's current tier.
  void _startIframe() {
    _timeout?.cancel();
    _iframe.style.visibility = 'hidden';
    _iframe.src = _viewerUrl;
    _timeout = Timer(_session.timeout, _fail);
  }

  /// The current tier failed: try the next default tier, else show the failure.
  void _fail() {
    _timeout?.cancel();
    if (!mounted) return;
    final fallback = _session.onFailed();
    setState(() {});
    if (fallback) {
      _startIframe();
    } else if (_session.status == SpatialWebLoadStatus.failed) {
      _iframe.style.visibility = 'hidden';
    }
  }

  void _onMessage(web.MessageEvent event) {
    if (!mounted) return;
    if (event.origin != web.window.location.origin) return;
    final source = event.source;
    if (source == null || source != _iframe.contentWindow) return;
    final data = event.data.dartify();
    if (data is! Map) return;
    final message = data['kubusSpatialViewer'];
    if (message is! String) return;
    if (message == 'viewer-ready') {
      _session.onViewerReady();
      unawaited(_sendLoad());
    } else if (message == 'ready') {
      _timeout?.cancel();
      setState(_session.onLoaded);
      if (_session.status == SpatialWebLoadStatus.ready) {
        _iframe.style.visibility = 'visible';
      }
    } else if (message.startsWith('error:')) {
      _fail();
    }
  }

  Future<void> _sendLoad() async {
    final variant = _session.variant;
    if (variant == null || !_session.takeLoadCommand()) return;
    final attempt = _session.attempt;
    final plan = SpatialWebDelivery.plan(widget.content, variant);
    if (plan.urls.isEmpty) {
      _fail();
      return;
    }
    // Best effort and bounded: a record without a readable manifest transform
    // simply opens untransformed.
    final transform = await SpatialWebDelivery.fetchTransform(plan.manifestUrl);
    if (!mounted || attempt != _session.attempt) return;
    final label = AppLocalizations.of(context)!.spatialArchiveTitle;
    final command = <String, Object?>{
      'kubusSpatialViewerCommand': <String, Object?>{
        'type': 'load',
        'label': label,
        'urls': plan.urls,
        if (plan.fileType != null) 'fileType': plan.fileType,
        if (transform != null) 'transform': transform,
      },
    };
    _iframe.contentWindow
        ?.postMessage(command.jsify(), web.window.location.origin.toJS);
  }

  void _reset() => _iframe.contentWindow?.postMessage(
        <String, Object?>{
          'kubusSpatialViewerCommand': <String, Object?>{'type': 'reset'},
        }.jsify(),
        web.window.location.origin.toJS,
      );

  void _retry() {
    setState(_session.retry);
    if (_session.variant != null) _startIframe();
  }

  /// Starts the archive tier, after a confirmation when it is large.
  Future<void> _loadArchive() async {
    final archive = _session.archive;
    if (archive == null) return;
    if (SpatialWebDelivery.archiveNeedsConfirmation(archive)) {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.spatialArchiveConfirmTitle),
          content: Text(
            l10n.spatialArchiveConfirmBody(
              NodeStatePresentation.formatBytes(archive.sizeBytes),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonContinue),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(_session.loadArchive);
    _startIframe();
  }

  /// "Load archival quality", with the size when the record states one.
  String _archiveLabel(AppLocalizations l10n) {
    final bytes = _session.archive?.sizeBytes ?? 0;
    return bytes > 0
        ? l10n.spatialLoadArchiveQualityWithSize(
            NodeStatePresentation.formatBytes(bytes),
          )
        : l10n.spatialLoadArchiveQuality;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final status = _session.status;
    final overlay = switch (status) {
      SpatialWebLoadStatus.ready => null,
      SpatialWebLoadStatus.loading => _Notice(
          poster: widget.posterUrl,
          icon: null,
          message: l10n.spatialViewerLoading,
          busy: true,
        ),
      SpatialWebLoadStatus.awaitingArchiveConsent => _Notice(
          poster: widget.posterUrl,
          icon: Icons.view_in_ar_outlined,
          message:
              '${l10n.spatialArchiveTitle}\n${l10n.spatialArchiveConsentBody}',
          action: FilledButton.icon(
            onPressed: () => unawaited(_loadArchive()),
            icon: const Icon(Icons.threed_rotation_rounded),
            label: Text(_archiveLabel(l10n)),
          ),
        ),
      SpatialWebLoadStatus.failed => _Notice(
          poster: widget.posterUrl,
          icon: Icons.view_in_ar_outlined,
          message: l10n.spatialViewerUnavailable,
          action: TextButton(
            onPressed: _retry,
            child: Text(l10n.spatialViewerRetry),
          ),
        ),
    };
    return Semantics(
      container: true,
      label: l10n.spatialArchiveTitle,
      child: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: HtmlElementView(
                      viewType: _viewType,
                      creationParams: _viewKey,
                    ),
                  ),
                ),
                if (overlay != null) Positioned.fill(child: overlay),
              ],
            ),
          ),
          if (status == SpatialWebLoadStatus.ready)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.spatialViewerDragHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  if (_session.canOfferArchive)
                    TextButton(
                      onPressed: () => unawaited(_loadArchive()),
                      child: Text(_archiveLabel(l10n)),
                    ),
                  TextButton(
                    onPressed: _reset,
                    child: Text(l10n.spatialViewerReset),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Poster, loading and failure surface drawn over the (hidden) iframe.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.message,
    this.poster,
    this.icon,
    this.busy = false,
    this.action,
  });

  final String? poster;
  final IconData? icon;
  final String message;
  final bool busy;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (poster != null && poster!.isNotEmpty)
            Image.network(
              poster!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (busy)
                    const InlineLoading(height: 4, tileSize: 2)
                  else if (icon != null)
                    Icon(icon, size: 40, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  if (action != null) ...<Widget>[
                    const SizedBox(height: 12),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
