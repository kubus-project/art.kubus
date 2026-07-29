import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../widgets/map/glass/kubus_map_platform_backdrop_host.dart';
import 'map_marker_chrome_occlusion_plan.dart';

/// Keeps passive map chrome mounted for stable measurement while removing
/// interaction and semantics whenever its measured region is occluded.
class MapPassiveChromeVisibility extends StatelessWidget {
  const MapPassiveChromeVisibility({
    super.key,
    required this.planListenable,
    required this.isOccluded,
    required this.measurementKey,
    required this.duration,
    required this.curve,
    required this.child,
  });

  final ValueListenable<MapMarkerChromeOcclusionPlan> planListenable;
  final bool Function(MapMarkerChromeOcclusionPlan plan) isOccluded;
  final GlobalKey measurementKey;
  final Duration duration;
  final Curve curve;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MapMarkerChromeOcclusionPlan>(
      valueListenable: planListenable,
      child: KeyedSubtree(key: measurementKey, child: child),
      builder: (context, plan, measuredChild) {
        final hidden = isOccluded(plan);
        return ExcludeSemantics(
          excluding: hidden,
          child: IgnorePointer(
            ignoring: hidden,
            child: AnimatedOpacity(
              opacity: hidden ? 0 : 1,
              duration: duration,
              curve: curve,
              child: KubusMapBackdropRegionVisibility(
                visible: !hidden,
                child: measuredChild!,
              ),
            ),
          ),
        );
      },
    );
  }
}
