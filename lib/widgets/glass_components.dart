import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import '../utils/design_tokens.dart';

/// Global flag to disable BackdropFilter effects on web when WebGL context is unstable.
/// This is set by the JS interop layer when repeated context losses are detected.
bool kubusDisableBackdropFilter = false;

Future<T?> showKubusDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Duration transitionDuration = const Duration(milliseconds: 220),
  bool useSafeArea = true,
  Offset? anchorPoint,
}) {
  final scheme = Theme.of(context).colorScheme;
  final resolvedBarrierColor = barrierColor ??
      scheme.scrim.withValues(alpha: KubusGlassEffects.backdropDimming);
  final resolvedBarrierLabel =
      barrierLabel ?? MaterialLocalizations.of(context).modalBarrierDismissLabel;

  // On web, BackdropFilter can crash when WebGL context is lost (Firefox).
  final useBackdropFilter = !kIsWeb || !kubusDisableBackdropFilter;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: resolvedBarrierLabel,
    barrierColor: resolvedBarrierColor,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    transitionDuration: transitionDuration,
    anchorPoint: anchorPoint,
    pageBuilder: (dialogContext, __, ___) {
      Widget content;
      if (useBackdropFilter) {
        content = BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: KubusGlassEffects.blurSigmaLight,
            sigmaY: KubusGlassEffects.blurSigmaLight,
          ),
          child: ColoredBox(
            color: Colors.transparent,
            child: Center(
              child: Builder(builder: (ctx) => builder(ctx)),
            ),
          ),
        );
      } else {
        content = ColoredBox(
          color: Colors.transparent,
          child: Center(
            child: Builder(builder: (ctx) => builder(ctx)),
          ),
        );
      }

      if (!useSafeArea) return content;
      return SafeArea(child: content);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// A reusable animated gradient background that provides subtle
/// movement and life to screens. Supports both dark and light modes.
class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;
  
  /// Duration of one full animation cycle
  final Duration duration;
  
  /// Whether to animate the gradient (set to false for static)
  final bool animate;
  
  /// Optional custom colors (defaults to theme-appropriate colors)
  final List<Color>? colors;

  /// Duration for smooth transitions when [colors] (or theme brightness)
  /// changes.
  final Duration paletteTransitionDuration;

  /// Optional hue shift in degrees applied subtly over time.
  ///
  /// This helps gradients feel more â€œaliveâ€ without requiring hardcoded
  /// multi-palette animations.
  final double hueShiftDegrees;
  
  /// Intensity of the animation (0.0 - 1.0)
  final double intensity;

  const AnimatedGradientBackground({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 8),
    this.animate = true,
    this.colors,
    this.intensity = 0.3,
    this.paletteTransitionDuration = const Duration(milliseconds: 900),
    this.hueShiftDegrees = 10.0,
  });

  @override
  State<AnimatedGradientBackground> createState() => _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
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
  void didUpdateWidget(AnimatedGradientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _motionController.duration = widget.duration;
    }
    if (widget.paletteTransitionDuration != oldWidget.paletteTransitionDuration) {
      _paletteController.duration = widget.paletteTransitionDuration;
    }
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
        _motionController.repeat(reverse: true);
      } else {
        _motionController.stop();
      }
    }

    // Palette transitions can be triggered by widget updates.
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
        final motionT = _motion.value;
        final progress = motionT * widget.intensity;
        
        // Animate alignment for subtle movement
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

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: effectivePalette,
              begin: beginOffset,
              end: endOffset,
              stops: _calculateStops(effectivePalette.length, progress),
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }

  List<double> _calculateStops(int count, double progress) {
    if (count <= 1) return const <double>[0.0];
    final List<double> stops = <double>[];
    for (int i = 0; i < count; i++) {
      final baseStop = i / (count - 1);
      // Add subtle movement to stops
      final offset = (i.isEven ? progress : -progress) * 0.1;
      stops.add((baseStop + offset).clamp(0.0, 1.0));
    }
    return stops;
  }

  void _syncPaletteIfNeeded({bool force = false}) {
    final desired = _resolveDesiredBasePalette(context);
    if (!force && _listEquals(desired, _paletteTo)) return;

    // Capture current palette as the starting point for a smooth transition.
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

    // Shift is subtle and oscillates with motion.
    final shift = (t - 0.5) * 2.0 * degrees * intensity;
    return colors
        .map((c) => _shiftHue(c, shift))
        .toList(growable: false);
  }

  static Color _shiftHue(Color color, double degrees) {
    if (color.a <= 0.0) return color;
    final hsl = HSLColor.fromColor(color);
    final newHue = (hsl.hue + degrees) % 360.0;
    return hsl.withHue(newHue < 0 ? newHue + 360.0 : newHue).toColor();
  }
}

