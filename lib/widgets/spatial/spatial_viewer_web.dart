import 'dart:async';
import 'dart:typed_data';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../l10n/app_localizations.dart';
import '../../models/kubus_node_models.dart';
import '../../services/anonymous_fetch_client.dart';
import '../../services/kubus_node_service.dart';
import '../../services/spatial_web_delivery.dart';
import '../../services/spatial_device_class.dart';
import '../../services/spatial_web_load_session.dart';
import '../../utils/node_state_presentation.dart';
import '../inline_loading.dart';

/// Flutter web splat viewer.
///
/// The bundled Spark viewer (`assets/spatial_viewer`) runs in a same-origin
/// iframe whose page carries a closed CSP (`default-src 'none'`, scripts only
/// from `'self'`, `connect-src blob:`). The iframe is not a security boundary:
/// `allow-same-origin` is required for the postMessage origin check, so a script
/// that escaped the page would share the app's origin. What keeps the risk small
/// is that the page only runs this app's own bundle, parses the splat bytes in
/// Spark's WASM (never executes them), is handed no credential, and cannot
/// reach the network at all: this host downloads the bytes itself (anonymous,
/// no cookies, no referrer) and hands the page a `blob:` URL, the only thing
/// the page's `connect-src` allows.
///
/// This widget only chooses the bytes and relays a few messages. Bytes come
/// from the one route the backend serves for published spatial variants
/// (`/api/upload/file/<cid>`), which is the publication gate; there is no
/// public-gateway fallback, and never a LAN node, so a secure page cannot issue
/// mixed content. A tier that fails falls back to the next default tier. The
/// archive tier is never the default; the visitor asks for it, and is asked to
/// confirm when it is large (or of unknown size).
///
/// Inside a page that scrolls, the iframe is inert until the visitor taps
/// "Tap to interact". An iframe is its own document: wheel and touch events
/// that start on it never reach Flutter, so a live viewer would swallow page
/// scroll for any thumb or wheel that lands on it. Inert (`pointer-events:
/// none`), the Flutter overlay takes the gesture and the page scrolls; active,
/// the viewer takes every gesture until the visitor taps outside it, presses
/// Done, or presses Escape in it. Where no vertical scroller encloses the
/// viewer (the fullscreen dialog) it is interactive at once.
Widget buildSpatialViewer({
  required BuildContext context,
  required SpatialContent content,
  required KubusNodeService nodeService,
  String? posterUrl,
  VoidCallback? onEscape,
  Future<Uint8List> Function()? privateBytes,
}) =>
    WebSpatialViewer(
      content: content,
      posterUrl: posterUrl,
      onEscape: onEscape,
      privateBytes: privateBytes,
    );

class WebSpatialViewer extends StatefulWidget {
  const WebSpatialViewer({
    required this.content,
    this.posterUrl,
    this.onEscape,
    this.privateBytes,
    super.key,
  });

  final SpatialContent content;
  final String? posterUrl;

  /// Relayed Escape; see [SpatialViewer.onEscape].
  final VoidCallback? onEscape;
  final Future<Uint8List> Function()? privateBytes;

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
    (int viewId, {Object? params}) =>
        // A viewer disposed before Flutter created its platform view leaves no
        // iframe in the map; an empty one keeps the factory total.
        _iframes[params as int] ?? web.HTMLIFrameElement(),
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

  /// The download of the current attempt, and the `blob:` URL its bytes live
  /// behind. Both are released when the attempt ends, so a replaced attempt
  /// stops downloading and no object URL outlives its use.
  web.AbortController? _download;
  web.AbortController? _manifestDownload;
  String? _objectUrl;
  late SpatialWebLoadSession _session;

  /// A vertical scroller encloses the viewer, so the iframe starts inert.
  bool _pageScrolls = true;

  /// The visitor activated the viewer; it now takes every gesture.
  bool _interactive = false;

  /// A confirmation dialog for the archive is open (guards a double tap).
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _ensureViewFactory();
    _iframe = web.HTMLIFrameElement()
      ..title = 'Interactive spatial archive'
      // Defence in depth only: it stops popups, forms and top navigation, but
      // a same-origin frame can remove its own attribute, so the CSP and the
      // no-credential hand-over above are what bound the page.
      ..setAttribute('sandbox', 'allow-scripts allow-same-origin')
      ..setAttribute('referrerpolicy', 'no-referrer')
      ..setAttribute('allow', '')
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.pointerEvents = 'none'
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

