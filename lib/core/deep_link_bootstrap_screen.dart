import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

import '../providers/deep_link_provider.dart';
import '../providers/artwork_provider.dart';
import '../providers/events_provider.dart';
import '../providers/exhibitions_provider.dart';
import '../providers/collections_provider.dart';
import '../providers/public_entity_takeover_provider.dart';
import '../services/public_entity_takeover_bridge.dart';
import '../services/share/share_deep_link_parser.dart';
import 'app_initializer.dart';

class DeepLinkBootstrapScreen extends StatefulWidget {
  const DeepLinkBootstrapScreen({
    super.key,
    required this.target,
    required this.initialUri,
  });

  final ShareDeepLinkTarget target;
  final Uri initialUri;

  @override
  State<DeepLinkBootstrapScreen> createState() =>
      _DeepLinkBootstrapScreenState();
}

class _DeepLinkBootstrapScreenState extends State<DeepLinkBootstrapScreen> {
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    if (kDebugMode) {
      debugPrint(
        'DeepLinkBootstrapScreen: seeding pending target: ${widget.target.type} id=${widget.target.id}',
      );
    }
    context.read<DeepLinkProvider>().setPending(widget.target);
    final takeover = context.read<PublicEntityTakeoverProvider>();
    takeover.seed(initialUri: widget.initialUri, target: widget.target);
    final bootstrap = takeover.validateBootstrap(
      raw: readPublicEntityBootstrap(),
      initialUri: widget.initialUri,
      target: widget.target,
    );
    final presentation = bootstrap?['presentation'];
    if (presentation is! Map) return;
    final publicPresentation = Map<String, dynamic>.from(presentation);
    switch (publicPresentation['type']) {
      case 'artwork':
        context.read<ArtworkProvider>().seedPublicPresentation(
          publicPresentation,
        );
        final id = publicPresentation['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          unawaited(
            context
                .read<ArtworkProvider>()
                .refreshArtwork(id)
                .catchError((_) => null),
          );
        }
        break;
      case 'event':
        context.read<EventsProvider>().seedPublicPresentation(
          publicPresentation,
        );
        break;
      case 'exhibition':
        context.read<ExhibitionsProvider>().seedPublicPresentation(
          publicPresentation,
        );
        break;
      case 'collection':
        context.read<CollectionsProvider>().seedPublicPresentation(
          publicPresentation,
        );
        break;
      default:
        // Other public entity types retain the validated presentation on the
        // takeover provider; their existing detail route remains responsible
        // for normal entity loading.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppInitializer(initialUri: widget.initialUri);
  }
}
