import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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

  /// If true, tapping the highlighted region on the last step completes it.
  ///
  /// Last-step target taps are visual-only by default so accidental map/control
  /// taps cannot silently dismiss and persist the tutorial.
  final bool dismissOnTargetTapWhenLast;

  /// If true, the tooltip card aligns its RIGHT edge to the target's right edge
  /// (useful for UI controls anchored near the window's right edge).
  final bool tooltipAlignToTargetRightEdge;

  const TutorialStepDefinition({
    required this.title,
    required this.body,
    this.targetKey,
    this.icon,
    this.onTargetTap,
    this.advanceOnTargetTap = false,
    this.dismissOnTargetTapWhenLast = false,
    this.tooltipAlignToTargetRightEdge = false,
  });
}

/// Full-screen coach-mark overlay that highlights a target widget (via [GlobalKey])
/// and renders a liquid-glass tooltip card with step controls.
class InteractiveTutorialOverlay extends StatefulWidget {
  final List<TutorialStepDefinition> steps;
  final int currentIndex;
  final String sessionKey;

  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  final String skipLabel;
  final String backLabel;
  final String nextLabel;
  final String doneLabel;

  const InteractiveTutorialOverlay({
    super.key,
    this.sessionKey = 'default',
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

  /// Root widget key for tests.
  static const Key overlayRootKey =
      ValueKey<String>('kubus_tutorial_overlay_root');

  /// Tooltip card key for tests.
  static const Key tooltipKey = ValueKey<String>('kubus_tutorial_tooltip');

  /// Highlight tap region key for tests.
  static const Key highlightTapRegionKey =
      ValueKey<String>('kubus_tutorial_highlight_tap_region');

  /// Full-screen modal pointer gate key for tests.
  static const Key modalPointerGateKey =
      ValueKey<String>('kubus_tutorial_modal_pointer_gate');

  @override
  State<InteractiveTutorialOverlay> createState() =>
      _InteractiveTutorialOverlayState();
}

class _InteractiveTutorialOverlayState extends State<InteractiveTutorialOverlay>
    with WidgetsBindingObserver {
  static const int _maxGeometryRetryCount = 30;

  Rect? _lastValidTargetRectGlobal;
  Rect? _lastValidTargetRectLocal;
  int _geometryRetryCount = 0;
  bool _geometryRetryScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant InteractiveTutorialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionKey != widget.sessionKey) {
      _debugLog(
        'sessionChanged old=${oldWidget.sessionKey} '
        'new=${widget.sessionKey}; clearing cached geometry',
      );
      _clearCachedGeometry();
      return;
    }
    if (widget.steps.isEmpty && oldWidget.steps.isNotEmpty) {
      _debugLog('stepsEmpty: clearing cached geometry');
      _clearCachedGeometry();
      return;
    }
    if (oldWidget.currentIndex != widget.currentIndex) {
      _debugLog(
        'stepChanged oldIndex=${oldWidget.currentIndex} '
        'newIndex=${widget.currentIndex}; clearing cached geometry',
      );
      _clearCachedGeometry();
    }
  }

  @override
  void didChangeMetrics() {
    _debugLog('didChangeMetrics: scheduling geometry refresh');
    _scheduleGeometryRetry(reason: 'metrics');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _debugLog('didChangeAppLifecycleState: state=$state');
    if (state == AppLifecycleState.resumed) {
      _scheduleGeometryRetry(reason: 'lifecycle-resumed');
    }
  }

