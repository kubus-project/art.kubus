import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';

import '../providers/deep_link_provider.dart';
import '../services/share/share_deep_link_parser.dart';
import 'app_initializer.dart';

class DeepLinkBootstrapScreen extends StatefulWidget {
  const DeepLinkBootstrapScreen({
    super.key,
    required this.target,
  });

  final ShareDeepLinkTarget target;

  @override
  State<DeepLinkBootstrapScreen> createState() => _DeepLinkBootstrapScreenState();
}

class _DeepLinkBootstrapScreenState extends State<DeepLinkBootstrapScreen> {
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    if (kDebugMode) {
      debugPrint('DeepLinkBootstrapScreen: seeding pending target: ${widget.target.type} id=${widget.target.id}');
    }
    context.read<DeepLinkProvider>().setPending(widget.target);
  }

  @override
  Widget build(BuildContext context) {
    return const AppInitializer();
  }
}
