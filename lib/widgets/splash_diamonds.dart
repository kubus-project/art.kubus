import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_logo.dart';
import 'package:art_kubus/providers/themeprovider.dart';

class SplashDiamonds extends StatefulWidget {
  final Color? accent;
  final int? seed;
  const SplashDiamonds({super.key, this.accent, this.seed});

  @override
  State<SplashDiamonds> createState() => _SplashDiamondsState();
}

class _SplashDiamondsState extends State<SplashDiamonds> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final int _seed;
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();
    _seed = widget.seed ?? (DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF);
    // Longer duration for a slower, more flowy sequence
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 280),
    )..repeat();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _logoScale = CurvedAnimation(parent: _logoController, curve: Curves.elasticOut);
    // Bounce in once
    _logoController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.accent ?? theme.colorScheme.primary;
    final baseBackground = theme.colorScheme.surface;
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.maybeOf(context);
        final mediaSize = mediaQuery?.size ?? const Size(800, 600);
        double sanitizeDimension(double candidate, double fallback) {
          if (candidate.isNaN || !candidate.isFinite || candidate <= 0) {
            return fallback;
          }
          return candidate;
        }

        final fallbackWidth = mediaSize.width.isFinite && mediaSize.width > 0 ? mediaSize.width : 800.0;
        final fallbackHeight = mediaSize.height.isFinite && mediaSize.height > 0 ? mediaSize.height : 600.0;
        final width = sanitizeDimension(
          constraints.hasBoundedWidth ? constraints.maxWidth : mediaSize.width,
          fallbackWidth,
        );
        final height = sanitizeDimension(
          constraints.hasBoundedHeight ? constraints.maxHeight : mediaSize.height,
          fallbackHeight,
        );

        final size = Size(width, height);
        // Build visible tile list once here (per layout) and generate a
        // random order to drive the lighting. This keeps paint cheap and
        // guarantees truly random tiles light up across the screen.
        return SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
            Builder(builder: (ctx) {
              final shortestSide = min(size.width, size.height);
              final baseSide = shortestSide.isFinite && shortestSide > 0 ? shortestSide : min(fallbackWidth, fallbackHeight);
              final tileSize = (baseSide / 44.0).clamp(6.0, 24.0);
              final isoW = tileSize;
              final isoH = tileSize * 0.5;
              final cx = size.width * 0.5;
              final cy = size.height * 0.5;
              final maxDist = sqrt(cx * cx + cy * cy) + tileSize * 6.0;
              final steps = (maxDist / isoW).ceil() + 6;

              final List<Map<String, dynamic>> tiles = [];
              for (int j = -steps; j < steps; j++) {
                for (int i = -steps; i < steps; i++) {
                  final x = cx + (i - j) * isoW;
                  final y = cy + (i + j) * isoH;
                  if (x < -tileSize || x > size.width + tileSize || y < -tileSize || y > size.height + tileSize) continue;
                  tiles.add({'i': i, 'j': j, 'x': x, 'y': y});
                }
              }

              // Build a random order (shuffled indices). If a seed was
              // provided use it for deterministic shuffling, otherwise use
              // an unseeded Random for true randomness each run.
              final rng = widget.seed != null ? Random(widget.seed) : Random();
              final order = List<int>.generate(tiles.length, (k) => k);
              order.shuffle(rng);

              return CustomPaint(
                size: size,
                painter: _DiamondsGridPainter(
                  accent: accentColor,
                  background: baseBackground,
                  seed: _seed,
                  animation: _controller,
                  tiles: tiles,
                  order: order,
                ),
              );
            }),
            Center(
              child: ScaleTransition(
                scale: _logoScale,
                child: Builder(builder: (ctx) {
                  // Guard AppLogo with provider existence check to avoid ProviderNotFoundException
                  try {
                    // Attempt to read ThemeProvider without listening; will throw if not found
                    ctx.read<ThemeProvider>();
                    return SizedBox(
                      width: min(size.width, size.height) * 0.22,
                      height: min(size.width, size.height) * 0.22,
                      child: const AppLogo(),
                    );
                  } catch (_) {
                    return const SizedBox.shrink();
                  }
                }),
              ),
            ),
          ],
          ),
        );
      },
    );
  }
}

class _DiamondsGridPainter extends CustomPainter {
  final Color accent;
  final Color background;
  final int seed;
  final Animation<double> animation;
  final List<Map<String, dynamic>> tiles;
  final List<int> order;

