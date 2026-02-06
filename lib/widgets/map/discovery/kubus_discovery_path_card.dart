import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../glass_components.dart';
import '../../inline_progress.dart';

/// Shared UI for the "Discovery path" module shown on both mobile and desktop
/// map screens.
///
/// Notes:
/// - No provider reads.
/// - Caller owns state (expanded/collapsed) and supplies task rows.
class KubusDiscoveryPathCard extends StatelessWidget {
  final double overallProgress;
  final bool expanded;
  final List<Widget> taskRows;

  /// Caller-provided toggle button so mobile/desktop can keep their own glass
  /// button implementation.
  final Widget toggleButton;

  final TextStyle? titleStyle;
  final TextStyle? percentStyle;

  final EdgeInsets glassPadding;
  final BoxConstraints? constraints;
  final bool enableMouseRegion;
  final MouseCursor mouseCursor;

  final double badgeGap;
  final double tasksTopGap;

  const KubusDiscoveryPathCard({
    super.key,
    required this.overallProgress,
    required this.expanded,
    required this.taskRows,
    required this.toggleButton,
    required this.titleStyle,
    required this.percentStyle,
    this.glassPadding = const EdgeInsets.all(14),
    this.constraints,
    this.enableMouseRegion = false,
    this.mouseCursor = SystemMouseCursors.basic,
    this.badgeGap = 10,
    this.tasksTopGap = 10,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final roles = KubusColorRoles.of(context);
    final badgeGradient = LinearGradient(
      colors: [
        roles.statTeal,
        roles.statAmber,
        roles.statCoral,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(18);
    final glassTint = scheme.surface.withValues(alpha: isDark ? 0.40 : 0.52);

    Widget card = Semantics(
      label: 'discovery_path',
      container: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        constraints: constraints,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.30),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: isDark ? 0.16 : 0.10),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: LiquidGlassPanel(
          padding: glassPadding,
          margin: EdgeInsets.zero,
          borderRadius: radius,
          showBorder: false,
          backgroundColor: glassTint,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShaderMask(
                    shaderCallback: (rect) =>
                        badgeGradient.createShader(rect),
                    blendMode: BlendMode.srcIn,
                    child: InlineProgress(
                      progress: overallProgress,
                      rows: 3,
                      cols: 5,
                      color: scheme.onSurface,
                      backgroundColor: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  SizedBox(width: badgeGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.mapDiscoveryPathTitle,
                          style: titleStyle,
                        ),
                        Text(
                          l10n.commonPercentComplete(
                            (overallProgress * 100).round(),
                          ),
                          style: percentStyle,
                        ),
                      ],
                    ),
                  ),
                  toggleButton,
                ],
              ),
              AnimatedCrossFade(
                crossFadeState: expanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 200),
                firstChild: Column(
                  children: [
                    SizedBox(height: tasksTopGap),
                    ...taskRows,
                  ],
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );

    if (enableMouseRegion) {
      card = MouseRegion(cursor: mouseCursor, child: card);
    }

    return card;
  }
}
