import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/map/navigation/walking_navigation_debug_harness.dart';
import '../../providers/walking_navigation_provider.dart';
import '../../services/walking_directions_service.dart';
import '../map_screen.dart';

/// Debug-only host for the deterministic walking-route rendering harness.
///
/// It swaps only the routing source and the location source, then hands over to
/// the real [MapScreen]. Everything after that — session lease, provider state,
/// `WalkingRoute.toGeoJson`, `WalkingNavigationMapCoordinator`,
/// `MapLayersManager`, the MapLibre walking-route source and layers, layer
/// visibility, and the route-overview camera fit — is untouched production
/// code, so a missing line here is a genuine rendering failure.
class WalkingRouteRenderHarnessScreen extends StatefulWidget {
  const WalkingRouteRenderHarnessScreen({super.key, this.useLiveRoutingSource});

  /// When true the real [WalkingDirectionsService] is used with the harness's
  /// fixed coordinates, so the routing source can be validated separately from
  /// rendering without depending on GPS.
  final bool? useLiveRoutingSource;

  @override
  State<WalkingRouteRenderHarnessScreen> createState() =>
      _WalkingRouteRenderHarnessScreenState();
}

class _WalkingRouteRenderHarnessScreenState
    extends State<WalkingRouteRenderHarnessScreen> {
  bool _prepared = false;
  bool _rejected = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prepared || _rejected) return;
    if (!WalkingNavigationDebugHarness.isEnabled) {
      _rejected = true;
      return;
    }
    final navigation = context.read<WalkingNavigationProvider>();
    final live = widget.useLiveRoutingSource ?? false;
    final applied = navigation.debugUseDirectionsApi(
      live ? WalkingDirectionsService() : DeterministicWalkingDirectionsApi(),
    );
    if (!applied) {
      _rejected = true;
      return;
    }
    _prepared = true;
    if (kDebugMode) {
      debugPrint(
        'WalkingRouteRenderHarness: '
        '${live ? 'live Overpass' : 'deterministic'} routing source installed',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_prepared) {
      return const Scaffold(
        body: Center(child: Text('Harness unavailable in this build')),
      );
    }
    return MapScreen(
      initialCenter: WalkingNavigationDebugHarness.origin,
      initialZoom: 16,
      autoFollow: false,
      walkingNavigationIntent: WalkingNavigationDebugHarness.intent,
      walkingLocationApi: DeterministicWalkingLocationService(),
    );
  }
}
