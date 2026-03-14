import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';

class GeneralBackground extends StatefulWidget {
  static const String lightMapAsset =
      'assets/images/backgrounds/background_map_light.png';
  static const String darkMapAsset =
      'assets/images/backgrounds/background_map_dark.png';

  final Widget child;
  final Duration duration;
  final bool animate;
  final List<Color>? colors;
  final Duration paletteTransitionDuration;
  final double hueShiftDegrees;
  final double intensity;
  final bool showMapLayer;

  const GeneralBackground({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 8),
    this.animate = true,
    this.colors,
    this.intensity = 0.3,
    this.paletteTransitionDuration = const Duration(milliseconds: 900),
    this.hueShiftDegrees = 10.0,
    this.showMapLayer = true,
  });

  @override
  State<GeneralBackground> createState() => _GeneralBackgroundState();
}

class _GeneralBackgroundState extends State<GeneralBackground>
    with TickerProviderStateMixin {
  late AnimationController _motionController;
  late Animation<double> _motion;

  late AnimationController _paletteController;
  List<Color> _paletteFrom = const <Color>[];
  List<Color> _paletteTo = const <Color>[];

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _motion = CurvedAnimation(
      parent: _motionController,
      curve: Curves.easeInOut,
    );

    _paletteController = AnimationController(
      duration: widget.paletteTransitionDuration,
      vsync: this,
    )..value = 1.0;

    if (widget.animate) {
      _motionController.repeat(reverse: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPaletteIfNeeded();
  }

  @override
  void didUpdateWidget(GeneralBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _motionController.duration = widget.duration;
    }
    if (widget.paletteTransitionDuration !=
        oldWidget.paletteTransitionDuration) {
      _paletteController.duration = widget.paletteTransitionDuration;
    }
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
        _motionController.repeat(reverse: true);
      } else {
        _motionController.stop();
      }
    }
    if (!_listEquals(widget.colors, oldWidget.colors)) {
      _syncPaletteIfNeeded(force: true);
    }
  }

  @override
  void dispose() {
    _motionController.dispose();
    _paletteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_motion, _paletteController]),
      builder: (context, child) {
        final theme = Theme.of(context);
        final motionT = _motion.value;
        final progress = motionT * widget.intensity;
        final isDark = theme.brightness == Brightness.dark;

        final beginOffset = Alignment(
          -1.0 + (progress * 0.5),
          -1.0 + (progress * 0.3),
        );
        final endOffset = Alignment(
          1.0 - (progress * 0.3),
          1.0 - (progress * 0.5),
        );

        final paletteT = Curves.easeInOut.transform(_paletteController.value);
        final basePalette = _lerpColorLists(_paletteFrom, _paletteTo, paletteT);
        final effectivePalette = _applyHueShift(
          basePalette,
          degrees: widget.hueShiftDegrees,
          t: motionT,
          intensity: widget.intensity,
        );
        final gradientAlpha =
            widget.showMapLayer ? (isDark ? 0.88 : 0.90) : 1.0;
        final gradientPalette = effectivePalette
            .map((color) => color.withValues(alpha: gradientAlpha))
            .toList(growable: false);

        return Stack(
          fit: StackFit.expand,
          children: [
            if (widget.showMapLayer) _buildStaticMapLayer(context),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientPalette,
                  begin: beginOffset,
                  end: endOffset,
                  stops: _calculateStops(gradientPalette.length, progress),
                ),
              ),
            ),
            if (child != null) child,
          ],
        );
      },
      child: widget.child,
    );
  }

  Widget _buildStaticMapLayer(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final shortestSide = media.size.shortestSide;
    final opacity = isDark ? 0.22 : 0.30;
    final blurSigma = isDark ? 0.8 : 1.1;
    final scale = shortestSide >= 1100
        ? 1.10
        : shortestSide >= 700
            ? 1.14
            : 1.22;

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: blurSigma,
            sigmaY: blurSigma,
          ),
          child: Transform.scale(
            scale: scale,
            child: Image.asset(
              isDark
                  ? GeneralBackground.darkMapAsset
                  : GeneralBackground.lightMapAsset,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }

  List<double> _calculateStops(int count, double progress) {
    if (count <= 1) return const <double>[0.0];
    final List<double> stops = <double>[];
    for (int i = 0; i < count; i++) {
      final baseStop = i / (count - 1);
      final offset = (i.isEven ? progress : -progress) * 0.1;
      stops.add((baseStop + offset).clamp(0.0, 1.0));
    }
    return stops;
  }

  void _syncPaletteIfNeeded({bool force = false}) {
    final desired = _resolveDesiredBasePalette(context);
    if (!force && _listEquals(desired, _paletteTo)) return;

    final current = _paletteFrom.isEmpty
        ? desired
        : _lerpColorLists(
            _paletteFrom,
            _paletteTo,
            Curves.easeInOut.transform(_paletteController.value),
          );

    _paletteFrom = current;
    _paletteTo = desired;
    _paletteController.forward(from: 0.0);
  }

  List<Color> _resolveDesiredBasePalette(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = widget.colors ??
        (isDark
            ? KubusGradients.animatedDarkColors
            : KubusGradients.animatedLightColors);

    if (colors.isEmpty) {
      return isDark
          ? KubusGradients.animatedDarkColors
          : KubusGradients.animatedLightColors;
    }
    return colors;
  }

  static bool _listEquals(List<Color>? a, List<Color>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].toARGB32() != b[i].toARGB32()) return false;
    }
    return true;
  }

  static List<Color> _lerpColorLists(List<Color> a, List<Color> b, double t) {
    if (a.isEmpty && b.isEmpty) return const <Color>[];
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;

    final length = a.length > b.length ? a.length : b.length;
    final aPad = _padToLength(a, length);
    final bPad = _padToLength(b, length);
    return List<Color>.generate(length, (index) {
      return Color.lerp(aPad[index], bPad[index], t) ?? bPad[index];
    }, growable: false);
  }

  static List<Color> _padToLength(List<Color> colors, int length) {
    if (colors.length == length) return colors;
    if (colors.isEmpty) {
      return List<Color>.filled(length, Colors.transparent, growable: false);
    }
    final last = colors.last;
    return List<Color>.generate(
      length,
      (i) => i < colors.length ? colors[i] : last,
      growable: false,
    );
  }

  static List<Color> _applyHueShift(
    List<Color> colors, {
    required double degrees,
    required double t,
    required double intensity,
  }) {
    if (colors.isEmpty) return colors;
    if (degrees.abs() < 0.001) return colors;
    if (intensity <= 0.0) return colors;

    final shift = (t - 0.5) * 2.0 * degrees * intensity;
    return colors.map((c) => _shiftHue(c, shift)).toList(growable: false);
  }

  static Color _shiftHue(Color color, double degrees) {
    if (color.a <= 0.0) return color;
    final hsl = HSLColor.fromColor(color);
    final newHue = (hsl.hue + degrees) % 360.0;
    return hsl.withHue(newHue < 0 ? newHue + 360.0 : newHue).toColor();
  }
}