  @override
  void dispose() {
    _clearCachedGeometry();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _clearCachedGeometry() {
    _lastValidTargetRectGlobal = null;
    _lastValidTargetRectLocal = null;
    _geometryRetryCount = 0;
    _geometryRetryScheduled = false;
  }

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

  Rect? _targetRectGlobal(TutorialStepDefinition step) {
    final key = step.targetKey;
    if (key == null) {
      _debugLog('targetRect: no targetKey step="${step.title}"');
      return null;
    }
    final ctx = key.currentContext;
    if (ctx == null || !ctx.mounted) {
      _debugLog(
        'targetRect: missing context mounted=${ctx?.mounted} '
        'step="${step.title}"',
      );
      return null;
    }

    RenderObject? rawRender;
    try {
      rawRender = ctx.findRenderObject();
    } catch (error) {
      _debugLog('targetRect: findRenderObject failed error=$error');
      return null;
    }
    final render = rawRender;
    if (render is! RenderBox) {
      _debugLog(
          'targetRect: render is not RenderBox type=${render.runtimeType}');
      return null;
    }
    if (!render.attached || !render.hasSize) {
      _debugLog(
        'targetRect: invalid render attached=${render.attached} '
        'hasSize=${render.hasSize} step="${step.title}"',
      );
      return null;
    }
    final size = render.size;
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      _debugLog('targetRect: invalid size=$size step="${step.title}"');
      return null;
    }

    try {
      final offset = render.localToGlobal(Offset.zero);
      if (!offset.dx.isFinite || !offset.dy.isFinite) {
        _debugLog('targetRect: invalid offset=$offset step="${step.title}"');
        return null;
      }
      final rect = offset & size;
      if (!_isRectUsable(rect)) {
        _debugLog('targetRect: unusable rect=$rect step="${step.title}"');
        return null;
      }
      _debugLog('targetRect: valid global=$rect step="${step.title}"');
      return rect;
    } catch (error) {
      // Web can briefly surface detached/invalid transforms during layout.
      _debugLog('targetRect: localToGlobal failed error=$error');
      return null;
    }
  }

  Rect? _convertGlobalRectToLocal({
    required Rect globalRect,
    required RenderBox overlayBox,
  }) {
    if (!overlayBox.attached || !overlayBox.hasSize) {
      _debugLog(
        'overlayBox: invalid attached=${overlayBox.attached} '
        'hasSize=${overlayBox.hasSize}',
      );
      return null;
    }

    try {
      final topLeft = overlayBox.globalToLocal(globalRect.topLeft);
      final bottomRight = overlayBox.globalToLocal(globalRect.bottomRight);
      if (!topLeft.dx.isFinite ||
          !topLeft.dy.isFinite ||
          !bottomRight.dx.isFinite ||
          !bottomRight.dy.isFinite) {
        _debugLog(
          'rectLocal: invalid points topLeft=$topLeft '
          'bottomRight=$bottomRight',
        );
        return null;
      }
      final rect = Rect.fromPoints(topLeft, bottomRight);
      if (!_isRectUsable(rect)) {
        _debugLog('rectLocal: unusable rect=$rect');
        return null;
      }
      return rect;
    } catch (error) {
      _debugLog('rectLocal: conversion failed error=$error');
      return null;
    }
  }

  void _scheduleGeometryRetry({required String reason}) {
    if (!mounted) return;
    if (_geometryRetryScheduled) return;
    if (_geometryRetryCount >= _maxGeometryRetryCount) {
      _debugLog(
        'geometryRetry: max reached reason=$reason '
        'count=$_geometryRetryCount',
      );
      return;
    }
    _geometryRetryScheduled = true;
    _geometryRetryCount += 1;
    _debugLog(
      'geometryRetry: scheduled reason=$reason count=$_geometryRetryCount',
    );
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return;
      _geometryRetryScheduled = false;
      _debugLog(
        'geometryRetry: repaint reason=$reason count=$_geometryRetryCount',
      );
      setState(() {});
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) {
      _debugLog('build: returning shrink reason=empty-steps');
      return const SizedBox.shrink();
    }
    if (widget.currentIndex < 0 || widget.currentIndex >= widget.steps.length) {
      _debugLog(
        'build: returning shrink reason=invalid-index '
        'index=${widget.currentIndex} steps=${widget.steps.length}',
      );
      return const SizedBox.shrink();
    }
    final step = widget.steps[widget.currentIndex];
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final media = MediaQuery.of(context);
        final size = constraints.biggest;
        if (!size.width.isFinite ||
            !size.height.isFinite ||
            size.width <= 0 ||
            size.height <= 0) {
          _debugLog(
            'build: returning shrink reason=invalid-layout-size size=$size',
          );
          return const SizedBox.shrink();
        }

