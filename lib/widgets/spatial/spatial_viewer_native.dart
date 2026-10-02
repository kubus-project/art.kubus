import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/kubus_node_models.dart';
import '../../services/kubus_node_service.dart';
import '../../services/spatial_content_proxy.dart';
import '../inline_loading.dart';

Widget buildSpatialViewer({
  required BuildContext context,
  required SpatialContent content,
  required KubusNodeService nodeService,
  String? posterUrl,
}) =>
    _NativeSpatialViewer(
      content: content,
      nodeService: nodeService,
      posterUrl: posterUrl,
      fullscreen: false,
    );

class _NativeSpatialViewer extends StatefulWidget {
  const _NativeSpatialViewer({
    required this.content,
    required this.nodeService,
    this.posterUrl,
    required this.fullscreen,
  });
  final SpatialContent content;
  final KubusNodeService nodeService;
  final String? posterUrl;
  final bool fullscreen;

  @override
  State<_NativeSpatialViewer> createState() => _NativeSpatialViewerState();
}

class _NativeSpatialViewerState extends State<_NativeSpatialViewer> {
  WebViewController? _controller;
  SpatialContentProxy? _proxy;
  String? _error;
  bool _ready = false;
  SpatialVariant? _selectedVariant;
  bool _awaitingArchiveConsent = false;

  @override
  void initState() {
    super.initState();
    final preferred = _preferredVariant();
    if (preferred?.role == 'spatial_archive') {
      _selectedVariant = preferred;
      _awaitingArchiveConsent = true;
    } else {
      unawaited(_initialize(preferred));
    }
  }

  List<SpatialVariant> get _supportedVariants =>
      widget.content.variants.where(_isSplatVariant).toList(growable: false);

  SpatialVariant? _preferredVariant() {
    final supported = _supportedVariants;
    return supported
            .where((item) => item.role == 'spatial_mobile')
            .firstOrNull ??
        supported.where((item) => item.role == 'spatial_preview').firstOrNull ??
        supported.where((item) => item.role == 'spatial_archive').firstOrNull;
  }

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
          _awaitingArchiveConsent = false;
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
              unawaited(
                controller.runJavaScript(
                  'window.loadSpatial(${_jsString(_proxy!.uri.toString())})',
                ),
              );
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

  static String _jsString(String value) =>
      "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

  static bool _isSplatVariant(SpatialVariant variant) {
    final format = variant.format.toLowerCase();
    final mimeType = variant.mimeType.toLowerCase();
    return const {'splat', 'ply', 'spz', 'ksplat', 'sog'}.any(
      (supported) =>
          format == supported ||
          format.endsWith('.$supported') ||
          mimeType.contains(supported),
    );
  }

  @override
  void dispose() {
    unawaited(_proxy?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    if (_awaitingArchiveConsent) {
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: FilledButton.icon(
            onPressed: () => unawaited(_initialize(_selectedVariant)),
            icon: const Icon(Icons.download_rounded),
            label: Text(l10n.spatialLoadArchiveQuality),
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
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
          ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: const Center(
              child: InlineLoading(width: 64, height: 64),
            ),
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
                        : () => unawaited(_initialize(variant)),
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
      ],
    );
  }

  String _qualityLabel(AppLocalizations l10n, String role) => switch (role) {
        'spatial_archive' => l10n.spatialQualityArchive,
        'spatial_preview' => l10n.spatialQualityPreview,
        _ => l10n.spatialQualityMobile,
      };
}
