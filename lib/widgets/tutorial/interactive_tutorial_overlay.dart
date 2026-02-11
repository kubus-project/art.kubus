import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../glass_components.dart';

class TutorialStepDefinition {
  final GlobalKey? targetKey;
  final String title;
  final String body;
  final IconData? icon;

  /// If provided, tapping the highlighted region will invoke this.
  final VoidCallback? onTargetTap;

  /// If true, tapping the highlighted region also advances to next step.
  final bool advanceOnTargetTap;

  /// If true, the tooltip card aligns its RIGHT edge to the target's right edge
  /// (useful for UI controls anchored near the window's right edge).
  final bool tooltipAlignToTargetRightEdge;

  const TutorialStepDefinition({
    required this.title,
    required this.body,
    this.targetKey,
    this.icon,
    this.onTargetTap,
    this.advanceOnTargetTap = true,
    this.tooltipAlignToTargetRightEdge = false,
  });
}

/// Full-screen coach-mark overlay that highlights a target widget (via [GlobalKey])
/// and renders a liquid-glass tooltip card with step controls.
class InteractiveTutorialOverlay extends StatelessWidget {
  final List<TutorialStepDefinition> steps;
  final int currentIndex;

  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  final String skipLabel;
  final String backLabel;
  final String nextLabel;
  final String doneLabel;

  const InteractiveTutorialOverlay({
    super.key,
    required this.steps,
    required this.currentIndex,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    required this.skipLabel,
    required this.backLabel,
    required this.nextLabel,
    required this.doneLabel,
  });

  bool _isRectUsable(Rect rect) {
    if (!rect.left.isFinite ||
        !rect.top.isFinite ||
        !rect.right.isFinite ||
        !rect.bottom.isFinite) {
      return false;
    }
    if (rect.width <= 0 || rect.height <= 0) return false;
    // Reject pathological values that can appear during transient web layouts.
    const maxAbs = 1e7;
    if (rect.left.abs() > maxAbs ||
        rect.top.abs() > maxAbs ||
        rect.right.abs() > maxAbs ||
        rect.bottom.abs() > maxAbs) {
      return false;
    }
    return true;
  }

  Rect? _targetRect(
    BuildContext context,
    TutorialStepDefinition step,
  ) {
    final key = step.targetKey;
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null || !ctx.mounted) return null;

    RenderObject? rawRender;
    try {
      rawRender = ctx.findRenderObject();
    } catch (_) {
      return null;
    }
    final render = rawRender;
    if (render is! RenderBox) return null;
    if (!render.attached) return null;
    if (!render.hasSize) return null;
    final size = render.size;
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return null;
    }

    try {
      final offset = render.localToGlobal(Offset.zero);
      if (!offset.dx.isFinite || !offset.dy.isFinite) return null;
      final rect = offset & size;
      if (!_isRectUsable(rect)) return null;
      return rect;
    } catch (_) {
      // Web can briefly surface detached/invalid transforms during layout.
      return null;
    }
  }

  bool _isInside(Rect rect, Offset point) {
    return point.dx >= rect.left &&
        point.dx <= rect.right &&
        point.dy >= rect.top &&
        point.dy <= rect.bottom;
  }

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    if (currentIndex < 0 || currentIndex >= steps.length) {
      return const SizedBox.shrink();
    }
    final step = steps[currentIndex];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final size = media.size;
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return const SizedBox.shrink();
    }

    final rect = _targetRect(context, step);

    // Expand the highlight a bit so it feels forgiving.
    final inflated = rect?.inflate(10);
    final highlightRect =
        inflated != null && _isRectUsable(inflated) ? inflated : null;

    // Tooltip sizing/position.
    // Keep this reasonably narrow so it doesn't feel like a full-width banner,
    // and so it can be positioned safely near right-edge targets.
    const double tooltipMaxWidth = 340;
    final availableWidth = math.max(0.0, size.width - 24);
    if (!availableWidth.isFinite || availableWidth <= 0) {
      return const SizedBox.shrink();
    }
    final double tooltipWidth = math
        .min(tooltipMaxWidth, availableWidth)
        .clamp(1.0, tooltipMaxWidth)
        .toDouble();

    final EdgeInsets safe = media.padding;

    const double horizontalSafeMargin = 12;

    final double preferredCenteredX = (highlightRect != null)
        ? (highlightRect.center.dx - (tooltipWidth / 2))
        : ((size.width - tooltipWidth) / 2);

    final bool alignRightEdge = step.tooltipAlignToTargetRightEdge;

    // If requested, align tooltip's RIGHT edge to the target's right edge.
    // Otherwise, center it; if centering would clamp on the right edge, fall
    // back to right-edge alignment to keep the association with the target.
    final bool wouldClampRight = highlightRect != null &&
        preferredCenteredX > (size.width - tooltipWidth - horizontalSafeMargin);

    final double preferredX =
        (highlightRect != null && (alignRightEdge || wouldClampRight))
            ? (highlightRect.right - tooltipWidth)
            : preferredCenteredX;

    final minX = horizontalSafeMargin;
    final maxX = math.max(
        horizontalSafeMargin, size.width - tooltipWidth - horizontalSafeMargin);
    final double tooltipX =
        preferredX.isFinite ? preferredX.clamp(minX, maxX).toDouble() : minX;

    // Decide whether to place tooltip above or below highlight.
    final double spaceAbove =
        (highlightRect?.top ?? (size.height / 2)) - safe.top;
    final double spaceBelow = size.height -
        safe.bottom -
        (highlightRect?.bottom ?? (size.height / 2));

    final bool placeBelow = spaceBelow >= spaceAbove;
    final rawTooltipY = () {
      if (highlightRect == null) {
        return safe.top + 84;
      }
      if (placeBelow) {
        return math.min(
          highlightRect.bottom + 14,
          size.height - safe.bottom - 220,
        );
      }
      return math.max(
        safe.top + 14,
        highlightRect.top - 14 - 220,
      );
    }();
    final minY = safe.top + 14;
    final maxY = math.max(minY, size.height - safe.bottom - 220);
    final double tooltipY =
        rawTooltipY.isFinite ? rawTooltipY.clamp(minY, maxY).toDouble() : minY;

    final isLast = currentIndex == steps.length - 1;
    final stepLabel = '${currentIndex + 1}/${steps.length}';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              if (highlightRect == null) return;
              final globalPosition = details.globalPosition;
              if (!globalPosition.dx.isFinite || !globalPosition.dy.isFinite) {
                return;
              }
              if (!_isInside(highlightRect, globalPosition)) return;

              final onTargetTap = step.onTargetTap;
              final shouldAdvance = step.advanceOnTargetTap && !isLast;
              if (onTargetTap == null && !shouldAdvance) return;

              // Web pointer dispatch can become unstable if tutorial callbacks
              // mutate layout synchronously during the active tap sequence.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                onTargetTap?.call();
                if (shouldAdvance) {
                  onNext();
                }
              });
            },
            child: CustomPaint(
              painter: _CoachMarkPainter(
                highlightRect: highlightRect,
                color: Colors.black.withValues(alpha: 0.55),
                accent: scheme.primary,
              ),
            ),
          ),
        ),

        // Skip button
        Positioned(
          top: safe.top + 10,
          right: 12,
          child: _GlassActionChip(
            label: skipLabel,
            onTap: onSkip,
          ),
        ),

        // Tooltip
        Positioned(
          left: tooltipX,
          top: tooltipY,
          width: tooltipWidth,
          child: _TutorialTooltipCard(
            title: step.title,
            body: step.body,
            icon: step.icon,
            stepLabel: stepLabel,
            backLabel: backLabel,
            nextLabel: isLast ? doneLabel : nextLabel,
            showBack: currentIndex > 0,
            onBack: onBack,
            onNext: onNext,
          ),
        ),
      ],
    );
  }
}