        final overlayRender = context.findRenderObject();
        final overlayBox = overlayRender is RenderBox &&
                overlayRender.attached &&
                overlayRender.hasSize
            ? overlayRender
            : null;

        final rectGlobal = _targetRectGlobal(step);
        final currentRectLocal = (rectGlobal != null && overlayBox != null)
            ? _convertGlobalRectToLocal(
                globalRect: rectGlobal,
                overlayBox: overlayBox,
              )
            : null;

        Rect? rectLocal = currentRectLocal;
        if (rectGlobal != null && currentRectLocal != null) {
          _lastValidTargetRectGlobal = rectGlobal;
          _lastValidTargetRectLocal = currentRectLocal;
          _geometryRetryCount = 0;
        } else if (_lastValidTargetRectGlobal != null && overlayBox != null) {
          rectLocal = _convertGlobalRectToLocal(
                globalRect: _lastValidTargetRectGlobal!,
                overlayBox: overlayBox,
              ) ??
              _lastValidTargetRectLocal;
          _debugLog(
            'geometry: using cached rect global=$_lastValidTargetRectGlobal '
            'local=$rectLocal',
          );
        } else if (_lastValidTargetRectLocal != null) {
          rectLocal = _lastValidTargetRectLocal;
          _debugLog('geometry: using cached local rect=$rectLocal');
        }

        final targetHasContext = step.targetKey?.currentContext != null;
        final currentGeometryValid = rectGlobal != null &&
            currentRectLocal != null &&
            _isRectUsable(currentRectLocal);
        if (!currentGeometryValid && targetHasContext) {
          _scheduleGeometryRetry(reason: 'invalid-target-geometry');
        }

        // Expand the highlight a bit so it feels forgiving.
        final inflated = rectLocal?.inflate(10);
        final highlightRect =
            inflated != null && _isRectUsable(inflated) ? inflated : null;
        _debugLog(
          'buildGeometry index=${widget.currentIndex} step="${step.title}" '
          'targetHasContext=$targetHasContext '
          'overlayBoxValid=${overlayBox != null} '
          'rectGlobalValid=${rectGlobal != null} '
          'rectLocalValid=${rectLocal != null} '
          'highlightValid=${highlightRect != null}',
        );