/// A glassmorphism panel widget with blur backdrop and semi-transparent surface.
/// Perfect for cards, sidebars, and content containers that need depth.
class LiquidGlassPanel extends StatelessWidget {
  final Widget child;
  
  /// Padding inside the glass panel
  final EdgeInsetsGeometry? padding;
  
  /// Margin around the glass panel
  final EdgeInsetsGeometry? margin;
  
  /// Border radius of the panel
  final BorderRadius? borderRadius;
  
  /// Blur intensity (defaults to standard)
  final double blurSigma;
  
  /// Whether to show the border
  final bool showBorder;
  
  /// Custom background color (overrides theme-based)
  final Color? backgroundColor;
  
  /// Callback when tapped
  final VoidCallback? onTap;

  const LiquidGlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blurSigma = KubusGlassEffects.blurSigma,
    this.showBorder = true,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final effectiveRadius = borderRadius ?? BorderRadius.circular(KubusRadius.lg);
    
    final bgColor = backgroundColor ??
        (isDark
            ? KubusColors.surfaceDark.withValues(alpha: KubusGlassEffects.glassOpacityDark)
            : KubusColors.surfaceLight.withValues(alpha: KubusGlassEffects.glassOpacityLight));
    
    final borderColor = isDark
        ? KubusColors.glassBorderDark
        : KubusColors.glassBorderLight;

    // On web, BackdropFilter can crash when WebGL context is lost (Firefox).
    // Use a solid fallback background instead to prevent UI crashes.
    final useBackdropFilter = !kIsWeb || !kubusDisableBackdropFilter;

    final innerContainer = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            bgColor,
            bgColor.withValues(alpha: (bgColor.a * 0.8)),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: effectiveRadius,
        border: showBorder
            ? Border.all(
                color: borderColor,
                width: KubusSizes.hairline,
              )
            : null,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(KubusSpacing.md),
        child: child,
      ),
    );

    Widget panel = Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: useBackdropFilter
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: innerContainer,
              )
            : innerContainer,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveRadius,
          child: panel,
        ),
      );
    }

    return panel;
  }
}

/// A card-flavored alias of [LiquidGlassPanel] that uses the app's card radius
/// and a slightly calmer blur by default.
///
/// This is intentionally a thin wrapper so the glass logic stays in one place.
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double blurSigma;
  final bool showBorder;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blurSigma = KubusGlassEffects.blurSigmaLight,
    this.showBorder = true,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassPanel(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius ?? BorderRadius.circular(KubusRadius.md),
      blurSigma: blurSigma,
      showBorder: showBorder,
      backgroundColor: backgroundColor,
      onTap: onTap,
      child: child,
    );
  }
}

/// A lightweight frosted container used for small floating UI (badges, chips,
/// info panels). Defaults are tuned for compact content.
class FrostedContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double blurSigma;
  final bool showBorder;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const FrostedContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blurSigma = KubusGlassEffects.blurSigmaLight,
    this.showBorder = true,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassPanel(
      padding: padding ?? const EdgeInsets.all(KubusSpacing.sm),
      margin: margin,
      borderRadius: borderRadius ?? BorderRadius.circular(KubusRadius.sm),
      blurSigma: blurSigma,
      showBorder: showBorder,
      backgroundColor: backgroundColor,
      onTap: onTap,
      child: child,
    );
  }
}

