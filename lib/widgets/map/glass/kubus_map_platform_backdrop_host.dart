import 'package:flutter/material.dart';

import 'kubus_map_platform_backdrop_controller.dart';
import 'kubus_map_platform_backdrop_dom_stub.dart'
    if (dart.library.js_interop) 'kubus_map_platform_backdrop_dom_web.dart';

export 'kubus_map_platform_backdrop_controller.dart';

class KubusMapPlatformBackdropHost extends StatefulWidget {
  const KubusMapPlatformBackdropHost({
    super.key,
    required this.controller,
    required this.enabled,
  });

  final KubusMapBackdropHostController controller;
  final bool enabled;

  static bool get isSupported => kubusMapPlatformBackdropDomSupported;

  @override
  State<KubusMapPlatformBackdropHost> createState() =>
      _KubusMapPlatformBackdropHostState();
}

class _KubusMapPlatformBackdropHostState
    extends State<KubusMapPlatformBackdropHost> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(KubusMapPlatformBackdropHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    disposeKubusMapPlatformBackdropDom();
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    syncKubusMapPlatformBackdropDom(
      enabled: widget.enabled && kubusMapPlatformBackdropDomSupported,
      regions: widget.controller.regions,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      ignoring: true,
      child: SizedBox.expand(),
    );
  }
}

class KubusMapBackdropRegionTracker extends StatefulWidget {
  const KubusMapBackdropRegionTracker({
    super.key,
    required this.id,
    required this.enabled,
    required this.borderRadius,
    required this.blurSigma,
    required this.child,
  });

  final String id;
  final bool enabled;
  final BorderRadius borderRadius;
  final double blurSigma;
  final Widget child;

  @override
  State<KubusMapBackdropRegionTracker> createState() =>
      _KubusMapBackdropRegionTrackerState();
}

class _KubusMapBackdropRegionTrackerState
    extends State<KubusMapBackdropRegionTracker> {
  KubusMapBackdropHostController? _controller;
  Rect? _lastRect;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextController = KubusMapBackdropScope.maybeOf(context);
    if (_controller != nextController) {
      _controller?.removeRegion(widget.id, deferNotify: true);
      _controller = nextController;
      _scheduleSync();
    }
  }

  @override
  void didUpdateWidget(KubusMapBackdropRegionTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _controller?.removeRegion(oldWidget.id, deferNotify: true);
      _lastRect = null;
    }
    _scheduleSync();
  }

  @override
  void dispose() {
    _controller?.removeRegion(widget.id, deferNotify: true);
    super.dispose();
  }

  void _scheduleSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncRegion());
  }

  void _syncRegion() {
    if (!mounted) return;
    final controller = _controller;
    if (!widget.enabled || controller == null) {
      controller?.removeRegion(widget.id);
      return;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      controller.removeRegion(widget.id);
      return;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final rect = topLeft & size;
    if (!rect.isFinite || rect.width <= 0 || rect.height <= 0) {
      controller.removeRegion(widget.id);
      return;
    }
    if (_lastRect == rect) {
      return;
    }
    _lastRect = rect;
    controller.upsertRegion(
      KubusMapBackdropRegion(
        id: widget.id,
        rect: rect,
        borderRadius: widget.borderRadius,
        blurSigma: widget.blurSigma,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _scheduleSync();
    return widget.child;
  }
}
