import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../models/kubus_node_models.dart';
import '../../services/kubus_node_service.dart';
import 'spatial_viewer_stub.dart'
    if (dart.library.js_interop) 'spatial_viewer_web.dart'
    if (dart.library.io) 'spatial_viewer_native.dart' as implementation;

/// Renderer-neutral spatial archive viewer. Gaussian rendering is currently
/// supplied by bundled Spark assets; callers only depend on SpatialContent.
/// Native builds host the viewer in a WebView, Flutter web in a same-origin
/// iframe (`spatial_viewer_web.dart`); the stub is the fallback elsewhere.
class SpatialViewer extends StatelessWidget {
  const SpatialViewer({
    required this.content,
    required this.nodeService,
    super.key,
    this.posterUrl,
    this.onEscape,
    this.privateBytes,
  });

  final SpatialContent content;
  final KubusNodeService nodeService;
  final String? posterUrl;

  /// Called when the visitor presses Escape inside the web viewer. The viewer
  /// is an iframe, so that key never reaches Flutter's own key handling; a host
  /// that wants Escape to dismiss it (the fullscreen dialog) passes this. The
  /// viewer itself closes nothing. Native and stub viewers never call it.
  final VoidCallback? onEscape;
  final Future<Uint8List> Function()? privateBytes;

  @override
  Widget build(BuildContext context) => implementation.buildSpatialViewer(
        context: context,
        content: content,
        nodeService: nodeService,
        posterUrl: posterUrl,
        onEscape: onEscape,
        privateBytes: privateBytes,
      );
}