/// A glass wrapper suitable for bottom sheets and floating "sheet" surfaces.
///
/// Use inside `showModalBottomSheet` builders so the sheet inherits the app's
/// glass rules (blur, border, opacity) without re-implementing them.
class BackdropGlassSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double blurSigma;
  final Color? backgroundColor;
  final bool showBorder;
  final bool showHandle;

  const BackdropGlassSheet({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.blurSigma = KubusGlassEffects.blurSigmaHeavy,
    this.backgroundColor,
    this.showBorder = true,
    this.showHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ??
        const BorderRadius.vertical(
          top: Radius.circular(KubusRadius.xl),
        );

    return SafeArea(
      top: false,
      child: LiquidGlassPanel(
        padding: padding ?? const EdgeInsets.all(KubusSpacing.lg),
        margin: EdgeInsets.zero,
        borderRadius: effectiveRadius,
        blurSigma: blurSigma,
        showBorder: showBorder,
        backgroundColor: backgroundColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHandle) ...[
              Container(
                height: KubusSpacing.xs,
                width: KubusSpacing.xl,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(KubusRadius.xl),
                ),
              ),
              const SizedBox(height: KubusSpacing.md),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// A frosted glass modal wrapper for dialogs and overlays
class FrostedModal extends StatelessWidget {
  final Widget child;
  
  /// Maximum width of the modal content
  final double? maxWidth;
  
  /// Padding inside the modal
  final EdgeInsetsGeometry? padding;
  
  /// Whether to close on tap outside
  final bool barrierDismissible;
  
  /// Callback when barrier is tapped
  final VoidCallback? onBarrierTap;

  const FrostedModal({
    super.key,
    required this.child,
    this.maxWidth = 500,
    this.padding,
    this.barrierDismissible = true,
    this.onBarrierTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // On web, BackdropFilter can crash when WebGL context is lost (Firefox).
    final useBackdropFilter = !kIsWeb || !kubusDisableBackdropFilter;

    Widget content = Center(
      child: GestureDetector(
        onTap: () {}, // Absorb taps on content
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? double.infinity,
          ),
          child: LiquidGlassPanel(
            padding: padding ?? const EdgeInsets.all(KubusSpacing.lg),
            blurSigma: KubusGlassEffects.blurSigmaHeavy,
            child: child,
          ),
        ),
      ),
    );

    if (useBackdropFilter) {
      content = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: KubusGlassEffects.blurSigmaLight,
          sigmaY: KubusGlassEffects.blurSigmaLight,
        ),
        child: content,
      );
    }

    return GestureDetector(
      onTap: barrierDismissible ? (onBarrierTap ?? () => Navigator.of(context).pop()) : null,
      child: Container(
        color: scheme.scrim.withValues(alpha: KubusGlassEffects.backdropDimming),
        child: content,
      ),
    );
  }
}

/// A subtle glass shimmer effect widget for premium look
class GlassShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final bool enabled;

  const GlassShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 3),
    this.enabled = true,
  });

  @override
  State<GlassShimmer> createState() => _GlassShimmerState();
}