        // Tooltip sizing/position.
        // Keep this reasonably narrow so it doesn't feel like a full-width banner,
        // and so it can be positioned safely near right-edge targets.
        const double tooltipMaxWidth = 340;
        final availableWidth = math.max(0.0, size.width - 24);
        if (!availableWidth.isFinite || availableWidth <= 0) {
          _debugLog(
            'build: returning shrink reason=invalid-available-width '
            'availableWidth=$availableWidth',
          );
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
            preferredCenteredX >
                (size.width - tooltipWidth - horizontalSafeMargin);

        final double preferredX =
            (highlightRect != null && (alignRightEdge || wouldClampRight))
                ? (highlightRect.right - tooltipWidth)
                : preferredCenteredX;

        final minX = horizontalSafeMargin;
        final maxX = math.max(horizontalSafeMargin,
            size.width - tooltipWidth - horizontalSafeMargin);
        final double tooltipX = preferredX.isFinite
            ? preferredX.clamp(minX, maxX).toDouble()
            : minX;

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
        final double tooltipY = rawTooltipY.isFinite
            ? rawTooltipY.clamp(minY, maxY).toDouble()
            : minY;
        _debugLog(
          'tooltip: x=$tooltipX y=$tooltipY width=$tooltipWidth '
          'highlight=${highlightRect != null}',
        );

        final isLast = widget.currentIndex == widget.steps.length - 1;
        final stepLabel = '${widget.currentIndex + 1}/${widget.steps.length}';

        void handleTargetTap() {
          final onTargetTap = step.onTargetTap;
          final shouldAdvance = step.advanceOnTargetTap && !isLast;
          final shouldDismiss = step.dismissOnTargetTapWhenLast && isLast;
          _debugLog(
            'targetTap index=${widget.currentIndex} step="${step.title}" '
            'isLast=$isLast advanceOnTargetTap=${step.advanceOnTargetTap} '
            'dismissOnTargetTapWhenLast=${step.dismissOnTargetTapWhenLast} '
            'hasOnTargetTap=${onTargetTap != null} '
            'willCallOnNext=${shouldAdvance || shouldDismiss}',
          );
          if (onTargetTap == null && !shouldAdvance && !shouldDismiss) return;

          // Web pointer dispatch can become unstable if tutorial callbacks
          // mutate layout synchronously during the active tap sequence.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _debugLog(
              'targetTapCallback index=${widget.currentIndex} step="${step.title}" '
              'callingOnTargetTap=${onTargetTap != null} '
              'callingOnNext=${shouldAdvance || shouldDismiss}',
            );
            onTargetTap?.call();
            if (shouldAdvance || shouldDismiss) {
              widget.onNext();
            }
          });
          WidgetsBinding.instance.scheduleFrame();
        }

        final shouldHandleTargetTap = highlightRect != null &&
            (step.onTargetTap != null ||
                step.advanceOnTargetTap ||
                step.dismissOnTargetTapWhenLast);

        void handleSkipTap() {
          _debugLog(
            'skipTap index=${widget.currentIndex} step="${step.title}" '
            'isLast=$isLast willDismiss=true',
          );
          widget.onSkip();
        }

        void handleBackTap() {
          _debugLog(
            'backTap index=${widget.currentIndex} step="${step.title}" '
            'isLast=$isLast',
          );
          widget.onBack();
        }

        void handleNextTap() {
          _debugLog(
            '${isLast ? 'doneTap' : 'nextTap'} index=${widget.currentIndex} '
            'step="${step.title}" isLast=$isLast willCallOnNext=true',
          );
          widget.onNext();
        }

        return SizedBox.expand(
          key: InteractiveTutorialOverlay.overlayRootKey,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Listener(
                  key: InteractiveTutorialOverlay.modalPointerGateKey,
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) {},
                  onPointerMove: (_) {},
                  onPointerUp: (_) {},
                  onPointerCancel: (_) {},
                  onPointerSignal: (_) {},
                  child: CustomPaint(
                    painter: _CoachMarkPainter(
                      highlightRect: highlightRect,
                      color: Colors.black.withValues(alpha: 0.55),
                      accent: scheme.primary,
                    ),
                  ),
                ),
              ),

              if (shouldHandleTargetTap)
                Positioned.fromRect(
                  rect: highlightRect,
                  child: GestureDetector(
                    key: InteractiveTutorialOverlay.highlightTapRegionKey,
                    behavior: HitTestBehavior.translucent,
                    onTap: handleTargetTap,
                    child: const SizedBox.expand(),
                  ),
                ),

              // Skip button
              Positioned(
                top: safe.top + 10,
                right: 12,
                child: _GlassActionChip(
                  label: widget.skipLabel,
                  onTap: handleSkipTap,
                ),
              ),

              // Tooltip
              Positioned(
                left: tooltipX,
                top: tooltipY,
                width: tooltipWidth,
                child: KeyedSubtree(
                  key: InteractiveTutorialOverlay.tooltipKey,
                  child: _TutorialTooltipCard(
                    title: step.title,
                    body: step.body,
                    icon: step.icon,
                    stepLabel: stepLabel,
                    backLabel: widget.backLabel,
                    nextLabel: isLast ? widget.doneLabel : widget.nextLabel,
                    showBack: widget.currentIndex > 0,
                    onBack: handleBackTap,
                    onNext: handleNextTap,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('InteractiveTutorialOverlay: $message');
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
        const Radius.circular(KubusRadius.lg),
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
