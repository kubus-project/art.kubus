import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../l10n/app_localizations.dart';
import '../../models/kubus_node_models.dart';
import '../../services/kubus_node_service.dart';
import '../../services/spatial_web_delivery.dart';
import '../inline_loading.dart';

/// Flutter web splat viewer.
///
/// The bundled Spark viewer (`assets/spatial_viewer`) runs in a sandboxed,
/// same-origin iframe. This widget only chooses the bytes and relays a few
/// messages: it never touches the splat itself. Bytes come from the routes the
/// backend really serves for published spatial variants
/// (`/api/upload/file/<cid>`, then public gateways), never from a LAN node, so
/// a secure page cannot issue mixed content. The archive tier is never the
/// default; the visitor asks for it.
Widget buildSpatialViewer({
  required BuildContext context,
  required SpatialContent content,
  required KubusNodeService nodeService,
  String? posterUrl,
}) =>
    WebSpatialViewer(content: content, posterUrl: posterUrl);

enum WebSpatialViewerStatus { awaitingArchiveConsent, loading, ready, failed }

class WebSpatialViewer extends StatefulWidget {
  const WebSpatialViewer({required this.content, this.posterUrl, super.key});

  final SpatialContent content;
  final String? posterUrl;

  @override
  State<WebSpatialViewer> createState() => _WebSpatialViewerState();
}

int _viewerSequence = 0;

/// How long a load may take before it is reported as failed.
const Duration _loadTimeout = Duration(seconds: 120);

class _WebSpatialViewerState extends State<WebSpatialViewer> {
  late final String _viewType = 'kubus-spatial-viewer-${_viewerSequence++}';
  late final web.HTMLIFrameElement _iframe;
  JSFunction? _messageListener;
  Timer? _timeout;

  WebSpatialViewerStatus _status = WebSpatialViewerStatus.loading;
  SpatialVariant? _variant;
  bool _viewerReady = false;
  bool _commandSent = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
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
    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int _) => _iframe);
    _messageListener = ((web.MessageEvent event) => _onMessage(event)).toJS;
    web.window.addEventListener('message', _messageListener);

    final initial = SpatialWebDelivery.defaultVariant(widget.content);
    if (initial != null) {
      _begin(initial);
    } else if (SpatialWebDelivery.archiveVariant(widget.content) != null) {
      _status = WebSpatialViewerStatus.awaitingArchiveConsent;
    } else {
      _status = WebSpatialViewerStatus.failed;
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
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

  void _begin(SpatialVariant variant) {
    _timeout?.cancel();
    _variant = variant;
    _viewerReady = false;
    _commandSent = false;
    _status = WebSpatialViewerStatus.loading;
    _iframe.style.visibility = 'hidden';
    _iframe.src = _viewerUrl;
    _timeout = Timer(_loadTimeout, () => _fail());
  }

  void _fail() {
    _timeout?.cancel();
    if (!mounted) return;
    setState(() => _status = WebSpatialViewerStatus.failed);
    _iframe.style.visibility = 'hidden';
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
      _viewerReady = true;
      unawaited(_sendLoad());
    } else if (message == 'ready') {
      _timeout?.cancel();
      setState(() => _status = WebSpatialViewerStatus.ready);
      _iframe.style.visibility = 'visible';
    } else if (message.startsWith('error:')) {
      _fail();
    }
  }

  Future<void> _sendLoad() async {
    final variant = _variant;
    if (variant == null || _commandSent || !_viewerReady) return;
    _commandSent = true;
    final attempt = _attempt;
    final plan = SpatialWebDelivery.plan(widget.content, variant);
    if (plan.urls.isEmpty) {
      _fail();
      return;
    }
    // Best effort and bounded: a record without a readable manifest transform
    // simply opens untransformed.
    final transform = await SpatialWebDelivery.fetchTransform(plan.manifestUrl);
    if (!mounted || attempt != _attempt) return;
    final command = <String, Object?>{
      'kubusSpatialViewerCommand': <String, Object?>{
        'type': 'load',
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
    _attempt++;
    final variant =
        _variant ?? SpatialWebDelivery.defaultVariant(widget.content);
    if (variant == null) return;
    setState(() => _begin(variant));
  }

  void _loadArchive() {
    final archive = SpatialWebDelivery.archiveVariant(widget.content);
    if (archive == null) return;
    _attempt++;
    setState(() => _begin(archive));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final archive = SpatialWebDelivery.archiveVariant(widget.content);
    final canOfferArchive = archive != null &&
        _variant?.role != 'spatial_archive' &&
        _status == WebSpatialViewerStatus.ready;
    final overlay = switch (_status) {
      WebSpatialViewerStatus.ready => null,
      WebSpatialViewerStatus.loading => _Notice(
          poster: widget.posterUrl,
          icon: null,
          message: l10n.spatialViewerLoading,
          busy: true,
        ),
      WebSpatialViewerStatus.awaitingArchiveConsent => _Notice(
          poster: widget.posterUrl,
          icon: Icons.view_in_ar_outlined,
          message: l10n.spatialArchiveTitle,
          action: FilledButton.icon(
            onPressed: _loadArchive,
            icon: const Icon(Icons.threed_rotation_rounded),
            label: Text(l10n.spatialLoadArchiveQuality),
          ),
        ),
      WebSpatialViewerStatus.failed => _Notice(
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
                    child: HtmlElementView(viewType: _viewType),
                  ),
                ),
                if (overlay != null) Positioned.fill(child: overlay),
              ],
            ),
          ),
          if (_status == WebSpatialViewerStatus.ready)
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
                  if (canOfferArchive)
                    TextButton(
                      onPressed: _loadArchive,
                      child: Text(l10n.spatialLoadArchiveQuality),
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