class _GlassShimmerState extends State<GlassShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(GlassShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final base = KubusGradients.glassShimmer;
            return LinearGradient(
              colors: base.colors,
              stops: base.stops,
              begin: Alignment(-2.0 + (_controller.value * 4), -1.0),
              end: Alignment(-1.0 + (_controller.value * 4), 1.0),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A glass-first dialog surface matching Kubus liquid glass rules.
///
/// Prefer using this with [showKubusDialog] so dialogs also blur the background.
class KubusAlertDialog extends StatelessWidget {
  final Widget? icon;
  final EdgeInsetsGeometry? iconPadding;
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final EdgeInsets? insetPadding;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionsPadding;
  final MainAxisAlignment actionsAlignment;
  final bool scrollable;
  final double blurSigma;
  final bool showBorder;
  final Clip clipBehavior;
  final String? semanticLabel;
  final double? elevation;
  final TextStyle? titleTextStyle;
  final TextStyle? contentTextStyle;

  const KubusAlertDialog({
    super.key,
    this.icon,
    this.iconPadding,
    this.title,
    this.content,
    this.actions,
    this.backgroundColor,
    this.shape,
    this.insetPadding,
    this.titlePadding,
    this.contentPadding,
    this.actionsPadding,
    this.actionsAlignment = MainAxisAlignment.end,
    this.scrollable = false,
    this.blurSigma = KubusGlassEffects.blurSigmaHeavy,
    this.showBorder = true,
    this.clipBehavior = Clip.hardEdge,
    this.semanticLabel,
    this.elevation,
    this.titleTextStyle,
    this.contentTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final surface = backgroundColor ?? scheme.surface;
    final tint = (Color.lerp(surface, scheme.primary, 0.06) ?? surface)
        .withValues(alpha: isDark ? 0.22 : 0.14);

    final resolvedShape = shape ??
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KubusRadius.xl),
        );

    BorderRadius resolvedRadius = BorderRadius.circular(KubusRadius.xl);
    if (resolvedShape is RoundedRectangleBorder) {
      final borderRadius = resolvedShape.borderRadius;
      if (borderRadius is BorderRadius) {
        resolvedRadius = borderRadius;
      } else {
        resolvedRadius = BorderRadius.circular(KubusRadius.xl);
      }
    }

    final effectiveTitlePadding = titlePadding ??
        const EdgeInsets.fromLTRB(
          KubusSpacing.lg,
          KubusSpacing.lg,
          KubusSpacing.lg,
          KubusSpacing.sm,
        );

    final effectiveContentPadding = contentPadding ??
        const EdgeInsets.fromLTRB(
          KubusSpacing.lg,
          KubusSpacing.none,
          KubusSpacing.lg,
          KubusSpacing.lg,
        );

    final effectiveActionsPadding = actionsPadding ??
        const EdgeInsets.fromLTRB(
          KubusSpacing.lg,
          KubusSpacing.none,
          KubusSpacing.lg,
          KubusSpacing.lg,
        );

    final iconWidget = icon == null
        ? null
        : Padding(
            padding: iconPadding ??
                const EdgeInsets.fromLTRB(
                  KubusSpacing.lg,
                  KubusSpacing.lg,
                  KubusSpacing.lg,
                  KubusSpacing.none,
                ),
            child: IconTheme(
              data: IconThemeData(color: scheme.onSurface),
              child: icon!,
            ),
          );

    final titleWidget = title == null
        ? null
        : Padding(
            padding: effectiveTitlePadding,
            child: DefaultTextStyle.merge(
              style: (titleTextStyle ?? KubusTextStyles.screenTitle).copyWith(
                color: scheme.onSurface,
              ),
              child: title!,
            ),
          );

    final contentWidget = content == null
        ? null
        : Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              padding: effectiveContentPadding,
              child: DefaultTextStyle.merge(
                style: (contentTextStyle ?? (KubusTypography.textTheme.bodyMedium ?? const TextStyle())).copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.9),
                ),
                child: content!,
              ),
            ),
          );

    final actionsWidget = (actions == null || actions!.isEmpty)
        ? null
        : Padding(
            padding: effectiveActionsPadding,
            child: Row(
              mainAxisAlignment: actionsAlignment,
              children: actions!,
            ),
          );

    Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (iconWidget != null) iconWidget,
        if (titleWidget != null) titleWidget,
        if (contentWidget != null) contentWidget,
        if (actionsWidget != null) actionsWidget,
      ],
    );

    if (scrollable) {
      body = SingleChildScrollView(child: body);
    }

    Widget dialog = Dialog(
      backgroundColor: Colors.transparent,
      elevation: elevation ?? 0,
      insetPadding: insetPadding ?? const EdgeInsets.all(KubusSpacing.lg),
      clipBehavior: clipBehavior,
      shape: resolvedShape,
      child: LiquidGlassPanel(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: resolvedRadius,
        blurSigma: blurSigma,
        showBorder: showBorder,
        backgroundColor: tint,
        child: body,
      ),
    );

    if (semanticLabel != null && semanticLabel!.trim().isNotEmpty) {
      dialog = Semantics(
        scopesRoute: true,
        namesRoute: true,
        label: semanticLabel,
        child: dialog,
      );
    }

    return dialog;
  }
}
