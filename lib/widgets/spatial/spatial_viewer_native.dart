import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
    );

class _NativeSpatialViewer extends StatefulWidget {
  const _NativeSpatialViewer({
    required this.content,
    required this.nodeService,
    this.posterUrl,
  });
  final SpatialContent content;
  final KubusNodeService nodeService;
  final String? posterUrl;

  @override
  State<_NativeSpatialViewer> createState() => _NativeSpatialViewerState();
}

class _NativeSpatialViewerState extends State<_NativeSpatialViewer> {
  WebViewController? _controller;
  SpatialContentProxy? _proxy;
  String? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final variants = widget.content.variants;
      final supported = variants.where(_isSplatVariant);
      final variant = supported
              .where((item) => item.role == 'spatial_mobile')
              .firstOrNull ??
          supported.where((item) => item.role == 'spatial_archive').firstOrNull;
      if (variant == null) {
        throw StateError('No viewable spatial variant is available.');
      }
      final candidates = await widget.nodeService
          .resolveContentCandidates('ipfs://${variant.cid}');
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
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
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
      ],
    );
  }
}