  _DiamondsGridPainter({
    required this.accent,
    required this.background,
    required this.seed,
    required this.animation,
    required this.tiles,
    required this.order,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..style = PaintingStyle.fill..color = background;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final t = animation.value; // 0..1
    final painterSide = min(size.width, size.height);
    final safeSide = painterSide.isFinite && painterSide > 0 ? painterSide : 800.0;
    final tileSize = (safeSide / 44.0).clamp(6.0, 24.0);
    final isoW = tileSize;
    final isoH = tileSize * 0.5;
    final tileList = tiles;
    final totalVisible = tileList.isEmpty ? 1 : tileList.length;

    // Build reverse lookup: tile index -> position in shuffled order. This
    // lets us compute distance in order-space cheaply per tile.
    final tv = totalVisible;
    final posInOrder = <int, int>{};
    for (int k = 0; k < order.length; k++) {
      posInOrder[order[k]] = k;
    }

    // Activation phase: during the first fraction of the animation we
    // progressively turn tiles on one-by-one in the shuffled order. After
    // the activation phase all tiles remain lit.
    const double activationPhase = 0.6; // fraction of first loop used to activate all tiles (larger = slower)
    final globalActivate = (t / activationPhase) * tv; // how many tiles should be activated (float)

    // Spark / easing animation: a very slow float position that eases in/out
    // and gives nearby tiles a temporary boost so lighting has a gentle
    // eased motion even after activation.
    final sparkRoundsPerAnimation = 0.06; // very slow traversal across the order list
    final seedOffset = (seed & 0x7FFFFFFF) % tv;
    final sparkFloatPos = (t * tv * sparkRoundsPerAnimation) + seedOffset;
    final sparkCenter = sparkFloatPos % tv;
    final sparkProgressWithin = sparkFloatPos - sparkFloatPos.floorToDouble();
    final sparkEased = Curves.easeInOut.transform(sparkProgressWithin.clamp(0.0, 1.0));

    for (int idx = 0; idx < tileList.length; idx++) {
      final tile = tileList[idx];
      final x = tile['x'] as double;
      final y = tile['y'] as double;
      final i = tile['i'] as int;
      final j = tile['j'] as int;
      final orderPos = posInOrder[idx] ?? idx;
      // Determine activation progress for this tile (0 = off, 1 = fully on)
      final tileProgress = globalActivate - orderPos;
      // Make per-tile fade much slower by using a multi-tile fade window.
      // Increasing this value slows the ease-in for each tile.
      const double tileFadeWindow = 6.0; // number of 'tile steps' over which a tile fades in
      double tileOnFraction;
      if (tileProgress <= 0.0) {
        tileOnFraction = 0.0; // not yet activated
      } else if (tileProgress < tileFadeWindow) {
        final frac = (tileProgress / tileFadeWindow).clamp(0.0, 1.0);
        tileOnFraction = Curves.easeOut.transform(frac);
      } else {
        tileOnFraction = 1.0; // fully activated
      }

      // Compute base activation opacity that eases from 0 -> 1 then falls to 0.9
      // at the end of activation. This gives a visible peak and a gentle
      // settle to 90%.
      final double p = tileOnFraction.clamp(0.0, 1.0);
      const double pPeak = 0.85;
      double baseOpacity;
      if (p <= 0.0) {
        baseOpacity = 0.0;
      } else if (p < pPeak) {
        baseOpacity = Curves.easeOut.transform((p / pPeak).clamp(0.0, 1.0));
      } else {
        final rem = ((p - pPeak) / (1.0 - pPeak)).clamp(0.0, 1.0);
        baseOpacity = 1.0 - 0.1 * Curves.easeIn.transform(rem); // falls to 0.9
      }

      // Spark distance in order-space and gaussian falloff
      double ds = (orderPos - sparkCenter).abs();
      if (ds > tv / 2) ds = (tv - ds);
      final double sparkSigma = max(1.0, tv * 0.012);
      final double sparkIntensity = exp(- (ds * ds) / (2 * sparkSigma * sparkSigma));
      final double sparkBoost = p * sparkEased * sparkIntensity * 0.9;

      // Blend spark on top of base opacity, without exceeding 1.0
      final double finalIntensity = min(1.0, baseOpacity + (1.0 - baseOpacity) * sparkBoost);

      if (finalIntensity > 0.01) {
        final key = (seed ^ (i * 73856093) ^ (j * 19349663)) & 0x7FFFFFFF;
        final rnd = Random(key);
        final baseHsl = HSLColor.fromColor(accent);
        final sat = (baseHsl.saturation * (0.85 + 0.2 * rnd.nextDouble())).clamp(0.5, 1.0);
        final light = (baseHsl.lightness * (0.45 + 0.4 * rnd.nextDouble())).clamp(0.25, 0.95);
        final color = baseHsl.withSaturation(sat).withLightness(light).toColor();
        final opacity = 0.12 + 0.88 * finalIntensity;
        final paint = Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: opacity);

        final path = Path();
        path.moveTo(x, y - isoH);
        path.lineTo(x + isoW, y);
        path.lineTo(x, y + isoH);
        path.lineTo(x - isoW, y);
        path.close();
        canvas.drawPath(path, paint);
      } else {
        final inactivePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..color = accent.withValues(alpha: 0.03);
        final path = Path();
        path.moveTo(x, y - isoH);
        path.lineTo(x + isoW, y);
        path.lineTo(x, y + isoH);
        path.lineTo(x - isoW, y);
        path.close();
        canvas.drawPath(path, inactivePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DiamondsGridPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.background != background ||
        oldDelegate.seed != seed;
  }
}