    _session = SpatialWebLoadSession(
      widget.content,
      constrained: SpatialDeviceClass.constrained,
    );
    if (_session.variant != null) _startIframe();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _iframe.title = AppLocalizations.of(context)!.spatialArchiveTitle;
    _pageScrolls = Scrollable.maybeOf(context, axis: Axis.vertical) != null;
  }

  @override
  void didUpdateWidget(covariant WebSpatialViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_contentKey(oldWidget.content) == _contentKey(widget.content)) return;
    // Same widget slot, different piece (or a refreshed record): start over
    // instead of keeping the old piece on screen.
    _timeout?.cancel();
    _releaseBytes();
    // Attempt numbers continue across sessions: the iframe is reused, and a
    // message still in flight from the old page must not match attempt 1 again.
    _session = SpatialWebLoadSession(
      widget.content,
      attemptBase: _session.attempt,
      constrained: SpatialDeviceClass.constrained,
    );
    _interactive = false;
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
    _releaseBytes();
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

  /// (Re)loads the viewer page for the session's current tier. The attempt
  /// number is part of the URL, so the page echoes it in every message and a
  /// page that is being replaced can never answer for the next attempt.
  void _startIframe() {
    _timeout?.cancel();
    _releaseBytes();
    _interactive = false;
    _iframe.style.visibility = 'hidden';
    _iframe.src = Uri.parse(_viewerUrl).replace(
        queryParameters: <String, String>{
          'a': '${_session.attempt}'
        }).toString();
    _timeout = Timer(
        widget.privateBytes == null
            ? _session.timeout
            : const Duration(minutes: 2),
        _fail);
  }

  /// The current tier failed: try the next default tier, else show the failure.
  void _fail() {
    _timeout?.cancel();
    if (!mounted) return;
    _releaseBytes();
    final fallback = _session.onFailed();
    setState(() {});
    if (fallback) {
      _startIframe();
    } else if (_session.status == SpatialWebLoadStatus.failed ||
        _session.status == SpatialWebLoadStatus.awaitingConsent) {
      // Hidden and emptied: a stalled page must not keep its download running.
      _interactive = false;
      _iframe.style.visibility = 'hidden';
      _iframe.src = 'about:blank';
    }
  }

  void _setInteractive(bool value) {
    if (!mounted || _interactive == value) return;
    setState(() => _interactive = value);
    _send(value ? 'activate' : 'deactivate');
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
    // Only the page loaded for the current attempt may speak for it.
    if ('${data['attempt']}' != '${_session.attempt}') return;
    if (message == 'escape') {
      _setInteractive(false);
      // Escape pressed inside the iframe never reaches Flutter's key handling;
      // the host that owns the viewer decides what it means (if anything).
      widget.onEscape?.call();
    } else if (message == 'viewer-ready') {
      _session.onViewerReady();
      unawaited(_sendLoad());
    } else if (message == 'ready') {
      _timeout?.cancel();
      // The viewer has parsed the bytes; the object URL has done its job.
      _revokeObjectUrl();
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
    if (plan.urls.isEmpty && widget.privateBytes == null) {
      _fail();
      return;
    }
    // The page cannot reach the network (its CSP allows `blob:` only), so the
    // bytes are downloaded here and handed over as an object URL. Best effort
    // and bounded for the transform: a record without a readable manifest
    // transform simply opens untransformed.
    final download = web.AbortController();
    _download = download;
    final bytes = widget.privateBytes == null
        ? _downloadAsObjectUrl(plan.urls, download)
        : _privateObjectUrl(widget.privateBytes!, download);
    // The manifest read is anonymous in the same way as the bytes (no cookies,
    // no Authorization, no Referer) and is aborted with them.
    final manifest = web.AbortController();
    _manifestDownload = manifest;
    final manifestClient = AnonymousFetchClient(abort: manifest);
    final Map<String, dynamic>? transform;
    try {
      transform = widget.privateBytes != null
          ? widget.content.transform
          : await SpatialWebDelivery.fetchTransform(
              plan.manifestUrl,
              client: manifestClient,
            );
    } finally {
      manifestClient.close();
    }
    final objectUrl = await bytes;
    // Also stale when this attempt already ended without a fallback (the tier
    // timeout fired and the viewer is in the failed state): the attempt number
    // did not change, but _releaseBytes ran before this URL existed, so it
    // revoked nothing and the URL would outlive the widget's load.
    if (!mounted || !_session.isLiveAttempt(attempt)) {
      // A newer attempt, a finished one (or a dispose) already released its own
      // state; this one's object URL was created after that and is nobody's.
      if (objectUrl != null) web.URL.revokeObjectURL(objectUrl);
      return;
    }
    if (objectUrl == null) {
      _fail();
      return;
    }
    _objectUrl = objectUrl;
    final label = AppLocalizations.of(context)!.spatialArchiveTitle;
    final command = <String, Object?>{
      'kubusSpatialViewerCommand': <String, Object?>{
        'type': 'load',
        'label': label,
        'urls': <String>[objectUrl],
        if (plan.fileType != null) 'fileType': plan.fileType,
        if (transform != null) 'transform': transform,
      },
    };
    _iframe.contentWindow
        ?.postMessage(command.jsify(), web.window.location.origin.toJS);
  }

  /// Downloads the first route that answers into a Blob and returns its object
  /// URL, or null when none did (or the download was aborted). Anonymous and
  /// referrer-free: the same request the page used to make itself, minus the
  /// page's access to the network.
  Future<String?> _downloadAsObjectUrl(
    List<String> urls,
    web.AbortController download,
  ) async {
    for (final url in urls) {
      try {
        final response = await web.window
            .fetch(
              url.toJS,
              web.RequestInit(
                method: 'GET',
                credentials: 'omit',
                referrerPolicy: 'no-referrer',
                signal: download.signal,
              ),
            )
            .toDart;
        if (!response.ok) continue;
        final blob = await response.blob().toDart;
        if (download.signal.aborted) return null;
        return web.URL.createObjectURL(blob);
      } catch (_) {
        if (download.signal.aborted) return null;
      }
    }
    return null;
  }

  Future<String?> _privateObjectUrl(
    Future<Uint8List> Function() load,
    web.AbortController download,
  ) async {
    try {
      final bytes = await load();
      if (download.signal.aborted) return null;
      return web.URL.createObjectURL(web.Blob([bytes.toJS].toJS));
    } catch (_) {
      return null;
    }
  }

  void _revokeObjectUrl() {
    final url = _objectUrl;
    _objectUrl = null;
    if (url != null) web.URL.revokeObjectURL(url);
  }

  /// Stops the download of the current attempt and frees its bytes.
  void _releaseBytes() {
    _download?.abort();
    _download = null;
    _manifestDownload?.abort();
    _manifestDownload = null;
    _revokeObjectUrl();
  }

  void _send(String type) => _iframe.contentWindow?.postMessage(
        <String, Object?>{
          'kubusSpatialViewerCommand': <String, Object?>{'type': type},
        }.jsify(),
        web.window.location.origin.toJS,
      );

  void _reset() => _send('reset');

  void _retry() {
    setState(_session.retry);
    if (_session.variant != null) _startIframe();
  }

  /// Asks before a large download. Returns true when the visitor continues.
  Future<bool> _confirmLarge(SpatialVariant variant) async {
    final l10n = AppLocalizations.of(context)!;
    final archive = variant.role == 'spatial_archive';
    _confirming = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          archive
              ? l10n.spatialArchiveConfirmTitle
              : l10n.spatialFullConfirmTitle,
        ),
        content: Text(
          variant.sizeBytes > 0
              ? l10n.spatialArchiveConfirmBody(
                  NodeStatePresentation.formatBytes(variant.sizeBytes),
                )
              : l10n.spatialArchiveConfirmBodyUnknownSize,
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
    _confirming = false;
    return confirmed == true && mounted;
  }

  /// Starts the archive tier, after a confirmation when it is large.
  Future<void> _loadArchive() async {
    final archive = _session.archive;
    if (archive == null || _confirming) return;
    if (SpatialWebDelivery.archiveNeedsConfirmation(archive) &&
        !await _confirmLarge(archive)) {
      return;
    }
    setState(_session.loadArchive);
    _startIframe();
  }

  /// Starts the optimised tier a constrained device parked behind a
  /// confirmation (the preview failed, or it is the only tier).
  Future<void> _loadPending() async {
    final pending = _session.pending;
    if (pending == null || _confirming) return;
    if (pending.role == 'spatial_archive') return _loadArchive();
    if (!await _confirmLarge(pending)) return;
    setState(_session.loadPending);
    _startIframe();
  }

  /// "Load full quality" from the preview a constrained device opened first.
  Future<void> _loadFullQuality() async {
    final full = _session.fullQuality;
    if (full == null || _confirming) return;
    if (SpatialWebDelivery.needsConfirmation(full, constrained: true) &&
        !await _confirmLarge(full)) {
      return;
    }
    setState(_session.loadFullQuality);
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

  String _fullLabel(AppLocalizations l10n, int bytes) => bytes > 0
      ? l10n.spatialLoadFullQualityWithSize(
          NodeStatePresentation.formatBytes(bytes),
        )
      : l10n.spatialLoadFullQuality;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final status = _session.status;
    final inert = _pageScrolls && !_interactive;
    // Idempotent DOM write: the iframe takes gestures only while it is the
    // active viewer, otherwise they stay with Flutter (and the page scroll).
    _iframe.style.pointerEvents = inert ? 'none' : 'auto';
    final overlay = switch (status) {
      SpatialWebLoadStatus.ready => null,
      SpatialWebLoadStatus.loading => _Notice(
          poster: widget.posterUrl,
          icon: null,
          message: l10n.spatialViewerLoading,
          busy: true,
        ),
      SpatialWebLoadStatus.awaitingConsent => _session.pending?.role ==
              'spatial_archive'
          ? _Notice(
              poster: widget.posterUrl,
              icon: Icons.view_in_ar_outlined,
              message:
                  '${l10n.spatialArchiveTitle}\n${l10n.spatialArchiveConsentBody}',
              action: FilledButton.icon(
                onPressed: () => unawaited(_loadArchive()),
                icon: const Icon(Icons.threed_rotation_rounded),
                label: Text(_archiveLabel(l10n)),
              ),
            )
          : _Notice(
              poster: widget.posterUrl,
              icon: Icons.view_in_ar_outlined,
              message: '${l10n.spatialArchiveTitle}\n'
                  '${l10n.spatialFullConsentBody}',
              action: FilledButton.icon(
                onPressed: () => unawaited(_loadPending()),
                icon: const Icon(Icons.threed_rotation_rounded),
                label: Text(_fullLabel(l10n, _session.pending?.sizeBytes ?? 0)),
              ),
            ),
      SpatialWebLoadStatus.failed => _Notice(
          poster: widget.posterUrl,
          icon: Icons.view_in_ar_outlined,
          message: l10n.spatialViewerUnavailable,
          // Nothing to retry for a record with no viewable variant: no button.
          action: _session.canRetry
              ? TextButton(
                  onPressed: _retry,
                  child: Text(l10n.spatialViewerRetry),
                )
              : null,
        ),
    };
    return Semantics(
      container: true,
      label: l10n.spatialArchiveTitle,
      child: TapRegion(
        onTapOutside: (_) => _setInteractive(false),
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
                  if (status == SpatialWebLoadStatus.ready && inert)
                    Positioned.fill(
                      child: _ActivateOverlay(
                        label: l10n.spatialViewerActivate,
                        onActivate: () => _setInteractive(true),
                      ),
                    ),
                ],
              ),
            ),
            if (status == SpatialWebLoadStatus.ready) _controls(context, l10n),
          ],
        ),
      ),
    );
  }

  /// The row under the viewer. While an embedded viewer is active the row is
  /// only "Done" and "Reset view", so it never gets taller than the idle row
  /// (a squeezed row would shrink the viewer above it).
  Widget _controls(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final active = _pageScrolls && _interactive;
    final hint = _pageScrolls ? '' : l10n.spatialViewerDragHint;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: active
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: () => _setInteractive(false),
                      child: Text(l10n.commonDone),
                    ),
                  )
                : Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
          ),
          if (_session.canOfferArchive && !active)
            TextButton(
              onPressed: () => unawaited(_loadArchive()),
              child: Text(
                _archiveLabel(l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (_session.fullQuality != null && !active)
            Semantics(
              button: true,
              label: l10n.spatialLoadFullQualitySemantics,
              excludeSemantics: true,
              child: TextButton(
                onPressed: () => unawaited(_loadFullQuality()),
                child: Text(
                  _fullLabel(l10n, _session.fullQuality!.sizeBytes),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          TextButton(
            onPressed: _reset,
            child: Text(l10n.spatialViewerReset),
          ),
        ],
      ),
    );
  }
}

/// Covers the inert viewer: a tap activates it, a drag or wheel passes through
/// to the page's scroller.
class _ActivateOverlay extends StatelessWidget {
  const _ActivateOverlay({required this.label, required this.onActivate});

  final String label;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      onTap: onActivate,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onActivate,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                ),
              ),
            ),
          ),
        ),
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
