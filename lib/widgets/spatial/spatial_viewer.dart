import 'package:flutter/material.dart';

import '../../models/kubus_node_models.dart';
import '../../services/kubus_node_service.dart';
import 'spatial_viewer_stub.dart'
    if (dart.library.io) 'spatial_viewer_native.dart' as implementation;

/// Renderer-neutral spatial archive viewer. Gaussian rendering is currently
/// supplied by bundled Spark assets; callers only depend on SpatialContent.
class SpatialViewer extends StatelessWidget {
  const SpatialViewer({
    required this.content,
    required this.nodeService,
    super.key,
    this.posterUrl,
  });

  final SpatialContent content;
  final KubusNodeService nodeService;
  final String? posterUrl;

  @override
  Widget build(BuildContext context) => implementation.buildSpatialViewer(
        context: context,
        content: content,
        nodeService: nodeService,
        posterUrl: posterUrl,
      );
}
