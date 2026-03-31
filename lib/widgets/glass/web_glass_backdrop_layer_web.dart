import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class WebGlassBackdropLayer extends StatefulWidget {
  const WebGlassBackdropLayer({
    super.key,
    required this.blurSigma,
    required this.borderRadius,
    required this.backgroundColor,
  });

  final double blurSigma;
  final BorderRadius borderRadius;
  final Color backgroundColor;

  @override
  State<WebGlassBackdropLayer> createState() => _WebGlassBackdropLayerState();
}

class _WebGlassBackdropLayerState extends State<WebGlassBackdropLayer> {
  static int _nextViewId = 0;

  late final String _viewType;
  web.HTMLDivElement? _element;

  @override
  void initState() {
    super.initState();
    _viewType = 'kubus-web-glass-backdrop-${_nextViewId++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (
      int viewId, {
      Object? params,
    }) {
      final element = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..style.pointerEvents = 'none'
        ..style.boxSizing = 'border-box'
        ..style.transform = 'translateZ(0)'
        ..style.willChange = 'backdrop-filter, background-color';
      _element = element;
      _applyStyles();
      return element;
    });
  }

  @override
  void didUpdateWidget(covariant WebGlassBackdropLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blurSigma != widget.blurSigma ||
        oldWidget.borderRadius != widget.borderRadius ||
        oldWidget.backgroundColor != widget.backgroundColor) {
      _applyStyles();
    }
  }

  void _applyStyles() {
    final element = _element;
    if (element == null) return;

    final blur = widget.blurSigma.clamp(0.0, 48.0).toStringAsFixed(1);
    final radius = widget.borderRadius;
    final color = widget.backgroundColor;
    final alpha = (color.a).clamp(0.0, 1.0);
    final domAlpha = alpha < 0.08 ? 0.08 : alpha;
    element.style
      ..backgroundColor =
          'rgba(${color.r.round()}, ${color.g.round()}, ${color.b.round()}, ${domAlpha.toStringAsFixed(3)})'
      ..backdropFilter = 'blur(${blur}px) saturate(1.12)'
      ..setProperty(
        '-webkit-backdrop-filter',
        'blur(${blur}px) saturate(1.12)',
      )
      ..borderTopLeftRadius = '${radius.topLeft.x.toStringAsFixed(1)}px'
      ..borderTopRightRadius = '${radius.topRight.x.toStringAsFixed(1)}px'
      ..borderBottomLeftRadius = '${radius.bottomLeft.x.toStringAsFixed(1)}px'
      ..borderBottomRightRadius = '${radius.bottomRight.x.toStringAsFixed(1)}px'
      ..overflow = 'hidden';
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
