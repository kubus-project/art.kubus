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

  TutorialStepDefinition get _step => steps[currentIndex];

  Rect? _targetRect(BuildContext context) {
    final key = _step.targetKey;
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final render = ctx.findRenderObject();
    if (render is! RenderBox) return null;
    if (!render.hasSize) return null;

    final offset = render.localToGlobal(Offset.zero);
    return offset & render.size;
  }

  bool _isInside(Rect rect, Offset point) {
    return point.dx >= rect.left &&
        point.dx <= rect.right &&
        point.dy >= rect.top &&
        point.dy <= rect.bottom;
  }

  @override
  Widget build(BuildContext context) {
    assert(steps.isNotEmpty);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final size = media.size;

    final rect = _targetRect(context);

    // Expand the highlight a bit so it feels forgiving.
    final highlightRect = rect?.inflate(10);

    // Tooltip sizing/position.
    // Keep this reasonably narrow so it doesn't feel like a full-width banner,
    // and so it can be positioned safely near right-edge targets.
    const double tooltipMaxWidth = 340;
    final double tooltipWidth = math.min(tooltipMaxWidth, size.width - 24);

    final EdgeInsets safe = media.padding;

    const double horizontalSafeMargin = 12;

    final double preferredCenteredX = (highlightRect != null)
      ? (highlightRect.center.dx - (tooltipWidth / 2))
      : ((size.width - tooltipWidth) / 2);

    final bool alignRightEdge = _step.tooltipAlignToTargetRightEdge;

    // If requested, align tooltip's RIGHT edge to the target's right edge.
    // Otherwise, center it; if centering would clamp on the right edge, fall
    // back to right-edge alignment to keep the association with the target.
    final bool wouldClampRight = highlightRect != null &&
      preferredCenteredX > (size.width - tooltipWidth - horizontalSafeMargin);

    final double preferredX = (highlightRect != null && (alignRightEdge || wouldClampRight))
      ? (highlightRect.right - tooltipWidth)
      : preferredCenteredX;

    final double tooltipX =
      preferredX.clamp(horizontalSafeMargin, size.width - tooltipWidth - horizontalSafeMargin);

    // Decide whether to place tooltip above or below highlight.
    final double spaceAbove = (highlightRect?.top ?? (size.height / 2)) - safe.top;
    final double spaceBelow = size.height - safe.bottom - (highlightRect?.bottom ?? (size.height / 2));

    final bool placeBelow = spaceBelow >= spaceAbove;
    final double tooltipY = () {
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
              if (!_isInside(highlightRect, details.globalPosition)) return;

              final onTargetTap = _step.onTargetTap;
              if (onTargetTap != null) onTargetTap();
              if (_step.advanceOnTargetTap && !isLast) {
                onNext();
              }
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
            title: _step.title,
            body: _step.body,
            icon: _step.icon,
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

  @override
  void paint(Canvas canvas, Size size) {
    final full = Rect.fromLTWH(0, 0, size.width, size.height);

    final overlayPath = Path()..addRect(full);
    final paint = Paint()..color = color;

    if (highlightRect == null) {
      canvas.drawPath(overlayPath, paint);
      return;
    }

    final rrect = RRect.fromRectAndRadius(
      highlightRect!,
      const Radius.circular(16),
    );

    final holePath = Path()..addRRect(rrect);
    final combined = Path.combine(PathOperation.difference, overlayPath, holePath);

    canvas.drawPath(combined, paint);

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
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: scheme.primary.withValues(alpha: 0.16),
                      border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
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
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
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
