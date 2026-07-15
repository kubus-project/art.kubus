import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/map/navigation/walking_navigation_map_coordinator.dart';
import '../../../providers/walking_navigation_provider.dart';

/// Shared provider-to-map binding. Screens provide only responsive placement.
class KubusWalkingNavigationBinding extends StatefulWidget {
  const KubusWalkingNavigationBinding({
    super.key,
    required this.coordinator,
    required this.builder,
  });

  final WalkingNavigationMapCoordinator coordinator;
  final Widget Function(
    BuildContext context,
    WalkingNavigationProvider navigation,
  ) builder;

  @override
  State<KubusWalkingNavigationBinding> createState() =>
      _KubusWalkingNavigationBindingState();
}

class _KubusWalkingNavigationBindingState
    extends State<KubusWalkingNavigationBinding> {
  bool _syncScheduled = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<WalkingNavigationProvider>(
      builder: (context, navigation, _) {
        if (!_syncScheduled) {
          _syncScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncScheduled = false;
            if (!mounted) return;
            unawaited(widget.coordinator.sync(navigation));
          });
        }
        return widget.builder(context, navigation);
      },
    );
  }
}
