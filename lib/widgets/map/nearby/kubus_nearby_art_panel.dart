import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../features/map/nearby/nearby_art_controller.dart';
import '../../../models/art_marker.dart';
import '../../../models/artwork.dart';
import '../../../providers/themeprovider.dart';
import '../../../utils/design_tokens.dart';
import '../../map_overlay_blocker.dart';
import '../kubus_map_glass_surface.dart';
import 'kubus_nearby_art_panel_body.dart';
import 'kubus_nearby_art_panel_types.dart';

export 'kubus_nearby_art_panel_types.dart';

/// Shared nearby art UI used in:
/// - mobile map bottom sheet
/// - desktop map explore nearby side panel
///
/// Important constraints:
/// - must intercept pointer/scroll so map doesn't scroll/zoom underneath
/// - must not perform async work or side-effects in build
class KubusNearbyArtPanel extends StatefulWidget {
  const KubusNearbyArtPanel({
    super.key,
    required this.controller,
    required this.layout,
    required this.artworks,
    required this.markers,
    required this.basePosition,
    required this.isLoading,
    required this.travelModeEnabled,
    required this.radiusKm,
    this.titleKey,
    this.discoveryProgress,
    this.onClose,
    this.onRadiusTap,
    this.scrollController,
    this.onInteractingChanged,
  });

  final NearbyArtController controller;
  final KubusNearbyArtPanelLayout layout;
  final List<Artwork> artworks;
  final List<ArtMarker> markers;
  final LatLng? basePosition;
  final bool isLoading;
  final bool travelModeEnabled;
  final double radiusKm;
  final Key? titleKey;
  final double? discoveryProgress;
  final VoidCallback? onClose;
  final VoidCallback? onRadiusTap;
  final ScrollController? scrollController;
  final ValueChanged<bool>? onInteractingChanged;

  @override
  State<KubusNearbyArtPanel> createState() => _KubusNearbyArtPanelState();
}

class _KubusNearbyArtPanelState extends State<KubusNearbyArtPanel> {
  KubusNearbyArtSort _sort = KubusNearbyArtSort.nearest;
  bool _useGrid = false;

  late final ScrollController _internalScrollController;

  ScrollController get _effectiveScrollController =>
      widget.scrollController ?? _internalScrollController;

  @override
  void initState() {
    super.initState();
    _internalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _internalScrollController.dispose();
    super.dispose();
  }

  void _setInteracting(bool value) {
    widget.onInteractingChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final scheme = Theme.of(context).colorScheme;
    final isMobile =
        widget.layout == KubusNearbyArtPanelLayout.mobileBottomSheet;
    final radius = isMobile
        ? const BorderRadius.vertical(top: Radius.circular(KubusRadius.xl))
        : BorderRadius.zero;

    Widget content = KubusNearbyArtPanelBody(
      controller: widget.controller,
      layout: widget.layout,
      artworks: widget.artworks,
      markers: widget.markers,
      basePosition: widget.basePosition,
      isLoading: widget.isLoading,
      travelModeEnabled: widget.travelModeEnabled,
      radiusKm: widget.radiusKm,
      titleKey: widget.titleKey,
      discoveryProgress: widget.discoveryProgress,
      sort: _sort,
      useGrid: _useGrid,
      accentColor: themeProvider.accentColor,
      onClose: widget.onClose,
      onRadiusTap: widget.onRadiusTap,
      scrollController: _effectiveScrollController,
      onSortChanged: (value) => setState(() => _sort = value),
      onToggleGrid: () => setState(() => _useGrid = !_useGrid),
    );

    content = buildKubusMapGlassSurface(
      context: context,
      kind: KubusMapGlassSurfaceKind.panel,
      borderRadius: radius,
      tintBase: scheme.surface,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: content,
    );

    return MapOverlayBlocker(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _setInteracting(true),
        onPointerUp: (_) => _setInteracting(false),
        onPointerCancel: (_) => _setInteracting(false),
        child: content,
      ),
    );
  }
}
