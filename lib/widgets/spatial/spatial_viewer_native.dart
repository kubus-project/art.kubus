import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/kubus_node_models.dart';
import '../../services/kubus_node_service.dart';
import '../../services/spatial_content_proxy.dart';
import '../../services/spatial_device_class.dart';
import '../../services/spatial_web_delivery.dart';
import '../../utils/node_state_presentation.dart';
import '../inline_loading.dart';

Widget buildSpatialViewer({
  required BuildContext context,
  required SpatialContent content,
  required KubusNodeService nodeService,
  String? posterUrl,
  VoidCallback? onEscape,
  Future<Uint8List> Function()? privateBytes,
}) =>
    _NativeSpatialViewer(
      content: content,
      nodeService: nodeService,
      posterUrl: posterUrl,
      fullscreen: false,
    );

/// The variant the native viewer opens by itself: the first role of the
/// device-class tier order ([SpatialWebDelivery.defaultRoles], then the
/// archive last) that [content] has in a format the WebView viewer reads.
@visibleForTesting
SpatialVariant? nativePreferredVariant(
  SpatialContent content, {
  required bool constrained,
}) {
  final supported =
      content.variants.where(_isSplatVariant).toList(growable: false);
  final roles = <String>[
    ...SpatialWebDelivery.defaultRoles(constrained: constrained),
    'spatial_archive',
  ];
  for (final role in roles) {
    final match = supported.where((item) => item.role == role).firstOrNull;
    if (match != null) return match;
  }
  return null;
}

bool _isSplatVariant(SpatialVariant variant) {
  final format = variant.format.toLowerCase();
  final mimeType = variant.mimeType.toLowerCase();
  return const {'splat', 'ply', 'spz', 'ksplat', 'sog'}.any(
    (supported) =>
        format == supported ||
        format.endsWith('.$supported') ||
        mimeType.contains(supported),
  );
}

/// Widget tests only: the native viewer without a WebView, in the loaded
/// state ([loaded]) or opened on a given variant ([initialVariant]).
@visibleForTesting
Widget debugNativeSpatialViewer({
  required SpatialContent content,
  required KubusNodeService nodeService,
  String? posterUrl,
  bool loaded = false,
  bool fullscreen = false,
  SpatialVariant? initialVariant,
}) =>
    _NativeSpatialViewer(
      content: content,
      nodeService: nodeService,
      posterUrl: posterUrl,
      fullscreen: fullscreen,
      initialVariant: initialVariant,
      debugLoaded: loaded,
    );

class _NativeSpatialViewer extends StatefulWidget {
  const _NativeSpatialViewer({
    required this.content,
    required this.nodeService,
    this.posterUrl,
    required this.fullscreen,
    this.initialVariant,
    this.debugLoaded = false,
  });
  final SpatialContent content;
  final KubusNodeService nodeService;
  final String? posterUrl;
  final bool fullscreen;

  /// The variant to open instead of choosing one. The fullscreen route is
  /// given the variant the visitor already has on screen, so it neither drops
  /// the quality they chose nor asks for the consent they already gave.
  final SpatialVariant? initialVariant;

  /// Widget tests only: start in the loaded state without a WebView.
  @visibleForTesting
  final bool debugLoaded;

  @override
  State<_NativeSpatialViewer> createState() => _NativeSpatialViewerState();
}

class _NativeSpatialViewerState extends State<_NativeSpatialViewer> {
  WebViewController? _controller;
  SpatialContentProxy? _proxy;
  String? _error;
  bool _ready = false;
  SpatialVariant? _selectedVariant;

  /// Nothing is loaded yet and the opening variant waits for the visitor.
  bool _awaitingConsent = false;

  /// A variant the visitor picked from the menu that waits for their go-ahead
  /// while the current one keeps running.
  SpatialVariant? _offered;
  late final bool _constrained = SpatialDeviceClass.constrained;