class _CoachMarkPainter extends CustomPainter {
  final Rect? highlightRect;
  final Color color;
  final Color accent;

  _CoachMarkPainter({
    required this.highlightRect,
    required this.color,
    required this.accent,
  });

  bool _isRectUsable(Rect rect) {
    return rect.left.isFinite &&
        rect.top.isFinite &&
        rect.right.isFinite &&
        rect.bottom.isFinite &&
        rect.width > 0 &&
        rect.height > 0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }
    final full = Rect.fromLTWH(0, 0, size.width, size.height);

    final overlayPath = Path()..addRect(full);
    final paint = Paint()..color = color;

    if (highlightRect == null || !_isRectUsable(highlightRect!)) {
      canvas.drawPath(overlayPath, paint);
      return;
    }

    try {
      final rrect = RRect.fromRectAndRadius(
        highlightRect!,
        const Radius.circular(16),
      );
      final maskedPath = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(full)
        ..addRRect(rrect);

      canvas.drawPath(maskedPath, paint);

      // Accent ring around the hole.
      final ringPaint = Paint()
        ..color = accent.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRRect(rrect, ringPaint);

      // Soft glow
      final glowPaint = Paint()
        ..color = accent.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

      canvas.drawRRect(rrect, glowPaint);
    } catch (_) {
      // On web, invalid transient geometry should fall back to a plain scrim.
      canvas.drawPath(overlayPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CoachMarkPainter oldDelegate) {
    return oldDelegate.highlightRect != highlightRect ||
        oldDelegate.color != color ||
        oldDelegate.accent != accent;
  }
}

class _TutorialTooltipCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData? icon;
  final String stepLabel;

  final String backLabel;
  final String nextLabel;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _TutorialTooltipCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.stepLabel,
    required this.backLabel,
    required this.nextLabel,
    required this.showBack,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bg = scheme.surface.withValues(alpha: isDark ? 0.52 : 0.62);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.18),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: LiquidGlassPanel(
          padding: const EdgeInsets.all(14),
          margin: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(18),
          blurSigma: KubusGlassEffects.blurSigmaLight,
          showBorder: false,
          backgroundColor: bg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: scheme.primary, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: KubusTypography.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: scheme.primary.withValues(alpha: 0.16),
                      border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      stepLabel,
                      style: KubusTypography.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: KubusTypography.textTheme.bodyMedium?.copyWith(
                  height: 1.35,
                  color: scheme.onSurface.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (showBack)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onBack,
                        child: Text(backLabel),
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                      ),
                      child: Text(nextLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GlassActionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.14),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LiquidGlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(999),
        showBorder: false,
        backgroundColor: scheme.surface.withValues(alpha: isDark ? 0.44 : 0.52),
        onTap: onTap,
        child: Text(
          label,
          style: KubusTypography.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
