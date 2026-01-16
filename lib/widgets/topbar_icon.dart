import 'package:flutter/material.dart';

import 'glass_components.dart';

class TopBarIcon extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final int? badgeCount;
  final Color? badgeColor;
  final double? size;

  const TopBarIcon({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.badgeCount,
    this.badgeColor,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 375;
    final containerSize = size ?? (isSmallScreen ? 40.0 : 44.0);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final radius = BorderRadius.circular(10);
    final glassTint = scheme.surface.withValues(alpha: isDark ? 0.16 : 0.10);

    Widget inner = IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: icon,
      onPressed: onPressed,
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      inner = Tooltip(message: tooltip!, child: inner);
    }

    return SizedBox(
      width: containerSize,
      height: containerSize,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: scheme.outline.withValues(alpha: 0.16),
          ),
        ),
        child: LiquidGlassPanel(
          padding: EdgeInsets.zero,
          margin: EdgeInsets.zero,
          borderRadius: radius,
          showBorder: false,
          backgroundColor: glassTint,
          child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            inner,
            if ((badgeCount ?? 0) > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor ?? theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.scaffoldBackgroundColor, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 18),
                  child: Center(
                    child: Text(
                      (badgeCount ?? 0) > 99 ? '99+' : '${badgeCount ?? 0}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}