  @override
  void initState() {
    super.initState();
    final given = widget.initialVariant;
    if (given != null) {
      unawaited(_initialize(given));
      return;
    }
    final preferred = _preferredVariant();
    if (widget.debugLoaded) {
      _selectedVariant = preferred;
      _ready = true;
    } else if (preferred != null && _needsConsent(preferred)) {
      _selectedVariant = preferred;
      _awaitingConsent = true;
    } else {
      unawaited(_initialize(preferred));
    }
  }

  List<SpatialVariant> get _supportedVariants =>
      widget.content.variants.where(_isSplatVariant).toList(growable: false);

  /// The archive always waits for the visitor; so does a large optimised model
  /// on a constrained device.
  bool _needsConsent(SpatialVariant variant) =>
      variant.role == 'spatial_archive' ||
      SpatialWebDelivery.needsConfirmation(variant, constrained: _constrained);

  SpatialVariant? _preferredVariant() =>
      nativePreferredVariant(widget.content, constrained: _constrained);

  Future<void> _initialize([SpatialVariant? requested]) async {
    try {
      final variant = requested ?? _preferredVariant();
      if (variant == null) {
        throw StateError('No viewable spatial variant is available.');
      }
      await _proxy?.close();
      _proxy = null;
      if (mounted) {
        setState(() {
          _selectedVariant = variant;
          _awaitingConsent = false;
          _offered = null;
          _error = null;
          _ready = false;
          _controller = null;
        });
      }
      final candidates = await widget.nodeService.resolveContentCandidates(
        'ipfs://${variant.cid}',
        localPath: variant.localPath,
      );
      if (candidates.isEmpty) {
        throw StateError('No content route is available.');
      }
      _proxy = await SpatialContentProxy.start(candidates);
      late final WebViewController controller;
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel(
          'SpatialViewer',
          onMessageReceived: (message) {
            if (!mounted) return;
            if (message.message == 'viewer-ready') {
              unawaited(_loadInto(controller, variant));
            } else if (message.message == 'ready') {
              setState(() => _ready = true);
            } else if (message.message.startsWith('error:')) {
              setState(
                  () => _error = 'This spatial archive could not be loaded.');
            }
          },
        )
        ..loadFlutterAsset('assets/spatial_viewer/index.html');
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  /// Hands the page the proxied bytes together with what the web host also
  /// passes: the Spark file type (a raw `.splat` has no magic number) and the
  /// placement (the published manifest's, or the local manifest's for content
  /// not yet published), so a piece the Node placed opens upright here too.
  /// The transform read is best effort and bounded, and never blocks the load
  /// beyond its own timeout.
  Future<void> _loadInto(
    WebViewController controller,
    SpatialVariant variant,
  ) async {
    final proxy = _proxy;
    if (proxy == null) return;
    final plan = SpatialWebDelivery.plan(widget.content, variant);
    final transform =
        await SpatialWebDelivery.resolveTransform(widget.content, plan);
    if (!mounted || !identical(proxy, _proxy)) return;
    final args = <String>[
      _jsString(proxy.uri.toString()),
      jsonEncode(transform),
      jsonEncode(plan.fileType),
    ].join(', ');
    await controller.runJavaScript('window.loadSpatial($args)');
  }

  static String _jsString(String value) =>
      "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

  @override
  void dispose() {
    unawaited(_proxy?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    if (_awaitingConsent) {
      final waiting = _selectedVariant;
      return _PosterBackdrop(
        poster: widget.posterUrl,
        child: _loadButton(l10n, waiting, () => _initialize(waiting)),
      );
    }
    if (_error != null) {
      return _PosterBackdrop(
        poster: widget.posterUrl,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.spatialViewerUnavailable, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => unawaited(_initialize(_selectedVariant)),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.spatialViewerRetry),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_controller != null) WebViewWidget(controller: _controller!),
        if (!_ready)
          _PosterBackdrop(
            poster: widget.posterUrl,
            child: const InlineLoading(width: 64, height: 64),
          ),
        if (_ready)
          Positioned(
            top: 12,
            right: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.spatialViewerReset,
                    onPressed: () => _controller?.runJavaScript(
                      'window.resetSpatialView?.()',
                    ),
                    icon: const Icon(Icons.center_focus_strong_rounded),
                  ),
                  if (!widget.fullscreen)
                    IconButton(
                      tooltip: l10n.spatialViewerFullscreen,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar:
                                AppBar(title: Text(l10n.spatialArchiveTitle)),
                            body: _NativeSpatialViewer(
                              content: widget.content,
                              nodeService: widget.nodeService,
                              posterUrl: widget.posterUrl,
                              fullscreen: true,
                              initialVariant: _selectedVariant,
                            ),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.fullscreen_rounded),
                    ),
                ],
              ),
            ),
          ),
        if (_ready && _supportedVariants.length > 1)
          Positioned(
            left: 12,
            bottom: 12,
            child: MenuAnchor(
              menuChildren: [
                for (final variant in _supportedVariants)
                  MenuItemButton(
                    onPressed: variant.cid == _selectedVariant?.cid
                        ? null
                        : () => _selectQuality(variant),
                    child: Text(_qualityLabel(l10n, variant.role)),
                  ),
              ],
              builder: (context, controller, _) => FilledButton.tonalIcon(
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                icon: const Icon(Icons.tune_rounded),
                label: Text(_qualityLabel(l10n, _selectedVariant?.role ?? '')),
              ),
            ),
          ),
        if (_ready && _offered != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 60,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: _loadButton(
                        l10n,
                        _offered,
                        () => _initialize(_offered),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() => _offered = null),
                      child: Text(l10n.commonCancel),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The opt-in button for a model that is large or of unknown size.
  Widget _loadButton(
    AppLocalizations l10n,
    SpatialVariant? variant,
    Future<void> Function() load,
  ) =>
      FilledButton.icon(
        onPressed: () => unawaited(load()),
        icon: const Icon(Icons.download_rounded),
        label: Text(variant?.role == 'spatial_archive'
            ? ((variant?.sizeBytes ?? 0) > 0
                ? l10n.spatialLoadArchiveQualityWithSize(
                    NodeStatePresentation.formatBytes(variant!.sizeBytes))
                : l10n.spatialLoadArchiveQuality)
            : (variant?.sizeBytes ?? 0) > 0
                ? l10n.spatialLoadFullQualityWithSize(
                    NodeStatePresentation.formatBytes(variant!.sizeBytes))
                : l10n.spatialLoadFullQuality),
      );

  /// Picking a quality from the menu follows the web rule: the archive when it
  /// is 50 MiB or larger or of unknown size, and a large optimised model on a
  /// constrained device, are offered with a button while the current variant
  /// stays on screen, so declining costs the visitor nothing.
  void _selectQuality(SpatialVariant variant) {
    if (SpatialWebDelivery.needsConfirmation(variant,
        constrained: _constrained)) {
      setState(() => _offered = variant);
      return;
    }
    unawaited(_initialize(variant));
  }

  String _qualityLabel(AppLocalizations l10n, String role) => switch (role) {
        'spatial_archive' => l10n.spatialQualityArchive,
        'spatial_preview' => l10n.spatialQualityPreview,
        _ => l10n.spatialQualityMobile,
      };
}

/// The artwork's poster behind a centred [child]: the surface the viewer shows
/// while it loads, while it waits for the visitor, and when nothing can be
/// shown. Without a poster, or when the poster itself fails, it is the plain
/// surface.
class _PosterBackdrop extends StatelessWidget {
  const _PosterBackdrop({required this.child, this.poster});

  final String? poster;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = poster;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url.isNotEmpty)
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          Center(child: child),
        ],
      ),
    );
  }
}
