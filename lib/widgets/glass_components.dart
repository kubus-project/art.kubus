import 'package:flutter/material.dart';
import 'dart:ui';
import '../utils/design_tokens.dart';

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
  
  /// Intensity of the animation (0.0 - 1.0)
  final double intensity;

  const AnimatedGradientBackground({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 8),
    this.animate = true,
    this.colors,
    this.intensity = 0.3,
  });

  @override
  State<AnimatedGradientBackground> createState() => _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedGradientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
        _controller.repeat(reverse: true);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColors = widget.colors ??
        (isDark ? KubusGradients.animatedDarkColors : KubusGradients.animatedLightColors);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = _animation.value * widget.intensity;
        
        // Animate alignment for subtle movement
        final beginOffset = Alignment(
          -1.0 + (progress * 0.5),
          -1.0 + (progress * 0.3),
        );
        final endOffset = Alignment(
          1.0 - (progress * 0.3),
          1.0 - (progress * 0.5),
        );

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: baseColors,
              begin: beginOffset,
              end: endOffset,
              stops: _calculateStops(baseColors.length, progress),
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }

  List<double> _calculateStops(int count, double progress) {
    final List<double> stops = [];
    for (int i = 0; i < count; i++) {
      final baseStop = i / (count - 1);
      // Add subtle movement to stops
      final offset = (i.isEven ? progress : -progress) * 0.1;
      stops.add((baseStop + offset).clamp(0.0, 1.0));
    }
    return stops;
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

    Widget panel = Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
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
                      width: 1.0,
                    )
                  : null,
            ),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(KubusSpacing.md),
              child: child,
            ),
          ),
        ),
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
    return GestureDetector(
      onTap: barrierDismissible ? (onBarrierTap ?? () => Navigator.of(context).pop()) : null,
      child: Container(
        color: Colors.black.withValues(alpha: KubusGlassEffects.backdropDimming),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: KubusGlassEffects.blurSigmaLight,
            sigmaY: KubusGlassEffects.blurSigmaLight,
          ),
          child: Center(
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
          ),
        ),
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
            return LinearGradient(
              colors: const [
                Color(0x00FFFFFF),
                Color(0x20FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: const [0.0, 0.5, 1.0],
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
